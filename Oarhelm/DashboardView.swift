import SwiftUI

struct DashboardView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var threads: [JSONValue] = []
    @State private var loading = false
    @State private var loadID: UUID?
    @State private var loadedProject = ""
    @State private var error: String?
    var body: some View {
        VikingScreen {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Oarhelm").font(VikingTheme.font(34, weight: .medium)).minimumScaleFactor(0.7).lineLimit(1)
                    Label(store.isConnected ? "Connected to Capy" : "Not connected", systemImage: store.isConnected ? "checkmark.seal" : "key").font(VikingTheme.font(11)).foregroundStyle(store.isConnected ? VikingTheme.success : VikingTheme.accent)
                }
            }.padding(.top, 14)
            if store.isConnected {
                Button { router.sheet = .newThread } label: { Label("New thread", systemImage: "plus").frame(maxWidth: .infinity) }.vikingPrimary().disabled(store.selectedProjectID.isEmpty)
                if store.projects.isEmpty {
                    VikingEmptyState(title: "No projects yet", message: "Create a project in Capy.", symbol: "folder")
                    Link("Open Capy", destination: URL(string: "https://capy.ai/sign-in")!).vikingSecondary()
                } else {
                    projectPicker
                    if loading { HStack { ProgressView(); Text("Loading…").foregroundStyle(VikingTheme.secondary) } }
                    if let error { VikingPanel { VStack(alignment: .leading, spacing: 15) { Text("Couldn’t load threads").font(VikingTheme.font(17, weight: .medium)); Text(error).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary); Button("Try again") { Task { await load() } }.vikingSecondary() } } }
                    if !threads.filter({ $0["needsYou"] == .bool(true) }).isEmpty {
                        threadSection("Needs you", items: threads.filter { $0["needsYou"] == .bool(true) })
                    }
                    threadSection("Recent threads", items: Array(threads.prefix(5)))
                }
            } else {
                VikingPanel {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Use your Capy API key.").font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary).lineSpacing(6)
                        Button { router.sheet = .connect } label: { Label("Connect to Capy", systemImage: "key").frame(maxWidth: .infinity) }.vikingPrimary()
                    }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("Workspace").font(VikingTheme.font(21, weight: .medium))
                NavigationLink(value: AppRoute.resource("Captains", "/api/v1/captains", "captains", "captains.create")) { VikingActionRow(title: "Captains", subtitle: "Long-running agents", symbol: "person.2") }
                NavigationLink(value: AppRoute.reviews) { VikingActionRow(title: "Code reviews", subtitle: "", symbol: "checkmark.shield") }
                NavigationLink(value: AppRoute.usage) { VikingActionRow(title: "Usage", subtitle: "Credits and spend", symbol: "chart.xyaxis.line") }
            }
        }.navigationTitle("Helm").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(store.isConnected)-\(store.selectedProjectID)") { await load() }.refreshable { await load() }
    }
    private var projectPicker: some View {
        Menu {
            ForEach(Array(store.projects.enumerated()), id: \.offset) { _, project in
                Button(project["name"]?.stringValue ?? "Project") { store.selectedProjectID = project["id"]?.stringValue ?? "" }
            }
        } label: {
            HStack { Label(store.projects.first { $0["id"] == .string(store.selectedProjectID) }?["name"]?.stringValue ?? "Choose project", systemImage: "folder"); Spacer(); Image(systemName: "chevron.down") }.font(VikingTheme.font(13)).padding(15)
        }.buttonStyle(.plain).vikingGlass().accessibilityLabel("Choose project")
    }
    private func threadSection(_ title: String, items: [JSONValue]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(title).font(VikingTheme.font(21, weight: .medium)); Spacer(); Button("View all") { router.select(.threads) }.font(VikingTheme.font(12)) }
            if items.isEmpty && !loading && error == nil {
                Text("No threads yet.").font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary).padding(.vertical, 14)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, thread in
                NavigationLink(value: AppRoute.thread(thread)) {
                    HStack(spacing: 14) {
                        Image(systemName: thread["needsYou"] == .bool(true) ? "bell.badge" : "bubble.left").foregroundStyle(VikingTheme.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(thread["title"]?.stringValue ?? "Untitled thread").font(VikingTheme.font(15, weight: .medium)).lineLimit(2)
                            Text(thread["ask"]?["text"]?.stringValue ?? thread["status"]?.stringValue?.capitalized ?? "Thread").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary).lineLimit(2)
                        }
                        Spacer()
                    }.padding(18).vikingGlass()
                }.buttonStyle(.plain)
            }
        }
    }
    private func load() async {
        let id = UUID(); loadID = id
        guard store.isConnected, !store.selectedProjectID.isEmpty else { threads = []; loading = false; return }
        let project = store.selectedProjectID; let account = store.accountRevision
        if loadedProject != project { threads = []; loadedProject = project }
        loading = true; error = nil
        defer { if loadID == id { loading = false } }
        do {
            let result = try await store.request("GET", "/api/v1/threads", query: ["projectId": project, "limit": "100"])
            guard !Task.isCancelled, loadID == id, account == store.accountRevision, store.isConnected, project == store.selectedProjectID else { return }
            threads = result["items"]?.arrayValue ?? []
        } catch { if !Task.isCancelled, loadID == id, account == store.accountRevision, store.isConnected, project == store.selectedProjectID { self.error = error.localizedDescription } }
    }
}
