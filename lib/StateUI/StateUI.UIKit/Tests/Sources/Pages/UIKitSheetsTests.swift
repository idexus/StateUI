// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A page under the numbered sheets one state lists.
@MainActor
private func sheetsOver(_ sheets: State<[Int]>) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        Text("beneath")
    } destination: { number in
        Text("On sheet \(number)")
    }
}

/// A page whose button asks for a sheet and a question in one turn, and for a second sheet once answered.
private struct SheetAndQuestion: View {
    @State private var sheets: [Int] = []

    var body: some View {
        ModalStack($sheets) {
            Button("Ask").onClicked(gate: .ignoreWhileRunning) {
                sheets.append(1)
                _ = try await Dialogs.confirm("Sure?", message: "Both come", accept: "Yes", cancel: "No")
                sheets.append(2)
            }
        } destination: { number in
            Text("On sheet \(number)")
        }
    }
}

/// Pages a window presents over its page, as UIKit presents them.
@MainActor
final class UIKitSheetsTests: XCTestCase {
    /// A question asked in the turn a sheet is asked for stands, is answered, and the sheets asked for before and
    /// after come: the window's root presents everything, one at a time, and UIKit drops nothing.
    @MainActor
    func testAQuestionAskedWithASheetIsAnsweredAndEverySheetComes() throws {
        let host = UIKitRenderer.running(reducesMotion: false) { SheetAndQuestion() }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)

        host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
        host.settle { host.actToolkit.showing?.alert.viewIfLoaded?.window != nil }
        XCTAssertNotNil(host.actToolkit.showing?.alert.viewIfLoaded?.window, "the question stands")

        XCTAssertEqual(host.actToolkit.showing?.press("Yes", typing: nil), true)
        host.settle {
            root.presentedViewController?.presentedViewController?.viewIfLoaded?.window != nil
                && root.presentedViewController?.presentedViewController?.transitionCoordinator == nil
        }

        let first = root.presentedViewController, second = first?.presentedViewController
        XCTAssertFalse(first is UIAlertController, "the first sheet over the page")
        XCTAssertNotNil(second?.viewIfLoaded?.window, "the second over the first")
        XCTAssertFalse(second is UIAlertController)
    }

    /// A window whose scene iOS let go of and brought back shows its sheets again, and the next sheet asked for
    /// comes over them: nothing is left presented outside the window.
    @MainActor
    func testASceneBroughtBackShowsItsSheetsAgain() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let sheets = State(wrappedValue: [1])
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(sheets) }
        defer { host.finish() }
        func root() -> UIViewController? { host.roster.windows.first?.1.window?.rootViewController }
        host.settle { root()?.presentedViewController?.viewIfLoaded?.window != nil }

        host.disconnect(scene)
        host.connect(scene)
        host.settle { root()?.presentedViewController?.viewIfLoaded?.window != nil }
        XCTAssertNotNil(root()?.presentedViewController?.viewIfLoaded?.window, "the sheet stands again")

        sheets.wrappedValue = [1, 2]
        host.settle { root()?.presentedViewController?.presentedViewController?.viewIfLoaded?.window != nil }
        XCTAssertNotNil(
            root()?.presentedViewController?.presentedViewController?.viewIfLoaded?.window, "the next comes over it")
    }

    /// Sheets the window starts with stand each over the one before, as UIKit presents over a controller only once
    /// it stands.
    @MainActor
    func testSheetsTheWindowStartsWithStandEachOverTheOneBefore() throws {
        let sheets = State(wrappedValue: [1, 2])
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(sheets) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)

        host.settle { root.presentedViewController?.presentedViewController != nil }

        XCTAssertNotNil(root.presentedViewController, "the first sheet over the page")
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "the second over the first")
    }

    /// Presenting sheets, moving as UIKit moves them, tells the window nothing: only the user's swipe does.
    @MainActor
    func testSheetsPresentedWithMotionTellTheWindowNothing() throws {
        let sheets = State(wrappedValue: [1, 2])
        let host = UIKitRenderer.running(reducesMotion: false) { sheetsOver(sheets) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)

        host.settle { root.presentedViewController?.presentedViewController != nil }
        let settled = Date(timeIntervalSinceNow: 1)
        host.settle { Date() > settled }

        XCTAssertEqual(sheets.wrappedValue, [1, 2])
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "both still stand")
    }

    /// A window whose sheets were still coming as it went leaves the next window's sheets to come as asked.
    @MainActor
    func testTheNextWindowsSheetsComeAfterOneWhoseSheetsWereMoving() throws {
        let before = State(wrappedValue: [Int]())
        let first = UIKitRenderer.running(reducesMotion: false) { sheetsOver(before) }
        before.wrappedValue = [1, 2]
        first.settle { first.roster.windows.first?.1.window?.rootViewController?.presentedViewController != nil }
        first.finish()

        let sheets = State(wrappedValue: [1, 2])
        let host = UIKitRenderer.running(reducesMotion: false) { sheetsOver(sheets) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle { root.presentedViewController?.presentedViewController != nil }

        XCTAssertEqual(sheets.wrappedValue, [1, 2], "nothing told the window its sheets went")
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "both came")
    }

    /// A sheet asked for while the one before is still coming, and already asked to go, comes once that one has
    /// gone: UIKit presents nothing over a controller whose sheet is still moving, and drops what it is asked.
    @MainActor
    func testASheetAskedForWhileTheOneBeforeStillMovesComesOnceItHasGone() throws {
        let sheets = State(wrappedValue: [Int]())
        let host = UIKitRenderer.running(reducesMotion: false) { sheetsOver(sheets) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        let shown = Date(timeIntervalSinceNow: 0.5)
        host.settle { Date() > shown }
        let stands = { host.views(UIKitTextView.self).first { $0.text == "On sheet 2" }?.window != nil }

        sheets.wrappedValue = [1]
        host.runtime.pump.turn()
        XCTAssertEqual(root.presentedViewController?.isBeingPresented, true, "the first sheet is on its way in")
        sheets.wrappedValue = []
        host.runtime.pump.turn()
        sheets.wrappedValue = [2]
        host.runtime.pump.turn()
        let given = Date(timeIntervalSinceNow: 3)
        host.settle { stands() || Date() > given }

        XCTAssertTrue(stands(), "the second sheet never stood in the window")
    }

    /// The user swiping the top sheet down takes it off the window's stack: the window hears how many stay.
    @MainActor
    func testTheUsersSwipeTakesTheTopSheetAway() throws {
        let sheets = State(wrappedValue: [1, 2])
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(sheets) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle { root.presentedViewController?.presentedViewController != nil }
        let top = try XCTUnwrap(root.presentedViewController?.presentedViewController)
        let presentation = try XCTUnwrap(top.presentationController)
        guard case .dismissSheet(let remaining)? = host.roster.windows.first?.1.presentation.wayBack else {
            return XCTFail("the window's way back is its top sheet")
        }
        XCTAssertEqual(remaining, 1)

        top.presentingViewController?.dismiss(animated: false)
        presentation.delegate?.presentationControllerDidDismiss?(presentation)
        host.settle { sheets.wrappedValue == [1] && root.presentedViewController?.presentedViewController == nil }

        XCTAssertEqual(sheets.wrappedValue, [1])
        XCTAssertNotNil(root.presentedViewController, "the first stays")
        XCTAssertNil(root.presentedViewController?.presentedViewController)
    }
}
