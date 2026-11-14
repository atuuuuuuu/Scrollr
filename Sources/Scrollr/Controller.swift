import AppKit
import ServiceManagement

final class Controller: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { save(enabled, "enabled") } }
    @Published var vertical: Bool { didSet { save(vertical, "vertical") } }
    @Published var horizontal: Bool { didSet { save(horizontal, "horizontal") } }
    @Published var autoDetect: Bool { didSet { save(autoDetect, "autoDetect") } }
    /// Mice the user switched off individually (ids from `Mice.Mouse`).
    @Published var excluded: Set<String> { didSet { save(Array(excluded), "excluded") } }

    @Published private(set) var mice: [Mice.Mouse] = []
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// What the last scroll came from and what Scrollr did with it, for the live check in Settings.
    @Published private(set) var lastScroll: String?

    private let hid = Mice()
    private var tap: CFMachPort?
    private var trustTimer: Timer?

    init() {
        defaults.register(defaults: ["enabled": true, "vertical": true, "horizontal": true, "autoDetect": true, "showIcon": true])
        enabled = defaults.bool(forKey: "enabled")
        vertical = defaults.bool(forKey: "vertical")
        horizontal = defaults.bool(forKey: "horizontal")
        autoDetect = defaults.bool(forKey: "autoDetect")
        excluded = Set(defaults.stringArray(forKey: "excluded") ?? [])

        hid.onChange = { [weak self] in self?.mice = self?.hid.connected ?? [] }
        mice = hid.connected

        // The tap can be dropped across sleep; switch it back on when the Mac wakes.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            if let tap = self?.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        }

        if trusted { startTap() } else { requestAccess() }
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    /// Reversal is actually happening right now (drives the menu bar icon).
    var active: Bool {
        trusted && enabled && (vertical || horizontal) && (!autoDetect || mice.contains { !excluded.contains($0.id) })
    }

    var status: String {
        if !trusted { return "Needs permission" }
        if !enabled || !(vertical || horizontal) { return "Paused" }
        if !autoDetect { return "Reversing every mouse wheel" }
        if mice.isEmpty { return "No external mouse" }
        return active ? "Reversing mouse scrolling" : "Mouse scrolling unchanged"
    }

    // MARK: Event tap

    private func startTap() {
        let me = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: 1 << CGEventType.scrollWheel.rawValue,
                                callback: { _, type, event, ctx in
            Unmanaged<Controller>.fromOpaque(ctx!).takeUnretainedValue().handle(type, event)
            return Unmanaged.passUnretained(event)
        }, userInfo: me)
        guard let tap else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .scrollWheel else { return }
        let phased = Scroll.isPhased(event), ids = mice.map(\.id)
        let reverse = Scroll.shouldReverse(phased: phased, enabled: enabled, autoDetect: autoDetect,
                                           mice: ids, lastWheel: hid.lastWheel, excluded: excluded)
        if reverse { Scroll.reverse(event, vertical: vertical, horizontal: horizontal) }

        let source = phased ? "Trackpad" : Scroll.source(mice: ids, lastWheel: hid.lastWheel)
            .flatMap { id in mice.first { $0.id == id }?.name } ?? "Mouse wheel"
        let report = "\(source): \(reverse ? "reversed" : "unchanged")"
        if report != lastScroll { lastScroll = report } // publish only on change, not per event
    }

    // MARK: Permission

    /// What System Settings calls the Accessibility list (renamed in macOS 27).
    static var accessibilityName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
    }

    /// Shows the system prompt (when `prompt`), then checks every 2 s until access is granted,
    /// because macOS sends no notification for this permission.
    func requestAccess(prompt: Bool = true) {
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted() else { return }
            timer.invalidate()
            trusted = true
            startTap()
        }
    }

    func openPrivacySettings() {
        requestAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: Settings

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func restoreDefaults() {
        enabled = true
        vertical = true
        horizontal = true
        autoDetect = true
        defaults.set(true, forKey: "showIcon") // read by @AppStorage in the scene and Settings
        excluded = []
        if launchAtLogin { setLaunchAtLogin(false) }
    }
}
