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
        Specimens.wearing(KeyboardElementContract.self).map(keyed) + [keyedThroughTheKeyboard]
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
                    Write(KeyboardElementContract.keysTaken, [Key.escape, .f5]), Hear(KeyboardElementContract.keyPressed) { heard.values.append($0) },
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
                    TextField("").onKeyPressed(.upArrow) { heard.values.append("field \($0 == .upArrow)") }.id("field")
                }
                .onKeyPressed(.escape, .upArrow) { heard.values.append("stack \($0 == .escape)") }
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
