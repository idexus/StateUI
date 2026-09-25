// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What every view is as the tree says, the tree changing it: shown or not, how opaque, taking input or not -
/// each case made for every element wearing the tier.
@_spi(Host) public enum Presence: ConformanceFamily {
    public static let name = "Presence"

    public static var cases: [ConformanceCase] {
        var cases: [ConformanceCase] = []
        for element in Specimens.wearing(VisualElementContract.self) {
            cases.append(shown(element))
            cases.append(opacity(element))
            cases.append(enabled(element))
        }
        return cases
    }

    /// A view is shown or not as the tree says, and hides when the tree says so.
    static func shown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isShownAsTheTreeSays", covers: [
            Covered(VisualElementContract.isVisible, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let shown = State(wrappedValue: true)
            s.start(reducesMotion: true) {
                VStack {
                    specimen(element, Write(VisualElementContract.isVisible, shown.wrappedValue))
                    Button("Hide").onClicked { shown.wrappedValue = false }.id("change")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(VisualElementContract.isVisible, on: view), true)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isVisible, on: view) == false }
            s.expect(try s.held(VisualElementContract.isVisible, on: view), false)
        }
    }

    /// A view is as opaque as the tree says, and changes as the tree does.
    static func opacity(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isAsOpaqueAsTheTreeSays", covers: [
            Covered(VisualElementContract.opacity, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let opacity = State(wrappedValue: 0.5)
            s.start(reducesMotion: true) {
                VStack {
                    specimen(element, Write(VisualElementContract.opacity, opacity.wrappedValue))
                    Button("Fade").onClicked { opacity.wrappedValue = 0.25 }.id("change")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(VisualElementContract.opacity, on: view), 0.5, within: 0.01)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { abs((try s.held(VisualElementContract.opacity, on: view) ?? 0) - 0.25) < 0.01 }
            s.expect(try s.held(VisualElementContract.opacity, on: view), 0.25, within: 0.01)
        }
    }

    /// A view takes input or not as the tree says, and stops when the tree says so.
    static func enabled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesInputAsTheTreeSays", covers: [
            Covered(VisualElementContract.isEnabled, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let enabled = State(wrappedValue: true)
            s.start(reducesMotion: true) {
                VStack {
                    specimen(element, Write(VisualElementContract.isEnabled, enabled.wrappedValue))
                    Button("Disable").onClicked { enabled.wrappedValue = false }.id("change")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), true)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isEnabled, on: view) == false }
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), false)
        }
    }

    /// `element`'s specimen wearing `write`.
    private static func specimen(_ element: String, _ write: any Written) -> any View {
        Specimens.make(element, Dressing([write])) ?? Label("no specimen of \(element)")
    }
}
