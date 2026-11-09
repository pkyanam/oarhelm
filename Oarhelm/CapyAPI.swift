import Foundation
import Observation
import Security

enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let v): try c.encode(v); case .array(let v): try c.encode(v); case .string(let v): try c.encode(v); case .number(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .null: try c.encodeNil() }
    }
    subscript(_ key: String) -> JSONValue? { if case .object(let v) = self { return v[key] }; return nil }
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    var prettyText: String { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return (try? String(data: e.encode(self), encoding: .utf8)) ?? "null" }
}

struct CapyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ConnectionPhase: Equatable { case disconnected, connecting, connected, failed(String) }

@MainActor @Observable final class CapyStore {
    private(set) var connectionPhase = ConnectionPhase.disconnected
    private(set) var apiKey: String
    private(set) var isConnected = false
    private(set) var accountRevision = 0
    private(set) var projects: [JSONValue] = []
    var selectedProjectID = ""
    var streamEvents: [String] = []
    private let service = "ai.capy.oarhelm"
    private var connectionGeneration = 0
    private var projectRefreshGeneration = 0
    private let session: URLSession
    private let persistsKey: Bool
    init(session: URLSession = .shared, persistsKey: Bool = true) {
        self.session = session; self.persistsKey = persistsKey
        if !persistsKey { apiKey = ""; return }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "ai.capy.oarhelm", kSecAttrAccount as String: "apiKey", kSecReturnData as String: true]
        var result: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data { apiKey = String(data: data, encoding: .utf8) ?? "" } else { apiKey = "" }
    }
    private func saveKey() {
        guard persistsKey else { return }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "apiKey"]
        SecItemDelete(q as CFDictionary)
        if !apiKey.isEmpty { var item = q; item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly; item[kSecValueData as String] = Data(apiKey.utf8); SecItemAdd(item as CFDictionary, nil) }
    }
    func connect(key: String) async throws {
        connectionGeneration += 1
        let generation = connectionGeneration
        let old = apiKey; let wasConnected = isConnected
        connectionPhase = .connecting
        do {
            let request = try makeRequest("GET", "/api/v1/projects", query: [:], body: nil, key: key)
            let (data, response) = try await session.data(for: request)
            try check(response, data: data)
            let result = data.isEmpty ? JSONValue.null : try JSONDecoder().decode(JSONValue.self, from: data)
            guard generation == connectionGeneration, !Task.isCancelled else { throw CancellationError() }
            apiKey = key; projects = result["items"]?.arrayValue ?? []
            selectedProjectID = projects.first?["id"]?.stringValue ?? ""
            isConnected = true; connectionPhase = .connected; saveKey()
            if wasConnected && old != key { accountRevision += 1 }
        } catch {
            guard generation == connectionGeneration else { throw CancellationError() }
            if Task.isCancelled { isConnected = wasConnected; connectionPhase = wasConnected ? .connected : .disconnected; throw CancellationError() }
            isConnected = wasConnected; connectionPhase = wasConnected ? .connected : .failed(error.localizedDescription)
            throw error
        }
    }
    func refreshProjects() async throws {
        projectRefreshGeneration += 1; let refreshGeneration = projectRefreshGeneration
        let generation = connectionGeneration; let key = apiKey
        let result = try await request("GET", "/api/v1/projects")
        guard generation == connectionGeneration, refreshGeneration == projectRefreshGeneration, key == apiKey, isConnected, !Task.isCancelled else { throw CancellationError() }
        let refreshed = result["items"]?.arrayValue ?? []
        projects = refreshed
        if !refreshed.contains(where: { $0["id"]?.stringValue == selectedProjectID }) {
            selectedProjectID = refreshed.first?["id"]?.stringValue ?? ""
        }
    }
    func disconnect() { connectionGeneration += 1; connectionPhase = .disconnected; apiKey = ""; saveKey(); isConnected = false; projects = []; selectedProjectID = ""; streamEvents = []; accountRevision += 1 }
    private func makeRequest(_ method: String, _ path: String, query: [String: String], body: JSONValue?, key: String? = nil) throws -> URLRequest {
        guard path.hasPrefix("/api/v1/"), !path.contains(".."), var components = URLComponents(string: "https://api.capy.ai" + path) else { throw CapyError(message: "Invalid API path") }
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.flatMap { key, value -> [URLQueryItem] in
            if let list = try? JSONDecoder().decode([String].self, from: Data(value.utf8)) { return list.map { URLQueryItem(name: key, value: $0) } }
            return [URLQueryItem(name: key, value: value)]
        } }
        guard let url = components.url else { throw CapyError(message: "Invalid URL") }
        let requestKey = key ?? apiKey
        guard !requestKey.isEmpty else { throw CapyError(message: "Connect in Account to use Capy.") }
        var request = URLRequest(url: url); request.httpMethod = method.uppercased(); request.setValue("Bearer \(requestKey)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    private func check(_ response: URLResponse, data: Data = Data()) throws {
        guard let http = response as? HTTPURLResponse else { throw CapyError(message: "Invalid response") }
        guard (200..<300).contains(http.statusCode) else { throw CapyError(message: "HTTP \(http.statusCode) · Retry-After: \(http.value(forHTTPHeaderField: "Retry-After") ?? "none") · \(String(data: data, encoding: .utf8) ?? "")") }
    }
    func request(_ method: String, _ path: String, query: [String: String] = [:], body: JSONValue? = nil) async throws -> JSONValue {
        let (data, response) = try await session.data(for: makeRequest(method, path, query: query, body: body)); try check(response, data: data)
        if data.isEmpty { return .null }; return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    func stream(_ method: String, _ path: String, query: [String: String] = [:], body: JSONValue? = nil, onEvent: (@MainActor (SSEFrame) -> Void)? = nil) async throws {
        if onEvent == nil { streamEvents = [] }
        let generation = connectionGeneration
        var lastID = query["after"]
        var streamQuery = query; streamQuery.removeValue(forKey: "after")
        var retryMS = 2000
        var attempts = 0
        while !Task.isCancelled {
            guard generation == connectionGeneration, isConnected else { throw CancellationError() }
            var req = try makeRequest(method, path, query: streamQuery, body: body)
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if let lastID { req.setValue(lastID, forHTTPHeaderField: "Last-Event-ID") }
            let (bytes, response) = try await session.bytes(for: req)
            try check(response)
            var lines: [String] = []
            for try await line in bytes.lines {
                try Task.checkCancellation()
                guard generation == connectionGeneration, !apiKey.isEmpty else { throw CancellationError() }
                if line.hasPrefix("retry:"), let delay = Int(line.dropFirst(6).trimmingCharacters(in: .whitespaces)) { retryMS = min(60000, max(1000, delay)) }
                if line.isEmpty {
                    guard !lines.isEmpty else { continue }
                    let frame = SSEFrame(lines: lines); lines = []
                    if let id = frame.id { lastID = id }
                    if frame.event != "heartbeat", !frame.data.isEmpty {
                        if let onEvent { onEvent(frame) }
                        else {
                            streamEvents.append(frame.raw)
                            if streamEvents.count > 200 { streamEvents.removeFirst(streamEvents.count - 200) }
                        }
                    }
                    if frame.event == "done" { return }
                    if frame.event == "error" { throw CapyError(message: frame.data) }
                } else { lines.append(line) }
            }
            attempts += 1
            guard attempts <= 3 else { throw CapyError(message: "The live connection closed. Tap Watch events to reconnect.") }
            try await Task.sleep(for: .milliseconds(retryMS))
        }
    }
}

struct SSEFrame: Sendable {
    let lines: [String]
    var event: String { field("event") ?? "message" }
    var id: String? { field("id") }
    var data: String { lines.filter { $0.hasPrefix("data:") }.map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n") }
    var raw: String { lines.joined(separator: "\n") }
    private func field(_ name: String) -> String? { lines.first { $0.hasPrefix(name + ":") }.map { String($0.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespaces) } }
}

struct UploadedFile: Identifiable, Sendable {
    let id: String
    let name: String
    var messageValue: JSONValue { .object(["fileId": .string(id), "name": .string(name)]) }
}
