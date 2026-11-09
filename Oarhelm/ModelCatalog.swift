import Foundation

struct CapyModel: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let provider: String
}

enum CapyModelCatalog {
    private struct Snapshot: Decodable, Sendable {
        let source: String
        let fetchedAt: String
        let models: [CapyModel]
    }

    private static let snapshot: Snapshot? = {
        guard let url = Bundle.main.url(forResource: "capy-models", withExtension: "json") ??
                Bundle.main.url(forResource: "capy-models", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              !snapshot.models.isEmpty,
              snapshot.models.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty }),
              Set(snapshot.models.map(\.id)).count == snapshot.models.count else { return nil }
        return snapshot
    }()

    static var models: [CapyModel] { snapshot?.models ?? [] }
    static var fetchedAt: String? { snapshot.map { String($0.fetchedAt.prefix(10)) } }
    static func displayName(for id: String) -> String {
        if id.isEmpty { return "Default" }
        return models.first(where: { $0.id == id })?.name ?? id
    }
    static func provider(for id: String) -> String {
        if id.isEmpty { return "capy" }
        return models.first(where: { $0.id == id })?.provider ?? id.split(separator: "/").first.map(String.init) ?? "capy"
    }
    static func providerName(_ provider: String) -> String {
        ["openai": "OpenAI", "xai": "xAI", "zai": "Z.ai", "deepseek": "DeepSeek", "minimax": "MiniMax", "moonshotai": "Moonshot", "nvidia": "NVIDIA", "qwen": "Qwen", "capy": "Capy"][provider] ?? provider.capitalized
    }
}
