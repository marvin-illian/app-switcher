import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var permissionController: PermissionController
    @ObservedObject var loginItemController: LoginItemController
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: AppIconFactory.appIcon(size: 48))
                    .resizable()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AppSwitcher")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Running app switcher")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Activation key")
                Spacer()
                Picker("", selection: $preferences.activationKey) {
                    ForEach(ActivationKey.knownKeys) { key in
                        Text(key.name).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }

            Toggle("Show menu bar icon", isOn: $preferences.showMenuBarIcon)
            Toggle("Show Dock icon", isOn: $preferences.showDockIcon)
            Toggle("Cycle same-app windows with Command-`", isOn: $preferences.enableWindowCycling)
            Toggle("Use Liquid Glass overlay style", isOn: $preferences.enableLiquidGlass)
            Toggle("Show icons in switcher lists", isOn: $preferences.showOverlayIcons)

            HStack {
                Text("Maximum list entries")
                Spacer()
                Stepper(
                    "\(preferences.maxListEntries)",
                    value: $preferences.maxListEntries,
                    in: AppPreferences.maxListEntriesRange
                )
                .frame(width: 92)
            }

            HStack {
                Toggle("Start automatically at login", isOn: Binding(
                    get: { loginItemController.isEnabled },
                    set: { loginItemController.setEnabled($0) }
                ))
                Spacer()
                Text(loginItemController.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(
                    title: "Accessibility",
                    isGranted: permissionController.accessibilityGranted,
                    action: permissionController.requestAccessibility
                )
                PermissionRow(
                    title: "Input Monitoring",
                    isGranted: permissionController.inputMonitoringGranted,
                    action: permissionController.requestInputMonitoring
                )
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit AppSwitcher") {
                    quit()
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            permissionController.refresh()
            loginItemController.refresh()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Granted")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Request Access") {
                    action()
                }
            }
        }
    }
}
