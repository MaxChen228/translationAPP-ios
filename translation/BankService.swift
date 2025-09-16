import Foundation

struct BankService {
    struct APIError: Error, LocalizedError { var errorDescription: String? { message }; let message: String }
    // no local seed data; backend is required

    func fetchRandom(difficulty: Int? = nil, tag: String? = nil, deviceId: String? = DeviceID.current, skipCompleted: Bool = false) async throws -> BankItem {
        if let base = AppConfig.backendURL {
            var comp = URLComponents(url: base.appendingPathComponent("/bank/random"), resolvingAgainstBaseURL: false)!
            var q: [URLQueryItem] = []
            if let d = difficulty { q.append(URLQueryItem(name: "difficulty", value: String(d))) }
            if let t = tag, !t.isEmpty { q.append(URLQueryItem(name: "tag", value: t)) }
            if let dev = deviceId, !dev.isEmpty { q.append(URLQueryItem(name: "deviceId", value: dev)) }
            if skipCompleted { q.append(URLQueryItem(name: "skipCompleted", value: "1")) }
            if !q.isEmpty { comp.queryItems = q }
            let (data, resp) = try await URLSession.shared.data(from: comp.url!)
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError(message: "bank_http_\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .useDefaultKeys
            return try dec.decode(BankItem.self, from: data)
        } else {
            throw APIError(message: "BACKEND_URL missing")
        }
    }

    func fetchItems(limit: Int = 50, offset: Int = 0, difficulty: Int? = nil, tag: String? = nil, deviceId: String? = DeviceID.current) async throws -> [BankItem] {
        if let base = AppConfig.backendURL {
            var comp = URLComponents(url: base.appendingPathComponent("/bank/items"), resolvingAgainstBaseURL: false)!
            var q: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if let d = difficulty { q.append(URLQueryItem(name: "difficulty", value: String(d))) }
            if let t = tag, !t.isEmpty { q.append(URLQueryItem(name: "tag", value: t)) }
            if let dev = deviceId, !dev.isEmpty { q.append(URLQueryItem(name: "deviceId", value: dev)) }
            comp.queryItems = q
            AppLog.uiInfo("[bank] HTTP GET /bank/items url=\(comp.url!.absoluteString)")
            let (data, resp) = try await URLSession.shared.data(from: comp.url!)
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError(message: "bank_http_\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .useDefaultKeys
            return try dec.decode([BankItem].self, from: data)
        } else {
            throw APIError(message: "BACKEND_URL missing")
        }
    }

    struct BankBook: Codable, Identifiable, Equatable { var id: String { name }; let name: String; let count: Int; let difficultyMin: Int; let difficultyMax: Int }

    func fetchBooks() async throws -> [BankBook] {
        if let base = AppConfig.backendURL {
            let url = base.appendingPathComponent("/bank/books")
            AppLog.uiInfo("[bank] HTTP GET /bank/books url=\(url.absoluteString)")
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw APIError(message: "bank_http_\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            let dec = JSONDecoder()
            return try dec.decode([BankBook].self, from: data)
        } else {
            throw APIError(message: "BACKEND_URL missing")
        }
    }

    struct ImportResult: Codable { let imported: Int; let errors: [String]? }

    func importClipboard(text: String, defaultTag: String? = nil, replace: Bool = false) async throws -> ImportResult {
        guard let base = AppConfig.backendURL else { throw APIError(message: "BACKEND_URL missing") }
        var req = URLRequest(url: base.appendingPathComponent("/bank/import"))
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = ["Content-Type": "application/json"]
        let payload: [String: Any?] = [
            "text": text,
            "defaultTag": defaultTag,
            "replace": replace
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 }, options: [])
        AppLog.uiInfo("[bank] HTTP POST /bank/import bytes=\(text.utf8.count)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError(message: "bank_http_\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        return try JSONDecoder().decode(ImportResult.self, from: data)
    }
}
