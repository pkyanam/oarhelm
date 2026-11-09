import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable { case welcome, keyGuide, keyEntry, project, ready }
@MainActor @Observable final class OnboardingState {
    var step: OnboardingStep
    var key = ""
    var checking = false
    var error: String?
    init(step: OnboardingStep = .welcome) { self.step = step }
    func advance(connected: Bool) {
        switch step {
        case .welcome: step = connected ? .project : .keyGuide
        case .keyGuide: step = .keyEntry
        case .keyEntry: if connected { key = ""; error = nil; step = .project }
        case .project: if connected { step = .ready }
        case .ready: break
        }
    }
    func back() {
        guard !checking else { return }
        error = nil
        switch step { case .welcome: break; case .keyGuide: step = .welcome; case .keyEntry: step = .keyGuide; case .project: step = .keyEntry; case .ready: step = .project }
    }
}
