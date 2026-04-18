import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var isEnabled = false
    private(set) var statusDescription = "Launch at login is off."
    private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        statusDescription = Self.description(for: status)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    private static func description(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            "SlamDih starts automatically when you sign in."
        case .requiresApproval:
            "macOS needs approval in Login Items before SlamDih can start automatically."
        case .notRegistered:
            "Launch at login is off."
        case .notFound:
            "Launch at login is unavailable for this build."
        @unknown default:
            "Launch at login status is unknown."
        }
    }
}
