import SwiftUI
import Charts

struct ReviewHubView: View {
    @Environment(CapyStore.self) private var store
    @Environment(AppRouter.self) private var router
    var body: some View {
        VikingScreen {
            if !store.isConnected { VikingEmptyState(title: "No connection", message: "", symbol: "checkmark.shield", actionTitle: "Connect to Capy", action: { router.sheet = .connect }) }
            else {
                NavigationLink(value: AppRoute.operation("reviews.start", [:])) { Label("Start a review", systemImage: "plus").frame(maxWidth: .infinity) }.vikingPrimary()
                NavigationLink(value: AppRoute.operation("reviews.round", [:])) { VikingActionRow(title: "Findings", subtitle: "Use a review request ID", symbol: "text.magnifyingglass").vikingGlass() }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repositories").font(VikingTheme.font(20, weight: .medium))
                    row("Review settings", "", "gearshape", "reviews.settings")
                    row("Configure repository", "", "slider.horizontal.3", "reviews.configure")
                }
                DisclosureGroup("Rules and filters") {
                    VStack(spacing: 10) {
                        row("Review rules", "", "list.bullet", "reviewRules.list")
                        row("Create rule", "", "plus", "reviewRules.create")
                        row("Filter rules", "", "line.3.horizontal.decrease", "reviewFilters.listRules")
                        row("Create filter", "", "plus", "reviewFilters.createRule")
                        row("Ignored paths", "", "folder.badge.minus", "reviewFilters.listIgnorePaths")
                        row("Add ignored paths", "", "plus", "reviewFilters.createIgnorePaths")
                    }.padding(.top, 12)
                }.padding(20).vikingGlass()
                DisclosureGroup("Review billing") {
                    VStack(spacing: 12) { ForEach([("Transfer status", "reviews.billingTransfer"), ("Offer transfer", "reviews.offerBillingTransfer"), ("Accept transfer", "reviews.acceptBillingTransfer"), ("Decline transfer", "reviews.declineBillingTransfer"), ("Cancel transfer", "reviews.cancelBillingTransfer")], id: \.1) { title, operation in NavigationLink(title, value: AppRoute.operation(operation, [:])).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) } }.padding(.top, 12)
                }.padding(20).vikingGlass()
            }
        }.navigationTitle("Reviews").navigationBarTitleDisplayMode(.inline)
    }
    private func row(_ title: String, _ subtitle: String, _ symbol: String, _ operation: String) -> some View {
        NavigationLink(value: AppRoute.operation(operation, [:])) { VikingActionRow(title: title, subtitle: subtitle, symbol: symbol) }
    }
}
struct UsageDashboardView: View {
    @Environment(CapyStore.self) private var store
    @State private var report: JSONValue?
    @State private var balance: JSONValue?
    @State private var points: [JSONValue] = []
    @State private var error: String?
    @State private var days = 7
    @State private var loadedDays: Int?
    @State private var loadID: UUID?
    @State private var loading = false
    @Environment(AppRouter.self) private var router
    var body: some View {
        VikingScreen {
            if !store.isConnected { VikingEmptyState(title: "No connection", message: "", symbol: "chart.xyaxis.line", actionTitle: "Connect to Capy", action: { router.sheet = .connect }) }
            else {
                HStack { Text("Window").foregroundStyle(VikingTheme.secondary); Spacer(); Picker("Window", selection: $days) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.menu) }.padding(16).vikingGlass()
                if loading { ProgressView("Loading…") }
                if let error { VikingPanel { VStack(alignment: .leading, spacing: 15) { Text("Couldn’t load usage"); Text(error).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary); Button("Try again") { Task { await load() } }.vikingSecondary() } } }
                if let balance {
                    VikingPanel { VStack(alignment: .leading, spacing: 16) { Text("Credits").foregroundStyle(VikingTheme.secondary); Text(balance["unlimited"] == .bool(true) ? "Unlimited" : money(balance["remainingDollars"])).font(VikingTheme.font(30, weight: .medium)); Link("Manage in Capy", destination: URL(string: "https://capy.ai/sign-in")!).font(VikingTheme.font(12)) } }
                }
                if let report {
                    VikingFormSection("Spend") {
                        LabeledContent("Billed", value: money(report["totals"]?["billedDollars"]))
                        LabeledContent("Models", value: money(report["totals"]?["llmDollars"]))
                        LabeledContent("Machines", value: money(report["totals"]?["vmDollars"]))
                        LabeledContent("Images", value: money(report["totals"]?["imageDollars"]))
                    }
                    VikingFormSection("Daily spend") {
                        if points.isEmpty { Text("No spend yet.").foregroundStyle(VikingTheme.secondary) }
                        else { Chart(Array(points.enumerated()), id: \.offset) { _, point in
                            if let date = point["start"]?.stringValue.flatMap({ ISO8601DateFormatter().date(from: $0) }), case .number(let amount) = point["billedDollars"] { BarMark(x: .value("Date", date, unit: .day), y: .value("USD", amount)).foregroundStyle(VikingTheme.accent).cornerRadius(3) }
                        }.frame(height: 180).chartYAxisLabel("USD").accessibilityLabel("Daily billed spend in US dollars") }
                    }
                    DisclosureGroup("Breakdown") { JSONTree(name: "Members", value: report["members"] ?? .array([])); JSONTree(name: "Models", value: report["models"] ?? .array([])) }.padding(20).vikingGlass()
                    NavigationLink("Usage filters and export", value: AppRoute.operation("usage.series", [:])).vikingSecondary()
                    ShareLink("Share report", item: report.prettyText).vikingSecondary()
                }
            }
        }.navigationTitle("Usage").navigationBarTitleDisplayMode(.inline).task(id: "\(store.isConnected)-\(days)") { await load() }.refreshable { await load() }
    }
    private func money(_ value: JSONValue?) -> String {
        if case .number(let amount) = value { return amount.formatted(.currency(code: "USD")) }
        return value?.stringValue ?? "Unavailable"
    }
    private func load() async {
        guard store.isConnected else { return }
        let id = UUID(); loadID = id; let period = days; let account = store.accountRevision
        if loadedDays != period { report = nil; points = []; loadedDays = period }
        loading = true; error = nil; defer { if loadID == id { loading = false } }
        let end = Date(); let start = Calendar.current.date(byAdding: .day, value: -period, to: end)!
        let formatter = ISO8601DateFormatter()
        let query = ["from": formatter.string(from: start), "to": formatter.string(from: end)]
        do {
            let newBalance = try await store.request("GET", "/api/v1/usage/balance")
            let newReport = try await store.request("GET", "/api/v1/usage", query: query)
            var seriesQuery = query; seriesQuery["granularity"] = "day"; seriesQuery["limit"] = "1000"
            let series = try await store.request("GET", "/api/v1/usage/series", query: seriesQuery)
            guard !Task.isCancelled, loadID == id, period == days, account == store.accountRevision, store.isConnected else { return }
            balance = newBalance; report = newReport; points = series["items"]?.arrayValue ?? []
        } catch { if !Task.isCancelled, loadID == id, period == days, account == store.accountRevision, store.isConnected { self.error = error.localizedDescription } }
    }
}

struct IssueSettingsView: View {
    var body: some View {
        List {
            NavigationLink("States", value: AppRoute.operation("issues.states", [:]))
            NavigationLink("Create state", value: AppRoute.operation("issues.createState", [:]))
            NavigationLink("Reorder states", value: AppRoute.operation("issues.reorderStates", [:]))
            NavigationLink("Default state", value: AppRoute.operation("issues.setDefaultState", [:]))
            NavigationLink("Labels", value: AppRoute.operation("issues.labels", [:]))
            NavigationLink("Create label", value: AppRoute.operation("issues.createLabel", [:]))
            NavigationLink("Issue prefix", value: AppRoute.operation("issues.prefix", [:]))
            NavigationLink("Set issue prefix", value: AppRoute.operation("issues.setPrefix", [:]))
        }.vikingList().navigationTitle("Issue settings")
    }
}
