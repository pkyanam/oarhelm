import SwiftUI

struct CreateAutomationView: View {
    let defaults: [String: String]
    var body: some View { NativeWorkspaceForm(automation: true, defaults: defaults) }
}

struct CreateIssueView: View {
    let defaults: [String: String]
    var body: some View { NativeWorkspaceForm(automation: false, defaults: defaults) }
}

private struct NativeWorkspaceForm: View {
    let automation: Bool
    let defaults: [String: String]
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var error: String?
    @State private var zoneSearch = ""
    @State private var states: [JSONValue] = []
    @State private var labels: [JSONValue] = []
    @State private var choicesError: String?
    @State private var choicesID = UUID()
    private var key: String { automation ? "native.automation.create" : "native.issue.create" }
    private var draft: OperationDraft {
        if let existing = router.operationDrafts[key] { return existing }
        let value = OperationDraft(); value.parameters = defaults
        router.operationDrafts[key] = value
        return value
    }
    private func field(_ name: String, _ fallback: String = "") -> Binding<String> {
        Binding(get: { draft.parameters[name] ?? fallback }, set: { draft.parameters[name] = $0 })
    }
    private func toggle(_ name: String) -> Binding<Bool> {
        Binding(get: { draft.parameters[name] == "true" }, set: { draft.parameters[name] = $0 ? "true" : "false" })
    }
    private var defaultTime: Date { Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() }
    private var busy: Bool { router.sendPhases[key] == .sending }
    var body: some View {
        VikingScreen {
            if !store.isConnected { Button("Connect to Capy") { router.sheet = .connect }.vikingPrimary() }
            VikingPanel {
                VStack(alignment: .leading, spacing: 16) {
                    if store.projects.isEmpty { Text("No projects available. Connect an account with access to a project.").foregroundStyle(VikingTheme.secondary) }
                    Picker("Project", selection: field("projectId", store.selectedProjectID)) {
                        Text("Choose a project").tag("")
                        ForEach(store.projects, id: \.self) { project in
                            Text(project["name"]?.stringValue ?? "Project").tag(project["id"]?.stringValue ?? "")
                        }
                    }
                    TextField(automation ? "Name" : "Title", text: field(automation ? "name" : "title"))
                    TextField(automation ? "Instructions" : "Description", text: field(automation ? "prompt" : "description"), axis: .vertical).lineLimit(4...10)
                    if automation { HStack { Text("Model"); Spacer(minLength: 8); CapyModelPicker(selection: field("model")) }; automationFields } else { issueFields }
                }.disabled(busy)
            }
            if let error { Text(error).foregroundStyle(VikingTheme.danger) }
            Button(busy ? "Creating…" : (automation ? "Create automation" : "Create issue")) { submit() }
                .vikingPrimary().disabled(busy || !store.isConnected || store.projects.isEmpty)
        }.font(VikingTheme.font(14)).navigationTitle(automation ? "New automation" : "New issue")
            .task(id: "\(store.accountRevision)-\(store.isConnected)") { await loadIssueChoices() }
    }
    private var automationFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Schedule", selection: field("schedule", "On demand")) {
                ForEach(["On demand", "Daily", "Weekdays", "Weekly"], id: \.self) { Text($0).tag($0) }
            }
            if field("schedule", "On demand").wrappedValue != "On demand" {
                DatePicker("Time", selection: Binding(get: { Date(timeIntervalSince1970: Double(draft.parameters["time"] ?? "") ?? defaultTime.timeIntervalSince1970) }, set: { draft.parameters["time"] = String($0.timeIntervalSince1970) }), displayedComponents: .hourAndMinute)
                if field("schedule").wrappedValue == "Weekly" {
                    Picker("Day", selection: field("weekday", "1")) {
                        ForEach(Array(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].enumerated()), id: \.offset) { i, day in Text(day).tag(String(i)) }
                    }
                }
                TextField("Search time zones", text: $zoneSearch)
                Picker("Time zone", selection: field("timezone", TimeZone.current.identifier)) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers.filter { zoneSearch.isEmpty || $0.localizedCaseInsensitiveContains(zoneSearch) || $0 == field("timezone", TimeZone.current.identifier).wrappedValue }, id: \.self) { Text($0).tag($0) }
                }
            }
            Picker("Thread", selection: field("threadMode", "new")) { Text("New for each run").tag("new"); Text("Single thread").tag("single") }
            TextField("Maximum runs per day (optional)", text: field("maxRunsPerDay")).keyboardType(.numberPad)
            Toggle("Enable immediately", isOn: toggle("enabled"))
            Text("Disabled automations can be enabled later.").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
            DisclosureGroup("Advanced") {
                VStack(spacing: 12) {
                    Picker("Machine", selection: field("machineSize")) { Text("Default").tag(""); ForEach(["small", "medium", "large", "ultra", "hyper", "bigguy"], id: \.self) { Text($0.capitalized).tag($0) } }
                    NavigationLink("Other triggers", value: AppRoute.advancedOperation("automations.create", defaults))
                }.padding(.top, 12)
            }
        }
    }
    private var issueFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("State", selection: field("stateId")) {
                Text("Default").tag("")
                ForEach(states, id: \.self) { state in
                    if let id = state["id"]?.stringValue { Text(state["name"]?.stringValue ?? id).tag(id) }
                }
            }
            Picker("Priority", selection: field("priority", "normal")) { ForEach(["urgent", "high", "normal", "low"], id: \.self) { Text($0.capitalized).tag($0) } }
            Picker("Visibility", selection: field("visibility", "org")) { Text("Project members").tag("org"); Text("Private").tag("private") }
            Toggle("Set due date", isOn: toggle("hasDue"))
            if toggle("hasDue").wrappedValue {
                DatePicker("Due date", selection: Binding(get: { Date(timeIntervalSince1970: Double(draft.parameters["due"] ?? "") ?? Date().timeIntervalSince1970) }, set: { draft.parameters["due"] = String($0.timeIntervalSince1970) }), displayedComponents: .date)
            }
            if !labels.isEmpty {
                DisclosureGroup("Labels") {
                    ForEach(labels, id: \.self) { label in
                        if let id = label["id"]?.stringValue {
                            Toggle(label["name"]?.stringValue ?? id, isOn: labelBinding(id))
                                .disabled(!labelIDs.contains(id) && labelIDs.count >= 20)
                        }
                    }
                }
            }
            if let choicesError { Text(choicesError).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.danger); Button("Reload choices") { Task { await loadIssueChoices() } }.vikingSecondary() }
        }
    }
    private var labelIDs: [String] { (try? JSONDecoder().decode([String].self, from: Data(draft.parameters["labelIds", default: "[]"].utf8))) ?? [] }
    private func labelBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { labelIDs.contains(id) }, set: { selected in
            var ids = labelIDs.filter { $0 != id }; if selected && ids.count < 20 { ids.append(id) }
            draft.parameters["labelIds"] = String(data: (try? JSONEncoder().encode(ids)) ?? Data("[]".utf8), encoding: .utf8)
        })
    }
    private func loadIssueChoices() async {
        guard !automation, store.isConnected else { return }
        let token = UUID(); choicesID = token; let account = store.accountRevision
        do {
            async let stateResult = store.request("GET", "/api/v1/issue-states")
            async let labelResult = store.request("GET", "/api/v1/issue-labels")
            let (nextStates, nextLabels) = try await (stateResult, labelResult)
            guard !Task.isCancelled, choicesID == token, account == store.accountRevision, store.isConnected else { return }
            states = nextStates["items"]?.arrayValue ?? []; labels = nextLabels["items"]?.arrayValue ?? []; choicesError = nil
        } catch { if !Task.isCancelled, choicesID == token, account == store.accountRevision, store.isConnected { choicesError = "Couldn’t load states and labels." } }
    }
    private func submit() {
        guard !busy else { return }
        let p = draft.parameters
        let project = p["projectId"] ?? store.selectedProjectID
        let title = p[automation ? "name" : "title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard store.isConnected, store.projects.contains(where: { $0["id"]?.stringValue == project }), !title.isEmpty, !automation || !(p["prompt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Choose a project and complete the required fields."; return }
        var body: [String: JSONValue] = ["projectId": .string(project)]
        if automation {
            body["name"] = .string(title); body["prompt"] = .string(p["prompt"] ?? "")
            let schedule = p["schedule"] ?? "On demand"
            var trigger: [String: JSONValue] = ["type": .string(schedule == "On demand" ? "on_demand" : "schedule")]
            if schedule != "On demand" {
                let date = Date(timeIntervalSince1970: Double(p["time"] ?? "") ?? defaultTime.timeIntervalSince1970)
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                let day = schedule == "Weekdays" ? "1-5" : (schedule == "Weekly" ? (p["weekday"] ?? "1") : "*")
                trigger["cron"] = .string("\(components.minute ?? 0) \(components.hour ?? 9) * * \(day)")
                trigger["timezone"] = .string(p["timezone"] ?? TimeZone.current.identifier)
            }
            body["triggers"] = .array([.object(trigger)]); body["threadMode"] = .string(p["threadMode"] ?? "new"); body["enabled"] = .bool(p["enabled"] == "true")
            if let max = p["maxRunsPerDay"], !max.isEmpty { guard let n = Int(max), n > 0 else { error = "Enter a positive daily limit."; return }; body["maxRunsPerDay"] = .number(Double(n)) }
            if let model = p["model"], !model.isEmpty { body["model"] = .object(["modelId": .string(model)]) }
            if let machine = p["machineSize"], !machine.isEmpty { body["machineSize"] = .string(machine) }
        } else {
            guard title.count <= 500 else { error = "Title must be 500 characters or fewer."; return }
            body["title"] = .string(title); body["description"] = .string(p["description"] ?? ""); body["priority"] = .string(p["priority"] ?? "normal"); body["visibility"] = .string(p["visibility"] ?? "org")
            if let state = p["stateId"], !state.isEmpty { body["stateId"] = .string(state) }
            if !labelIDs.isEmpty { body["labelIds"] = .array(labelIDs.map(JSONValue.string)) }
            if p["hasDue"] == "true" { body["dueAt"] = .string(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(p["due"] ?? "") ?? Date().timeIntervalSince1970))) }
        }
        let payload = JSONValue.object(body)
        guard let requestID = router.beginSend(key, payload: payload) else { return }
        if automation { body["requestId"] = .string(requestID) }
        draft.requestBody = .object(body); error = nil
        let account = store.accountRevision
        Task { @MainActor in
            do {
                let result = try await store.request("POST", automation ? "/api/v1/automations" : "/api/v1/issues", body: .object(body))
                guard account == store.accountRevision, store.isConnected else { return }
                router.finishSend(key); router.operationDrafts[key] = nil
                router.replaceTop(.resourceItem(automation ? "automations" : "issues", result))
            } catch {
                guard account == store.accountRevision, store.isConnected else { return }
                router.failSend(key, message: error.localizedDescription); self.error = error.localizedDescription
            }
        }
    }
}
