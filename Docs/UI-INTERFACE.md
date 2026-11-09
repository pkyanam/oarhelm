# Redesign integration contract

Root owns VikingTheme.swift, AppRouter.swift, OarhelmApp.swift, DashboardView.swift, CapyAPI.swift and project files. Thread agent owns WorkViews.swift only. Workspace agent owns WorkspaceTools.swift, StartThreadView.swift and FileTransfer.swift only. Existing API contract and transport APIs stay compatible.

Shared primitives (root implements):
- VikingTheme: background, surface, raised, ink, secondary, accent (warm brass), ember, success, danger Colors. static font(CGFloat, weight: Font.Weight = .regular) -> Font, using Paper Mono.
- VikingBackdrop: View background; .ignoresSafeArea only background itself.
- VikingPanel<Content:View>(@ViewBuilder content:()->Content): glass surface with padding, RoundedRectangle 22; do not stack glass inside glass.
- VikingScreen<Content:View>(@ViewBuilder content:()->Content): scrollable background, max content width 960, margins 20. Use for overview/forms, not entire chat which owns its ScrollView.
- VikingEmptyState(title:String,message:String,symbol:String = "sailboat",actionTitle:String? = nil,action:(()->Void)? = nil)
- VikingPageHeader(title:String,subtitle:String,symbol:String) non-card heading.
- VikingActionRow(title:String,subtitle:String,symbol:String) label for NavigationLink; root applies glass to whole row when used. No nested panels.
- .vikingGlass() View modifier: actual .glassEffect on iOS26+ and material fallback. .vikingPrimary() and .vikingSecondary() View modifiers for Button styles.
- .vikingList() View modifier: clear list backgrounds, warm dark row surfaces, theme text, inset list styling.

Routing:
AppRoute: Hashable cases .thread(JSONValue), .operation(String,[String:String]), .resource(String,String,String,String?) [title,path,kind,create], .resourceItem(String,JSONValue), .data(String,String), .reviews, .usage, .issueSettings, .helpers(String), .controls.
Use NavigationLink(value: AppRoute...) for ALL drill-ins. Root registers navigationDestination and owns navigation stack. No NavigationStack inside WorkHomeView or WorkspaceView. StartThreadView modal may NavigationLink(value:) via modal stack root registration.
AppRouter @Observable @MainActor environment: var section: AppSection [.helm,.threads,.workspace,.account], var sheet: AppSheet? [.connect,.newThread]; var drafts:[String:String], var deliveries:[String:String]; func open(_ route:AppRoute), func select(_ section:AppSection), func reset(), paths dictionary. All shell paths survive compact/regular changes. Draft text lives router.drafts[threadId].
Root screens existing type names preserved: WorkHomeView, ThreadDetailView(thread:JSONValue), WorkspaceView, ResourceList(title:path:create:kind:), ResourceItem(kind:item:), ResourceDetail(title:path:), ReviewHubView, UsageDashboardView, IssueSettingsView, HelperListView(threadID:), StartThreadView. Resource* types must be internal, not private, for root destination routing.

Direction: near-black timber world, cream legible copy, warm brass glass controls, restrained ember/sea-green status. Supplied Image("Helm") for logo only; no fantasy glyphs, slogans, mock records, all-caps eyebrows. Actual Liquid Glass (.buttonStyle(.glass/.glassProminent), .glassEffect) iOS26+ availability guards, not just .material pretending to be glass. Sidebar and nav bars stay system-native so Duo reserved regions work. Paper Mono throughout. Clean signed-out and no-data states with explicit actions. No long menus for everyday tasks; advanced API options under disclosure/More. Use human task names, sentence case. Inner uses spacious two-pane shell with sidebar; narrow uses tab dock and stack. Size classes/container widths, no fixed device dimensions.
