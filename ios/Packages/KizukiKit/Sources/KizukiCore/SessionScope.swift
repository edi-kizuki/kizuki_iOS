// Related: [[2026-10-25-architecture-concept-v2]], [[012-b01-live-composition-seam]].
import Foundation

/// One account generation. Register tasks, channel removals and cache purges here.
/// Cleanup is awaited before the next account becomes visible.
@MainActor
public final class SessionScope {
    public let userID: UUID
    public let generation: Int
    public private(set) var isCancelled = false
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var cleanups: [UUID: @Sendable () async -> Void] = [:]
    private var cancellation: Task<Void, Never>?

    public init(userID: UUID, generation: Int) {
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
        tasks.removeValue(forKey: id)?.cancel()
        if let cleanup = cleanups.removeValue(forKey: id) { await cleanup() }
    }

    public func cancel() async {
        if let cancellation { await cancellation.value; return }
        isCancelled = true
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        let callbacks = Array(cleanups.values)
        cleanups.removeAll()
        let work = Task { for cleanup in callbacks { await cleanup() } }
        cancellation = work
        await work.value
    }
}
