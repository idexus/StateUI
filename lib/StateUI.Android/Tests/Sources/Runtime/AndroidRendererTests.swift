// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// A page and its counter: a click raises the count, and the caption reads it.
struct CounterPage: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
        }
    }
}

final class AndroidRendererTests: XCTestCase {
    static var allTests: [(String, (AndroidRendererTests) -> () throws -> Void)] {
        [
            ("testThePageShowsItsControlsInTheRoot", testThePageShowsItsControlsInTheRoot),
            ("testAClickRendersWhatItsHandlerChanged", testAClickRendersWhatItsHandlerChanged),
            ("testAControlNoRegistrationAnswersShowsItsName", testAControlNoRegistrationAnswersShowsItsName),
            ("testASecondActivityShowsTheSceneTheFirstShowed", testASecondActivityShowsTheSceneTheFirstShowed),
        ]
    }

    func testThePageShowsItsControlsInTheRoot() {
        onMainActor {
            let host = AndroidRenderer.running { CounterPage() }

            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["count 0"])
            XCTAssertEqual(host.views(AndroidButtonView.self).map(\.text), ["Add"])
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
        }
    }

    /// The proof of the host's spine: the click reaches the handler, the state it wrote renders, and the patch reaches the view.
    func testAClickRendersWhatItsHandlerChanged() throws {
        try onMainActor {
            let host = AndroidRenderer.running { CounterPage() }
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            button.click()
            button.click()

            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["count 2"])
        }
    }

    func testAControlNoRegistrationAnswersShowsItsName() {
        onMainActor {
            let host = AndroidRenderer.running { VStack { ActivityIndicator() } }

            XCTAssertEqual(
                host.views(AndroidUnsupportedView.self).map(\.text), ["Android: unsupported ActivityIndicator"])
        }
    }

    /// The process outlives its activity - Back finishes it, the launcher starts another - and the next
    /// activity shows the scene the first showed, with its state, rather than a second scene.
    func testASecondActivityShowsTheSceneTheFirstShowed() throws {
        try onMainActor {
            let first = AndroidRenderer.running { CounterPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()

            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)

            XCTAssertEqual(second.tree.root?.children.filter { $0.type == .scene }.count, 1)
            XCTAssertEqual(second.views(AndroidLabelView.self).map(\.text), ["count 1"])
            XCTAssertEqual(Java.callInt(second.root.reference, TestJava.getChildCount), 1)
        }
    }
}
