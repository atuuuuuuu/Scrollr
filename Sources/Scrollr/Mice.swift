import Foundation
import IOKit.hid

/// Tracks connected external mice with IOHIDManager. Callbacks run on the main run loop.
final class Mice {
    struct Mouse: Hashable {
        let id: String   // "vendor:product", so a setting sticks to the model across reconnects
        let name: String
        let detail: String // e.g. "USB · 373B:1031"
    }

    private(set) var connected: [Mouse] = []
    /// The mouse whose wheel moved last. Only wheel elements are watched, so pointer motion
    /// from 8 kHz mice costs nothing.
    private(set) var lastWheel: String?
    var onChange: () -> Void = {}

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var devices: [IOHIDDevice: Mouse] = [:]

    init() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
        ] as CFDictionary)
        IOHIDManagerSetInputValueMatchingMultiple(manager, [
            [kIOHIDElementUsagePageKey: kHIDPage_GenericDesktop, kIOHIDElementUsageKey: kHIDUsage_GD_Wheel],
            [kIOHIDElementUsagePageKey: kHIDPage_Consumer, kIOHIDElementUsageKey: kHIDUsage_Csmr_ACPan],
        ] as CFArray)

        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            Unmanaged<Mice>.fromOpaque(ctx!).takeUnretainedValue().added(device)
        }, me)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            Unmanaged<Mice>.fromOpaque(ctx!).takeUnretainedValue().removed(device)
        }, me)
        IOHIDManagerRegisterInputValueCallback(manager, { ctx, _, _, value in
            guard IOHIDValueGetIntegerValue(value) != 0 else { return }
            let mice = Unmanaged<Mice>.fromOpaque(ctx!).takeUnretainedValue()
            mice.lastWheel = mice.devices[IOHIDElementGetDevice(IOHIDValueGetElement(value))]?.id
        }, me)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func added(_ device: IOHIDDevice) {
        func prop(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }
        let name = prop(kIOHIDProductKey) as? String ?? "Mouse"
        // The built-in trackpad and Magic Trackpads also report themselves as mice.
        guard (prop(kIOHIDBuiltInKey) as? Bool) != true, !name.localizedCaseInsensitiveContains("trackpad") else { return }
        let vendor = prop(kIOHIDVendorIDKey) as? Int ?? 0, product = prop(kIOHIDProductIDKey) as? Int ?? 0
        let ids = String(format: "%04X:%04X", vendor, product)
        let transport = (prop(kIOHIDTransportKey) as? String).map { $0 == "Bluetooth Low Energy" ? "Bluetooth" : $0 }
        devices[device] = Mouse(id: "\(vendor):\(product)", name: name, detail: [transport, ids].compactMap { $0 }.joined(separator: " · "))
        update()
    }

    private func removed(_ device: IOHIDDevice) {
        guard devices.removeValue(forKey: device) != nil else { return }
        update()
    }

    private func update() {
        var seen = Set<String>()
        // One physical mouse can show up as several HID devices; keep one entry per model.
        connected = devices.values.sorted { $0.name < $1.name }.filter { seen.insert($0.id).inserted }
        onChange()
    }
}
