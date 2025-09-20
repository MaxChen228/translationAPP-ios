import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    var role: Role
    var content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct ChatTurnResponse: Codable, Equatable {
    var reply: String
    var state: State
    var checklist: [String]?

    enum State: String, Codable { case gathering, ready, completed }
}

struct ChatResearchResponse: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var sourceZh: String?
    var attemptEn: String?
    var correctedEn: String
    var errors: [ErrorItem]

    private enum CodingKeys: String, CodingKey {
        case title, summary, sourceZh, attemptEn, correctedEn, errors
    }
}
