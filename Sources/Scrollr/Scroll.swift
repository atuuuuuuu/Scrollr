import CoreGraphics

enum Scroll {
    /// Trackpads (and the Magic Mouse) always send phased scrolls (began/changed/ended, then momentum).
    /// Wheel mice never do. This is what keeps the trackpad untouched.
    static func isPhased(_ e: CGEvent) -> Bool {
        e.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
            || e.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    }

    /// The connected mouse a wheel event most likely came from: the one whose wheel moved last,
    /// else the first one. nil when no external mouse is connected.
    static func source(mice: [String], lastWheel: String?) -> String? {
        lastWheel.flatMap { mice.contains($0) ? $0 : nil } ?? mice.first
    }

    /// - Parameter mice: ids of the connected external mice.
    static func shouldReverse(phased: Bool, enabled: Bool, autoDetect: Bool,
                              mice: [String], lastWheel: String?, excluded: Set<String>) -> Bool {
        guard enabled, !phased else { return false }
        guard autoDetect else { return true }
        guard let mouse = source(mice: mice, lastWheel: lastWheel) else { return false }
        return !excluded.contains(mouse)
    }

    /// Flips the chosen axes in all three delta representations apps read (lines, pixels, fixed point).
    static func reverse(_ e: CGEvent, vertical: Bool = true, horizontal: Bool = true) {
        var axes: [(CGEventField, CGEventField, CGEventField)] = []
        if vertical {
            axes.append((.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1))
        }
        if horizontal {
            axes.append((.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2))
        }
        for (line, point, fixed) in axes {
            // Read everything first: setting the line delta makes CoreGraphics recompute the others.
            let l = e.getIntegerValueField(line), p = e.getIntegerValueField(point), f = e.getDoubleValueField(fixed)
            e.setIntegerValueField(line, value: -l)
            e.setDoubleValueField(fixed, value: -f)
            e.setIntegerValueField(point, value: -p)
        }
    }
}
