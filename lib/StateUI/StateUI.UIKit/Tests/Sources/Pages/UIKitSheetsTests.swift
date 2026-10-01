// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A page under the numbered sheets one state lists.
private func sheetsOver(_ sheets: State<[Int]>) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        Label("beneath")
    } destination: { number in
        Label("On sheet \(number)")
    }
}

/// Pages a window presents over its page, as UIKit presents them.
final class UIKitSheetsTests: XCTestCase {
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
