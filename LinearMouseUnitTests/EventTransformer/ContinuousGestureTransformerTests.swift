// MIT License
// Copyright (c) 2021-2026 LinearMouse

import CoreGraphics
@testable import LinearMouse
import XCTest

private let gestureHIDTypeField = CGEventField(rawValue: 110)!
private let gestureStartEndSeriesTypeField = CGEventField(rawValue: 117)!
private let gesturePhaseField = CGEventField(rawValue: 132)!
private let gestureScrollXField = CGEventField(rawValue: 118)!
private let gestureScrollYField = CGEventField(rawValue: 119)!

final class ContinuousGestureTransformerTests: XCTestCase {
    private var emittedEvents = [CGEvent]()
    private var warpedPositions = [CGPoint]()

    override func setUp() {
        super.setUp()
        emittedEvents = []
        warpedPositions = []
    }

    override func tearDown() {
        SettingsState.shared.endButtonMappingRecording()
        super.tearDown()
    }

    private func makeTransformer(
        _ trigger: Scheme.Trigger = .init(input: .button(.mouse(3)))
    ) throws -> ContinuousGestureTransformer {
        try XCTUnwrap(ContinuousGestureTransformer(
            trigger: trigger,
            warpPointer: { [weak self] in self?.warpedPositions.append($0) },
            eventSink: { [weak self] in self?.emittedEvents.append($0) }
        ))
    }

    private func transform(
        _ transformer: ContinuousGestureTransformer,
        _ event: CGEvent
    ) -> CGEvent? {
        transformer.transform(event, in: .init(device: nil))
    }

    private func buttonEvent(
        _ type: CGEventType,
        button: Int,
        flags: CGEventFlags = []
    ) throws -> CGEvent {
        let mouseButton = try XCTUnwrap(CGMouseButton(rawValue: UInt32(button)))
        let event = try XCTUnwrap(CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: .zero,
            mouseButton: mouseButton
        ))
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        event.flags = flags
        return event
    }

    private func movedEvent(deltaX: Double = 5, deltaY: Double = 7) throws -> CGEvent {
        let event = try XCTUnwrap(CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: .zero,
            mouseButton: .left
        ))
        event.setDoubleValueField(.mouseEventDeltaX, value: deltaX)
        event.setDoubleValueField(.mouseEventDeltaY, value: deltaY)
        return event
    }

    func testRejectsTriggersThatCannotBeHeld() {
        XCTAssertNil(ContinuousGestureTransformer(trigger: .init(input: .button(.mouse(0)))))
        XCTAssertNil(ContinuousGestureTransformer(trigger: .init(input: .wheel(.down))))
    }

    func testMovementPassesThroughWhileReleased() throws {
        let transformer = try makeTransformer()

        XCTAssertNotNil(try transform(transformer, movedEvent()))
        XCTAssertTrue(emittedEvents.isEmpty)
        XCTAssertFalse(transformer.hasActiveInteraction)
    }

    func testHeldTriggerConsumesDownAndUpAndEmitsSeries() throws {
        let transformer = try makeTransformer()

        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3)))
        XCTAssertTrue(transformer.hasActiveInteraction)

        let move = try movedEvent(deltaX: 4, deltaY: -6)
        XCTAssertNil(transform(transformer, move))
        XCTAssertEqual(warpedPositions, [move.location])

        // First move: boundary started + began scroll.
        XCTAssertEqual(emittedEvents.count, 2)
        XCTAssertEqual(emittedEvents[0].getIntegerValueField(gestureHIDTypeField), 61)
        XCTAssertEqual(emittedEvents[1].getIntegerValueField(gesturePhaseField), Int64(CGSGesturePhase.began.rawValue))
        XCTAssertEqual(emittedEvents[1].getDoubleValueField(gestureScrollXField), 4)
        XCTAssertEqual(emittedEvents[1].getDoubleValueField(gestureScrollYField), -6)

        let secondMove = try movedEvent(deltaX: 1, deltaY: 2)
        XCTAssertNil(transform(transformer, secondMove))
        XCTAssertEqual(emittedEvents.count, 3)
        XCTAssertEqual(emittedEvents[2].getIntegerValueField(gesturePhaseField), Int64(CGSGesturePhase.changed.rawValue))

        let zeroMove = try movedEvent(deltaX: 0, deltaY: 0)
        XCTAssertNil(transform(transformer, zeroMove))
        XCTAssertEqual(emittedEvents.count, 3)

        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseUp, button: 3)))
        XCTAssertFalse(transformer.hasActiveInteraction)
        // ended scroll + boundary ended
        XCTAssertEqual(emittedEvents.count, 5)
        XCTAssertEqual(emittedEvents[3].getIntegerValueField(gesturePhaseField), Int64(CGSGesturePhase.ended.rawValue))
        XCTAssertEqual(emittedEvents[4].getIntegerValueField(gestureHIDTypeField), 62)

        XCTAssertNotNil(try transform(transformer, movedEvent()))
        XCTAssertEqual(emittedEvents.count, 5)
    }

    func testOtherButtonsPassThroughWhileTriggerIsHeld() throws {
        let transformer = try makeTransformer()

        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3)))
        XCTAssertNotNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 4)))
        XCTAssertNotNil(try transform(transformer, buttonEvent(.otherMouseUp, button: 4)))
        XCTAssertTrue(transformer.hasActiveInteraction)

        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseUp, button: 3)))
        XCTAssertFalse(transformer.hasActiveInteraction)
    }

    func testModifiersMustMatchWhenTheTriggerIsPressed() throws {
        let transformer = try makeTransformer(.init(input: .button(.mouse(3)), modifiers: [.option]))

        XCTAssertNotNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3)))
        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3, flags: .maskAlternate)))
        XCTAssertTrue(transformer.hasActiveInteraction)
        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseUp, button: 3)))
    }

    func testBypassesTriggerWhileRecording() throws {
        let transformer = try makeTransformer()
        SettingsState.shared.beginButtonMappingRecording(sessionID: UUID())

        XCTAssertNotNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3)))
        XCTAssertNotNil(try transform(transformer, movedEvent()))
        XCTAssertNotNil(try transform(transformer, buttonEvent(.otherMouseUp, button: 3)))
        XCTAssertTrue(emittedEvents.isEmpty)
    }

    func testDeactivateClosesOpenSeries() throws {
        let transformer = try makeTransformer()

        XCTAssertNil(try transform(transformer, buttonEvent(.otherMouseDown, button: 3)))
        XCTAssertNil(try transform(transformer, movedEvent()))
        XCTAssertEqual(emittedEvents.count, 2)

        transformer.deactivate()
        XCTAssertFalse(transformer.hasActiveInteraction)
        // ended + boundary
        XCTAssertEqual(emittedEvents.count, 4)
        XCTAssertEqual(emittedEvents[2].getIntegerValueField(gesturePhaseField), Int64(CGSGesturePhase.ended.rawValue))
        XCTAssertEqual(emittedEvents[3].getIntegerValueField(gestureHIDTypeField), 62)
    }

    func testDeactivateWithoutSeriesDoesNothing() throws {
        let transformer = try makeTransformer()
        transformer.deactivate()
        XCTAssertTrue(emittedEvents.isEmpty)
    }
}
