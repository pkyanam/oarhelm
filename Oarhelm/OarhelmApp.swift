import SwiftUI
import UIKit

@main struct OarhelmApp: App {
    @State private var store = CapyStore()
    @State private var router = AppRouter()
    init() {
        let regular = UIFont(name: "PaperMono-Regular", size: 15) ?? .monospacedSystemFont(ofSize: 15, weight: .regular)
        let title = UIFont(name: "PaperMono-Medium", size: 30) ?? .monospacedSystemFont(ofSize: 30, weight: .medium)
        UINavigationBar.appearance().titleTextAttributes = [.font: regular]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: title]
        UITabBarItem.appearance().setTitleTextAttributes([.font: regular.withSize(10)], for: .normal)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router)
                .font(VikingTheme.font(14)).tint(VikingTheme.accent).foregroundStyle(VikingTheme.ink).preferredColorScheme(.dark)
        }
    }
}
struct RootView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var widthClass
    @AppStorage("oarhelmOnboardingComplete") private var onboardingComplete = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    var body: some View {
        @Bindable var router = router
        Group {
            if !onboardingComplete {
                OnboardingView(state: router.onboarding, onComplete: { onboardingComplete = true })
            } else if widthClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                } detail: { stack(router.section) }
                    .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $router.section) {
                    ForEach(AppSection.allCases) { section in
                        stack(section).tabItem { Label(section.title, systemImage: section.symbol) }.tag(section)
                    }
                }
            }
        }
        .sheet(item: $router.sheet, onDismiss: { router.browser = nil; router.connectionOnboarding.key = "" }) { sheet in
            NavigationStack {
                Group { switch sheet { case .connect: ConnectView(); case .newThread: StartThreadView() } }
                    .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
            }.presentationBackground(.ultraThinMaterial).preferredColorScheme(.dark)
                .font(VikingTheme.font(14)).tint(VikingTheme.accent)
                .fullScreenCover(item: browserBinding(inSheet: true)) { session in
                    InAppBrowser(session: session, onClose: { router.browser = nil }).interactiveDismissDisabled(true)
                }
        }
        .fullScreenCover(item: browserBinding(inSheet: false)) { session in
            InAppBrowser(session: session, onClose: { router.browser = nil }).interactiveDismissDisabled(true)
        }
        .environment(\.openURL, OpenURLAction { url in
            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") { router.browse(url); return .handled }
            return .systemAction
        })
        .task {
            if !store.apiKey.isEmpty && !store.isConnected {
                try? await store.connect(key: store.apiKey)
                if store.isConnected && !onboardingComplete { router.onboarding.step = .project }
            }
        }
        .onChange(of: store.accountRevision) { _,_ in router.reset() }
    }
    private func browserBinding(inSheet: Bool) -> Binding<BrowserSession?> {
        Binding(get: { (router.sheet != nil) == inSheet ? router.browser : nil }, set: { router.browser = $0 })
    }
    private func stack(_ section: AppSection) -> some View {
        NavigationStack(path: router.path(for: section)) {
            Group { switch section {
            case .helm: DashboardView()
            case .threads: WorkHomeView()
            case .workspace: WorkspaceView()
            case .account: AccountView()
            } }.navigationDestination(for: AppRoute.self) { RouteDestination(route: $0).toolbar { homeToolbar } }
                .toolbar { homeToolbar }
                .toolbar {
                    if (section == .helm || section == .threads) && (router.paths[section]?.isEmpty ?? true) {
                        ToolbarItem(placement: .primaryAction) { Button("New thread", systemImage: "square.and.pencil") { router.sheet = .newThread } }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .background { VikingBackdrop() }
        }
    }
    @ToolbarContentBuilder private var homeToolbar: some ToolbarContent {
        if widthClass != .regular || columnVisibility != .all { brandedHomeToolbar }
    }
    @ToolbarContentBuilder private var brandedHomeToolbar: some ToolbarContent {
        if #available(iOS 27.1, *) {
            ToolbarItem(placement: .topBarLeading) { HomeButton() }
                .sharedBackgroundVisibility(.hidden)
                .axisBehavior(.horizontalOnly)
                .visibilityPriority(.high)
        } else if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarLeading) { HomeButton() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { HomeButton() }
        }
    }
    private var sidebar: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 8) {
                        ForEach(AppSection.allCases) { section in
                            Button { if section == .helm { router.goHome() } else { router.select(section) } } label: {
                                HStack(spacing: 15) { Image(systemName: section.symbol).frame(minWidth: 24); Text(section.title); Spacer() }.padding(15)
                            }.buttonStyle(.plain).foregroundStyle(router.section == section ? VikingTheme.accent : VikingTheme.ink)
                                .background { if router.section == section { RoundedRectangle(cornerRadius: 16).fill(VikingTheme.accent.opacity(0.13)) } }
                        }
                    }.padding(8).vikingGlass()
                    Text("Your workspace").font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
                    VStack(spacing: 6) {
                        sidebarLink("Captains", symbol: "person.2", route: .resource("Captains","/api/v1/captains","captains","captains.create"))
                        sidebarLink("Automations", symbol: "repeat", route: .resource("Automations","/api/v1/automations","automations","automations.create"))
                        sidebarLink("Reviews", symbol: "checkmark.shield", route: .reviews)
                        sidebarLink("Usage", symbol: "chart.xyaxis.line", route: .usage)
                    }
                    Button { router.sheet = .newThread } label: { Label("New thread", systemImage: "plus").frame(maxWidth: .infinity) }.vikingPrimary()
                }.padding(18)
        }.background { VikingBackdrop() }
            .navigationTitle("Oarhelm").navigationBarTitleDisplayMode(.inline)
            .toolbar { brandedHomeToolbar }
    }
    private func sidebarLink(_ title: String, symbol: String, route: AppRoute) -> some View {
        Button { router.selectWorkspaceRoot(route) } label: { Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 11) }.buttonStyle(.plain).foregroundStyle(VikingTheme.secondary)
    }
}
struct ConnectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CapyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        OnboardingView(state: router.connectionOnboarding, onComplete: { dismiss() }, allowExplore: false)
            .interactiveDismissDisabled(router.connectionOnboarding.checking)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { router.connectionOnboarding.key = ""; dismiss() }.disabled(router.connectionOnboarding.checking) } }
            .onAppear { if !store.isConnected && router.connectionOnboarding.step == .ready { router.connectionOnboarding.step = .keyGuide } }
    }
}
struct AccountView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var disconnect = false
    var body: some View {
        VikingScreen {

            VikingPanel {
                VStack(alignment: .leading, spacing: 20) {
                    Label(store.isConnected ? "Connected to Capy" : "Not connected", systemImage: store.isConnected ? "checkmark.seal" : "key").foregroundStyle(store.isConnected ? VikingTheme.success : VikingTheme.accent)
                    if store.isConnected { Button("Disconnect", role: .destructive) { disconnect = true }.vikingSecondary() }
                    else { Button("Connect to Capy") { router.sheet = .connect }.vikingPrimary() }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Button("Setup guide", systemImage: "questionmark.circle") { router.connectionOnboarding.step = store.isConnected ? .project : .welcome; router.sheet = .connect }.vikingSecondary()
                Text("Web").font(VikingTheme.font(20, weight: .medium))
                Link(destination: URL(string: "https://capy.ai/sign-in")!) { VikingActionRow(title: "Capy dashboard", subtitle: "", symbol: "globe") }
                Link(destination: URL(string: "https://docs.capy.ai")!) { VikingActionRow(title: "Documentation", subtitle: "", symbol: "book") }
                Text("Tools").font(VikingTheme.font(20, weight: .medium))
                NavigationLink(value: AppRoute.usage) { VikingActionRow(title: "Usage and credits", subtitle: "", symbol: "chart.xyaxis.line") }
                NavigationLink(value: AppRoute.controls) { VikingActionRow(title: "Advanced controls", subtitle: "All API actions", symbol: "slider.horizontal.3") }
                NavigationLink(value: AppRoute.issueSettings) { VikingActionRow(title: "Issue preferences", subtitle: "States and labels", symbol: "tag") }
            }
            VikingPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Manage in Capy").font(VikingTheme.font(17, weight: .medium))
                    Text("Computers, integrations, credits, and plugins.").font(VikingTheme.font(13)).foregroundStyle(VikingTheme.secondary).lineSpacing(5)
                    Link("Open Capy", destination: URL(string: "https://capy.ai/sign-in")!).vikingSecondary()
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) { Text("Oarhelm for Capy").font(VikingTheme.font(13, weight: .medium)); Link("Documentation", destination: URL(string: "https://docs.capy.ai")!).font(VikingTheme.font(12)) }
            }
        }.navigationTitle("Account").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Disconnect this device?", isPresented: $disconnect, titleVisibility: .visible) { Button("Disconnect", role: .destructive) { store.disconnect() } } message: { Text("API key will be removed from this device.") }
    }
}
