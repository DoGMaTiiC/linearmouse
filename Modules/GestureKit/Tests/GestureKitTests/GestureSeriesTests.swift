// MIT License
// Copyright (c) 2021-2026 LinearMouse

@testable import GestureKit
import XCTest

final class GestureSeriesTests: XCTestCase {
    func testStartsOnlyOnFirstNonZeroMove() {
        var series = GestureSeries()

        XCTAssertNil(series.move(deltaX: 0, deltaY: 0))
        XCTAssertNil(series.move(deltaX: 0, deltaY: 0))

        let began = series.move(deltaX: 3, deltaY: -2)
        XCTAssertEqual(began?.phase, .began)
        XCTAssertEqual(began?.deltaX, 3)
        XCTAssertEqual(began?.deltaY, -2)
    }

    func testTwoAxesPreserveSignAndProportion() {
        var series = GestureSeries()

        let first = series.move(deltaX: 4, deltaY: -2)
        XCTAssertEqual(first?.phase, .began)
        XCTAssertEqual(first?.deltaX, 4)
        XCTAssertEqual(first?.deltaY, -2)

        let second = series.move(deltaX: 8, deltaY: -4)
        XCTAssertEqual(second?.phase, .changed)
        XCTAssertEqual(second?.deltaX, 8)
        XCTAssertEqual(second?.deltaY, -4)
    }

    func testEndEmitsSingleFinalPhase() {
        var series = GestureSeries()
        _ = series.move(deltaX: 1, deltaY: 1)

        let final = series.end()
        XCTAssertEqual(final?.phase, .ended)
        XCTAssertNil(series.end())
        XCTAssertNil(series.end())
    }

    func testCancelClosesOpenSeries() {
        var series = GestureSeries()
        _ = series.move(deltaX: 1, deltaY: 0)

        XCTAssertEqual(series.cancel()?.phase, .cancelled)
        XCTAssertNil(series.cancel())

        // No orphaned series: a closed series can be reopened by a new move.
        XCTAssertEqual(series.move(deltaX: 1, deltaY: 0)?.phase, .began)
    }

    func testEndWithoutStartEmitsNothing() {
        var series = GestureSeries()

        XCTAssertNil(series.end())
        XCTAssertNil(series.cancel())
    }

    func testZeroMoveWhileOpenDoesNotCloseSeries() {
        var series = GestureSeries()
        _ = series.move(deltaX: 1, deltaY: 0)

        XCTAssertNil(series.move(deltaX: 0, deltaY: 0))
        XCTAssertEqual(series.end()?.phase, .ended)
    }

    func testCancelAfterEndEmitsNothing() {
        var series = GestureSeries()
        _ = series.move(deltaX: 1, deltaY: 0)
        XCTAssertEqual(series.end()?.phase, .ended)
        XCTAssertNil(series.cancel())
    }
}
