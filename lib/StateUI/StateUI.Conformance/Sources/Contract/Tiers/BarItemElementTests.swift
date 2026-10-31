// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BarItemElementContract` on a host drawing its bar itself: an item on the bar - a button, a setting, a group -
/// stands on the background the tree gives it, takes the values of the style it names, and follows the pointer
/// over it.
@_spi(Host) public enum BarItemElementTests: ConformanceFamily {
    public static let name = "BarItemElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BarItemElementContract.self).flatMap { element in
            [
                Aspects.holds(BarItemElementContract.background, on: element, .color(.steelBlue), then: .color(.firebrick)),
                styled(element),
                pointed(element),
            ]
        }
    }

    /// An item naming a style takes the background the style gives it.
    @MainActor
    static func styled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesTheValuesOfTheStyleItNames", proves: [
            Covered(BarItemElementContract.style, on: element),
        ], needs: [Covered(BarItemElementContract.background, on: element)]) { s in
            s.start {
                Specimens.page(element, [Write(BarItemElementContract.style, Name(Styled.key(element)))], beside: [WearsStyledSheet()])
            }
            let item = try s.element("specimen")

            try s.settle { try s.held(BarItemElementContract.background, on: item) == .color(.steelBlue) }
            s.expect(try s.held(BarItemElementContract.background, on: item), .color(.steelBlue), "the style's background")
        }
    }

    /// The pointer coming over an item shows its pointer-over values, and leaving gives its own back.
    @MainActor
    static func pointed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).followsThePointerOverIt", proves: [
            Covered(BarItemElementContract.pointerEntered, on: element),
            Covered(BarItemElementContract.pointerExited, on: element),
        ], needs: [Covered(BarItemElementContract.background, on: element)]) { s in
            s.start { BarItemStates.page(element, .pointerOver) }
            let item = try s.element("specimen")
            let background = { try s.held(BarItemElementContract.background, on: item) }
            try s.settle { try background() == .color(.steelBlue) }

            try s.perform(.hover(at: Point(8, 8)), on: item)
            try s.settle { try background() == .color(.firebrick) }
            s.expect(try background(), .color(.firebrick), "its pointer-over background")

            try s.perform(.leave, on: item)
            try s.settle { try background() == .color(.steelBlue) }
            s.expect(try background(), .color(.steelBlue), "its own again")
        }
    }
}

/// An item on a bar - by its node type's name - on a background of steel blue, firebrick in `state`, found as
/// "specimen" on its page's bar.
@MainActor
enum BarItemStates {
    /// The state an item shows firebrick in.
    enum Lit { case pointerOver, pressed }

    static func page(_ element: String, _ state: Lit) -> AnyView {
        AnyView(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
            switch element {
            case "ToolbarToggle":
                DeclaringPage(toggles: { [lit(ToolbarToggle("Ruler", isOn: false), state).id("specimen")] })
            case "ToolbarGroup":
                DeclaringPage(groups: { [lit(ToolbarGroup { ToolbarButton("Add"); ToolbarButton("Edit") }, state).id("specimen")] })
            default:
                DeclaringPage { [lit(ToolbarButton("Save"), state).id("specimen")] }
            }
        } destination: { _ in Text("Pushed") })
    }

    private static func lit(_ item: ToolbarButton, _ state: Lit) -> ToolbarButton {
        item.background(.steelBlue).visualState(state == .pressed ? .pressed : .pointerOver) { $0.background(.firebrick) }
    }

    private static func lit(_ item: ToolbarToggle, _ state: Lit) -> ToolbarToggle {
        item.background(.steelBlue).visualState(state == .pressed ? .pressed : .pointerOver) { $0.background(.firebrick) }
    }

    private static func lit(_ item: ToolbarGroup, _ state: Lit) -> ToolbarGroup {
        item.background(.steelBlue).visualState(.pointerOver) { $0.background(.firebrick) }
    }
}
