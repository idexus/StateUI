// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A page presenting a sheet while `first`, which presents another in it while `second`.
@MainActor
private func sheetsOver(_ first: State<Bool>, _ second: State<Bool>) -> some View {
    Text("beneath")
        .sheet(isPresented: first.projectedValue) {
            Text("On sheet 1")
                .sheet(isPresented: second.projectedValue) { Text("On sheet 2") }
        }
}

/// A page whose button asks for a sheet and a question in one turn, and for a second sheet in it once answered.
private struct SheetAndQuestion: View {
    @Environment(\.window) private var window
    @State private var first = false
    @State private var second = false

    var body: some View {
        Button("Ask")
            .onClicked(gate: .ignoreWhileRunning) {
                first = true
                _ = try await window.confirm("Sure?", message: "Both come", accept: "Yes", cancel: "No")
                second = true
            }
            .sheet(isPresented: $first) {
                Text("On sheet 1").sheet(isPresented: $second) { Text("On sheet 2") }
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

        XCTAssertEqual(host.actToolkit.showing?.press(.accept, typing: nil), true)
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
        let (first, second) = (State(wrappedValue: true), State(wrappedValue: false))
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(first, second) }
        defer { host.finish() }
        func root() -> UIViewController? { host.roster.windows.first?.1.window?.rootViewController }
        host.settle { root()?.presentedViewController?.viewIfLoaded?.window != nil }

        host.disconnect(scene)
        host.connect(scene)
        host.settle { root()?.presentedViewController?.viewIfLoaded?.window != nil }
        XCTAssertNotNil(root()?.presentedViewController?.viewIfLoaded?.window, "the sheet stands again")

        second.wrappedValue = true
        host.settle { root()?.presentedViewController?.presentedViewController?.viewIfLoaded?.window != nil }
        XCTAssertNotNil(
            root()?.presentedViewController?.presentedViewController?.viewIfLoaded?.window, "the next comes over it")
    }

    /// Sheets the window starts with stand each over the one before, as UIKit presents over a controller only once
    /// it stands.
    @MainActor
    func testSheetsTheWindowStartsWithStandEachOverTheOneBefore() throws {
        let (first, second) = (State(wrappedValue: true), State(wrappedValue: true))
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(first, second) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)

        host.settle { root.presentedViewController?.presentedViewController != nil }

        XCTAssertNotNil(root.presentedViewController, "the first sheet over the page")
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "the second over the first")
    }

    /// A sheet stands as the platform's own: a card in the middle of a wide screen - an iPad's - and rising from
    /// the bottom of a narrow one, never a page over the whole of a wide screen.
    @MainActor
    func testASheetStandsAsThePlatformsSheet() throws {
        let first = State(wrappedValue: true)
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(first, State(wrappedValue: false)) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle { root.presentedViewController?.viewIfLoaded?.window != nil }
        let sheet = try XCTUnwrap(root.presentedViewController)

        XCTAssertEqual(sheet.modalPresentationStyle, .formSheet)
        if root.traitCollection.horizontalSizeClass == .regular {
            XCTAssertLessThan(sheet.view.frame.width, root.view.bounds.width * 0.8, "a card in the middle")
        }
    }

    /// Presenting sheets, moving as UIKit moves them, tells the window nothing: only the user's swipe does.
    @MainActor
    func testSheetsPresentedWithMotionTellTheWindowNothing() throws {
        let (first, second) = (State(wrappedValue: true), State(wrappedValue: true))
        let host = UIKitRenderer.running(reducesMotion: false) { sheetsOver(first, second) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)

        host.settle { root.presentedViewController?.presentedViewController != nil }
        let settled = Date(timeIntervalSinceNow: 1)
        host.settle { Date() > settled }

        XCTAssertEqual([first.wrappedValue, second.wrappedValue], [true, true])
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "both still stand")
    }

    /// A window whose sheets were still coming as it went leaves the next window's sheets to come as asked.
    @MainActor
    func testTheNextWindowsSheetsComeAfterOneWhoseSheetsWereMoving() throws {
        let (one, two) = (State(wrappedValue: false), State(wrappedValue: false))
        let before = UIKitRenderer.running(reducesMotion: false) { sheetsOver(one, two) }
        (one.wrappedValue, two.wrappedValue) = (true, true)
        before.settle { before.roster.windows.first?.1.window?.rootViewController?.presentedViewController != nil }
        before.finish()

        let (first, second) = (State(wrappedValue: true), State(wrappedValue: true))
        let host = UIKitRenderer.running(reducesMotion: false) { sheetsOver(first, second) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle { root.presentedViewController?.presentedViewController != nil }

        XCTAssertEqual([first.wrappedValue, second.wrappedValue], [true, true], "nothing told the window they went")
        XCTAssertNotNil(root.presentedViewController?.presentedViewController, "both came")
    }

    /// A sheet asked for while the one before is still coming, and already asked to go, comes once that one has
    /// gone: UIKit presents nothing over a controller whose sheet is still moving, and drops what it is asked.
    @MainActor
    func testASheetAskedForWhileTheOneBeforeStillMovesComesOnceItHasGone() throws {
        let (one, two) = (State(wrappedValue: false), State(wrappedValue: false))
        let host = UIKitRenderer.running(reducesMotion: false) {
            VStack {
                Text("beneath").sheet(isPresented: one.projectedValue) { Text("On sheet 1") }
                Text("beside").sheet(isPresented: two.projectedValue) { Text("On sheet 2") }
            }
        }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        let shown = Date(timeIntervalSinceNow: 0.5)
        host.settle { Date() > shown }
        let stands = { host.views(UIKitTextView.self).first { $0.text == "On sheet 2" }?.window != nil }

        one.wrappedValue = true
        host.runtime.pump.turn()
        XCTAssertEqual(root.presentedViewController?.isBeingPresented, true, "the first sheet is on its way in")
        one.wrappedValue = false
        host.runtime.pump.turn()
        two.wrappedValue = true
        host.runtime.pump.turn()
        let given = Date(timeIntervalSinceNow: 3)
        host.settle { stands() || Date() > given }

        XCTAssertTrue(stands(), "the second sheet never stood in the window")
    }

    /// The user swiping the top sheet down takes it away: false onto its state, the one under it staying.
    @MainActor
    func testTheUsersSwipeTakesTheTopSheetAway() throws {
        let (first, second) = (State(wrappedValue: true), State(wrappedValue: true))
        let host = UIKitRenderer.running(reducesMotion: true) { sheetsOver(first, second) }
        defer { host.finish() }
        let root = try XCTUnwrap(host.roster.windows.first?.1.window?.rootViewController)
        host.settle { root.presentedViewController?.presentedViewController != nil }
        let top = try XCTUnwrap(root.presentedViewController?.presentedViewController)
        let presentation = try XCTUnwrap(top.presentationController)
        guard case .dismissSheets(let pages)? = host.roster.windows.first?.1.presentation.wayBack else {
            return XCTFail("the window's way back is its top sheet")
        }
        XCTAssertEqual(pages.count, 1)

        top.presentingViewController?.dismiss(animated: false)
        presentation.delegate?.presentationControllerDidDismiss?(presentation)
        host.settle { !second.wrappedValue && root.presentedViewController?.presentedViewController == nil }

        XCTAssertEqual([first.wrappedValue, second.wrappedValue], [true, false])
        XCTAssertNotNil(root.presentedViewController, "the first stays")
        XCTAssertNil(root.presentedViewController?.presentedViewController)
    }
}
