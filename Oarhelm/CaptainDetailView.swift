import SwiftUI

/// Native overview backed by the Captain, crew and digest endpoints.
struct CaptainDetailView: View {
    let captain: JSONValue
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var current: JSONValue?
    @State private var crew: [JSONValue] = []
    @State private var digest: String?
    @State private var error: String?
    @State private var loading = false
    @State private var requestID = UUID()
    @State private var filter = "All"

    private var id: String { captain["id"]?.stringValue ?? "" }
    private var displayed: JSONValue { current ?? captain }
    private var filtered: [JSONValue] {
        crew.filter { item in
            switch filter {
            case "Needs you": return item["needsYou"] == .bool(true)
            case "Working": return item["status"]?.stringValue == "working"
            default: return true
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Text((displayed["avatar"]?["kind"] == .string("emoji") ? displayed["avatar"]?["value"]?.stringValue : nil) ?? "⚓").font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayed["name"]?.stringValue ?? displayed["title"]?.stringValue ?? "Captain").font(VikingTheme.font(25, weight: .medium))
                        if let status = displayed["status"]?.stringValue { Text(status.capitalized).font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary) }
                    }
                    Spacer()
                }
                if displayed["needsYou"] == .bool(true) { Label("Needs you", systemImage: "bell.badge").font(VikingTheme.font(13)).foregroundStyle(VikingTheme.ember) }
                if let description = displayed["description"]?.stringValue, !description.isEmpty { Text(description).font(VikingTheme.font(14)).lineSpacing(4) }
                HStack {
                    if let current, current["id"]?.stringValue != nil {
                        Button { router.open(.thread(current)) } label: { Label("Captain chat", systemImage: "bubble.left") }.vikingPrimary()
                    }
                    Link("Open Capy", destination: URL(string: "https://capy.ai/sign-in")!).vikingSecondary()
                }
                if loading { ProgressView("Loading Captain…") }
                if let error {
                    VikingPanel { VStack(alignment: .leading, spacing: 10) {
                        Text("Couldn’t load Captain").font(VikingTheme.font(16, weight: .medium))
                        Text(error).font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary)
                        Button("Try again") { Task { await load() } }.vikingSecondary()
                    } }
                }
                if current != nil {
                    VikingPanel { VStack(alignment: .leading, spacing: 12) {
                        Text("Digest").font(VikingTheme.font(17, weight: .medium))
                        if let digest, !digest.isEmpty {
                            Text((try? AttributedString(markdown: digest)) ?? AttributedString(digest)).font(VikingTheme.font(14)).lineSpacing(5).textSelection(.enabled)
                        } else { Text("No digest available yet.").foregroundStyle(VikingTheme.secondary) }
                    } }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Crew").font(VikingTheme.font(17, weight: .medium))
                        HStack { ForEach(["Needs you", "Working", "All"], id: \.self) { option in
                            Button(option) { filter = option }.vikingSecondary().tint(filter == option ? VikingTheme.accent : VikingTheme.secondary)
                        } }
                        if filtered.isEmpty { Text(crew.isEmpty ? "No crew threads yet." : "No threads in this view.").font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary) }
                        ForEach(filtered, id: \.self) { item in
                            if item["id"]?.stringValue != nil {
                                Button { router.open(.thread(item)) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item["title"]?.stringValue ?? "Untitled thread").font(VikingTheme.font(14, weight: .medium))
                                            Text(item["needsYou"] == .bool(true) ? "Needs you" : (item["status"]?.stringValue?.capitalized ?? "Status unavailable")).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
                                        }
                                        Spacer(); Image(systemName: "chevron.right")
                                    }.padding(14).contentShape(Rectangle())
                                }.buttonStyle(.plain).vikingGlass()
                            }
                        }
                    }
                }
            }.frame(maxWidth: 760, alignment: .leading).padding(20).frame(maxWidth: .infinity)
        }.navigationTitle("Captain").navigationBarTitleDisplayMode(.inline).background { VikingBackdrop() }.foregroundStyle(VikingTheme.ink)
            .task(id: "\(id):\(store.accountRevision)") { await load() }
            .refreshable { await load() }
    }
    @MainActor private func load() async {
        let token = UUID(); requestID = token
        let revision = store.accountRevision
        guard store.isConnected, !id.isEmpty, let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) else {
            loading = false; current = nil; crew = []; digest = nil; error = "Connect to Capy and select a valid Captain."; return
        }
        loading = true; error = nil
        defer { if requestID == token { loading = false } }
        let path = "/api/v1/captains/\(encoded)"
        do {
            async let captainResult = store.request("GET", path)
            async let crewResult = store.request("GET", path + "/crew")
            async let digestResult = store.request("GET", path + "/digest")
            let (nextCaptain, nextCrew, nextDigest) = try await (captainResult, crewResult, digestResult)
            guard !Task.isCancelled, requestID == token, revision == store.accountRevision, store.isConnected else { return }
            current = nextCaptain; crew = nextCrew["items"]?.arrayValue ?? []; digest = nextDigest["markdown"]?.stringValue; error = nil; loading = false
        } catch {
            guard !Task.isCancelled, requestID == token, revision == store.accountRevision, store.isConnected else { return }
            self.error = error.localizedDescription
        }
    }
}
