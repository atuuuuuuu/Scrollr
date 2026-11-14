import CoreGraphics
import XCTest
@testable import Scrollr

final class ScrollTests: XCTestCase {
    private func decide(phased: Bool = false, enabled: Bool = true, autoDetect: Bool = true,
                        mice: [String] = ["a"], lastWheel: String? = nil, excluded: Set<String> = []) -> Bool {
        Scroll.shouldReverse(phased: phased, enabled: enabled, autoDetect: autoDetect,
                             mice: mice, lastWheel: lastWheel, excluded: excluded)
    }

    func testTrackpadIsNeverReversed() {
        XCTAssertFalse(decide(phased: true))
        XCTAssertFalse(decide(phased: true, autoDetect: false))
    }

    func testRules() {
        XCTAssertTrue(decide())
        XCTAssertFalse(decide(enabled: false))
        XCTAssertFalse(decide(mice: []))                          // nothing detected
        XCTAssertTrue(decide(autoDetect: false, mice: []))        // detection off: every wheel
        XCTAssertFalse(decide(excluded: ["a"]))
        XCTAssertTrue(decide(autoDetect: false, excluded: ["a"])) // per-mouse needs detection
    }

    func testSeveralMiceUseTheOneThatScrolled() {
        XCTAssertFalse(decide(mice: ["a", "b"], lastWheel: "b", excluded: ["b"]))
        XCTAssertTrue(decide(mice: ["a", "b"], lastWheel: "a", excluded: ["b"]))
        XCTAssertTrue(decide(mice: ["a", "b"], lastWheel: "gone", excluded: ["b"])) // falls back to first
    }

    func testReverseFlipsAllDeltas() throws {
        let e = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 30, wheel2: -12, wheel3: 0))
        let before = (e.getIntegerValueField(.scrollWheelEventDeltaAxis1), e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
                      e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), e.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        XCTAssertNotEqual(before.1, 0)
        XCTAssertFalse(Scroll.isPhased(e))
        Scroll.reverse(e)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), -before.0)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), -before.1)
        XCTAssertEqual(e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), -before.2)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis2), -before.3)
    }

    func testAxisChoice() throws {
        let e = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 3, wheel2: 2, wheel3: 0))
        Scroll.reverse(e, vertical: true, horizontal: false)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), -3)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis2), 2)
        Scroll.reverse(e, vertical: false, horizontal: true)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), -3)
        XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis2), -2)
    }

    func testSource() {
        XCTAssertNil(Scroll.source(mice: [], lastWheel: "a"))
        XCTAssertEqual(Scroll.source(mice: ["a", "b"], lastWheel: "b"), "b")
        XCTAssertEqual(Scroll.source(mice: ["a", "b"], lastWheel: nil), "a")
    }

    func testPhasedEventIsDetected() throws {
        let e = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 5, wheel2: 0, wheel3: 0))
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2) // kCGScrollPhaseChanged
        XCTAssertTrue(Scroll.isPhased(e))
    }
}
