# Project Conventions

This is a small native macOS Swift/AppKit utility. Keep changes focused on the Escape-hold running-app switcher MVP unless a task explicitly expands scope.

## Architecture

- `AppDelegate` wires the app together and handles permission failure UI.
- `KeyboardMonitor` owns the `CGEvent` tap, activation-key pass-through behavior, query navigation, and `Command` + backtick interception.
- `SwitchSessionState` owns switch-mode state, query text, matching, and activation.
- `RunningAppProvider` enumerates `NSWorkspace.shared.runningApplications`.
- `FuzzyMatcher` is pure Swift and covered by unit tests.
- `OverlayWindowController` and `OverlayView` render the lightweight non-activating app and window overlays.
- `Assets.xcassets/AppIcon.appiconset` is the bundle icon used by Finder and the Dock. `AppIconFactory` is still used for runtime/menu-bar generated images.
- `AppPreferences`, `SettingsView`, and `SettingsWindowController` own user-facing preferences.
- `PermissionController` owns Accessibility/Input Monitoring request and status checks.
- `LoginItemController` owns `SMAppService.mainApp` start-at-login state.
- `WindowCycler` owns Accessibility-based same-app window cycling.

## Rules

- Use native Swift, AppKit, and SwiftUI only. Do not add third-party dependencies for the MVP.
- Do not implement app launching, a command palette, or broader productivity-suite behavior unless requested.
- Keep event-tap changes conservative. Normal keyboard traffic must pass through unless switch mode is active.
- Treat only bare activation-key presses as switch-mode starts. Modified shortcuts such as `Command` + `Option` + Escape must pass through.
- Preserve the no-query activation-key pass-through behavior and the synthetic-event marker guard.
- Keep the search overlay hidden until the query is non-empty.
- Once any query character has been typed in a session, keep the search overlay visible even if Backspace deletes the query back to empty.
- Keep the same-app window overlay visible across repeated backtick presses. Do not focus the highlighted window until Command is released.
- Same-app window cycling supports `Command` + `Shift` + backtick for reverse cycling and should include minimized windows where Accessibility exposes them.
- Same-app window cycling also supports Up/Down arrow navigation and fuzzy-search typing while the overlay is open.
- No-visible-window app activation should behave like a Dock icon click by using LaunchServices before falling back to `Command` + `N`.
- Keep Liquid Glass optional and off by default. Use native `NSGlassEffectView` only behind availability checks.
- Exclude the switcher app from matches where practical.
- Add or update focused tests for matcher behavior when changing fuzzy scoring.

## Verification

Preferred command:

```sh
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -derivedDataPath .build test
```

For compiler verification when signing is not available locally:

```sh
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

If XCTest cannot communicate with macOS test services from a sandboxed environment, rerun with the needed local permission rather than weakening the tests.
