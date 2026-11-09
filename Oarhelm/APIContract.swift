import Foundation

struct ConsoleOperation: Identifiable {
    let id: String, method: String, path: String, title: String, group: String
    let spec: JSONValue
    var isStream: Bool { path.hasSuffix("/stream") }
    var needsConfirmation: Bool { method != "GET" }
}
enum Catalog {
    static let document: JSONValue = {
        guard let url = Bundle.main.url(forResource: "openapi", withExtension: "json"), let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return .null }
        return value
    }()
    static let operations: [ConsoleOperation] = {
        guard case .object(let paths) = document["paths"] else { return [] }
        var result: [ConsoleOperation] = []
        for (path, value) in paths {
            guard case .object(let methods) = value else { continue }
            for (method, spec) in methods where ["get", "post", "put", "patch", "delete"].contains(method) {
                guard let id = spec["operationId"]?.stringValue else { continue }
                result.append(.init(id: id, method: method.uppercased(), path: path, title: spec["summary"]?.stringValue ?? id, group: spec["tags"]?.arrayValue?.first?.stringValue ?? "Other", spec: spec))
            }
        }
        return result.sorted { $0.title < $1.title }
    }()
    static func resolve(_ schema: JSONValue) -> JSONValue {
        guard let ref = schema["$ref"]?.stringValue else { return schema }
        return document["components"]?["schemas"]?[String(ref.split(separator: "/").last ?? "")] ?? schema
    }
    static func initial(_ schema: JSONValue, defaults: [String:String] = [:]) -> JSONValue {
        let s = resolve(schema)
        if let first = (s["anyOf"] ?? s["oneOf"])?.arrayValue?.first { return initial(first, defaults: defaults) }
        if let value = s["enum"]?.arrayValue?.first { return value }
        switch s["type"]?.stringValue {
        case "object":
            var object: [String:JSONValue] = [:]
            if case .object(let properties) = s["properties"] {
                for (key, property) in properties where (s["required"]?.arrayValue ?? []).contains(.string(key)) || defaults[key] != nil || ["requestId", "clientKey"].contains(key) {
                    object[key] = defaults[key].map { text in
                        let type = resolve(property)["type"]?.stringValue
                        return ["array", "object", "boolean", "number", "integer"].contains(type ?? "") ? ((try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))) ?? .string(text)) : .string(text)
                    } ?? (key == "requestId" || key == "clientKey" ? .string(UUID().uuidString) : initial(property, defaults: defaults))
                }
            }
            return .object(object)
        case "array": return .array([])
        case "boolean": return .bool(false)
        case "number", "integer": return .number(0)
        case "null": return .null
        default: return .string("")
        }
    }
    static func validate(_ value: JSONValue, schema: JSONValue, name: String = "Request") throws {
        let s = resolve(schema)
        if let choices = (s["anyOf"] ?? s["oneOf"])?.arrayValue {
            guard choices.contains(where: { (try? validate(value, schema: $0, name: name)) != nil }) else { throw CapyError(message: "\(name): choose a valid value.") }; return
        }
        if let choices = s["enum"]?.arrayValue, !choices.contains(value) { throw CapyError(message: "\(name): choose a listed value.") }
        switch (s["type"]?.stringValue, value) {
        case ("object", .object(let object)):
            for key in s["required"]?.arrayValue?.compactMap(\.stringValue) ?? [] where object[key] == nil { throw CapyError(message: "\(name): \(key) is required.") }
            if case .object(let properties) = s["properties"] { for (key,v) in object {
                if let property = properties[key] { try validate(v, schema: property, name: key) }
                else if s["additionalProperties"] == .bool(false) { throw CapyError(message: "Unknown field: \(key)") }
            } } else if let mapSchema = s["additionalProperties"], case .object = mapSchema { for (key,v) in object { try validate(v, schema: mapSchema, name: key) } }
        case ("array", .array(let items)): if let schema = s["items"] { for item in items { try validate(item, schema: schema, name: name) } }
        case ("string", .string(let text)):
            if let min = s["minLength"], case .number(let n) = min, text.count < Int(n) { throw CapyError(message: "\(name) needs at least \(Int(n)) characters.") }
        case ("boolean", .bool), ("number", .number), ("null", .null): break
        case ("integer", .number(let n)): if n.rounded() != n { throw CapyError(message: "\(name) must be an integer.") }
        case (nil, _): break
        default: throw CapyError(message: "\(name) has the wrong type.")
        }
    }
}
