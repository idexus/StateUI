// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidGestureTests: XCTestCase {
    static var allTests: [(String, (AndroidGestureTests) -> () throws -> Void)] {
        [
            ("testTapsAreCountedToTheCountAsked", testTapsAreCountedToTheCountAsked),
            ("testAPanSaysHowFarItHasComeAndMovesItsState", testAPanSaysHowFarItHasComeAndMovesItsState),
            ("testASwipePastItsThresholdSaysItsDirection", testASwipePastItsThresholdSaysItsDirection),
            ("testAPinchSaysItsScaleAndWhereItIsCentred", testAPinchSaysItsScaleAndWhereItIsCentred),
            ("testThePointerPressesMovesReleasesAndHovers", testThePointerPressesMovesReleasesAndHovers),
        ]
    }

    /// Two taps near each other, soon after each other, are a double tap; one alone, or two slow ones, are not.
    func testTapsAreCountedToTheCountAsked() throws {
        try onMainActor {
            let heard = Received<String>()
            let (host, box) = try Self.box { $0.onTapped(count: 2) { heard.values.append("double") } }

            box.touch(0, x: 50, y: 50, at: 0)
            box.touch(1, x: 50, y: 50, at: 50)
            host.pump()
            XCTAssertEqual(heard.values, [])
            box.touch(0, x: 52, y: 50, at: 150)
            box.touch(1, x: 52, y: 50, at: 200)
            host.pump()
            XCTAssertEqual(heard.values, ["double"])

            box.touch(0, x: 50, y: 50, at: 1000)
            box.touch(1, x: 50, y: 50, at: 1050)
            box.touch(0, x: 50, y: 50, at: 2000)
            box.touch(1, x: 50, y: 50, at: 2050)
            host.pump()
            XCTAssertEqual(heard.values, ["double"])
        }
    }

    /// A pan says how far it has come in points, from where it began, and moves the state it carries by as much.
    func testAPanSaysHowFarItHasComeAndMovesItsState() throws {
        try onMainActor {
            let heard = Received<String>()
            let across = State(wrappedValue: 5.0)
            let (host, box) = try Self.box {
                $0.panX(across.projectedValue)
                    .onPanUpdated { heard.values.append("\($0.phase) \(Int($0.totalX)) \(Int($0.totalY))") }
            }

            box.touch(0, x: 10, y: 10, at: 0)
            box.touch(2, x: 110, y: 10, at: 20)
            box.touch(2, x: 170, y: 30, at: 40)
            box.touch(1, x: 170, y: 30, at: 60)
            host.settle { heard.values.count == 4 }

            XCTAssertEqual(heard.values, ["started 0 0", "running 50 0", "running 80 10", "completed 0 0"])
            XCTAssertEqual(across.wrappedValue, 85)
        }
    }

    /// A swipe in a direction asked for, past its threshold, says the direction; one the other way, or too short,
    /// says nothing.
    func testASwipePastItsThresholdSaysItsDirection() throws {
        try onMainActor {
            let heard = Received<Int32>()
            let (host, box) = try Self.box {
                $0.onSwiped(direction: [.left, .up], threshold: 40) { heard.values.append($0.rawValue) }
            }

            for (fromX, fromY, toX, toY) in [(50, 150, 150, 150), (150, 150, 50, 150), (150, 150, 150, 90), (150, 150, 150, 50)] {
                box.touch(0, x: Float(fromX), y: Float(fromY), at: 0)
                box.touch(2, x: Float(toX), y: Float(toY), at: 20)
                box.touch(1, x: Float(toX), y: Float(toY), at: 40)
            }
            host.pump()

            XCTAssertEqual(heard.values, [2, 4])
        }
    }

    /// Two fingers spreading from 600 to 900 pixels apart in steps of 75: the pinch starts once Android tells
    /// it apart - at the first step, 675 - runs from there to 900 and completes, centred where the fingers are.
    func testAPinchSaysItsScaleAndWhereItIsCentred() throws {
        try onMainActor {
            let phases = Received<String>()
            let scales = Received<Double>()
            let (host, box) = try Self.box {
                $0.onPinchUpdated { pinch in
                    phases.values.append("\(pinch.phase) \(pinch.scaleOrigin.x) \(pinch.scaleOrigin.y)")
                    if pinch.phase == .running { scales.values.append(pinch.scale) }
                }
            }

            TestTouches.pinch(box, x: 100, y: 100, from: 600, to: 900)
            host.pump()

            XCTAssertEqual(phases.values.first, "started 0.5 0.5")
            XCTAssertEqual(phases.values.last, "completed 0.5 0.5")
            XCTAssertEqual(scales.values.reduce(1, *), 900.0 / 675.0, accuracy: 0.01)
        }
    }

    /// The pointer pressing, moving and releasing, where it is in points; and a mouse entering, moving, leaving.
    func testThePointerPressesMovesReleasesAndHovers() throws {
        try onMainActor {
            let heard = Received<String>()
            let (host, box) = try Self.box {
                $0.onPointerPressed { heard.values.append("pressed \(Int($0.x)) \(Int($0.y))") }
                    .onPointerMoved { heard.values.append("moved \(Int($0.x)) \(Int($0.y))") }
                    .onPointerReleased { heard.values.append("released \(Int($0.x)) \(Int($0.y))") }
                    .onPointerEntered { heard.values.append("entered") }
                    .onPointerExited { heard.values.append("exited") }
            }

            box.touch(0, x: 20, y: 40, at: 0)
            box.touch(2, x: 30, y: 40, at: 10)
            box.touch(1, x: 30, y: 40, at: 20)
            TestTouches.hover(box, x: 20, y: 40)
            host.pump()

            XCTAssertEqual(heard.values, [
                "pressed 10 20", "moved 15 20", "released 15 20", "entered", "moved 15 20", "exited",
            ])
        }
    }

    /// A box of 100 points - 200 pixels - at the top left, listening as `listens` has it.
    @MainActor
    private static func box(_ listens: @escaping @Sendable (ColorBox) -> any View) throws -> (AndroidRenderer, AndroidView) {
        let host = AndroidRenderer.running {
            listens(ColorBox(.red).width(100).height(100).horizontalAlignment(.start).verticalAlignment(.start))
        }
        host.layOut()
        return (host, try XCTUnwrap(host.views(AndroidColorBoxView.self).first))
    }
}

/// Touches a user gives a view: `TestTouches.java`.
@MainActor
enum TestTouches {
    private static let owner = Java.findClass("stateui/android/test/TestTouches")
    private static let pinching = Java.staticMethod(owner, "pinch", "(Landroid/view/View;FFFF)V")
    private static let hovering = Java.staticMethod(owner, "hover", "(Landroid/view/View;FF)V")

    /// Two fingers either side of (`x`, `y`) pixels, `from` pixels apart moving to `to`, then lifted.
    static func pinch(_ view: AndroidView, x: Float, y: Float, from: Float, to: Float) {
        Java.callStatic(owner, pinching, .object(view.reference), .float(x), .float(y), .float(from), .float(to))
    }

    /// A mouse entering at (`x`, `y`) pixels, moving 10 pixels right, and leaving.
    static func hover(_ view: AndroidView, x: Float, y: Float) {
        Java.callStatic(owner, hovering, .object(view.reference), .float(x), .float(y))
    }
}
