// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidIndicatorViewTests: XCTestCase {
    static var allTests: [(String, (AndroidIndicatorViewTests) -> () throws -> Void)] {
        [
            ("testAProgressBarShowsTheShareDone", testAProgressBarShowsTheShareDone),
            ("testAnIndicatorKeepsItsRoomWhileItDoesNotRun", testAnIndicatorKeepsItsRoomWhileItDoesNotRun),
            ("testAStepperStepsWithinItsRangeAndSaysSo", testAStepperStepsWithinItsRangeAndSaysSo),
        ]
    }

    func testAProgressBarShowsTheShareDone() throws {
        try onMainActor {
            let host = AndroidRenderer.running { ProgressBar(0.25) }

            let bar = try XCTUnwrap(host.views(AndroidProgressBarView.self).first)
            XCTAssertEqual(bar.progress, 0.25, accuracy: 0.0001)
        }
    }

    /// Stopped, the indicator draws nothing and holds its place; running, it turns; hidden, it takes no room.
    func testAnIndicatorKeepsItsRoomWhileItDoesNotRun() throws {
        try onMainActor {
            let running = State(wrappedValue: false)
            let host = AndroidRenderer.running(reducesMotion: true) {
                VStack {
                    ActivityIndicator().isRunning(running.wrappedValue)
                    Button("Run").onClicked { running.wrappedValue = true }
                }
            }
            host.layOut()
            let indicator = try XCTUnwrap(host.views(AndroidActivityIndicatorView.self).first)

            XCTAssertEqual(Java.callInt(indicator.reference, JavaAPI.getVisibility), ViewConstants.invisible)
            XCTAssertGreaterThan(indicator.frame.height, 0)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            XCTAssertEqual(Java.callInt(indicator.reference, JavaAPI.getVisibility), ViewConstants.visible)
        }
    }

    /// Up a step to the top of the range, where the way up is off; the state hears each step.
    func testAStepperStepsWithinItsRangeAndSaysSo() throws {
        try onMainActor {
            let count = State(wrappedValue: 5.0)
            let host = AndroidRenderer.running {
                Stepper(count.projectedValue).minimum(0).maximum(6).step(1)
            }
            let stepper = try XCTUnwrap(host.views(AndroidStepperView.self).first)
            let buttons = stepper.buttons

            buttons.up.click()
            XCTAssertEqual(count.wrappedValue, 6)
            XCTAssertFalse(Java.callBool(buttons.up.reference, TestJava.isEnabled))

            buttons.up.click()
            XCTAssertEqual(count.wrappedValue, 6, "no step past the top")

            buttons.down.click()
            XCTAssertEqual(count.wrappedValue, 5)
            XCTAssertTrue(Java.callBool(buttons.up.reference, TestJava.isEnabled))
        }
    }
}
