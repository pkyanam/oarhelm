import SwiftUI
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case helm, threads, workspace, account
    var id: String { rawValue }
    var title: String { switch self { case .helm: "Helm"; case .threads: "Threads"; case .workspace: "Workspace"; case .account: "Account" } }
    var symbol: String { switch self { case .helm: "sailboat"; case .threads: "bubble.left.and.bubble.right"; case .workspace: "square.stack.3d.up"; case .account: "person.crop.circle" } }
}
enum AppSheet: String, Identifiable { case connect, newThread; var id: String { rawValue } }
enum AppRoute: Hashable {
    case thread(JSONValue), operation(String, [String:String]), advancedOperation(String, [String:String]), resource(String,String,String,String?), resourceItem(String,JSONValue), data(String,String), reviews, usage, issueSettings, helpers(String), controls
    func isSameDestination(as other: AppRoute) -> Bool {
        switch (self, other) {
        case let (.thread(a), .thread(b)):
            if let id = a["id"]?.stringValue, !id.isEmpty { return id == b["id"]?.stringValue }
        case let (.resourceItem(kindA, a), .resourceItem(kindB, b)) where kindA == kindB:
            if let id = a["id"]?.stringValue, !id.isEmpty { return id == b["id"]?.stringValue }
        default: break
        }
        return self == other
    }
}
enum SendPhase: Equatable { case ready, sending, failed(String) }

@MainActor @Observable final class OperationDraft {
    var parameters: [String:String] = [:]
    var requestBody: JSONValue = .object([:])
    var advanced = false
    var bodyText = ""
    var initialized = false
    var lastPayload: JSONValue?
}
@MainActor @Observable final class AppRouter {
    var section: AppSection = .helm
    private(set) var paths: [AppSection:[AppRoute]] = [:]
    var sheet: AppSheet?
    var browser: BrowserSession?
    var onboarding = OnboardingState()
    var connectionOnboarding = OnboardingState(step: .keyGuide)
    func browse(_ url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        guard browser?.url != url else { return }
        browser = BrowserSession(url: url)
    }

    var drafts: [String:String] = [:]
    var deliveries: [String:String] = [:]
    var attachments: [String:[UploadedFile]] = [:]
    var sendPhases: [String:SendPhase] = [:]
    private var messageKeys: [String:String] = [:]
    private var messagePayloads: [String:JSONValue] = [:]
    var uploadingFiles: [String:Int] = [:]
    var operationDrafts: [String:OperationDraft] = [:]
    func beginSend(_ id: String, payload: JSONValue = .null) -> String? {
        guard sendPhases[id] != .sending, uploadingFiles[id, default: 0] == 0 else { return nil }
        let key = messagePayloads[id] == payload ? (messageKeys[id] ?? UUID().uuidString) : UUID().uuidString
        messagePayloads[id] = payload
        messageKeys[id] = key; sendPhases[id] = .sending; return key
    }
    func finishSend(_ id: String) { drafts[id] = ""; attachments[id] = []; messageKeys[id] = nil; messagePayloads[id] = nil; sendPhases[id] = .ready }
    func failSend(_ id: String, message: String) { sendPhases[id] = .failed(message) }
    /// Return to the home root while preserving other navigation stacks and unsent work.
    func goHome() { sheet = nil; paths[.helm] = []; section = .helm }
    func select(_ section: AppSection) { self.section = section }
    /// Sidebar destinations are roots within Workspace, independent of prior history.
    func selectWorkspaceRoot(_ route: AppRoute) {
        paths[.workspace] = [route]
        section = .workspace
    }
    private func canonicalPath(_ proposed: [AppRoute]) -> [AppRoute] {
        var result: [AppRoute] = []
        for route in proposed {
            if let index = result.firstIndex(where: { $0.isSameDestination(as: route) }) { result = Array(result.prefix(index)) + [route] }
            else { result.append(route) }
        }
        return result
    }
    func open(_ route: AppRoute) { paths[section] = canonicalPath((paths[section] ?? []) + [route]) }
    func replaceTop(_ route: AppRoute) { paths[section] = canonicalPath(Array((paths[section] ?? []).dropLast()) + [route]) }
    func reset() { paths = [:]; drafts = [:]; deliveries = [:]; attachments = [:]; sendPhases = [:]; messageKeys = [:]; messagePayloads = [:]; uploadingFiles = [:]; operationDrafts = [:]; browser = nil; sheet = nil; onboarding.key = ""; connectionOnboarding.key = ""; onboarding = OnboardingState(); connectionOnboarding = OnboardingState(step: .keyGuide); section = .helm }
    func path(for section: AppSection) -> Binding<[AppRoute]> { Binding(get: { self.paths[section] ?? [] }, set: { self.paths[section] = self.canonicalPath($0) }) }
}
