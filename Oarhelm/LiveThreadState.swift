import Foundation

/// Bounded, deterministic projection of the durable transcript and transient stream.
struct LiveThreadState {
    var messages: [JSONValue] = []
    var previews: [String: String] = [:]
    var tools: [String: String] = [:]
    var helpers: [String: String] = [:]
    var status: String?
    var cursor: String?
    static let historyLimit = 1000
    static let previewLimit = 32000
    static let activityLimit = 100

    mutating func upsert(_ message: JSONValue) {
        guard let id = message["id"]?.stringValue else { return }
        if let index = messages.firstIndex(where: { $0["id"]?.stringValue == id }) { messages[index] = message }
        else { messages.append(message) }
        if messages.count > Self.historyLimit { messages.removeFirst(messages.count - Self.historyLimit) }
        if let call = message["callId"]?.stringValue { previews.removeValue(forKey: call) }
        tools.removeValue(forKey: id)
    }
    mutating func apply(_ frame: SSEFrame) {
        guard let data = frame.data.data(using: .utf8), let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return }
        switch frame.event {
        case "status": status = value["status"]?.stringValue; previews.removeAll(); tools.removeAll()
        case "assistant":
            guard let id = value["callId"]?.stringValue, let text = value["text"]?.stringValue else { return }
            previews[id] = String((previews[id, default: ""] + text).suffix(Self.previewLimit))
            Self.trim(&previews)
        case "tool_call":
            guard let id = value["callId"]?.stringValue else { return }
            tools[id] = String(([value["name"]?.stringValue, value["text"]?.stringValue].compactMap { $0 }.joined(separator: " · ")).prefix(1200)); Self.trim(&tools)
        case "transcript": upsert(value); if let id = frame.id { cursor = id }
        case "run": if value["phase"]?.stringValue == "end" { previews.removeAll(); tools.removeAll() }
        case "turn": if value["outcome"]?.stringValue == "dropped" { previews.removeAll(); tools.removeAll() }
        case "subagent":
            if let id = value["id"]?.stringValue ?? value["subagentId"]?.stringValue { helpers[id] = String((value["status"]?.stringValue ?? "active").prefix(100)); Self.trim(&helpers) }
        default: break
        }
    }
    private static func trim(_ values: inout [String: String]) { while values.count > Self.activityLimit, let key = values.keys.sorted().first { values.removeValue(forKey: key) } }
}
