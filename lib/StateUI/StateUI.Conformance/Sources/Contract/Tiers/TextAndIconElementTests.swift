// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextAndIconElementContract` on a host: an element showing words and a picture - a button, a bar's item - stands
/// its words beside its picture as the tree says, each case made for every element wearing the tier; a button's
/// words out of sight name it.
@_spi(Host) public enum TextAndIconElementTests: ConformanceFamily {
    public static let name = "TextAndIconElement"

    public static var cases: [ConformanceCase] {
        // A bar's item is named by its title on every platform; a button standing for its picture by its words.
        Specimens.wearing(TextAndIconElementContract.self).map(besidePicture) + [outOfSightNaming("Button")]
    }

    /// Its words out of sight name it to assistive technology.
    @MainActor
    static func outOfSightNaming(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).itsWordsOutOfSightNameIt", proves: [
            Covered(TextAndIconElementContract.showsText, on: element),
        ], needs: [Covered(VisualElementContract.accessibilityLabel, on: element)]) { s in
            s.start { standing(element, showsText: false, beside: []) }
            try s.settle { try s.held(VisualElementContract.accessibilityLabel, on: s.element("save")) == "Save" }
            s.expect(try s.held(VisualElementContract.accessibilityLabel, on: s.element("save")), "Save", "its words name it")
        }
    }

    /// Its words stand beside its picture, then the picture stands alone.
    @MainActor
    static func besidePicture(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).itsWordsStandBesideItsPictureAsItSays", proves: [
            Covered(TextAndIconElementContract.showsText, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let words = State(wrappedValue: true)
            s.start {
                standing(
                    element, showsText: words.wrappedValue,
                    beside: [Button("Picture alone").onClicked { words.wrappedValue = false }.id("change")])
            }
            try s.settle { try s.held(TextAndIconElementContract.showsText, on: s.element("save")) == true }
            s.expect(try s.held(TextAndIconElementContract.showsText, on: s.element("save")), true, "words beside it")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(TextAndIconElementContract.showsText, on: s.element("save")) == false }
            s.expect(try s.held(TextAndIconElementContract.showsText, on: s.element("save")), false, "the picture alone")
        }
    }

    /// "Save" of `element`'s kind with a picture, its words beside it as `showsText` says, `beside` views of its
    /// page: a button among views, a bar's item on its page's bar over a stack.
    @MainActor
    static func standing(_ element: String, showsText: Bool, beside: [any View]) -> AnyView {
        let page = { (items: @escaping @MainActor () -> [ToolbarButton], toggles: @escaping @MainActor () -> [ToolbarToggle]) in
            AnyView(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage(beside: beside, key: "\(showsText)", items, toggles: toggles)
            } destination: { _ in Text("Pushed") })
        }
        switch element {
        case "ToolbarButton":
            return page({ [ToolbarButton("Save").icon("test_dot.png").showsText(showsText).id("save")] }, { [] })
        case "ToolbarToggle":
            return page({ [] }, { [ToolbarToggle("Save", isOn: false).icon("test_dot.png").showsText(showsText).id("save")] })
        default:
            return AnyView(VStack { Beside([Button("Save").icon("test_dot.png").showsText(showsText).id("save")] + beside) })
        }
    }
}
