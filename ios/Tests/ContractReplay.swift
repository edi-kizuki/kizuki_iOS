import Foundation
import KizukiCore

final class ContractBundleMarker: NSObject {}

/// Versioned, credential-free transport recordings. Unknown operations fail instead of being skipped.
struct RepositoryContract: Decodable {
    struct Request: Decodable { let method: String; let path: String; let query: [String: String] }
    struct Response: Decodable { let status: Int; let body: String }
    struct Expected: Decodable { let profile: Profile?; let fails: Bool }
    let version: Int
    let operation: String
    let userID: UUID
    let request: Request
    let response: Response
    let expected: Expected
}
