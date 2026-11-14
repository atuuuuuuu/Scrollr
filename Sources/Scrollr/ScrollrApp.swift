import SwiftUI

@main
struct ScrollrApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--render-art"), i + 1 < CommandLine.arguments.count {
            MainActor.assumeIsolated { ArtRenderer.run(CommandLine.arguments[i + 1]) }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(get: { delegate.app.showIcon }, set: { delegate.app.showIcon = $0 })) {
            MenuContent(app: delegate.app)
        } label: {
            MenuIcon(app: delegate.app)
        }
        Settings {
            SettingsView(app: delegate.app)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let app = Controller()

    /// Opening Scrollr again (Finder, Spotlight) brings a hidden menu bar icon back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        app.showIcon = true
        return true
    }
}

private struct MenuIcon: View {
    @ObservedObject var app: Controller
    var body: some View {
        Image(nsImage: app.active ? Brand.menuIcon : Brand.menuIconPaused)
            .accessibilityLabel("Scrollr: \(app.status)")
    }
}

private struct MenuContent: View {
    @ObservedObject var app: Controller
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(app.status)
        if !app.trusted {
            Button("Allow in \(Controller.accessibilityName)…", action: app.openPrivacySettings)
        }
        Divider()
        Toggle("Reverse Mouse Scrolling", isOn: $app.enabled)
        if app.autoDetect {
            Section(app.mice.isEmpty ? "No Mouse Connected" : "Connected Mice") {
                ForEach(app.mice, id: \.id) { mouse in
                    Toggle(mouse.name, isOn: app.binding(for: mouse)).disabled(!app.enabled)
                }
            }
        }
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit Scrollr") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

extension Controller {
    /// On/off switch for one mouse, stored as "excluded" so new mice start on.
    func binding(for mouse: Mice.Mouse) -> Binding<Bool> {
        Binding(get: { !self.excluded.contains(mouse.id) },
                set: { on in if on { self.excluded.remove(mouse.id) } else { self.excluded.insert(mouse.id) } })
    }
}
