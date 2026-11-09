# Architecture map

| Area | Files and responsibility |
| --- | --- |
| App shell | OarhelmApp.swift selects compact tabs or expanded sidebar and hosts sheets/browser. RouteDestination.swift dispatches typed routes. |
| Navigation and drafts | AppRouter.swift canonicalizes destinations and owns account-scoped drafts, attachments, busy phases, and idempotency keys. OnboardingState.swift models setup stages. |
| API transport | CapyAPI.swift implements JSONValue, Keychain persistence, bearer HTTP requests, errors, cancellable SSE, and connection generations. No SDK or MCP dependency. |
| Contract tools | APIContract.swift reads Resources/openapi.json. APIConsole.swift renders searchable operations, schema forms, pagination, JSON trees, and advanced execution. |
| Conversations | StartThreadView.swift creates a thread. WorkViews.swift loads resources and conversations. LiveThreadState.swift reduces stream events; ChatMessageView.swift renders durable messages and tool activity. FileTransfer.swift handles presigned uploads. |
| Native workflows | CreateCaptainView.swift and CaptainDetailView.swift provide Captain setup/crew/digest. NativeWorkspaceForms.swift provides automation and issue setup. WorkspaceTools.swift holds reviews and usage. DashboardView.swift presents actual work. |
| Models and identity | ModelCatalog.swift reads the dated capy-models.json snapshot. ModelPicker.swift searches/selects it. BrandMarks.swift maps provider names to bundled marks. |
| Web | BrowserSession.swift models loading and overlay state. InAppBrowser.swift hosts persistent WebKit storage, navigation, find/share, page-derived backing color, and recoverable floating controls. |
| Visuals | VikingTheme.swift supplies Paper Mono, semantic color, spacing, and native glass. DitherSurface.swift is static texture. HomeButton.swift holds the circular identity control. |
| Verification | Tests/ContractChecks.swift and AsyncStateChecks.swift run through Scripts/check.sh. No live account fixtures are bundled. |

The API key and the web session are separate identities. WebKit must not receive the API key. The currently selected project controls scoped resources; asynchronous work must not commit across account/project changes. Drafts live in memory in the router, not an offline write queue or durable database.

Read LIMITATIONS.md before adding capabilities and API-COVERAGE.md before changing contract behavior. Read DESIGN.md before introducing new controls.
