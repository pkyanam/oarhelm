import SwiftUI

/// A compact identity control, never an illustration in the page content.
/// Native toolbar placement leaves fold, camera and vertical-bar positioning to SwiftUI.
struct HomeButton: View {
    @Environment(AppRouter.self) private var router
    var body: some View {
        if #available(iOS 26, *) {
            button.buttonStyle(.glass).buttonBorderShape(.circle)
        } else {
            button.buttonStyle(.bordered).buttonBorderShape(.circle)
        }
    }
    private var button: some View {
        Button { router.goHome() } label: {
            Label {
                Text("Home")
            } icon: {
                Image("BrandMark").resizable().scaledToFit()
                    .frame(width: 36, height: 36).clipShape(Circle())
            }.labelStyle(.iconOnly).padding(4).frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Home")
        .accessibilityHint("Return to the helm. Unsent drafts are kept.")
        .accessibilityIdentifier("oarhelm-home")
        .help("Home")
    }
}
