import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: Controller

    var body: some View {
        TabView {
            GeneralPane(app: app).tabItem { Label("General", systemImage: "gearshape") }
            MicePane(app: app).tabItem { Label("Mice", systemImage: "computermouse") }
            AboutPane().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var app: Controller
    @State private var confirmReset = false

    var body: some View {
        Form {
            if !app.trusted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill").font(.title2).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scrollr needs your permission").font(.headline)
                            Text("Turn Scrollr on in \(Controller.accessibilityName) so it can change the direction of mouse scrolls.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings", action: app.openPrivacySettings)
                    }
                    .padding(.vertical, 4)
                }
                .transition(.opacity)
            }

            Section {
                Toggle(isOn: $app.enabled.animation(.snappy)) {
                    Text("Reverse mouse scrolling")
                    Text("Mouse wheels scroll the opposite way. Your trackpad keeps the direction set in System Settings.")
                }
                if app.enabled {
                    Toggle("Up and down", isOn: $app.vertical)
                    Toggle("Left and right", isOn: $app.horizontal)
                }
            } header: {
                Text("Scrolling")
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: Binding(get: { app.launchAtLogin }, set: app.setLaunchAtLogin))
                Toggle(isOn: $app.showIcon) {
                    Text("Show in menu bar")
                    Text("When hidden, open Scrollr again from Applications to bring the icon back.")
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Restore Defaults…") { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.snappy, value: app.trusted)
        .confirmationDialog("Restore all Scrollr settings to their defaults?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive, action: app.restoreDefaults)
        } message: {
            Text("Scrolling is reversed for every mouse again, detection is turned on and Launch at login is turned off.")
        }
    }
}

// MARK: Mice

private struct MicePane: View {
    @ObservedObject var app: Controller

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $app.autoDetect.animation(.snappy)) {
                    Text("Detect mice automatically")
                    Text(app.autoDetect
                         ? "Scrollr reverses only the mice listed below, and only while they are connected."
                         : "Every scroll wheel is reversed, including mice Scrollr can't identify.")
                }
            }

            if app.autoDetect {
                Section("Connected") {
                    if app.mice.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "computermouse").foregroundStyle(.secondary)
                            Text("No external mouse connected").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    ForEach(app.mice, id: \.id) { mouse in
                        Toggle(isOn: app.binding(for: mouse)) {
                            Label {
                                Text(mouse.name)
                                Text(mouse.detail).monospacedDigit()
                            } icon: {
                                Image(systemName: "computermouse.fill").foregroundStyle(Brand.gradient)
                            }
                        }
                        .disabled(!app.enabled)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }

            Section {
                LabeledContent("Last scroll") {
                    Text(app.lastScroll ?? "Scroll with any device to check")
                        .foregroundStyle(app.lastScroll == nil ? .tertiary : .secondary)
                        .contentTransition(.opacity)
                }
            } footer: {
                Text("Trackpad scrolling is always left unchanged.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .animation(.snappy, value: app.mice)
        .animation(.easeOut(duration: 0.15), value: app.lastScroll)
    }
}

// MARK: About

private struct AboutPane: View {
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        VStack(spacing: 10) {
            AppIconView().frame(width: 96, height: 96)
            Text("Scrollr").font(.system(.title, design: .rounded, weight: .bold))
            Text("Version \(info["CFBundleShortVersionString"] as? String ?? "–") (\(info["CFBundleVersion"] as? String ?? "–"))")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Reverse your mouse. Keep your trackpad.")
                .font(.system(.body, design: .rounded))
                .padding(.top, 4)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/atuuuuuuu/Scrollr")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/atuuuuuuu/Scrollr/issues")!)
            }
            .padding(.top, 6)
            Text(info["NSHumanReadableCopyright"] as? String ?? "")
                .font(.footnote).foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}
