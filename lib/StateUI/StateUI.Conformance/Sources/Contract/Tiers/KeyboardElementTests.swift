// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `KeyboardElementContract` on a host: the keys an element takes reach it as the host layer routes them - out from
/// the view holding the keyboard, else from the page's content - and stop there; each case made for every element
/// wearing the tier.
@_spi(Host) public enum KeyboardElementTests: ConformanceFamily {
    public static let name = "KeyboardElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(KeyboardElementContract.self).flatMap { [keyed($0), moving($0)] } + [keyedThroughTheKeyboard]
    }

    /// The keys an element takes reach it as its page's content, with nothing holding the keyboard, and a key it
    /// does not take, or one held with the platform's own key, does not.
    @MainActor
    static func keyed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).hearsTheKeysItTakes", proves: [
            Covered(KeyboardElementContract.keyPressed, on: element), Covered(KeyboardElementContract.keysTaken, on: element),
        ]) { s in
            let heard = Received<Key>()
            s.start {
                Specimens.view(element, [
                    Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                    Write(KeyboardElementContract.keysTaken, [Key.escape, .f5]),
                    HearTwo(KeyboardElementContract.keyPressed) { key, _ in heard.values.append(key) },
                ])
            }
            let view = try s.element("specimen")

            try s.perform(.pressKeys(KeyboardShortcut(.escape, modifiers: [])), on: view)
            s.settle { heard.values == [.escape] }
            s.expect(heard.values, [.escape], "a key it takes")
            try s.perform(.pressKeys(KeyboardShortcut(.f6, modifiers: [])), on: view)
            try s.perform(.pressKeys(KeyboardShortcut(.f5, modifiers: [.primary])), on: view)
            s.turn()
            s.expect(heard.values, [.escape], "a key it does not take, and one held with the platform's own key")
            try s.perform(.pressKeys(KeyboardShortcut(.f5, modifiers: [])), on: view)
            s.settle { heard.values == [.escape, .f5] }
            s.expect(heard.values, [.escape, .f5])
        }
    }

    /// The keys moving through a page - Tab, Space, Home, End, Page Up and Page Down - reach the element taking
    /// them, and Tab held with Shift reaches it told apart from Tab alone.
    @MainActor
    static func moving(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).hearsTheKeysMovingThroughAPage", proves: [
            Covered(KeyboardElementContract.keyPressed, on: element),
            Covered(KeyboardElementContract.keysTaken, on: element),
        ]) { s in
            let names: [Key: String] = [
                .tab: "tab", .space: "space", .home: "home", .end: "end", .pageUp: "pageUp", .pageDown: "pageDown",
            ]
            let heard = Received<String>()
            s.start {
                Specimens.view(element, [
                    Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                    Write(KeyboardElementContract.keysTaken, Array(names.keys)),
                    HearTwo(KeyboardElementContract.keyPressed) { key, held in
                        heard.values.append((names[key] ?? "?") + (held.contains(.shift) ? " with shift" : ""))
                    },
                ])
            }
            let view = try s.element("specimen")

            let pressed: [(Key, KeyModifiers)] = [
                (.tab, .shift), (.tab, []), (.space, []), (.home, []), (.end, []), (.pageUp, []), (.pageDown, []),
            ]
            for (key, held) in pressed {
                try s.perform(.pressKeys(KeyboardShortcut(key, modifiers: held)), on: view)
            }
            let expected = ["tab with shift", "tab", "space", "home", "end", "pageUp", "pageDown"]
            s.settle { heard.values == expected }
            s.expect(heard.values, expected)
        }
    }

    /// A key reaches the view holding the keyboard first, and the view holding that one after: the field takes
    /// its arrow, the stack around it Escape.
    @MainActor
    static var keyedThroughTheKeyboard: ConformanceCase {
        ConformanceCase("aKeyReachesTheViewHoldingTheKeyboardFirst", proves: [
            Covered(KeyboardElementContract.keyPressed, on: "TextField"), Covered(KeyboardElementContract.keyPressed, on: "VStack"),
        ], needs: [Covered(FocusElementContract.focus, on: "TextField")]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    TextField("")
                        .onKeyPressed(.upArrow) { heard.values.append("field \($0.key == .upArrow)") }
                        .id("field")
                }
                .onKeyPressed(.escape, .upArrow) { heard.values.append("stack \($0.key == .escape)") }
                .id("stack")
            }
            let field = try s.element("field")

            try s.perform(.focus, on: field)
            try s.settle { try s.focused(field) }
            try s.perform(.pressKeys(KeyboardShortcut(.upArrow, modifiers: [])), on: field)
            s.settle { heard.values == ["field true"] }
            s.expect(heard.values, ["field true"], "the field holding the keyboard takes its arrow first")
            try s.perform(.pressKeys(KeyboardShortcut(.escape, modifiers: [])), on: field)
            s.settle { heard.values == ["field true", "stack true"] }
            s.expect(heard.values, ["field true", "stack true"], "the stack holding it takes Escape")
        }
    }
}
