// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidMenusTests: XCTestCase {
    static var allTests: [(String, (AndroidMenusTests) -> () throws -> Void)] {
        [
            ("testAContextMenuIsWrittenAsTheUserAsksAndItsItemsRun", testAContextMenuIsWrittenAsTheUserAsksAndItsItemsRun),
            ("testAViewWhoseMenuGoesOffersNone", testAViewWhoseMenuGoesOffersNone),
        ]
    }

    /// A view with a context menu takes a long press; the menu is written as the user asks for it - an item, a
    /// submenu with an item that cannot be chosen, a line, a destructive item, and one that cannot be chosen
    /// shown as such rather than in the error colour - and an item chosen runs.
    func testAContextMenuIsWrittenAsTheUserAsksAndItsItemsRun() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running {
                Label("Row").contextMenu {
                    MenuItem("Duplicate").onClicked { heard.values.append("duplicate") }
                    Menu("Move") {
                        MenuItem("To the top").isEnabled(false).onClicked { heard.values.append("top") }
                    }
                    MenuSeparator()
                    MenuItem("Remove").isDestructive(true).onClicked { heard.values.append("remove") }
                    MenuItem("Erase").isDestructive(true).isEnabled(false).onClicked { heard.values.append("erase") }
                }
            }
            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)
            XCTAssertTrue(Java.callBool(label.reference, JavaAPI.isLongClickable))

            let menu = TestMenus.empty()
            label.menuOpening(menu.reference)
            XCTAssertEqual(TestMenus.describe(menu), "Duplicate, Move [To the top (off)] | Remove (red), Erase (off)")

            for words in ["Duplicate", "To the top", "Remove", "Erase"] { TestMenus.choose(menu, words) }
            host.pump()
            XCTAssertEqual(heard.values, ["duplicate", "remove"])
        }
    }

    /// The same view once its menu goes: no longer long-pressed for one, and written none.
    func testAViewWhoseMenuGoesOffersNone() throws {
        try onMainActor {
            let offers = State(wrappedValue: true)
            let host = AndroidRenderer.running {
                if offers.wrappedValue { return Label("Row").contextMenu { MenuItem("Duplicate") } }
                return Label("Row")
            }
            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)

            offers.wrappedValue = false
            host.pump()
            XCTAssertTrue(host.views(AndroidLabelView.self).first === label, "the same view")
            XCTAssertFalse(Java.callBool(label.reference, JavaAPI.isLongClickable))
            let menu = TestMenus.empty()
            label.menuOpening(menu.reference)
            XCTAssertEqual(TestMenus.describe(menu), "")
        }
    }
}

/// Android's own menus, read back as words and chosen from by their words: `TestMenus.java`.
@MainActor
enum TestMenus {
    private static let owner = Java.findClass("stateui/android/test/TestMenus")
    private static let newMenu = Java.staticMethod(owner, "empty", "(Landroid/content/Context;)Landroid/view/Menu;")
    private static let describeMenu = Java.staticMethod(
        owner, "describe", "(Landroid/content/Context;Landroid/view/Menu;)Ljava/lang/String;")
    private static let chooseItem = Java.staticMethod(owner, "choose", "(Landroid/view/Menu;Ljava/lang/String;)Z")
    static let getMenu = Java.method(Java.findClass("android/widget/Toolbar"), "getMenu", "()Landroid/view/Menu;")

    /// An empty menu, as a context menu is before its view writes it.
    static func empty() -> JavaObject {
        JavaObject(Java.callStaticObject(owner, newMenu, .object(TestContext.context.reference))!)
    }

    /// Each entry's words: a submenu's in brackets, ", " within a group, " | " between groups; " (off)",
    /// " (red)" and " (picture)" where an item cannot be chosen, is destructive, or has a picture - " (dimmed
    /// picture)" where it is drawn translucent.
    static func describe(_ menu: JavaObject) -> String {
        Java.frame {
            Java.callStaticObject(
                owner, describeMenu, .object(TestContext.context.reference), .object(menu.reference)
            ).map { Java.text($0) } ?? ""
        }
    }

    /// Chooses the item that says `words`, as a touch does.
    @discardableResult
    static func choose(_ menu: JavaObject, _ words: String) -> Bool {
        let text = Java.string(words)
        defer { Java.release(local: text) }
        return Java.callStaticBool(owner, chooseItem, .object(menu.reference), .object(text))
    }
}
