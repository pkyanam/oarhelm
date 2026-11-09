import Foundation

/// Test-only transport whose responses are released explicitly, without network or timing assumptions.
final class DeferredProtocol: URLProtocol, @unchecked Sendable {
    static let responses = DeferredResponses()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.responses.register(self) }
    override func stopLoading() {}
    func complete(status: Int, body: String) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
}
final class DeferredResponses: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [String: [DeferredProtocol]] = [:]
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    func register(_ request: DeferredProtocol) {
        let key = request.request.value(forHTTPHeaderField: "Authorization")!
        lock.lock(); pending[key, default: []].append(request); let ready = waiters.removeValue(forKey: key) ?? []; lock.unlock()
        ready.forEach { $0.resume() }
    }
    func wait(_ key: String) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if pending[key]?.isEmpty == false { lock.unlock(); continuation.resume() }
            else { waiters[key, default: []].append(continuation); lock.unlock() }
        }
    }
    func complete(_ key: String, status: Int = 200, body: String = #"{"items":[]}"#) {
        lock.lock(); let request = pending[key]!.removeFirst(); lock.unlock()
        request.complete(status: status, body: body)
    }
}

extension Checks {
    @MainActor static func asyncStateChecks() async throws {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [DeferredProtocol.self]
        let store = CapyStore(session: URLSession(configuration: configuration), persistsKey: false)
        let responses = DeferredProtocol.responses
        let abandoned = Task { try await store.connect(key: "race-abandoned") }
        await responses.wait("Bearer race-abandoned")
        precondition(store.apiKey.isEmpty, "Candidate credentials must stay private until verification")
        store.disconnect()
        responses.complete("Bearer race-abandoned")
        await expectCancelled(abandoned)
        precondition(!store.isConnected && store.apiKey.isEmpty && store.projects.isEmpty)

        let old = Task { try await store.connect(key: "race-old") }
        await responses.wait("Bearer race-old")
        let latest = Task { try await store.connect(key: "race-latest") }
        await responses.wait("Bearer race-latest")
        responses.complete("Bearer race-latest", body: #"{"items":[{"id":"current-project","name":"Transport test"}]}"#)
        try await latest.value
        responses.complete("Bearer race-old", status: 500)
        await expectCancelled(old)
        precondition(store.isConnected && store.apiKey == "race-latest" && store.selectedProjectID == "current-project")

        let refresh = Task { try await store.refreshProjects() }
        await responses.wait("Bearer race-latest")
        store.disconnect()
        responses.complete("Bearer race-latest", body: #"{"items":[{"id":"stale-project"}]}"#)
        await expectCancelled(refresh)
        precondition(!store.isConnected && store.projects.isEmpty && store.selectedProjectID.isEmpty)
    }
    private static func expectCancelled(_ task: Task<Void, Error>) async {
        do { try await task.value; fatalError("Superseded work must not commit") }
        catch is CancellationError {} catch { fatalError("Expected cancellation, got \(error)") }
    }
}
