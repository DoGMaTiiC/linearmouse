// MIT License
// Copyright (c) 2021-2026 LinearMouse

import Foundation

public struct GestureSeries {
    public enum Phase: Equatable, Sendable {
        case began
        case changed
        case ended
        case cancelled
    }

    public struct Step: Equatable, Sendable {
        public let phase: Phase
        public let deltaX: Double
        public let deltaY: Double

        public init(phase: Phase, deltaX: Double, deltaY: Double) {
            self.phase = phase
            self.deltaX = deltaX
            self.deltaY = deltaY
        }
    }

    private var isOpen: Bool = false

    public init() {}

    public mutating func move(deltaX: Double, deltaY: Double) -> Step? {
        guard deltaX != 0 || deltaY != 0 else {
            return nil
        }

        if !isOpen {
            isOpen = true
            return Step(phase: .began, deltaX: deltaX, deltaY: deltaY)
        }

        return Step(phase: .changed, deltaX: deltaX, deltaY: deltaY)
    }

    public mutating func end() -> Step? {
        guard isOpen else {
            return nil
        }

        isOpen = false
        return Step(phase: .ended, deltaX: 0, deltaY: 0)
    }

    public mutating func cancel() -> Step? {
        guard isOpen else {
            return nil
        }

        isOpen = false
        return Step(phase: .cancelled, deltaX: 0, deltaY: 0)
    }
}
