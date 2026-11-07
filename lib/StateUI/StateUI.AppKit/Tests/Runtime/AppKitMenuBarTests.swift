// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The menu bar an AppKit application stands with.
@MainActor
final class AppKitMenuBarTests: XCTestCase {
    /// The bar is read in English - whatever language the machine running the tests speaks - but where a test says
    /// another.
    override func setUp() async throws {
        Self.speak("en")
    }

    override func tearDown() async throws {
        Self.speak("")
    }

    /// The locale the core hears: `language`, or none.
    private static func speak(_ language: String) {
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: language.isEmpty ? nil : LocaleTag(language), timeZone: nil, uses24HourClock: true,
            firstDayOfWeek: .monday, isMetric: true, writingDirection: .leftToRight))
    }

    /// The bar's own menus and entries say the library's words in the system's language, as AppKit translates no
    /// title set in code: a Polish system's bar is Plik, Edycja, Okno.
    @MainActor
    func testTheMenuBarSpeaksTheSystemsLanguage() throws {
        Self.speak("pl")
        let main = AppKitHost.mainMenu(newWindow: nil)
        XCTAssertEqual(main.items.map(\.title).dropFirst(), ["Plik", "Edycja", "Okno"])
        XCTAssertEqual(main.item(withTitle: "Plik")?.submenu?.items.map(\.title), ["Nowe okno"])
        XCTAssertEqual(
            main.item(withTitle: "Edycja")?.submenu?.items.filter { !$0.isSeparatorItem }.map(\.title),
            ["Cofnij", "Ponów", "Wytnij", "Kopiuj", "Wklej", "Usuń", "Zaznacz wszystko"])
        XCTAssertEqual(main.item(withTitle: "Okno")?.submenu?.items.map(\.title), ["Minimalizuj", "Wszystko na wierzch"])
        XCTAssertTrue(main.items.first?.submenu?.items.first?.title.hasPrefix("Zakończ ") == true)
    }
    /// The keys a keyboard sends read as the keys they are: Delete sends DEL and the keypad's Enter ETX, not the
    /// characters a key equivalent names them by.
    @MainActor
    func testTheCharactersAKeyboardSendsReadAsTheirKeys() {
        XCTAssertEqual(AppKitKeys.shortcut(key: "\u{7f}", modifiers: [])?.key, Key(.delete))
        XCTAssertEqual(AppKitKeys.shortcut(key: "\u{3}", modifiers: [])?.key, Key(.return))
        XCTAssertEqual(AppKitKeys.shortcut(key: "\u{8}", modifiers: [])?.key, Key(.delete), "and the equivalent's own")
        XCTAssertEqual(AppKitKeys.typed(of: KeyboardShortcut(.delete, modifiers: [])), "\u{7f}")
    }

    /// Edit holds the text commands a field answers - AppKit routes ⌘C, ⌘V and ⌘Z through the menu bar's key
    /// equivalents, so without them a field copies, pastes and undoes nothing.
    @MainActor
    func testTheMenuBarHoldsTheTextCommandsAFieldAnswers() throws {
        let main = AppKitHost.mainMenu(newWindow: nil)
        XCTAssertEqual(main.items.map(\.title).dropFirst(), ["File", "Edit", "Window"])

        let edit = try XCTUnwrap(main.item(withTitle: "Edit")?.submenu)
        let commands = edit.items.filter { !$0.isSeparatorItem }.map { item in
            let shift = item.keyEquivalentModifierMask.contains(.shift) ? "⇧" : ""
            return "\(shift)\(item.keyEquivalent) \(item.action.map(NSStringFromSelector) ?? "")"
        }
        XCTAssertEqual(commands, ["z undo:", "⇧z redo:", "x cut:", "c copy:", "v paste:", " delete:", "a selectAll:"])
    }

    /// A page's menus join the bar by identity, whatever their captions: a standard menu joins the platform's own as a
    /// section after its entries, one the platform keeps none of stands where the platform puts it, any other before
    /// Window; an entry the tree disables stays disabled there, and the bar is as it was once the menus go.
    @MainActor
    func testAPagesMenusJoinTheBarByIdentity() throws {
        let renderer = AppKitRenderer.running {
            Text("Page").menuBar {
                Menu("Plik") {
                    MenuItem("Eksportuj").id("export")
                    MenuItem("Zapisz").isEnabled(false).id("save")
                }
                .joins(.file)
                Menu("Pomoc") { MenuItem("Podręcznik") }.joins(.help)
                Menu("Widok") { MenuItem("Powiększ") }.joins(.view)
                Menu("Format") { MenuItem("Pogrub") }
            }
        }
        defer { renderer.finish() }
        let main = AppKitHost.mainMenu(newWindow: nil)
        let controller = try XCTUnwrap(renderer.windowsForTesting.first)

        renderer.installPageMenus(controller.pageMenus, into: main)
        XCTAssertEqual(Array(main.items.map(\.title).dropFirst()), ["File", "Edit", "Widok", "Format", "Window", "Pomoc"])
        let file = try XCTUnwrap(main.items[1].submenu)
        XCTAssertEqual(file.items.map { $0.isSeparatorItem ? "-" : $0.title }, ["New Window", "-", "Eksportuj", "Zapisz"])
        file.update()
        XCTAssertEqual(file.items.suffix(2).map(\.isEnabled), [true, false], "enabled as the tree says")

        renderer.installPageMenus([], into: main)
        XCTAssertEqual(Array(main.items.map(\.title).dropFirst()), ["File", "Edit", "Window"])
        XCTAssertEqual(file.items.map(\.title), ["New Window"])
    }

    /// A page's entry stands on the bar with its shortcut whole - its key and every key held with it - so the bar
    /// shows and answers ⌘⇧S, not ⌘S.
    @MainActor
    func testAPagesEntryStandsOnTheBarWithItsShortcutWhole() throws {
        let renderer = AppKitRenderer.running {
            Text("Page").menuBar {
                Menu("Format") { MenuItem("Save As").keyboardShortcut("s", modifiers: [.primary, .shift]) }
            }
        }
        defer { renderer.finish() }
        let main = AppKitHost.mainMenu(newWindow: nil)
        let controller = try XCTUnwrap(renderer.windowsForTesting.first)

        renderer.installPageMenus(controller.pageMenus, into: main)
        defer { renderer.installPageMenus([], into: main) }
        let format = try XCTUnwrap(main.items.first { $0.title == "Format" }?.submenu)
        XCTAssertEqual(format.items.first?.keyEquivalent, "s")
        XCTAssertEqual(format.items.first?.keyEquivalentModifierMask, [.command, .shift])
    }
}
#endif
