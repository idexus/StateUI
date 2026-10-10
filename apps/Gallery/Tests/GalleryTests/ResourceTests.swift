// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gallery's own styles, checked the way its catalog is.
//
// A style is written once and applies to everything, which is exactly what makes
// a mistake in one quiet: a target type spelled wrong, or two styles claiming
// the same key, changes nothing visible until somebody notices the control that
// never took its colour.

import Foundation
import XCTest
@testable import GalleryUI
@_spi(Host) @testable import StateUI

@MainActor
final class ResourceTests: XCTestCase {
    private var styles: [AnyStyle] {
        AppStyles.sheet.written
    }

    /// Every element a style may target, by its node type: the library's, and
    /// the Gallery's own.
    ///
    /// The Gallery's own are declared once for every host - a contract and a
    /// `View`, shared - and each host registers what they ARE for itself. So
    /// they belong here whichever host this build is for, and the list comes
    /// from `GalleryElements` rather than from a copy that could fall behind.
    private static var elements: Set<String> {
        Set(LibraryContracts.elements.map { $0.nodeType.name }).union(GalleryElements.names)
    }

    func testEveryStyleTargetsAnElementAContractDeclares() {
        XCTAssertFalse(styles.isEmpty)

        for style in styles {
            XCTAssertTrue(Self.elements.contains(style.target.name),
                          "\(style.target.name) is no element a contract declares")
        }
    }

    /// A style with no setters is a style that does nothing, and the way to end
    /// up with one is a closure that forgot to return what it was given.
    func testEveryStyleActuallySetsSomething() {
        for style in styles {
            let key = style.key ?? style.target.name

            XCTAssertFalse(style.props.isEmpty, "\(key) sets nothing")

            for state in style.states {
                XCTAssertFalse(state.setters.isEmpty, "\(key) in \(state.name) sets nothing")
            }
        }
    }

    /// Two styles under one key means one of them is not there, and nothing
    /// says so.
    func testNothingIsFiledTwice() {
        var keys: Set<String> = []
        var implicitTargets: Set<String> = []

        for style in styles {
            if let key = style.key {
                XCTAssertTrue(keys.insert(key).inserted, "two styles answer to \"\(key)\"")
            } else {
                XCTAssertTrue(implicitTargets.insert(style.target.name).inserted,
                              "two implicit styles for \(style.target.name)")
            }
        }
    }

    /// The Gallery's look is a light one and a dark one. A colour written for
    /// only one theme is the thing that reads wrong on the other, so every
    /// colour a style writes but a clear one is written for both.
    ///
    /// Asked of the sheet itself: a value written with a half for each theme
    /// is held as the PAIR until the differ builds the element wearing it, so
    /// a colour standing bare is one written for a single theme.
    func testTheStylesAreWrittenForBothThemes() {
        for style in styles {
            for (name, value) in style.props {
                if case .color(_, _, _, let alpha) = value {
                    XCTAssertEqual(alpha, 0, "\(style.key ?? style.target.name).\(name) is written for one theme")
                }
            }
        }
    }

    /// The keyed styles the gallery asks for by name exist. A key nothing was
    /// filed under leaves the control with the default appearance and no word
    /// about it.
    func testTheKeysTheGalleryAsksForAreThere() {
        let keys = Set(styles.compactMap { $0.key })

        XCTAssertTrue(keys.contains("Headline"))

        // What the menu's rows are written against - see Gallery/Views/MenuRow.swift.
        XCTAssertTrue(keys.contains("MenuRow"))
        XCTAssertTrue(keys.contains("MenuRowText"))
    }

    /// The menu is a page and its selected section is application state. A
    /// chosen row writes its fill over the shared style, so the invariant
    /// worth pinning is that chosen and resting rows render differently.
    func testTheChosenMenuRowIsDrawnDifferentlyFromTheRest() {
        func drawn(chosen: Bool) -> Node {
            MenuRow("Layout", action: {}).icon("nav_layout.png").chosen(chosen).body.node
        }

        XCTAssertNotEqual(drawn(chosen: true).props["background"], drawn(chosen: false).props["background"],
                          "the row you are on looks like every other row")
    }
}
