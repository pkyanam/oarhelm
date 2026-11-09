# Notify browser research

Read-only inspection of `notify/apps/expo/modules/notify-web-apps/ios/NotifyHostedWebView.swift` and `NotifyAppWebView.swift`: hosted pages use a WKWebView with a website data store, transparent web and scroll backgrounds, navigation delegates, and route target-frame-less links into the existing view. The shared view installs a native long-press recognizer and allows simultaneous recognition with WebKit gestures. Notify's hosted origin restrictions and device bridges are specific to its verified apps; Oarhelm's general browser does not reproduce those bridges.

## Oarhelm integration

Oarhelm uses a persistent WKWebView with native Liquid Glass return controls, same-view HTTP and HTTPS popup routing, loading and retry states, page-color backing, and the two-finger restore recognizer. Website requests never receive Capy's API key. The browser is a fullscreen cover owned by the currently presented root or sheet, preserving the sheet and its local navigation. The cover disables interactive dismissal without changing the presenting sheet's UIKit dismissal flags.

Control modes are visible, docked as an edge tab, and entirely hidden. Holding the visible control offers Back, Reload, Dock, Hide, and Return. An outward horizontal drag docks; a vertical drag repositions it. Active fold and camera regions are queried for control placement. VoiceOver retains visible return controls. The first-use explanation persists only after Got it.

Simulator verification: public Capy and documentation pages loaded, light page color filled the outer Duo status column, the documentation page filled the inner display, Return restored the underlying setup sheet, the edge tab restored the control, a two-finger hold recovered a hidden control, and a downward gesture did not dismiss the fullscreen browser. Fold pose requests returned no hinge-angle sample, so active displays were confirmed by screenshots rather than angle telemetry.
