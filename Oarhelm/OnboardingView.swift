import SwiftUI

struct OnboardingView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Bindable var state: OnboardingState
    let onComplete: () -> Void
    var allowExplore = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule().fill(step.rawValue <= state.step.rawValue ? VikingTheme.accent : VikingTheme.raised).frame(height: 3)
                }
            }.padding(20).accessibilityLabel("Setup step \(state.step.rawValue + 1) of 5")
            VikingScreen {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: symbol).font(.system(size: 48, weight: .ultraLight)).foregroundStyle(VikingTheme.accent).accessibilityHidden(true)
                    Text(title).font(VikingTheme.font(29, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    content
                    if let error = state.error { Text(error).font(VikingTheme.font(13)).foregroundStyle(VikingTheme.danger).fixedSize(horizontal: false, vertical: true) }
                }.padding(.top, 12)
            }
            VStack(spacing: 12) {
                Button(action: next) { HStack { if state.checking { ProgressView() }; Text(primaryTitle).frame(maxWidth: .infinity) } }.vikingPrimary().disabled(primaryDisabled)
                HStack {
                    if state.step != .welcome { Button("Back") { state.back() }.disabled(state.checking) }
                    Spacer()
                    if allowExplore && state.step != .ready { Button("Explore first") { state.key = ""; onComplete() }.disabled(state.checking) }
                }.font(VikingTheme.font(12))
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background { VikingBackdrop() }.foregroundStyle(VikingTheme.ink).font(VikingTheme.font(14))
    }
    @ViewBuilder private var content: some View {
        switch state.step {
        case .welcome:
            Text("Control your Capy workspace.").foregroundStyle(VikingTheme.secondary)
            VikingPanel { VStack(alignment: .leading, spacing: 18) {
                Label("Start and steer threads", systemImage: "bubble.left.and.bubble.right")
                Label("Follow agents and crew", systemImage: "person.2")
                Label("Review work and spend", systemImage: "checkmark.shield")
            }.font(VikingTheme.font(14)) }
        case .keyGuide:
            CapyWordmark(height: 22)
            Text("Capy: Settings, API.").foregroundStyle(VikingTheme.secondary)
            Button { router.browse(URL(string: "https://capy.ai/sign-in")!) } label: { Label("Open Capy", systemImage: "globe").frame(maxWidth: .infinity) }.vikingSecondary()
            Text("Create a key there, then return here.").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
        case .keyEntry:
            VikingPanel { VStack(alignment: .leading, spacing: 16) {
                SecureField("API key", text: $state.key).textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(state.checking)
                    .padding(14).background(VikingTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("api-key")
                Label("Saved in this device’s Keychain", systemImage: "lock").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
            } }
        case .project:
            if store.projects.isEmpty {
                Text("No projects yet.").foregroundStyle(VikingTheme.secondary)
                Button("Create in Capy") { router.browse(URL(string: "https://capy.ai/sign-in")!) }.vikingSecondary()
                Button("Refresh") { verify(existing: true) }.vikingSecondary().disabled(state.checking)
            } else {
                ForEach(Array(store.projects.enumerated()), id: \.offset) { _, project in
                    if let id = project["id"]?.stringValue {
                        Button { store.selectedProjectID = id } label: {
                            HStack(spacing: 14) { Image(systemName: "folder"); Text(project["name"]?.stringValue ?? "Project").fixedSize(horizontal: false, vertical: true); Spacer(); if store.selectedProjectID == id { Image(systemName: "checkmark") } }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).vikingGlass().accessibilityAddTraits(store.selectedProjectID == id ? .isSelected : [])
                    }
                }
            }
        case .ready:
            VikingPanel { VStack(alignment: .leading, spacing: 16) {
                Label("Connected", systemImage: "checkmark.seal").foregroundStyle(VikingTheme.success)
                if let project = store.projects.first(where: { $0["id"] == .string(store.selectedProjectID) }) { Label(project["name"]?.stringValue ?? "Project", systemImage: "folder") }
            } }
            Text("Your agents run remotely.").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
        }
    }
    private var title: String { switch state.step { case .welcome: "Oarhelm"; case .keyGuide: "Get an API key"; case .keyEntry: "Connect"; case .project: "Choose a project"; case .ready: "Ready" } }
    private var symbol: String { switch state.step { case .welcome: "sailboat"; case .keyGuide: "key"; case .keyEntry: "lock.shield"; case .project: "folder"; case .ready: "checkmark.seal" } }
    private var primaryTitle: String { if state.checking { return "Connecting…" }; switch state.step { case .welcome: return "Set up"; case .keyGuide: return "I have a key"; case .keyEntry: return "Connect"; case .project: return store.projects.isEmpty ? "Continue without a project" : "Continue"; case .ready: return "Open workspace" } }
    private var primaryDisabled: Bool { state.checking || (state.step == .keyEntry && state.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    private func next() {
        if state.step == .keyEntry { verify(existing: false) }
        else if state.step == .ready { onComplete() }
        else { state.advance(connected: store.isConnected) }
    }
    private func verify(existing: Bool) {
        guard !state.checking else { return }; state.checking = true; state.error = nil
        Task {
            defer { state.checking = false }
            do {
                if existing { try await store.refreshProjects() }
                else { try await store.connect(key: state.key.trimmingCharacters(in: .whitespacesAndNewlines)) }
                state.key = ""; state.step = .project
            } catch { state.error = error.localizedDescription }
        }
    }
}
