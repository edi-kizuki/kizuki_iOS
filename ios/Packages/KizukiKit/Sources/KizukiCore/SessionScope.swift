// Related: [[2026-10-25-architecture-concept-v2]], [[012-b01-live-composition-seam]].
import Foundation

/// One account generation. Register tasks, channel removals and cache purges here.
/// Tasks and cleanup are awaited within a shared deadline before the next account becomes visible.
/// Cancellation-ignoring work may finish later: every cache/state write must check isCancelled.
/// Account stores remain generation-scoped; a timed-out old scope cannot publish to a new one.
@MainActor
public final class SessionScope {
    public let userID: UUID
    public let generation: Int
    public private(set) var isCancelled = false
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var cleanups: [UUID: @Sendable () async -> Void] = [:]
    private let cleanupTimeout: Duration
    private var cancellation: Task<Void, Never>?

    public init(userID: UUID, generation: Int, cleanupTimeout: Duration = .seconds(2)) {
        self.cleanupTimeout = cleanupTimeout
        self.userID = userID
        self.generation = generation
    }

    @discardableResult
    public func run(_ operation: @escaping @Sendable () async -> Void) -> UUID {
        let id = UUID()
        guard !isCancelled else { return id }
        tasks[id] = Task { [weak self] in
            guard !Task.isCancelled else { return }
            await operation()
            self?.tasks[id] = nil
        }
        return id
    }

    /// Also use on view/AsyncStream termination; removal runs exactly once.
    @discardableResult
    public func onCancel(_ cleanup: @escaping @Sendable () async -> Void) -> UUID {
        let id = UUID()
        if isCancelled { Task { await cleanup() } }
        else { cleanups[id] = cleanup }
        return id
    }

    public func remove(_ id: UUID) async {
        let task = tasks.removeValue(forKey: id)
        task?.cancel()
        let cleanup = cleanups.removeValue(forKey: id)
        await Self.bounded(timeout: cleanupTimeout) {
            await task?.value
            await cleanup?()
        }
    }

    public func cancel() async {
        if let cancellation { await cancellation.value; return }
        isCancelled = true
        let pending = Array(tasks.values)
        pending.forEach { $0.cancel() }
        tasks.removeAll()
        let callbacks = Array(cleanups.values)
        cleanups.removeAll()
        let timeout = cleanupTimeout
        let work = Task {
            await Self.bounded(timeout: timeout) {
                await withTaskGroup(of: Void.self) { group in
                    for task in pending { group.addTask { await task.value } }
                    for cleanup in callbacks { group.addTask { await cleanup() } }
                }
            }
        }
        cancellation = work
        await work.value
    }

    /// An unstructured race is intentional: a structured timeout would await an uncooperative child forever.
    private static func bounded(timeout: Duration, operation: @escaping @Sendable () async -> Void) async {
        let (stream, completion) = AsyncStream<Void>.makeStream()
        let work = Task { await operation(); completion.yield(()); completion.finish() }
        let deadline = Task {
            do { try await Task.sleep(for: timeout) } catch { return }
            completion.yield(())
            completion.finish()
        }
        for await _ in stream { break }
        work.cancel()
        deadline.cancel()
    }
}
