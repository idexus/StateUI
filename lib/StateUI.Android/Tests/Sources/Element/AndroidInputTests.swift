// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidInputTests: XCTestCase {
    static var allTests: [(String, (AndroidInputTests) -> () throws -> Void)] {
        [
            ("testATapReachesItsHandlerAndLeavesWithIt", testATapReachesItsHandlerAndLeavesWithIt),
            ("testALayoutThatIgnoresInputLetsTheTouchThroughToWhatIsBehind", testALayoutThatIgnoresInputLetsTheTouchThroughToWhatIsBehind),
            ("testAFieldSaysWhenItTakesTheFocusAndLosesIt", testAFieldSaysWhenItTakesTheFocusAndLosesIt),
        ]
    }

    /// Any view with a tap handler answers the user's tap; a view whose tap is taken away takes none.
    func testATapReachesItsHandlerAndLeavesWithIt() throws {
        try onMainActor {
            let taps = Received<Int>()
            let host = AndroidRenderer.running {
                VStack {
                    Border { Label("card") }.onTapped { taps.values.append(1) }
                }
            }
            let border = try XCTUnwrap(host.views(AndroidBorderView.self).first)

            border.click()
            XCTAssertEqual(taps.values, [1])

            let label = AndroidLabelView()
            label.setTapped {}
            XCTAssertTrue(Java.callBool(label.reference, TestJava.isClickable))
            label.setTapped(nil)
            XCTAssertFalse(Java.callBool(label.reference, TestJava.isClickable))
        }
    }

    /// A layer that ignores input stands over a button: the finger reaches the button, not the tappable card
    /// the layer holds.
    func testALayoutThatIgnoresInputLetsTheTouchThroughToWhatIsBehind() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Grid {
                    Button("behind").onClicked {}
                    VStack {
                        Border { Label("over") }.onTapped {}
                    }
                    .ignoresInput(true)
                }
                .width(200)
                .height(100)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()
            let page = try XCTUnwrap(host.views(AndroidSingleChildView.self).first)
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let border = try XCTUnwrap(host.views(AndroidBorderView.self).first)

            page.touch(0, x: 200, y: 100)
            XCTAssertTrue(Java.callBool(button.reference, TestJava.isPressed), "the button behind is pressed")
            XCTAssertFalse(Java.callBool(border.reference, TestJava.isPressed))
            page.touch(3, x: 200, y: 100)
        }
    }
}

extension AndroidInputTests {
    /// A field takes the keyboard's focus and says so; another taking it, it says it lost it.
    func testAFieldSaysWhenItTakesTheFocusAndLosesIt() throws {
        try onMainActor {
            let focused = State(wrappedValue: false)
            let host = AndroidRenderer.running {
                VStack {
                    TextField("").isFocused(focused.projectedValue)
                    TextField("")
                }
            }
            let fields = host.views(AndroidTextFieldView.self)
            XCTAssertEqual(fields.count, 2)

            XCTAssertTrue(Java.callBool(try XCTUnwrap(fields.first).reference, TestJava.requestFocus))
            host.pump()
            XCTAssertTrue(focused.wrappedValue)

            XCTAssertTrue(Java.callBool(try XCTUnwrap(fields.last).reference, TestJava.requestFocus))
            host.pump()
            XCTAssertFalse(focused.wrappedValue)
        }
    }
}
