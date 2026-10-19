// MIT License
// Copyright (c) 2021-2026 LinearMouse

import CoreGraphics
import Foundation
import GestureKit

/// Converts pointer movement into a continuous scroll gesture series while a
/// configured trigger button is held. The trigger press and release are consumed
/// so the button does not click.
final class ContinuousGestureTransformer {
    typealias EventSink = (CGEvent) -> Void
    typealias WarpPointer = (CGPoint) -> Void

    private let triggerButtonNumber: Int
    private let triggerModifierFlags: CGEventFlags
    private let warpPointer: WarpPointer
    private let eventSink: EventSink

    private var heldButton: CGMouseButton?
    private var series = GestureSeries()

    /// Returns nil unless `trigger` is a valid continuous-gesture trigger.
    init?(
        trigger: Scheme.Trigger,
        warpPointer: @escaping WarpPointer = { CGWarpMouseCursorPosition($0) },
        eventSink: @escaping EventSink = { $0.post(tap: .cgSessionEventTap) }
    ) {
        guard trigger.isValidRedirectsToScrollTrigger,
              case let .button(.mouse(buttonNumber)) = trigger.input else {
            return nil
        }

        triggerButtonNumber = buttonNumber
        triggerModifierFlags = trigger.modifierFlags
        self.warpPointer = warpPointer
        self.eventSink = eventSink
    }

}

extension ContinuousGestureTransformer: EventTransformer {
    var handlesPointerMotion: Bool {
        hasActiveInteraction
    }

    func transform(_ event: CGEvent, in _: EventTransformerContext) -> CGEvent? {
        guard !SettingsState.shared.recording || hasActiveInteraction else {
            return event
        }

        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard heldButton == nil,
                  let button = MouseEventView(event).mouseButton,
                  Int(button.rawValue) == triggerButtonNumber,
                  ModifierState.generic(from: event.flags) == triggerModifierFlags else {
                return event
            }

            heldButton = button
            series = GestureSeries()
            return nil

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            guard let heldButton,
                  MouseEventView(event).mouseButton == heldButton else {
                return event
            }

            closeSeries(flags: event.flags)
            self.heldButton = nil
            return nil

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            guard hasActiveInteraction else {
                return event
            }

            warpPointer(event.location)

            let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
            let deltaY = event.getDoubleValueField(.mouseEventDeltaY)

            guard let step = series.move(deltaX: deltaX, deltaY: deltaY) else {
                return nil
            }

            if step.phase == .began {
                GestureEvent(
                    scrollSeriesSource: nil,
                    started: true,
                    flags: event.flags
                )?.send(to: eventSink)
            }

            let gesturePhase = gesturePhase(for: step.phase)

            GestureEvent(
                scrollSource: nil,
                phase: gesturePhase,
                deltaX: step.deltaX,
                deltaY: step.deltaY,
                flags: event.flags
            )?.send(to: eventSink)

            return nil

        default:
            return event
        }
    }
}

extension ContinuousGestureTransformer: EventTransformerInteractionTracking {
    var hasActiveInteraction: Bool {
        heldButton != nil
    }
}

extension ContinuousGestureTransformer: Deactivatable {
    func deactivate() {
        if heldButton != nil {
            closeSeries(flags: [])
        }
        heldButton = nil
        series = GestureSeries()
    }
}

private extension ContinuousGestureTransformer {
    func gesturePhase(for phase: GestureSeries.Phase) -> CGSGesturePhase {
        switch phase {
        case .began:
            return .began
        case .changed:
            return .changed
        case .ended:
            return .ended
        case .cancelled:
            return .cancelled
        }
    }

    func closeSeries(flags: CGEventFlags) {
        guard let step = series.end() else {
            return
        }

        let gesturePhase = gesturePhase(for: step.phase)

        GestureEvent(
            scrollSource: nil,
            phase: gesturePhase,
            deltaX: step.deltaX,
            deltaY: step.deltaY,
            flags: flags
        )?.send(to: eventSink)

        GestureEvent(
            scrollSeriesSource: nil,
            started: false,
            flags: flags
        )?.send(to: eventSink)
    }
}
