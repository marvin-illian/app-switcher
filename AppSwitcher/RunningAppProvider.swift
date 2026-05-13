import AppKit

struct RunningAppInfo: Identifiable {
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let application: NSRunningApplication
    let icon: NSImage?

    var id: String {
        "\(bundleIdentifier)-\(processIdentifier)"
    }
}

final class RunningAppProvider {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func runningApps() -> [RunningAppInfo] {
        let currentPID = NSRunningApplication.current.processIdentifier
        let currentBundleIdentifier = Bundle.main.bundleIdentifier

        return workspace.runningApplications
            .compactMap { application -> RunningAppInfo? in
                guard application.activationPolicy == .regular,
                      !application.isTerminated,
                      application.processIdentifier != currentPID,
                      let bundleIdentifier = application.bundleIdentifier,
                      bundleIdentifier != currentBundleIdentifier,
                      let name = application.localizedName,
                      !name.isEmpty else {
                    return nil
                }

                return RunningAppInfo(
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    processIdentifier: application.processIdentifier,
                    application: application,
                    icon: application.icon
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
