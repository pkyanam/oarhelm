import SwiftUI

struct StartThreadView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var form = OperationDraft()
    @State private var settings = false
    private let draftKey = "native.thread.create"
    private func field(_ name: String, default fallback: String = "") -> Binding<String> {
        Binding(get: { form.parameters[name] ?? fallback }, set: { form.parameters[name] = $0 })
    }
    private var project: String { form.parameters["projectId"] ?? store.selectedProjectID }
    private var prompt: String { form.parameters["prompt", default: ""].trimmingCharacters(in: .whitespacesAndNewlines) }
    private var busy: Bool { form.parameters["busy"] == "true" }
    private var projectName: String { store.projects.first { $0["id"]?.stringValue == project }?["name"]?.stringValue ?? "Choose project" }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { projectControl; machineControl }
                        VStack(alignment: .leading, spacing: 12) { projectControl; machineControl }
                    }
                    if !store.isConnected {
                        VikingPanel { VStack(alignment: .leading, spacing: 14) {
                            Label("Not connected", systemImage: "key").foregroundStyle(VikingTheme.accent)
                            Button("Connect to Capy") { router.sheet = .connect }.vikingPrimary()
                        } }
                    } else if store.projects.isEmpty {
                        Text("Create a project in Capy to start.").foregroundStyle(VikingTheme.secondary)
                        Link("Open Capy", destination: URL(string: "https://capy.ai/sign-in")!).vikingSecondary()
                    }
                    if settings {
                        VikingPanel { VStack(alignment: .leading, spacing: 18) {
                            TextField("Title (optional)", text: field("title"))
                            Toggle("Private", isOn: Binding(get: { form.parameters["private"] == "true" }, set: { form.parameters["private"] = String($0) }))
                            Picker("Reasoning", selection: field("reasoning")) {
                                Text("Default").tag("")
                                ForEach(["none", "instant", "minimal", "low", "medium", "high", "xhigh", "max"], id: \.self) { Text($0.capitalized).tag($0) }
                            }.disabled(form.parameters["model", default: ""].isEmpty)
                            DisclosureGroup("Paired computer") {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextField("Device ID", text: field("deviceID")).textInputAutocapitalization(.never).autocorrectionDisabled()
                                    TextField("Workspace path", text: field("workspace")).textInputAutocapitalization(.never).autocorrectionDisabled()
                                    Link("Manage in Capy", destination: URL(string: "https://capy.ai/sign-in")!)
                                }.padding(.top, 12)
                            }
                        } }.disabled(busy)
                    }
                    if let error = form.parameters["error"] { Text(error).font(VikingTheme.font(13)).foregroundStyle(VikingTheme.danger).fixedSize(horizontal: false, vertical: true) }
                }.padding(20).frame(maxWidth: 820).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
            composer.padding(.horizontal, 18).padding(.bottom, 14).padding(.top, 8).frame(maxWidth: 860).frame(maxWidth: .infinity)
        }
        .background { VikingBackdrop() }
        .navigationTitle("New thread").navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(busy)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.disabled(busy) } }
        .onAppear {
            if let retained = router.operationDrafts[draftKey] { form = retained }
            else { router.operationDrafts[draftKey] = form }
        }
    }
    private var projectControl: some View {
        Menu {
            ForEach(store.projects, id: \.self) { project in
                if let id = project["id"]?.stringValue { Button(project["name"]?.stringValue ?? "Project") { form.parameters["projectId"] = id } }
            }
        } label: { Label(projectName, systemImage: "folder").font(VikingTheme.font(12)).lineLimit(1) }.vikingSecondary().disabled(busy || store.projects.isEmpty)
    }
    private var machineControl: some View {
        Menu {
            Button("Default cloud machine") { form.parameters["machine"] = "" }
            ForEach(["small", "medium", "large", "ultra", "hyper", "bigguy"], id: \.self) { size in Button(size.capitalized) { form.parameters["machine"] = size } }
        } label: { Label(form.parameters["machine"].flatMap { $0.isEmpty ? nil : $0.capitalized } ?? "Cloud", systemImage: "cloud").font(VikingTheme.font(12)) }.vikingSecondary().disabled(busy)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Ask Capy…", text: field("prompt"), axis: .vertical)
                .font(VikingTheme.font(16)).lineLimit(1...8).disabled(busy).padding(.horizontal, 3)
            HStack(spacing: 10) {
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { settings.toggle() } } label: { Image(systemName: settings ? "slider.horizontal.3" : "plus").frame(width: 28, height: 28) }
                    .vikingSecondary(compact: true, icon: true).accessibilityLabel("Run settings").disabled(busy)
                CapyModelPicker(selection: field("model")).disabled(busy).frame(maxWidth: .infinity, alignment: .leading)
                Button(action: create) {
                    if busy { ProgressView() } else { Image(systemName: "arrow.up").frame(width: 24, height: 24) }
                }.vikingPrimary().buttonBorderShape(.circle).accessibilityLabel("Start thread")
                    .disabled(busy || prompt.isEmpty || !store.isConnected || !store.projects.contains(where: { $0["id"]?.stringValue == project }))
            }
        }.padding(18).vikingGlass()
    }
    private func create() {
        guard !busy, store.isConnected, !prompt.isEmpty, store.projects.contains(where: { $0["id"]?.stringValue == project }) else { return }
        let retained = form
        var payload: [String: JSONValue] = ["projectId": .string(project), "message": .string(prompt)]
        for key in ["title"] { if let value = form.parameters[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { payload[key] = .string(value) } }
        if form.parameters["private"] == "true" { payload["visibility"] = .string("private") }
        if let size = form.parameters["machine"], !size.isEmpty { payload["machineSize"] = .string(size) }
        if let model = form.parameters["model"], !model.isEmpty {
            var selection: [String: JSONValue] = ["modelId": .string(model)]
            if let reasoning = form.parameters["reasoning"], !reasoning.isEmpty { selection["reasoningMode"] = .string(reasoning) }
            payload["model"] = .object(selection)
        }
        if let device = form.parameters["deviceID"], !device.isEmpty {
            guard let path = form.parameters["workspace"], !path.isEmpty else { form.parameters["error"] = "Enter the paired computer’s workspace path."; return }
            payload["device"] = .object(["deviceId": .string(device), "workspace": .object(["kind": .string("linked"), "root": .string(path)])])
        }
        let logical = JSONValue.object(payload)
        if form.lastPayload != logical || form.parameters["requestId"] == nil { form.parameters["requestId"] = UUID().uuidString; form.lastPayload = logical }
        payload["requestId"] = .string(form.parameters["requestId"]!)
        form.parameters["busy"] = "true"; form.parameters["error"] = nil
        let account = store.accountRevision
        Task { @MainActor in
            defer { retained.parameters["busy"] = "false" }
            do {
                let thread = try await store.request("POST", "/api/v1/threads", body: .object(payload))
                guard !Task.isCancelled, store.isConnected, account == store.accountRevision else { return }
                router.operationDrafts[draftKey] = nil
                dismiss(); router.open(.thread(thread))
            } catch {
                guard !Task.isCancelled, store.isConnected, account == store.accountRevision else { return }
                retained.parameters["error"] = error.localizedDescription
            }
        }
    }
}
