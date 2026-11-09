import SwiftUI

/// Creates a Captain with project, name, brief, owner, emoji avatar and optional model ID.
/// Advanced model reasoning/modes and custom avatar images remain available through the API.
struct CreateCaptainView: View {
    let defaults: [String: String]
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var users: [JSONValue] = []
    @State private var userError: String?
    @State private var error: String?
    @State private var attempted = false
    private let key = "native.captains.create"

    private var draft: OperationDraft {
        if let existing = router.operationDrafts[key] { return existing }
        let created = OperationDraft()
        created.parameters["projectId"] = defaults["projectId"] ?? store.selectedProjectID
        router.operationDrafts[key] = created
        return created
    }
    private func field(_ name: String) -> Binding<String> {
        Binding(get: { draft.parameters[name] ?? "" }, set: { draft.parameters[name] = $0 })
    }
    private var busy: Bool { draft.parameters["busy"] == "true" }
    private var name: String { (draft.parameters["name"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    private var project: String { draft.parameters["projectId"] ?? "" }
    private var validProject: Bool { store.projects.contains { $0["id"]?.stringValue == project } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if !store.isConnected {
                    VikingPanel { VStack(alignment: .leading, spacing: 12) { Text("Connect to Capy to create a Captain."); Button("Connect account") { router.sheet = .connect }.vikingPrimary() } }
                }
                if draft.parameters["success"] == "true" {
                    VikingPanel { VStack(alignment: .leading, spacing: 12) { Label("Captain created", systemImage: "checkmark.circle.fill").foregroundStyle(VikingTheme.success); Text("Your Captain is ready."); Button("Create another") { router.operationDrafts[key] = nil }.vikingSecondary() } }
                } else {
                    VikingPanel { VStack(alignment: .leading, spacing: 16) {
                        Text("The essentials").font(VikingTheme.font(17, weight: .medium))
                        Picker("Project", selection: field("projectId")) {
                            Text("Choose a project").tag("")
                            ForEach(store.projects, id: \.self) { item in if let id = item["id"]?.stringValue { Text(item["name"]?.stringValue ?? id).tag(id) } }
                        }.pickerStyle(.menu)
                        if attempted && !validProject { Text("Choose an available project.").foregroundStyle(VikingTheme.danger) }
                        TextField("Captain name", text: field("name")) .textFieldStyle(.roundedBorder)
                        if attempted && (name.isEmpty || name.count > 100) { Text(name.isEmpty ? "Enter a name." : "Use 100 characters or fewer.").foregroundStyle(VikingTheme.danger) }
                        Text("First instructions (optional)").foregroundStyle(VikingTheme.secondary)
                        TextField("What should your Captain start on?", text: field("brief"), axis: .vertical).lineLimit(3...8).textFieldStyle(.roundedBorder)
                        Text("These instructions are sent when you create the Captain.").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
                    } }.disabled(busy)
                    VikingPanel { VStack(alignment: .leading, spacing: 14) {
                        Text("Personalize").font(VikingTheme.font(17, weight: .medium))
                        Picker("Human owner", selection: field("authorId")) {
                            Text("Current user (default)").tag("")
                            ForEach(users, id: \.self) { user in if let id = user["id"]?.stringValue { Text(userLabel(user)).tag(id) } }
                        }.pickerStyle(.menu)
                        Text("Service keys need a human owner.").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
                        if let userError { Text(userError).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.danger); Button("Retry loading owners") { Task { await loadUsers() } }.vikingSecondary() }
                        Picker("Avatar", selection: field("avatar")) { Text("Default").tag(""); Text("⚓ Anchor").tag("⚓"); Text("🌊 Wave").tag("🌊"); Text("🧭 Compass").tag("🧭"); Text("⛵ Sailboat").tag("⛵") }.pickerStyle(.menu)
                        HStack { Text("Model"); Spacer(minLength: 8); CapyModelPicker(selection: field("modelId")) }
                    } }.disabled(busy)
                    if let error { Text(error).foregroundStyle(VikingTheme.danger) }
                    Button { create() } label: { if busy { ProgressView() } else { Text("Create Captain") } }.vikingPrimary().disabled(busy)
                }
            }.frame(maxWidth: 680, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 24)
        }.navigationTitle("New captain").navigationBarTitleDisplayMode(.inline).background { VikingBackdrop() }.task { if store.isConnected { await loadUsers() } }
    }
    private func userLabel(_ user: JSONValue) -> String {
        let name = [user["firstName"]?.stringValue, user["lastName"]?.stringValue].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? (user["email"]?.stringValue ?? "Member") : name
    }
    private func loadUsers() async {
        let revision = store.accountRevision
        do { let result = try await store.request("GET", "/api/v1/users"); guard revision == store.accountRevision, store.isConnected else { return }; users = result["items"]?.arrayValue ?? []; userError = nil }
        catch { guard revision == store.accountRevision, store.isConnected else { return }; userError = "Couldn’t load owners. \(error.localizedDescription)" }
    }
    private func create() {
        attempted = true
        guard !busy, validProject, !name.isEmpty, name.count <= 100, store.isConnected else { return }
        let current = draft
        var fields: [String: JSONValue] = ["projectId": .string(project), "name": .string(name)]
        for (input, output) in [("brief", "brief"), ("authorId", "authorId")] { let value = current.parameters[input, default: ""].trimmingCharacters(in: .whitespacesAndNewlines); if !value.isEmpty { fields[output] = .string(value) } }
        let model = current.parameters["modelId", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty { fields["model"] = .object(["modelId": .string(model)]) }
        if let avatar = current.parameters["avatar"], !avatar.isEmpty { fields["avatar"] = .object(["kind": .string("emoji"), "value": .string(avatar), "background": .string("blue")]) }
        let payload = JSONValue.object(fields)
        if current.lastPayload != payload { current.parameters["requestId"] = UUID().uuidString; current.lastPayload = payload }
        fields["requestId"] = .string(current.parameters["requestId"] ?? UUID().uuidString)
        current.requestBody = .object(fields); current.parameters["busy"] = "true"; error = nil
        let revision = store.accountRevision; let selectedProject = project
        Task {
            do {
                let result = try await store.request("POST", "/api/v1/captains", body: current.requestBody)
                current.parameters["busy"] = "false"
                guard revision == store.accountRevision, store.isConnected, router.operationDrafts[key] === current, current.parameters["projectId"] == selectedProject else { return }
                router.operationDrafts[key] = nil
                router.replaceTop(.resourceItem("captains", result))
            } catch {
                current.parameters["busy"] = "false"
                guard revision == store.accountRevision, store.isConnected, router.operationDrafts[key] === current, current.parameters["projectId"] == selectedProject else { return }
                self.error = error.localizedDescription
            }
        }
    }
}
