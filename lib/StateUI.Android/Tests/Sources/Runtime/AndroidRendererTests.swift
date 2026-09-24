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
            ("testTheActivitysLifecycleMovesTheWindowAndTheScene", testTheActivitysLifecycleMovesTheWindowAndTheScene),
            ("testAWindowStoppedComesBackResumedAndHearsItIsGoing", testAWindowStoppedComesBackResumedAndHearsItIsGoing),
            ("testTheWindowsTitleNamesTheActivity", testTheWindowsTitleNamesTheActivity),
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
            let host = AndroidRenderer.running { VStack { PositionIndicator() } }

            XCTAssertEqual(host.views(AndroidUnsupportedView.self).map(\.text), ["Android: unsupported PositionIndicator"])
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

    /// The activity's pause, resume and stop move the application's phase, and the window's and the scene's
    /// with it, each rendered before the next is heard.
    func testTheActivitysLifecycleMovesTheWindowAndTheScene() {
        onMainActor {
            let host = AndroidRenderer.running { PhaseLabel() }
            var said: String { host.views(AndroidLabelView.self).map(\.text).joined() }

            host.setPhase(.inactive)
            XCTAssertEqual(said, "deactivated inactive")

            host.setPhase(.active)
            XCTAssertEqual(said, "activated active")

            host.setPhase(.background)
            XCTAssertEqual(said, "stopped background")
        }
    }
}

extension AndroidRendererTests {
    /// A window stopped and shown again is resumed on its way to active; the activity finishing tells it it is
    /// going; and it is told it was made once, not again with each render.
    func testAWindowStoppedComesBackResumedAndHearsItIsGoing() {
        onMainActor {
            let log = Received<String>()
            let host = AndroidRenderer.running { WindowPhaseLog(log: log) }

            host.setPhase(.background)
            host.setPhase(.active)
            host.destroying()
            host.pump()

            XCTAssertEqual(log.values, ["stopped", "resumed", "activated", "destroying"])
        }
    }
}

extension AndroidRendererTests {
    /// The window's title is what the activity - and its task among the recent ones - is called.
    func testTheWindowsTitleNamesTheActivity() {
        onMainActor {
            let host = AndroidRenderer.running { TitledWindowPage(title: "Notes") }
            XCTAssertEqual(host.windowTitle, .some("Notes"))
        }
    }
}

/// A page that names its window.
private struct TitledWindowPage: ContentView {
    @Environment private var window: WindowSession
    let title: String

    var content: any View {
        let window = self.window
        let title = self.title
        return Label(title).onCreated { window.title = title }
    }
}

/// Each phase the window moves to, in order.
private struct WindowPhaseLog: ContentView {
    @Environment private var window: WindowSession
    let log: Received<String>

    var content: any View {
        let window = self.window
        let log = self.log
        return Label("\(window.phase)").onChanged(window.phase) { log.values.append("\(window.phase)") }
    }
}

/// The window's phase and the scene's, as a page reads them.
private struct PhaseLabel: ContentView {
    @Environment private var window: WindowSession
    @Environment private var scene: SceneSession

    var content: any View {
        Label("\(window.phase) \(scene.phase)")
    }
}
