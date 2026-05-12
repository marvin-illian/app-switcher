import Combine
import ServiceManagement

final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusText = ""

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            statusText = "Enabled"
        case .requiresApproval:
            isEnabled = true
            statusText = "Needs approval in System Settings"
        case .notRegistered:
            isEnabled = false
            statusText = "Off"
        case .notFound:
            isEnabled = false
            statusText = "Unavailable"
        @unknown default:
            isEnabled = false
            statusText = "Unknown"
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusText = error.localizedDescription
        }

        refresh()
    }
}
