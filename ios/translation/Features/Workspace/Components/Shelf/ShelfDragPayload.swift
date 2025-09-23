import Foundation

struct ShelfDragPayload {
    var primaryID: String
    var selectedIDs: [String]

    func encodedString() -> String {
        let unique = Array(Set(selectedIDs))
        guard unique.count > 1 else {
            return primaryID
        }

        let payload: [String: Any] = [
            "primary": primaryID,
            "selected": unique
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return primaryID
    }

    static func decode(from string: String) -> ShelfDragPayload {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let primary = json["primary"] as? String,
              let selected = json["selected"] as? [String] else {
            return ShelfDragPayload(primaryID: string, selectedIDs: [string])
        }
        return ShelfDragPayload(primaryID: primary, selectedIDs: selected)
    }
}
