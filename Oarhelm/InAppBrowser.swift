import SwiftUI
import WebKit
import UIKit

struct InAppBrowser: View {
    @Bindable var session: BrowserSession
    let onClose: () -> Void
    @AppStorage("browserControlsTutorialV2") private var acknowledged = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var background = Color(uiColor: .systemBackground)
    @State private var darkChrome = true
    @State private var webView: WKWebView?
    @State private var dragging: CGSize = .zero
    private var mode: BrowserOverlayMode { voiceOver ? .visible : session.overlayMode }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88) }

    var body: some View {
        GeometryReader { geometry in
            let inset = geometry.safeAreaInsets
            let width = geometry.size.width, height = geometry.size.height
            let minX = inset.leading + 30
            let maxX = max(minX, width - inset.trailing - 30)
            let x = session.dockedLeft ? minX : maxX
            let minY = inset.top + 30
            let maxY = max(minY, height - inset.bottom - 30)
            let y = min(max(height * session.verticalPosition, minY), maxY)
            let visiblePoint = clearPoint(CGPoint(x: min(max(x + dragging.width, minX), maxX), y: min(max(y + dragging.height, minY), maxY)), in: geometry)
            let dockedPoint = clearPoint(CGPoint(x: session.dockedLeft ? inset.leading + 22 : width - inset.trailing - 22, y: y), in: geometry)
            let outsideX: CGFloat = session.dockedLeft ? -60 : width + 60
            ZStack {
                // The page stays within system-safe bounds. Its backing surface fills every edge.
                BrowserWebView(session: session, background: $background, darkChrome: $darkChrome, webView: $webView)
                if session.isLoading {
                    ProgressView().padding(12).background(.regularMaterial, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 12).allowsHitTesting(false)
                }
                if let error = session.error {
                    VStack(spacing: 16) {
                        Text("Couldn’t load page").font(VikingTheme.font(20, weight: .medium))
                        Text(error).font(VikingTheme.font(12)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Button("Retry") { session.error = nil; webView?.reload() }.vikingPrimary()
                        Button("Return to Oarhelm", action: onClose).vikingSecondary()
                    }.padding(20).vikingGlass().padding(24)
                }
                menuControl
                    .position(x: mode == .visible ? visiblePoint.x : outsideX, y: visiblePoint.y)
                    .opacity(mode == .visible ? 1 : 0)
                    .allowsHitTesting(mode == .visible)
                    .accessibilityHidden(mode != .visible)
                    .animation(motion, value: mode)
                    .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { value in
                        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
                        withTransaction(transaction) { dragging = value.translation }
                    }.onEnded { value in
                        withAnimation(motion) {
                            let targetX = x + value.translation.width
                            session.dockedLeft = targetX < width / 2
                            session.verticalPosition = Double(min(max(y + value.translation.height, minY), maxY) / max(height, 1))
                            let outward = session.dockedLeft ? value.translation.width < -24 : value.translation.width > 24
                            let atEdge = targetX < minX + 8 || targetX > maxX - 8
                            if outward && atEdge && abs(value.translation.width) > abs(value.translation.height) { session.dockControls() }
                            dragging = .zero
                        }
                    })
                dockedControl
                    .position(x: mode == .docked ? dockedPoint.x : outsideX, y: dockedPoint.y)
                    .opacity(mode == .docked ? 1 : 0)
                    .allowsHitTesting(mode == .docked)
                    .accessibilityHidden(mode != .docked)
                    .animation(motion, value: mode)
            }
            .accessibilityAction(named: "Restore browser controls") { session.restoreControls() }
            .accessibilityAction(named: "Return to Oarhelm", onClose)
        }
        .background { background.ignoresSafeArea(.container) }
        .interactiveDismissDisabled(true)
        .preferredColorScheme(darkChrome ? .dark : .light)
        .alert("Browser controls", isPresented: Binding(get: { !acknowledged }, set: { _ in })) {
            Button("Got it") { acknowledged = true }
        } message: { Text("Tap the logo for the menu. Drag to an edge to dock. Two-finger hold restores hidden controls.") }
    }
    private func clearPoint(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        guard #available(iOS 27.1, *) else { return point }
        let regions = (geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed) + geometry.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)).filter(\.isActive).map(\.frame)
        func clear(_ candidate: CGPoint) -> Bool {
            let frame = CGRect(x: candidate.x - 30, y: candidate.y - 30, width: 60, height: 60)
            return !regions.contains { $0.intersects(frame) }
        }
        guard !clear(point) else { return point }
        let inset = geometry.safeAreaInsets
        let minY = inset.top + 30, maxY = max(minY, geometry.size.height - inset.bottom - 30)
        let candidates = regions.flatMap { region in [CGPoint(x: point.x, y: region.minY - 31), CGPoint(x: point.x, y: region.maxY + 31)] }
            .filter { $0.y >= minY && $0.y <= maxY && clear($0) }
        return candidates.min { abs($0.y - point.y) < abs($1.y - point.y) } ?? point
    }
    private var menuControl: some View {
        Group {
            if #available(iOS 26, *) { browserMenu.buttonStyle(.glass).buttonBorderShape(.circle) }
            else { browserMenu.buttonStyle(.bordered).buttonBorderShape(.circle) }
        }
    }
    private var browserMenu: some View {
        Menu {
            if let host = (session.currentURL ?? session.url).host { Text(host) }
            Button("Back", systemImage: "chevron.backward") { webView?.goBack() }.disabled(!session.canGoBack)
            Button("Forward", systemImage: "chevron.forward") { webView?.goForward() }.disabled(webView?.canGoForward != true)
            Button("Reload", systemImage: "arrow.clockwise") { webView?.reload() }
            Button("Find in Page", systemImage: "magnifyingglass") { webView?.findInteraction?.presentFindNavigator(showingReplace: false) }
            ShareLink(item: session.currentURL ?? session.url) { Label("Share page", systemImage: "square.and.arrow.up") }
            Divider()
            Button("Dock", systemImage: "sidebar.left") { session.dockControls() }
            Button("Hide", systemImage: "eye.slash") { session.hideControls() }
            Divider()
            Button("Return to Oarhelm", systemImage: "house", action: onClose)
        } label: {
            Image("BrandMark").resizable().scaledToFit().frame(width: 32, height: 32).clipShape(Circle()).padding(10)
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Browser controls")
        .accessibilityHint("Opens navigation and visibility controls.")
        .accessibilityIdentifier("browser-controls")
    }
    private var dockedControl: some View {
        Button { session.restoreControls() } label: {
            Image(systemName: session.dockedLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 11, weight: .semibold)).frame(width: 14, height: 54)
                .vikingGlass().offset(x: session.dockedLeft ? -14 : 14)
                .frame(width: 44, height: 60).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("Restore browser controls")
            .accessibilityIdentifier("browser-docked-control")
    }
}

private struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession
    @Binding var background: Color
    @Binding var darkChrome: Bool
    @Binding var webView: WKWebView?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.add(context.coordinator, contentWorld: .defaultClient, name: "oarhelmCanvas")
        config.userContentController.addUserScript(WKUserScript(source: Self.canvasScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator; view.uiDelegate = context.coordinator
        view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .automatic
        view.allowsBackForwardNavigationGestures = true
        view.isFindInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.restore(_:)))
        gesture.numberOfTouchesRequired = 2; gesture.minimumPressDuration = 0.8
        gesture.cancelsTouchesInView = false; gesture.delegate = context.coordinator
        view.addGestureRecognizer(gesture)
        DispatchQueue.main.async { webView = view }
        if ["http", "https"].contains(session.url.scheme?.lowercased() ?? "") { view.load(URLRequest(url: session.url)) }
        else { session.error = "Use an HTTP or HTTPS address." }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "oarhelmCanvas", contentWorld: .defaultClient)
    }
    // Read rendered edge colors in an isolated script world. No website DOM or CSS is changed.
    private static let canvasScript = #"""
    (() => {
        let timer, previous;
        const canvas = document.createElement('canvas'); canvas.width = canvas.height = 1;
        const context = canvas.getContext('2d', { willReadFrequently: true });
        if (!context) return;
        function rgba(color) {
            context.clearRect(0, 0, 1, 1); context.fillStyle = color; context.fillRect(0, 0, 1, 1);
            return Array.from(context.getImageData(0, 0, 1, 1).data);
        }
        function edgeColor(x, y) {
            let element = document.elementFromPoint(x, y);
            while (element) {
                const color = rgba(getComputedStyle(element).backgroundColor);
                if (color[3] === 255) return color;
                element = element.parentElement;
            }
            return null;
        }
        function sample() {
            const w = innerWidth, h = innerHeight;
            const colors = [[w / 2, h - 2], [2, h - 2], [w - 2, h - 2]]
                .map(([x, y]) => edgeColor(Math.max(0, x), Math.max(0, y))).filter(Boolean);
            if (!colors.length) return;
            const counts = new Map();
            for (const color of colors) { const key = color.join(','); counts.set(key, (counts.get(key) || 0) + 1); }
            colors.sort((a, b) => counts.get(b.join(',')) - counts.get(a.join(',')));
            const value = colors[0], key = value.join(',');
            if (key !== previous) { previous = key; window.webkit.messageHandlers.oarhelmCanvas.postMessage(value); }
        }
        function schedule() { if (timer !== undefined) return; timer = setTimeout(() => { timer = undefined; sample(); }, 120); }
        new MutationObserver(schedule).observe(document.documentElement, { attributes: true, subtree: true, attributeFilter: ['class', 'style'] });
        addEventListener('load', schedule); addEventListener('pageshow', schedule); addEventListener('resize', schedule);
        matchMedia('(prefers-color-scheme: dark)').addEventListener('change', schedule);
        schedule();
    })();
    """#
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate, WKScriptMessageHandler {
        var parent: BrowserWebView
        init(_ parent: BrowserWebView) { self.parent = parent }
        @objc func restore(_ gesture: UILongPressGestureRecognizer) { if gesture.state == .began { parent.session.restoreControls() } }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        func apply(_ color: UIColor, to webView: WKWebView) {
            let color = color.resolvedColor(with: webView.traitCollection)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard color.getRed(&r, green: &g, blue: &b, alpha: &a), a > 0.05 else { return }
            parent.background = Color(uiColor: color)
            parent.darkChrome = 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.5
            webView.backgroundColor = color
            webView.scrollView.backgroundColor = color
            webView.underPageBackgroundColor = color
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let view = message.webView,
                  let source = message.frameInfo.request.url, let current = view.url,
                  source.scheme == current.scheme, source.host == current.host, source.port == current.port,
                  let components = message.body as? [Double], components.count == 4,
                  components.allSatisfy({ $0.isFinite && (0...255).contains($0) }), components[3] == 255 else { return }
            apply(UIColor(red: components[0] / 255, green: components[1] / 255, blue: components[2] / 255, alpha: 1), to: view)
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { decisionHandler(.cancel); return }
            if ["http", "https"].contains(scheme) {
                if action.targetFrame == nil { webView.load(action.request); decisionHandler(.cancel) } else { decisionHandler(.allow) }
            } else if ["about", "blob", "data"].contains(scheme) { decisionHandler(.allow) }
            else {
                decisionHandler(.cancel)
                if action.navigationType == .linkActivated, action.sourceFrame.isMainFrame { UIApplication.shared.open(url) }
            }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { webView.load(action.request) }
            return nil
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { parent.session.isLoading = true; parent.session.error = nil }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.session.isLoading = false; parent.session.canGoBack = webView.canGoBack; parent.session.currentURL = webView.url
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.session.error = "Page stopped. Reload to continue." }
        private func fail(_ error: Error) { parent.session.isLoading = false; if (error as NSError).code != NSURLErrorCancelled { parent.session.error = error.localizedDescription } }
    }
}
