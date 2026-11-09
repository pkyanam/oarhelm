import SwiftUI

struct RouteDestination: View {
    let route: AppRoute
    var body: some View {
        Group {
            switch route {
            case .thread(let thread): ThreadDetailView(thread: thread)
            case .operation(let id, let defaults):
                switch id {
                case "captains.create": CreateCaptainView(defaults: defaults)
                case "automations.create": CreateAutomationView(defaults: defaults)
                case "issues.create": CreateIssueView(defaults: defaults)
                default: OperationView(operationID: id, defaults: defaults)
                }
            case .advancedOperation(let id, let defaults): OperationView(operationID: id, defaults: defaults)
            case .resource(let title,let path,let kind,let create): ResourceList(title: title, path: path, create: create, kind: kind)
            case .resourceItem(let kind,let item):
                if kind == "captains" { CaptainDetailView(captain: item) }
                else { ResourceItem(kind: kind, item: item) }
            case .data(let title,let path): ResourceDetail(title: title, path: path)
            case .reviews: ReviewHubView()
            case .usage: UsageDashboardView()
            case .issueSettings: IssueSettingsView()
            case .helpers(let id): HelperListView(threadID: id)
            case .controls: APIConsoleView()
            }
        }.navigationBarTitleDisplayMode(.inline).foregroundStyle(VikingTheme.ink).tint(VikingTheme.accent)
            .background { VikingBackdrop() }
    }
}
