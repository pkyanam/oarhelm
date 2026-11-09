import SwiftUI
import UniformTypeIdentifiers

struct FileUploadButton: View {
    @Environment(CapyStore.self) private var store
    @Binding var files: [UploadedFile]
    var threadID: String? = nil
    var compact = false
    @Environment(AppRouter.self) private var router
    @State private var choosing = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { choosing = true } label: {
                if compact { Image(systemName: busy ? "hourglass" : "plus").frame(width: 24, height: 24) }
                else { Label(busy ? "Uploading…" : "Attach file", systemImage: "paperclip") }
            }.vikingSecondary(compact: compact, icon: compact).accessibilityLabel(busy ? "Uploading file" : "Attach file").disabled(busy || !store.isConnected || threadID.map { router.uploadingFiles[$0, default: 0] > 0 } == true)
            if busy { ProgressView() }
            if !compact { ForEach(files) { file in
                HStack { Text(file.name); Spacer(); Button(role: .destructive) { files.removeAll { $0.id == file.id } } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Remove \(file.name)") }
            } }
            if let error { Text(error).foregroundStyle(VikingTheme.danger) }
        }.fileImporter(isPresented: $choosing, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url): Task { await upload(url) }
            case .failure(let e): error = e.localizedDescription
            }
        }
    }
    private func upload(_ url: URL) async {
        guard !busy, store.isConnected else { return }
        let account = store.accountRevision
        if let threadID { router.uploadingFiles[threadID, default: 0] += 1 }
        defer { if account == store.accountRevision, let threadID { router.uploadingFiles[threadID] = max(0, router.uploadingFiles[threadID, default: 0] - 1) } }
        let principalKey = store.apiKey
        busy = true; error = nil; defer { busy = false }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let meta = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            guard let size = meta.fileSize, size > 0, size <= 262_144_000 else { throw CapyError(message: "Choose a file between 1 byte and 250 MB.") }
            let mime = meta.contentType?.preferredMIMEType ?? "application/octet-stream"
            let result = try await store.request("POST", "/api/v1/files", body: .object(["files": .array([.object(["name": .string(url.lastPathComponent), "mediaType": .string(mime), "sizeBytes": .number(Double(size))])])]))
            guard let target = result["targets"]?.arrayValue?.first, let id = target["fileId"]?.stringValue, let targetURL = target["url"]?.stringValue.flatMap(URL.init(string:)), targetURL.scheme == "https" else { throw CapyError(message: "Capy did not return an upload target.") }
            var request = URLRequest(url: targetURL); request.httpMethod = "PUT"
            request.setValue(mime, forHTTPHeaderField: "Content-Type"); request.setValue(String(size), forHTTPHeaderField: "Content-Length")
            // Presigned URLs carry their own credentials. Never forward the API key.
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: url)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw CapyError(message: "Upload failed. Try again.") }
            guard !Task.isCancelled, store.isConnected, account == store.accountRevision, store.apiKey == principalKey else { return }
            files.append(UploadedFile(id: id, name: url.lastPathComponent))
        } catch { if !Task.isCancelled, store.isConnected, account == store.accountRevision { self.error = error.localizedDescription } }
    }
}

struct HelperListView: View {
    @Environment(CapyStore.self) private var store
    let threadID: String
    @State private var helpers: [JSONValue] = []
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        List {
            Text("Steer via the parent thread.").foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(VikingTheme.danger) }
            if helpers.isEmpty && error == nil { Text("No helpers yet.").foregroundStyle(.secondary) }
            ForEach(Array(helpers.enumerated()), id: \.offset) { _, helper in
                if let id = helper["id"]?.stringValue {
                    NavigationLink(value: AppRoute.resourceItem("helper", helper)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(helper["title"]?.stringValue ?? helper["subagentPath"]?.stringValue ?? id)
                            Text(helper["status"]?.stringValue ?? "").foregroundStyle(VikingTheme.secondary)
                        }
                    }
                    NavigationLink("Messages", value: AppRoute.operation("subagents.messages", ["subagentId": id]))
                    NavigationLink("Live activity", value: AppRoute.operation("streams.subagent", ["subagentId": id]))
                }
            }
            if cursor != nil { Button("Load more") { Task { await load(more: true) } }.disabled(loading) }
        }.vikingList().navigationTitle("Helpers").task { await load() }.refreshable { await load() }
    }
    private func load(more: Bool = false) async {
        guard store.isConnected, !loading else { return }
        loading = true; defer { loading = false }
        let account = store.accountRevision
        do {
            var query: [String:String] = [:]; if more { query["after"] = cursor }
            let page = try await store.request("GET", "/api/v1/threads/\(threadID)/subagents", query: query)
            guard !Task.isCancelled, store.isConnected, account == store.accountRevision else { return }
            let items = page["items"]?.arrayValue ?? []; helpers = more ? helpers + items : items
            cursor = page["cursor"]?.stringValue; error = nil
        } catch { if !Task.isCancelled, store.isConnected, account == store.accountRevision { self.error = error.localizedDescription } }
    }
}
