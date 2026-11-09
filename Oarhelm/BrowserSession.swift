import Foundation
import Observation

enum BrowserPhase: Equatable { case opening, loading, ready, failed(String) }
enum BrowserOverlayMode: Equatable { case visible, docked, hidden }
@MainActor @Observable final class BrowserSession: Identifiable {
    let id = UUID()
    let url: URL
    var phase: BrowserPhase = .opening
    var overlayMode: BrowserOverlayMode = .visible
    var canGoBack = false
    var dockedLeft = true
    var verticalPosition: Double = 0.45
    var currentURL: URL?
    var isLoading: Bool {
        get { phase == .opening || phase == .loading }
        set { if newValue { phase = .loading } else if isLoading { phase = .ready } }
    }
    var error: String? {
        get { if case .failed(let error) = phase { return error }; return nil }
        set { if let newValue { phase = .failed(newValue) } else if case .failed = phase { phase = .ready } }
    }
    func restoreControls() { overlayMode = .visible }
    func dockControls() { overlayMode = .docked }
    func hideControls() { overlayMode = .hidden }
    init(url: URL) { self.url = url }
}
