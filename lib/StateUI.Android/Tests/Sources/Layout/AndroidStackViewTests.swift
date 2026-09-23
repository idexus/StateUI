// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidStackViewTests: XCTestCase {
    static var allTests: [(String, (AndroidStackViewTests) -> () throws -> Void)] {
        [
            ("testAStackPlacesItsChildrenWhereTheArithmeticSays", testAStackPlacesItsChildrenWhereTheArithmeticSays),
            ("testAStackWrapsItsChildrenWhereThePageCentresIt", testAStackWrapsItsChildrenWhereThePageCentresIt),
            ("testALayoutDoesNotCutItsChildrenOff", testALayoutDoesNotCutItsChildrenOff),
            ("testAButtonWhoseWordsGrowIsMeasuredWider", testAButtonWhoseWordsGrowIsMeasuredWider),
        ]
    }

    /// Points become pixels at the host's density - two here - and nothing else moves them.
    func testAStackPlacesItsChildrenWhereTheArithmeticSays() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label("A").width(100).height(40).horizontalAlignment(.start)
                    Label("B").width(80).height(60).horizontalAlignment(.end)
                }
                .spacing(10)
                .padding(20)
            }

            host.layOut(width: 1080, height: 1920)

            let labels = host.views(AndroidLabelView.self)
            XCTAssertEqual(labels.count, 2)
            XCTAssertTrue(labels[0].frame == (40, 40, 200, 80), "\(labels[0].frame)")
            XCTAssertTrue(labels[1].frame == (1080 - 40 - 160, 140, 160, 120), "\(labels[1].frame)")
        }
    }

    func testAStackWrapsItsChildrenWhereThePageCentresIt() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label("A").width(100).height(40)
                }
                .verticalAlignment(.center)
            }

            host.layOut(width: 1080, height: 1920)

            let stack = try XCTUnwrap(host.views(AndroidStackView.self).first)
            XCTAssertTrue(stack.frame == (0, (1920 - 80) / 2, 1080, 80), "\(stack.frame)")
        }
    }

    /// A child on its way, turned or moved, is drawn past its layout's edges: a layout cuts off only where told to.
    func testALayoutDoesNotCutItsChildrenOff() throws {
        try onMainActor {
            let host = AndroidRenderer.running { VStack { Label("moving").translationX(500) } }
            let stack = try XCTUnwrap(host.views(AndroidStackView.self).first)

            XCTAssertFalse(Java.callBool(stack.reference, TestJava.getClipChildren))
            XCTAssertFalse(Java.callBool(stack.reference, TestJava.getClipToPadding))
        }
    }

    /// The words a click writes are measured anew: the stack gives the button the room they take.
    func testAButtonWhoseWordsGrowIsMeasuredWider() throws {
        try onMainActor {
            let count = State(wrappedValue: 0)
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    Button(count.wrappedValue == 0 ? "Go" : "Gone a long way").onClicked { count.wrappedValue += 1 }
                        .horizontalAlignment(.center)
                }
            }
            host.layOut()
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let before = button.frame.width

            button.click()
            host.layOut()

            XCTAssertGreaterThan(button.frame.width, before + 100, "\(before) -> \(button.frame.width)")
        }
    }
}
