# AppSwitcher

AppSwitcher is a minimal native macOS utility for switching between running applications with a Contexts-like key hold workflow:

1. Hold Escape.
2. Type a fuzzy app abbreviation, for example `saf`, `ter`, `chr`, or `code`.
3. Release Escape to activate the best running-app match.

The activation key is configurable in the settings window. The app also supports a small same-app window cycler on `Command` + backtick, with `Command` + `Shift` + backtick cycling backward.

It does not implement launching, a command palette, or a productivity-suite style feature set.

## Requirements

- macOS 14 or newer.
- Apple Silicon Mac.
- Xcode 26.x or a recent Xcode with the macOS SDK.

## Permissions

The global Escape hold shortcut uses a `CGEvent` tap. macOS may require:

- Accessibility permission.
- Input Monitoring permission.

The settings window has explicit request buttons for both permissions. Once macOS reports access as granted, each button is replaced by a green granted indicator.

If the event tap cannot be created, AppSwitcher asks macOS to show the Accessibility prompt and displays a short explanation with buttons for the relevant System Settings panes. After granting permissions, relaunch the app.

## Settings

Open settings from the menu bar icon, or from the app menu when the Dock icon is enabled.

Available options:

- Activation key selection.
- Show or hide the menu bar icon.
- Show or hide the Dock icon.
- Enable or disable same-app window cycling with `Command` + backtick.
- Enable or disable automatic start at login.
- Enable or disable Liquid Glass overlay styling. This is off by default and uses `NSGlassEffectView` on macOS 26 or newer; older systems keep the standard material overlay.
- Show or hide application icons in the app and window switcher lists. Icons are off by default.
- Set the maximum number of visible list entries. The default is 5.
- Request Accessibility and Input Monitoring permissions.
- Quit AppSwitcher.

## Build And Run

Build and test:

```sh
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -derivedDataPath .build test
```

Build only:

```sh
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -derivedDataPath .build build
```

For compiler-only verification on a machine without the configured signing certificate:

```sh
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

Run from Xcode with the `AppSwitcher` scheme, or run the built app bundle:

```sh
open .build/Build/Products/Debug/AppSwitcher.app
```

The menu bar icon is enabled by default. The Dock icon is off by default and can be enabled in settings.

## Key Handling

AppSwitcher consumes the configured activation key-down event to enter switch mode. The search overlay stays hidden until the first query character is typed. If the activation key is released without a query, the app synthesizes a replacement key-down and key-up pair so the foreground app still receives a normal press.

Those synthesized events carry a private `eventSourceUserData` marker. The event tap checks for that marker and passes the replacement events through instead of treating them as a new activation.

While switch mode is active, alphanumeric key events, Backspace, and Up/Down arrows are consumed so query text and navigation do not leak into the foreground app. Activation-key repeat events are ignored. Once a query has been typed, the overlay stays open even if Backspace deletes the query back to empty. In that empty-after-typing state, Up/Down still navigates the running-app list and releasing the activation key selects the highlighted app.

Only bare activation-key presses enter switch mode. Modified shortcuts such as `Command` + `Option` + Escape are passed through to macOS.

When activating a matched app with no visible windows, AppSwitcher asks LaunchServices to open the already-running application bundle. This mirrors a Dock icon click more closely than plain process activation, so apps like Safari can reopen a window. If no window appears shortly after activation, AppSwitcher falls back to sending `Command` + `N`.

`Command` + backtick is handled separately when same-app window cycling is enabled. The app uses Accessibility window APIs to list windows for the frontmost application and shows a small window list overlay while Command is held. `Command` + `Shift` + backtick cycles backward, Up/Down arrows move through the same list, and alphanumeric typing fuzzy-searches window titles. Backspace edits the window query. The highlighted window is not focused until Command is released. If the frontmost app has only one window, the overlay still appears with that window selected and focus remains there. Minimized windows are included and are unminimized before focus. When the custom feature is disabled, AppSwitcher passes `Command` + backtick through.

The app and window overlays respect the configured maximum list-entry count as a visible-row limit. The overlay height is adjusted to the number of visible rows, optional icons increase row height slightly, and keyboard navigation can still move through the full matching app or window set by sliding the visible list.

## Known Limitations

- App switching still targets running applications only.
- No launcher behavior for apps that are not already running.
- Same-app window cycling depends on Accessibility window metadata exposed by each application.
- No-visible-window app activation uses LaunchServices first, then the app's standard `Command` + `N` shortcut as a fallback.
- Automatic start at login uses `SMAppService.mainApp` and requires a signed app.
- Matching uses a small deterministic in-process fuzzy matcher, not Spotlight or LaunchServices search.
- The overlay is centered on the screen containing the pointer, which is a practical approximation of the active screen.

## Manual Test Plan

- Launch the app.
- Grant Accessibility and Input Monitoring permissions if prompted, then relaunch.
- Open settings from the menu bar icon.
- Change the activation key and confirm the hold-to-search workflow uses the new key.
- Toggle the menu bar icon and Dock icon.
- Toggle automatic start at login.
- Toggle Liquid Glass styling if running on macOS 26 or newer.
- Toggle list icons and confirm both switcher overlays show or hide application icons.
- Change maximum list entries and confirm both switcher overlays cap their visible rows and resize.
- Use the settings quit button and confirm the app exits.
- Open Safari, Terminal, Finder, and another app.
- Hold Escape, type `saf`, release Escape: Safari should become active.
- Hold Escape, type `ter`, release Escape: Terminal should become active.
- Hold Escape without typing: no overlay should appear.
- Press and release Escape without typing: the foreground app should receive a normal Escape.
- Hold Escape, type random letters with no match, release: nothing should switch.
- Hold Escape, type `saf`, press Backspace until the query is empty: the overlay should stay open.
- With that emptied query still open, use Up/Down and release Escape: the highlighted visible app should activate.
- Continue typing after deleting to empty, release: the corrected query should be used.
- Hold Escape, type a query with multiple matches, use Up/Down, release: the highlighted app should activate.
- Set maximum list entries to a small value, then use Up/Down in a larger app result set: the visible list should scroll while selection continues through all matches.
- In an app with multiple windows, press `Command` + backtick repeatedly: it should move the window overlay highlight without focusing the selected window yet.
- In an app with one window, press `Command` + backtick: the window overlay should show one entry and the same window should remain focused.
- Keep Command held and release backtick after window cycling: the window overlay should remain visible and the focused window should not change.
- While keeping Command held, use Up/Down arrows in the window overlay: the highlighted window should change.
- While keeping Command held, type part of a window title: the window overlay should fuzzy-filter to matching windows.
- Use Backspace in the window overlay: the window query should update and the filtered list should refresh.
- Press `Command` + `Shift` + backtick: it should cycle through windows in the opposite direction.
- Minimize one window, then use `Command` + backtick: the minimized window should be included and restored when selected.
- Release Command after window cycling: the highlighted window should be focused and the window overlay should hide immediately.
- Press `Command` + `Option` + Escape: macOS should open Force Quit Applications.
- Switch to Safari after closing all Safari windows: Safari should behave like a Dock icon click and open a new window.
- Typed query letters should not appear in the foreground app.
