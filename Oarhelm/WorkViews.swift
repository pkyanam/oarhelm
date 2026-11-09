import SwiftUI

private enum OHTheme {
    static let background = VikingTheme.background
    static let ink = VikingTheme.ink
    static let accent = VikingTheme.accent
    static func font(_ size: CGFloat) -> Font { VikingTheme.font(size) }
}

private func label(_ value: JSONValue) -> String {
    value["title"]?.stringValue ?? value["name"]?.stringValue ?? value["code"]?.stringValue ?? value["id"]?.stringValue ?? "Untitled"
}
private func pathID(_ value: String) -> String { { var allowed = CharacterSet.urlPathAllowed; allowed.remove(charactersIn: "/?#%"); return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }() }
private struct EmptyWork: View {
    var title: String
    var detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "tray", description: Text(detail))
    }
}

struct WorkHomeView: View {
    @Environment(CapyStore.self) private var store
    @State private var threads: [JSONValue] = []
    @State private var cursor: String?
    @State private var search = ""
    @State private var error: String?
    @State private var loading = false
    @State private var activeLoad = UUID()
    @Environment(AppRouter.self) private var router
    @State private var filter = "All"
    private var visible: [JSONValue] {
        threads.filter { thread in
            (search.isEmpty || label(thread).localizedCaseInsensitiveContains(search)) && (filter == "All" || (filter == "Needs you" && thread["needsYou"] == .bool(true)) || (filter == "Working" && thread["status"] == .string("working")))
        }
    }
    var body: some View {
        VikingScreen {
            if !store.isConnected {
                VikingEmptyState(title: "No connection", message: "", symbol: "sailboat", actionTitle: "Connect to Capy", action: { router.sheet = .connect })
            } else {
                HStack {
                    Menu {
                        ForEach(Array(store.projects.enumerated()), id: \.offset) { _, project in Button(label(project)) { store.selectedProjectID = project["id"]?.stringValue ?? "" } }
                    } label: { Label(store.projects.first { $0["id"] == .string(store.selectedProjectID) }?["name"]?.stringValue ?? "Choose project", systemImage: "folder") }.vikingSecondary()
                    Spacer()
                    Button { router.sheet = .newThread } label: { Label("New", systemImage: "plus") }.vikingPrimary().disabled(store.selectedProjectID.isEmpty)
                }
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(VikingTheme.secondary); TextField("Find a thread", text: $search).autocorrectionDisabled() }.padding(16).vikingGlass()
                HStack(spacing: 8) { ForEach(["All", "Needs you", "Working"], id: \.self) { option in
                    Button { filter = option } label: { Text(option).font(VikingTheme.font(12)).frame(maxWidth: .infinity).padding(.vertical, 4) }.vikingSecondary().tint(filter == option ? VikingTheme.accent : VikingTheme.secondary).accessibilityAddTraits(filter == option ? .isSelected : [])
                } }
                if loading { HStack { ProgressView(); Text("Loading threads…").foregroundStyle(VikingTheme.secondary) } }
                if let error { VikingPanel { VStack(alignment: .leading, spacing: 16) { Text("Couldn’t load threads"); Text(error).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary); Button("Try again") { Task { await load() } }.vikingSecondary() } } }
                if visible.isEmpty && !loading && error == nil {
                    VikingEmptyState(title: threads.isEmpty ? "No threads yet" : "Nothing matches", message: threads.isEmpty ? "" : "Try another filter.", symbol: "sailboat", actionTitle: threads.isEmpty ? "Start a thread" : "Clear filters", action: { if threads.isEmpty { router.sheet = .newThread } else { search = ""; filter = "All" } })
                }
                LazyVStack(spacing: 12) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, thread in
                        NavigationLink(value: AppRoute.thread(thread)) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: thread["needsYou"] == .bool(true) ? "bell.badge" : "bubble.left").font(.system(size: 22, weight: .light)).foregroundStyle(thread["needsYou"] == .bool(true) ? VikingTheme.ember : VikingTheme.accent)
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(label(thread)).font(VikingTheme.font(16, weight: .medium)).lineLimit(3)
                                    if let ask = thread["ask"]?["text"]?.stringValue { Text(ask).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.ember).lineLimit(2) }
                                    HStack(spacing: 7) { Circle().fill(thread["status"] == .string("working") ? VikingTheme.success : VikingTheme.secondary).frame(width: 5, height: 5); Text(thread["status"]?.stringValue?.capitalized ?? "Thread").font(VikingTheme.font(11)).foregroundStyle(VikingTheme.secondary) }
                                }; Spacer(minLength: 0)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).vikingGlass()
                        }.buttonStyle(.plain)
                    }
                }
                if cursor != nil { Button("Load more threads") { Task { await load(more: true) } }.vikingSecondary().disabled(loading) }
            }
        }.navigationTitle("Threads").navigationBarTitleDisplayMode(.inline).refreshable { await load() }
            .task(id: "\(store.isConnected)-\(store.selectedProjectID)") { await load() }
    }
    private func load(more: Bool = false) async {
        guard store.isConnected, !store.selectedProjectID.isEmpty, !(more && loading) else { return }
        let account = store.accountRevision
        let projectID = store.selectedProjectID
        let token = UUID(); activeLoad = token; loading = true
        if !more { threads = []; cursor = nil; error = nil }
        defer { if activeLoad == token { loading = false } }
        do {
            var query = ["projectId": projectID, "limit": "50"]
            if more, let cursor { query["cursor"] = cursor }
            let result = try await store.request("GET", "/api/v1/threads", query: query)
            guard !Task.isCancelled, activeLoad == token, account == store.accountRevision, store.isConnected, projectID == store.selectedProjectID else { return }
            let items = result["items"]?.arrayValue ?? []
            threads = more ? threads + items : items
            cursor = result["cursor"]?.stringValue; error = nil
        } catch { if !Task.isCancelled, activeLoad == token, account == store.accountRevision, store.isConnected, projectID == store.selectedProjectID { self.error = error.localizedDescription } }
    }
}

struct ThreadDetailView: View {
    let thread: JSONValue
    @Environment(CapyStore.self) private var store
    @State private var state = LiveThreadState()
    @State private var reconnectToken = UUID()
    @State private var stopping = false
    @State private var followLive = true
    private var messages: [JSONValue] { state.messages }
    private var model: Binding<String> { Binding(get: { router.operationDrafts["model:" + id]?.parameters["model"] ?? "" }, set: { value in let draft = router.operationDrafts["model:" + id] ?? OperationDraft(); draft.parameters["model"] = value; router.operationDrafts["model:" + id] = draft }) }
    @Environment(AppRouter.self) private var router
    private var text: Binding<String> { Binding(get: { router.drafts[id, default: ""] }, set: { router.drafts[id] = $0 }) }
    private var delivery: String { get { router.deliveries[id] ?? "steer" } nonmutating set { router.deliveries[id] = newValue } }
    private var files: Binding<[UploadedFile]> { Binding(get: { router.attachments[id] ?? [] }, set: { router.attachments[id] = $0 }) }
    @State private var liveThread: JSONValue?
    @State private var resumeAfter: String?
    @State private var refreshing = false
    @State private var error: String?
    private var busy: Bool { router.sendPhases[id] == .sending }
    private var id: String { thread["id"]?.stringValue ?? "" }
    private var base: String { "/api/v1/threads/\(pathID(id))" }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    HStack { Label((state.status ?? (liveThread ?? thread)["status"]?.stringValue)?.capitalized ?? "Thread", systemImage: "circle.dotted").foregroundStyle(VikingTheme.success); Spacer(); NavigationLink("Helpers", value: AppRoute.helpers(id)) }.font(VikingTheme.font(12))
                    if let ask = (liveThread ?? thread)["ask"]?["text"]?.stringValue {
                        VikingPanel { VStack(alignment: .leading, spacing: 14) { Label("Needs you", systemImage: "bell.badge").foregroundStyle(VikingTheme.ember); Text(ask); if let kind = (liveThread ?? thread)["ask"]?["kind"]?.stringValue, ["environment", "mcp", "credits", "desktop"].contains(kind) { Link("Continue in Capy", destination: URL(string: "https://capy.ai/sign-in")!).vikingSecondary() } } }
                    }
                    if let error { VStack(alignment: .leading, spacing: 10) { Text(error).foregroundStyle(VikingTheme.danger).fixedSize(horizontal: false, vertical: true); Button("Reconnect") { reconnectToken = UUID() } }.font(VikingTheme.font(12)) }
                    if refreshing && messages.isEmpty { ProgressView("Loading conversation…") }
                    if messages.isEmpty && !refreshing { VikingEmptyState(title: "No messages yet", message: "", symbol: "bubble.left") }
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in ChatMessageView(message: message, threadID: id).id(message["id"]?.stringValue ?? message.prettyText) }
                    ForEach(state.previews.keys.sorted(), id: \.self) { key in Text(state.previews[key] ?? "").font(VikingTheme.font(14)).lineSpacing(6).textSelection(.enabled) }
                    if !state.tools.isEmpty { DisclosureGroup("Tool activity (\(state.tools.count))") { ForEach(state.tools.keys.sorted(), id: \.self) { key in Text(state.tools[key] ?? "").font(VikingTheme.font(12)).fixedSize(horizontal: false, vertical: true) } }.font(VikingTheme.font(12)) }
                    ForEach(state.helpers.keys.sorted(), id: \.self) { key in Label("Helper · " + (state.helpers[key] ?? ""), systemImage: "person.2").font(VikingTheme.font(11)).foregroundStyle(VikingTheme.secondary) }
                    Color.clear.frame(height: 1).id("end")
                }.padding(20).frame(maxWidth: 920).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
                .onScrollPhaseChange { _, phase in if phase == .interacting { followLive = false } }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 80
                } action: { _, nearBottom in if nearBottom { followLive = true } }
                .onChange(of: messages.count) { old, _ in if old == 0 || busy || followLive { proxy.scrollTo("end", anchor: .bottom) } }
                .onChange(of: state.previews) { _,_ in if followLive { proxy.scrollTo("end", anchor: .bottom) } }
        }.background { VikingBackdrop() }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer.padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: 920).frame(maxWidth: .infinity) }
            .navigationTitle(label(thread)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Menu {
                NavigationLink("Live activity", value: AppRoute.operation("streams.thread", ["threadId": id]))
                NavigationLink("Helpers", value: AppRoute.helpers(id))
                NavigationLink("Attachments", value: AppRoute.data("Attachments", base + "/attachments"))
                ShareLink("Share thread ID", item: id)
                Section("Organize") {
                    NavigationLink("Rename", value: AppRoute.operation("threads.rename", ["threadId": id]))
                    NavigationLink("File in folder", value: AppRoute.operation("folders.file", ["threadIds": JSONValue.array([.string(id)]).prettyText]))
                    NavigationLink("Pin", value: AppRoute.operation("folders.pin", ["threadIds": JSONValue.array([.string(id)]).prettyText]))
                    NavigationLink("Archive", value: AppRoute.operation("threads.archive", ["threadId": id]))
                }
                Section("More") {
                    ForEach([("Interrupt", "messages.interrupt"), ("Unarchive", "threads.unarchive"), ("Mark read", "threads.read"), ("Mark unread", "threads.unread"), ("Join", "threads.join"), ("Leave", "threads.leave"), ("Subscribe", "threads.subscribe"), ("Unsubscribe", "threads.unsubscribe"), ("Take over", "threads.takeover")], id: \.1) { title, operation in NavigationLink(title, value: AppRoute.operation(operation, ["threadId": id])) }
                    NavigationLink("Browse transcript", value: AppRoute.operation("messages.list", ["threadId": id]))
                }
            } label: { Label("Thread actions", systemImage: "slider.horizontal.3") } } }
            .refreshable { await refresh() }
            .task(id: "\(id)-\(store.accountRevision)-\(reconnectToken)") { await watch() }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !files.wrappedValue.isEmpty {
                ScrollView(.horizontal) { HStack(spacing: 10) {
                    ForEach(files.wrappedValue) { file in
                        Button { files.wrappedValue.removeAll { $0.id == file.id } } label: { Label(file.name, systemImage: "xmark.circle").font(VikingTheme.font(11)).lineLimit(1).padding(8) }.buttonStyle(.plain).disabled(busy)
                    }
                } }
            }
            TextField("Ask Capy…", text: text, axis: .vertical).disabled(busy).lineLimit(1...6).font(VikingTheme.font(15))
            HStack(spacing: 8) {
                FileUploadButton(files: files, threadID: id, compact: true).disabled(busy)
                CapyModelPicker(selection: model).disabled(busy).frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Button("Steer at the next step") { delivery = "steer" }
                    Button("Queue after current work") { delivery = "queue" }
                    Button("Interrupt and send") { delivery = "interrupt" }
                } label: { Image(systemName: delivery == "queue" ? "text.badge.plus" : delivery == "interrupt" ? "stop.circle" : "sailboat").frame(width: 22, height: 24) }.vikingSecondary(compact: true, icon: true).accessibilityLabel("Delivery: \(delivery.capitalized)").disabled(busy)
                if (state.status ?? (liveThread ?? thread)["status"]?.stringValue) == "working" && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && files.wrappedValue.isEmpty {
                    Button { Task { await stop() } } label: { Image(systemName: "stop.fill").frame(width: 24, height: 24) }.vikingPrimary().buttonBorderShape(.circle).accessibilityLabel("Stop agent").disabled(stopping)
                } else {
                    Button { Task { await send() } } label: { if busy { ProgressView() } else { Image(systemName: "arrow.up").frame(width: 24, height: 24) } }.vikingPrimary().buttonBorderShape(.circle).accessibilityLabel("Send message")
                        .disabled((text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && files.wrappedValue.isEmpty) || busy || router.uploadingFiles[id, default: 0] > 0)
                }
            }
        }.padding(17).vikingGlass()
    }
    private func refresh() async {
        guard store.isConnected, !id.isEmpty, !refreshing else { return }
        let account = store.accountRevision
        refreshing = true; defer { refreshing = false }
        do {
            var all = messages; var after = resumeAfter; var checkpoint = resumeAfter; var seen = Set<String>()
            repeat {
                var query = ["limit": "100"]
                if let after { query["after"] = after }
                let page = try await store.request("GET", base + "/messages", query: query)
                let additions = page["items"]?.arrayValue ?? []
                var ids = Set(all.compactMap { $0["id"]?.stringValue })
                all += additions.filter { value in value["id"]?.stringValue.map { ids.insert($0).inserted } ?? true }
                if all.count > 1000 { all.removeFirst(all.count - 1000) }
                after = page["cursor"]?.stringValue
                if let after { checkpoint = after }
                if let after, !seen.insert(after).inserted { break }
            } while after != nil && !Task.isCancelled
            try Task.checkCancellation()
            let updatedThread = try await store.request("GET", base)
            guard !Task.isCancelled, account == store.accountRevision, store.isConnected else { return }
            for message in all { state.upsert(message) }; resumeAfter = checkpoint; liveThread = updatedThread; error = nil
        } catch { if !Task.isCancelled, account == store.accountRevision, store.isConnected { self.error = error.localizedDescription } }
    }
    private func send() async {
        guard store.isConnected, !id.isEmpty, !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.wrappedValue.isEmpty else { return }
        let account = store.accountRevision
        var payload: [String:JSONValue] = ["text": .string(text.wrappedValue), "delivery": .string(delivery), "files": .array(files.wrappedValue.map(\.messageValue))]
        if !model.wrappedValue.isEmpty { payload["model"] = .object(["modelId": .string(model.wrappedValue)]) }
        guard let key = router.beginSend(id, payload: .object(payload)) else { return }
        payload["clientKey"] = .string(key)
        followLive = true
        error = nil
        do {
            _ = try await store.request("POST", base + "/message", body: .object(payload))
            guard account == store.accountRevision, store.isConnected else { return }; router.finishSend(id); await refresh()
        } catch { if account == store.accountRevision, store.isConnected { self.error = error.localizedDescription; router.failSend(id, message: error.localizedDescription) } }
    }
    private func watch() async {
        let account = store.accountRevision
        await refresh()
        guard !Task.isCancelled, account == store.accountRevision, store.isConnected else { return }
        do {
            var query = ["frames": "subagent"]
            if let cursor = state.cursor ?? resumeAfter { query["after"] = cursor }
            try await store.stream("GET", base + "/stream", query: query) { frame in
                guard !Task.isCancelled, account == store.accountRevision, store.isConnected else { return }
                state.apply(frame)
            }
        } catch { if !Task.isCancelled, account == store.accountRevision, store.isConnected { self.error = error.localizedDescription } }
    }
    private func stop() async {
        guard !stopping, store.isConnected else { return }
        stopping = true; defer { stopping = false }
        let account = store.accountRevision
        do { _ = try await store.request("POST", base + "/interrupt"); guard account == store.accountRevision, store.isConnected else { return }; await refresh() }
        catch { if account == store.accountRevision, store.isConnected { self.error = error.localizedDescription } }
    }

}

struct WorkspaceView: View {
    private let groups: [(String, [(String, String, String, AppRoute)])] = [
        ("Work", [("Projects", "", "square.stack.3d.up", .resource("Projects", "/api/v1/projects", "projects", nil)), ("Folders", "", "folder", .resource("Folders", "/api/v1/folders", "folders", nil)), ("Issues", "", "checklist", .resource("Issues", "/api/v1/issues", "issues", "issues.create"))]),
        ("Agents", [("Captains", "Long-running agents", "person.2", .resource("Captains", "/api/v1/captains", "captains", "captains.create")), ("Automations", "Scheduled and event work", "clock.arrow.circlepath", .resource("Automations", "/api/v1/automations", "automations", "automations.create")), ("Reviews", "", "checkmark.shield", .reviews)]),
        ("Settings", [("Usage", "Credits and spend", "chart.bar", .usage), ("People", "", "person.3", .resource("Users", "/api/v1/users", "users", nil)), ("Issue settings", "", "gearshape", .issueSettings), ("Controls", "All API actions", "slider.horizontal.3", .controls)])
    ]
    var body: some View {
        VikingScreen {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.0).font(VikingTheme.font(18, weight: .semibold)).foregroundStyle(VikingTheme.ink)
                        ForEach(group.1, id: \.0) { item in
                            NavigationLink(value: item.3) { VikingActionRow(title: item.0, subtitle: item.1, symbol: item.2) }.vikingGlass()
                        }
                    }
                }
            }
        }.navigationTitle("Workspace").navigationBarTitleDisplayMode(.inline)
    }
}

struct ResourceList: View {
    let title: String
    let path: String
    var create: String? = nil
    let kind: String
    @Environment(CapyStore.self) private var store
    @State private var items: [JSONValue] = []
    @State private var cursor: String?
    @State private var error: String?
    @Environment(AppRouter.self) private var router
    @State private var loading = false
    @State private var loadID: UUID?
    @State private var loadedProject = ""
    var body: some View {
        VikingScreen {
            if !store.isConnected { VikingEmptyState(title: "No connection", message: "", symbol: symbol, actionTitle: "Connect to Capy", action: { router.sheet = .connect }) }
            else {
                if let create { NavigationLink(value: AppRoute.operation(create, ["projectId": store.selectedProjectID])) { Label(createTitle, systemImage: "plus").frame(maxWidth: .infinity) }.vikingPrimary() }
                if loading { ProgressView("Loading…") }
                if let error { Text(error).foregroundStyle(VikingTheme.danger); Button("Try again") { Task { await load() } }.vikingSecondary() }
                if items.isEmpty && error == nil && !loading { VikingEmptyState(title: "No \(title.lowercased()) yet", message: "", symbol: symbol) }
                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in NavigationLink(value: AppRoute.resourceItem(kind, item)) { VikingActionRow(title: label(item), subtitle: item["description"]?.stringValue ?? item["status"]?.stringValue?.capitalized ?? "", symbol: symbol).vikingGlass() }.buttonStyle(.plain) }
                }
                if cursor != nil { Button("Load more") { Task { await load(more: true) } }.vikingSecondary().disabled(loading) }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).task(id: "\(store.isConnected)-\(store.selectedProjectID)") { await load() }.refreshable { await load() }
    }
    private var createTitle: String { switch kind { case "captains": "New captain"; case "automations": "New automation"; case "issues": "New issue"; default: "Create" } }
    private var subtitle: String { switch kind { case "captains": ""; case "automations": ""; case "issues": ""; case "folders": ""; case "projects": ""; default: "" } }
    private var symbol: String { switch kind { case "captains": "person.2"; case "automations": "repeat"; case "issues": "checklist"; case "folders": "folder"; case "projects": "square.stack.3d.up"; default: "person.3" } }
    private func load(more: Bool = false) async {
        if more && loading { return }
        let id = UUID(); loadID = id
        guard store.isConnected else { loading = false; return }
        let project = store.selectedProjectID; let account = store.accountRevision
        if loadedProject != project { items = []; cursor = nil; error = nil; loadedProject = project }
        loading = true; defer { if loadID == id { loading = false } }
        do { var query: [String:String] = [:]; if more { query["cursor"] = cursor }; if ["automations", "issues"].contains(kind), !store.selectedProjectID.isEmpty { query["projectId"] = store.selectedProjectID }; let result = try await store.request("GET", path, query: query); guard !Task.isCancelled, loadID == id, account == store.accountRevision, store.isConnected, project == store.selectedProjectID else { return }; let next = result["items"]?.arrayValue ?? result["rules"]?.arrayValue ?? result.arrayValue ?? []; items = more ? items + next : next; cursor = (result["cursor"] ?? result["nextCursor"])?.stringValue; error = nil }
        catch { if !Task.isCancelled, loadID == id, account == store.accountRevision, store.isConnected, project == store.selectedProjectID { self.error = error.localizedDescription } }
    }
}

struct ResourceItem: View {
    let kind: String
    let item: JSONValue
    private var id: String { item["id"]?.stringValue ?? "" }
    private var code: String { item["code"]?.stringValue ?? id }
    var body: some View {
        VikingScreen {
            VikingFormSection("Details") { Text(label(item)); if let status = item["status"]?.stringValue { Text(status.capitalized).foregroundStyle(VikingTheme.secondary) }; if let description = item["description"]?.stringValue { Text(description) }; DisclosureGroup("Advanced JSON") { JSONTree(name: "Details", value: item) } }
            if kind == "captains" {
                NavigationLink("Details", value: AppRoute.data("Captain", "/api/v1/captains/\(pathID(id))"))
                NavigationLink("Crew", value: AppRoute.data("Crew", "/api/v1/captains/\(pathID(id))/crew"))
                NavigationLink("Digest", value: AppRoute.data("Digest", "/api/v1/captains/\(pathID(id))/digest"))
            }
            if kind == "issues" {
                NavigationLink("Details", value: AppRoute.data("Issue", "/api/v1/issues/\(pathID(code))"))
                NavigationLink("Comments", value: AppRoute.data("Comments", "/api/v1/issues/\(pathID(code))/comments"))
                NavigationLink("Timeline", value: AppRoute.data("Timeline", "/api/v1/issues/\(pathID(code))/timeline"))
                NavigationLink("Update", value: AppRoute.operation("issues.update", ["code": code]))
                NavigationLink("Add comment", value: AppRoute.operation("issues.comment", ["code": code]))
                NavigationLink("Relations", value: AppRoute.operation("issues.relations", ["code": code]))
                NavigationLink("Relate issue", value: AppRoute.operation("issues.relate", ["code": code]))
                NavigationLink("Link work", value: AppRoute.operation("issues.link", ["code": code]))
            }
            if kind == "folders" { NavigationLink("Threads", value: AppRoute.data("Threads", "/api/v1/folders/\(pathID(id))/threads")) }
            if kind == "projects" { NavigationLink("Environment variables", value: AppRoute.operation("projects.listEnvironmentVariables", ["projectId": id])); NavigationLink("Set environment variables", value: AppRoute.operation("projects.setEnvironmentVariables", ["projectId": id])) }
            if kind == "automations" {
                Menu("Manage automation", systemImage: "slider.horizontal.3") { ForEach(["enable", "disable", "delete", "restore"], id: \.self) { action in NavigationLink(action.capitalized, value: AppRoute.operation("automations.\(action)", ["automationId": id])) }
                }
                NavigationLink("Batches", value: AppRoute.data("Batches", "/api/v1/automations/\(pathID(id))/batches"))
            }
            if kind == "helper" { NavigationLink("Messages", value: AppRoute.operation("subagents.messages", ["subagentId": id])); NavigationLink("Live activity", value: AppRoute.operation("streams.subagent", ["subagentId": id])) }
            if kind == "reviewRules" { NavigationLink("Edit rule", value: AppRoute.operation("reviewRules.update", ["id": id])) }
        }.navigationTitle(label(item)).navigationBarTitleDisplayMode(.inline)
    }
}

struct ResourceDetail: View {
    let title: String
    let path: String
    @Environment(CapyStore.self) private var store
    @State private var value: JSONValue?
    @State private var error: String?
    @State private var cursor: String?
    @State private var loading = false
    var body: some View {
        VikingScreen {
            if !store.isConnected { Text("Connect to Capy to continue.") }
            else if let error { Text(error).foregroundStyle(.red) }
            else if let value {
                if let items = value["items"]?.arrayValue ?? value.arrayValue {
                    if items.isEmpty { Text("Nothing here yet.").foregroundStyle(.secondary) }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        if title == "Threads" || title == "Crew" { NavigationLink(label(item), value: AppRoute.thread(item)) }
                        else if title == "Attachments", let fileID = item["id"]?.stringValue { NavigationLink(label(item), value: AppRoute.operation("attachments.download", ["threadId": String(path.split(separator: "/").dropFirst(3).first ?? ""), "fileId": fileID])) }
                        else { VStack(alignment: .leading) { Text(label(item)); if let description = item["description"]?.stringValue { Text(description).foregroundStyle(VikingTheme.secondary) }; DisclosureGroup("Advanced JSON") { JSONTree(name: label(item), value: item) } } }
                    }
                } else { Text(value["text"]?.stringValue ?? value["summary"]?.stringValue ?? label(value)); if let description = value["description"]?.stringValue { Text(description) }; DisclosureGroup("Advanced JSON") { JSONTree(name: title, value: value) } }
                if cursor != nil { Button("Load more") { Task { await load(more: true) } }.disabled(loading) }
            } else { ProgressView() }
        }.font(OHTheme.font(13)).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable { await load() }
    }
    private func load(more: Bool = false) async {
        guard store.isConnected, !loading else { return }
        loading = true; defer { loading = false }
        let account = store.accountRevision
        do {
            var query: [String:String] = [:]
            if more { query[path.hasSuffix("/batches") ? "cursor" : "after"] = cursor }
            var page = try await store.request("GET", path, query: query)
            guard !Task.isCancelled, store.isConnected, account == store.accountRevision else { return }
            cursor = page["cursor"]?.stringValue
            if more, let old = value?["items"]?.arrayValue, let next = page["items"]?.arrayValue, case .object(var object) = page { object["items"] = .array(old + next); page = .object(object) }
            value = page; error = nil
        } catch { if !Task.isCancelled, store.isConnected, account == store.accountRevision { self.error = error.localizedDescription } }
    }
}
