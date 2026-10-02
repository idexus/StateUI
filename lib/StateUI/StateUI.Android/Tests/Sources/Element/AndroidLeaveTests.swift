// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance
import XCTest

/// A page whose second button goes when the first is clicked.
struct LeavingPage: ContentView {
    @State private var shown = true

    var content: some View {
        VStack {
            Button("Hide")
                .onClicked { shown = false }
            if shown {
                Button("Leaving")
            }
        }
    }
}

final class AndroidLeaveTests: XCTestCase {
    static var allTests: [(String, (AndroidLeaveTests) -> () throws -> Void)] {
        [
            ("testAViewThatLeavesIsLetGoAndItsGroupNoLongerHoldsIt", testAViewThatLeavesIsLetGoAndItsGroupNoLongerHoldsIt),
            ("testEveryElementsViewIsLetGoOfEachTimeItLeaves", testEveryElementsViewIsLetGoOfEachTimeItLeaves),
        ]
    }

    /// Nothing in the host holds a control after the tree drops it: its number no longer answers a Java callback.
    func testAViewThatLeavesIsLetGoAndItsGroupNoLongerHoldsIt() throws {
        try onMainActor {
            let host = AndroidRenderer.running { LeavingPage() }
            XCTAssertEqual(host.views(AndroidButtonView.self).map(\.text), ["Hide", "Leaving"])
            let hide = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let leaving = try XCTUnwrap(host.views(AndroidButtonView.self).last?.number)
            let stack = try XCTUnwrap(host.views(AndroidStackView.self).first)

            hide.click()

            XCTAssertEqual(host.views(AndroidButtonView.self).map(\.text), ["Hide"])
            XCTAssertEqual(Java.callInt(stack.reference, TestJava.getChildCount), 1)
            XCTAssertNil(AndroidView.find(leaving))
        }
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        try onMainActor {
            let driver = AndroidDriver()
            defer { driver.finish() }
            XCTAssertEqual(try Leaving.outlived(on: driver), [])
        }
    }
}
