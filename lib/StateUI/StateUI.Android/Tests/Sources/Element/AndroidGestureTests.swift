// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

final class AndroidGestureTests: XCTestCase {
    static var allTests: [(String, (AndroidGestureTests) -> () throws -> Void)] {
        [
            ("testTapsAreCountedToTheCountAsked", testTapsAreCountedToTheCountAsked),
            ("testAPanSaysHowFarItHasComeAndMovesItsState", testAPanSaysHowFarItHasComeAndMovesItsState),
            ("testASwipePastItsThresholdSaysItsDirection", testASwipePastItsThresholdSaysItsDirection),
            ("testAPinchSaysItsScaleAndWhereItIsCentred", testAPinchSaysItsScaleAndWhereItIsCentred),
            ("testThePointerPressesMovesReleasesAndHovers", testThePointerPressesMovesReleasesAndHovers),
            ("testAPressOnAViewInFrontIsNotHeardBehindIt", testAPressOnAViewInFrontIsNotHeardBehindIt),
        ]
    }

    /// Two taps near each other, soon after each other, are a double tap; one alone, or two slow ones, are not.
    func testTapsAreCountedToTheCountAsked() throws {
        try onMainActor {
            let heard = Received<String>()
            let (host, box) = try Self.box { $0.onTapped(count: 2) { heard.values.append("double") } }

            box.touch(0, x: 50, y: 50, at: 0)
            box.touch(1, x: 50, y: 50, at: 50)
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, [])
            box.touch(0, x: 52, y: 50, at: 150)
            box.touch(1, x: 52, y: 50, at: 200)
            host.runtime.pump.turn()
            XCTAssertEqual(heard.values, ["double"])

            box.touch(0, x: 50, y: 50, at: 1000)
            box.touch(1, x: 50, y: 50, at: 1050)
            box.touch(0, x: 50, y: 50, at: 2000)
            box.touch(1, x: 50, y: 50, at: 2050)
            host.runtime.pump.turn()
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

            XCTAssertEqual(heard.values, ["began 0 0", "changed 50 0", "changed 80 10", "ended 0 0"])
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
            host.runtime.pump.turn()

            XCTAssertEqual(heard.values, [2, 4])
        }
    }

    /// Two fingers spreading from 600 to 900 pixels apart in steps of 75: the pinch begins once Android tells
    /// it apart - at the first step, 675 - changes from there to 900 and ends, centred where the fingers are.
    func testAPinchSaysItsScaleAndWhereItIsCentred() throws {
        try onMainActor {
            let phases = Received<String>()
            let scales = Received<Double>()
            let (host, box) = try Self.box {
                $0.onPinchUpdated { pinch in
                    phases.values.append("\(pinch.phase) \(pinch.scaleOrigin.x) \(pinch.scaleOrigin.y)")
                    if pinch.phase == .changed { scales.values.append(pinch.scale) }
                }
            }

            TestTouches.pinch(box, x: 100, y: 100, from: 600, to: 900)
            host.runtime.pump.turn()

            XCTAssertEqual(phases.values.first, "began 0.5 0.5")
            XCTAssertEqual(phases.values.last, "ended 0.5 0.5")
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
            host.runtime.pump.turn()

            XCTAssertEqual(heard.values, [
                "pressed 10 20", "moved 15 20", "released 15 20", "entered", "moved 15 20", "exited",
            ])
        }
    }

    /// A press on a view in front is that view's, whether or not it answers: a view behind it hears no tap - a touch
    /// handed down the window from its root, as Android hands a user's.
    func testAPressOnAViewInFrontIsNotHeardBehindIt() {
        onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                ZStack {
                    ColorBox(.red).onTapped { heard.values.append("behind") }
                    ColorBox(.blue)
                }
                .width(100).height(100).horizontalAlignment(.start).verticalAlignment(.start)
            }
            host.layOut()

            for (action, time) in [(Int32(0), Int64(0)), (1, 50)] {
                let event = Java.callStaticObject(
                    TestJava.motionEvent, TestJava.obtain, .long(0), .long(time), .int(action), .float(100), .float(100),
                    .int(0))
                _ = Java.callBool(host.root.reference, TestJava.dispatchTouchEvent, .object(event))
                Java.call(event!, TestJava.recycle)
                Java.release(local: event)
            }
            host.settle { !heard.values.isEmpty }

            XCTAssertEqual(heard.values, [], "the box in front took the press")
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
    private static let hoveringOnce = Java.staticMethod(owner, "hover", "(Landroid/view/View;IFF)V")
    private static let pinchingBy = Java.staticMethod(owner, "pinchBy", "(Landroid/view/View;FFF)V")

    /// Two fingers either side of (`x`, `y`) pixels, `from` pixels apart moving to `to`, then lifted.
    static func pinch(_ view: AndroidView, x: Float, y: Float, from: Float, to: Float) {
        Java.callStatic(owner, pinching, .object(view.reference), .float(x), .float(y), .float(from), .float(to))
    }

    /// Two fingers about (`x`, `y`) pixels, one step of the pinch scaled by `scale`, then lifted.
    static func pinch(_ view: AndroidView, x: Float, y: Float, by scale: Float) {
        Java.callStatic(owner, pinchingBy, .object(view.reference), .float(x), .float(y), .float(scale))
    }

    /// A mouse doing `action` - entering, moving or leaving - at (`x`, `y`) pixels.
    static func hover(_ view: AndroidView, action: Int32, x: Float, y: Float) {
        Java.callStatic(owner, hoveringOnce, .object(view.reference), .int(action), .float(x), .float(y))
    }

    /// A mouse entering at (`x`, `y`) pixels, moving 10 pixels right, and leaving.
    static func hover(_ view: AndroidView, x: Float, y: Float) {
        Java.callStatic(owner, hovering, .object(view.reference), .float(x), .float(y))
    }
}
