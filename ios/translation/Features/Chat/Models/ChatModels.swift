import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ChatAttachment: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case image }

    let id: UUID
    var kind: Kind
    var mimeType: String
    private var storage: Data

    init(id: UUID = UUID(), kind: Kind, mimeType: String, data: Data) {
        self.id = id
        self.kind = kind
        self.mimeType = mimeType
        self.storage = data
    }

    var data: Data { storage }

    #if canImport(UIKit)
    var uiImage: UIImage? { UIImage(data: storage) }
    #endif

    private enum CodingKeys: String, CodingKey { case id, kind, mimeType, base64 }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        let base64 = try container.decode(String.self, forKey: .base64)
        guard let data = Data(base64Encoded: base64) else {
            throw DecodingError.dataCorruptedError(forKey: .base64, in: container, debugDescription: "Invalid base64 data")
        }
        storage = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(storage.base64EncodedString(), forKey: .base64)
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    var role: Role
    var content: String
    var attachments: [ChatAttachment]

    init(id: UUID = UUID(), role: Role, content: String, attachments: [ChatAttachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
    }
}

struct ChatTurnResponse: Codable, Equatable {
    var reply: String
    var state: State
    var checklist: [String]?

    enum State: String, Codable { case gathering, ready, completed }
}

struct ChatResearchItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var term: String
    var explanation: String
    var context: String
    var type: ErrorType

    private enum CodingKeys: String, CodingKey {
        case term
        case explanation
        case context
        case type
    }

    init(id: UUID = UUID(), term: String, explanation: String, context: String, type: ErrorType) {
        self.id = id
        self.term = term
        self.explanation = explanation
        self.context = context
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        explanation = try container.decode(String.self, forKey: .explanation)
        context = try container.decode(String.self, forKey: .context)
        let rawType = try container.decode(String.self, forKey: .type)
        type = ErrorType(rawValue: rawType) ?? .lexical
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(term, forKey: .term)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(context, forKey: .context)
        try container.encode(type.rawValue, forKey: .type)
    }
}

struct ChatResearchResponse: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var items: [ChatResearchItem]

    private enum CodingKeys: String, CodingKey { case items }
}
