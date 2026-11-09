import Foundation

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.responder!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: ["Content-Type":"application/json", "Retry-After":"5"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@main struct Checks {
    @MainActor static func main() async throws {
        try await asyncStateChecks()
        let router = AppRouter()
        router.drafts["a"] = "Preserve this draft"
        router.open(.thread(.object(["id": .string("a")])))
        router.select(.workspace); router.open(.reviews); router.select(.helm)
        precondition(router.paths[.helm]?.count == 1 && router.paths[.workspace]?.count == 1 && router.drafts["a"] != nil)
        let captain = AppRoute.resource("Captains", "/api/v1/captains", "captains", "captains.create")
        router.selectWorkspaceRoot(captain); router.selectWorkspaceRoot(captain)
        precondition(router.paths[.workspace] == [captain])
        router.open(.operation("captains.create", [:])); router.open(.operation("captains.create", [:]))
        precondition(router.paths[.workspace] == [captain, .operation("captains.create", [:])])
        router.selectWorkspaceRoot(.reviews); router.selectWorkspaceRoot(captain)
        precondition(router.paths[.workspace] == [captain] && router.paths[.helm]?.count == 1 && router.drafts["a"] == "Preserve this draft")
        router.path(for: .workspace).wrappedValue = [captain, .reviews, captain]
        precondition(router.paths[.workspace] == [captain])
        let refreshedThread = AppRoute.thread(.object(["id": .string("a"), "status": .string("working")]))
        router.select(.helm); router.open(refreshedThread); precondition(router.paths[.helm] == [refreshedThread])
        router.goHome()
        precondition(router.section == .helm && router.paths[.helm]?.isEmpty == true && router.paths[.workspace]?.count == 1 && router.drafts["a"] == "Preserve this draft")
        let firstKey = router.beginSend("a")!; precondition(router.beginSend("a") == nil)
        router.failSend("a", message:"Retry"); precondition(router.beginSend("a") == firstKey)
        router.finishSend("a"); precondition(router.drafts["a"] == "" && router.beginSend("a") != firstKey)
        router.failSend("a", message:"Retry")
        let revisedKey = router.beginSend("a", payload: .string("changed message")); precondition(revisedKey != firstKey)
        router.failSend("a", message:"Upload in progress"); router.uploadingFiles["a"] = 1; precondition(router.beginSend("a") == nil)
        let form = OperationDraft(); form.bodyText = "retained"; router.operationDrafts["op"] = form
        router.select(.account); precondition(router.operationDrafts["op"]?.bodyText == "retained")
        router.onboarding.key = "secret"; router.connectionOnboarding.key = "secret"
        router.reset(); precondition(router.paths.isEmpty && router.drafts.isEmpty && router.onboarding.key.isEmpty && router.connectionOnboarding.key.isEmpty)
        let setup = OnboardingState()
        setup.advance(connected: false); precondition(setup.step == .keyGuide)
        setup.advance(connected: false); setup.advance(connected: false); precondition(setup.step == .keyEntry)
        setup.key = "test-only"; setup.advance(connected: true); precondition(setup.step == .project && setup.key.isEmpty)
        setup.advance(connected: true); precondition(setup.step == .ready)
        let url = URL(string: "https://docs.capy.ai")!
        router.sheet = .connect; router.browse(url)
        precondition(router.sheet == .connect && router.browser?.url == url)
        let browser = router.browser!; browser.dockControls(); precondition(browser.overlayMode == .docked)
        browser.hideControls(); precondition(browser.overlayMode == .hidden)
        browser.restoreControls(); precondition(browser.overlayMode == .visible)
        router.browser = nil; precondition(router.sheet == .connect)
        router.reset()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]
        let store = CapyStore(session: URLSession(configuration: config), persistsKey: false)
        StubProtocol.responder = { request in
            precondition(request.url!.absoluteString == "https://api.capy.ai/api/v1/projects")
            precondition(request.value(forHTTPHeaderField:"Authorization") == "Bearer test-only-key")
            return (200, Data(#"{"items":[{"id":"contract-project","name":"Contract fixture"}]}"#.utf8))
        }
        try await store.connect(key: "test-only-key")
        precondition(store.isConnected && store.selectedProjectID == "contract-project" && store.projects.count == 1)
        StubProtocol.responder = { request in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL:false)!.queryItems!
            precondition(q.filter { $0.name == "groupBy" }.map(\.value) == ["user", "item"])
            return (200, Data("{}".utf8))
        }
        _ = try await store.request("GET", "/api/v1/usage/series", query:["groupBy": "[\"user\",\"item\"]"])
        StubProtocol.responder = { _ in (429, Data(#"{"_tag":"capy/RateLimited","retryAfterSeconds":5}"#.utf8)) }
        do { _ = try await store.request("GET", "/api/v1/projects"); fatalError("Expected rate limit") }
        catch { precondition(error.localizedDescription.contains("429") && error.localizedDescription.contains("RateLimited") && error.localizedDescription.contains("5")) }
        do { try await store.refreshProjects(); fatalError("Expected refresh failure") } catch {}
        precondition(store.isConnected && store.apiKey == "test-only-key" && store.projects.count == 1 && store.selectedProjectID == "contract-project")
        do { try await store.connect(key: "replacement-key"); fatalError("Expected replacement failure") } catch {}
        precondition(store.isConnected && store.apiKey == "test-only-key" && store.accountRevision == 0)
        StubProtocol.responder = { _ in (200, Data(#"{"items":[]}"#.utf8)) }
        try await store.connect(key: "new-account-key")
        precondition(store.isConnected && store.accountRevision == 1 && store.projects.isEmpty)
        do { _ = try await store.request("GET", "/api/v1/../secrets"); fatalError("Expected invalid path") } catch {}
        store.disconnect(); precondition(!store.isConnected && store.apiKey.isEmpty && store.projects.isEmpty && store.accountRevision == 2)
        let data = Data(#"{"a":[1,true,null,"x"],"b":{"c":2}}"#.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from:data)
        let roundtrip = try JSONDecoder().decode(JSONValue.self, from:JSONEncoder().encode(value)); precondition(roundtrip == value)
        precondition(Catalog.operations.count == 108)
        for op in Catalog.operations {
            precondition(op.path.hasPrefix("/api/v1/"))
            if let schema = op.spec["requestBody"]?["content"]?["application/json"]?["schema"] {
                let initial = Catalog.initial(schema, defaults:["projectId":"contract-project"])
                _ = try JSONEncoder().encode(initial)
            }
        }
        let frame = SSEFrame(lines: ["id: event-1", "event: transcript", "data: {\"text\":\"actual frame\"}"])
        precondition(frame.id == "event-1" && frame.event == "transcript" && frame.data.contains("actual frame"))
        let pinSchema = Catalog.document["components"]!["schemas"]!["PinThreadsRequest"]
        if let pinSchema { precondition(Catalog.initial(pinSchema, defaults:["threadIds":"[\"contract-thread\"]"])["threadIds"] == .array([.string("contract-thread")])) }
        let sendSchema = Catalog.document["components"]!["schemas"]!["SendMessageRequest"]!
        precondition(Catalog.initial(sendSchema)["clientKey"]?.stringValue?.isEmpty == false)
        let createSchema = Catalog.document["components"]!["schemas"]!["CreateThreadRequest"]!
        let first = Catalog.initial(createSchema, defaults:["projectId":"contract-project"])
        precondition(first["requestId"]?.stringValue?.isEmpty == false && first["projectId"] == .string("contract-project"))
        do { try Catalog.validate(.object([:]), schema:createSchema); fatalError("Expected required field error") } catch {}
        var live = LiveThreadState()
        live.apply(SSEFrame(lines: ["event: assistant", #"data: {"callId":"call-a","text":"First "}"#]))
        live.apply(SSEFrame(lines: ["event: assistant", #"data: {"callId":"call-a","text":"reply"}"#]))
        precondition(live.previews["call-a"] == "First reply")
        live.apply(SSEFrame(lines: ["id: cursor-a", "event: transcript", #"data: {"id":"message-a","source":"assistant","callId":"call-a","text":"First reply"}"#]))
        precondition(live.messages.count == 1 && live.previews.isEmpty && live.cursor == "cursor-a")
        live.apply(SSEFrame(lines: ["event: transcript", #"data: {"id":"message-a","source":"assistant","callId":"call-a","text":"First reply"}"#]))
        precondition(live.messages.count == 1)
        live.apply(SSEFrame(lines: ["event: tool_call", #"data: {"callId":"tool-a","name":"bash","text":"Checking changes"}"#]))
        live.apply(SSEFrame(lines: ["event: transcript", #"data: {"id":"tool-a","source":"tool","tool":"bash","text":"Checking changes"}"#]))
        precondition(live.tools.isEmpty)
        live.apply(SSEFrame(lines: ["event: assistant", #"data: {"callId":"discard","text":"Uncommitted"}"#]))
        live.apply(SSEFrame(lines: ["event: turn", #"data: {"phase":"end","outcome":"dropped"}"#]))
        precondition(live.previews.isEmpty && live.messages.count == 2)
        precondition(CapyModelCatalog.models.count == 56 && Set(CapyModelCatalog.models.map(\.id)).count == 56)
        print("Passed transport authentication, project decoding, rate limit, path guard, disconnect, JSON roundtrip, 108-operation contract, SSE parsing, request initialization, persistent navigation, drafts, send-state, browser presentation, overlay recovery, and onboarding checks.")
    }
}
