import Foundation

/// A named section of tokens. Same shape as a 2FAS backup group.
public struct TokenGroup: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isExpanded: Bool

    public init(id: String = UUID().uuidString, name: String, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.isExpanded = isExpanded
    }
}
