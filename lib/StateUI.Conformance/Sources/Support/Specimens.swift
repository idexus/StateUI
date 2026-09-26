// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One element of each kind the library declares, as small as it can be and standing where an application puts
/// one: a control in a stack, a span in a label's words, a menu's item in a view's menu, a toolbar's on its page's
/// bar, an arrangement as the page, a title bar over its window. What a tier's cases dress, so a case written once
/// covers its member on every element wearing the tier.
/// Design: docs/design/host/conformance.md#a-tiers-cases
@_spi(Host) public enum Specimens {
    /// The control a specimen stands for, by its node type's name, dressed; nil for an element that stands
    /// nowhere in a stack.
    public static func make(_ element: String, _ dressing: Dressing) -> (any View)? {
        switch element {
        case "ActivityIndicator": return dressing.dress(ActivityIndicator(true))
        case "Button": return dressing.dress(Button())
        case "Canvas": return dressing.dress(Canvas())
        case "CheckBox": return dressing.dress(CheckBox())
        case "ColorBox": return dressing.dress(ColorBox())
        case "DatePicker": return dressing.dress(DatePicker())
        case "Ellipse": return dressing.dress(Ellipse())
        case "Grid": return dressing.dress(Grid())
        case "HStack": return dressing.dress(HStack())
        case "Image": return dressing.dress(Image())
        case "Label": return dressing.dress(Label())
        case "Line": return dressing.dress(Line())
        case "Map": return dressing.dress(Map())
        case "Path": return dressing.dress(Path())
        case "Picker": return dressing.dress(Picker())
        case "Polygon": return dressing.dress(Polygon())
        case "Polyline": return dressing.dress(Polyline())
        case "PositionIndicator": return dressing.dress(PositionIndicator())
        case "ProgressBar": return dressing.dress(ProgressBar())
        case "RadioButton": return dressing.dress(RadioButton())
        case "Rectangle": return dressing.dress(Rectangle())
        case "ScrollView": return dressing.dress(ScrollView())
        case "SearchField": return dressing.dress(SearchField())
        case "Slider": return dressing.dress(Slider())
        case "Stepper": return dressing.dress(Stepper())
        case "Switch": return dressing.dress(Switch())
        case "TextEditor": return dressing.dress(TextEditor())
        case "TextField": return dressing.dress(TextField())
        case "TimePicker": return dressing.dress(TimePicker())
        case "VStack": return dressing.dress(VStack())
        case "WebView": return dressing.dress(WebView())
        case "ZStack": return dressing.dress(ZStack())
        default: return nil
        }
    }

    /// `element`'s control wearing `worn`, found by `id` - or words naming the element that stands in no stack, which
    /// the case finding it by its id then fails on.
    public static func view(_ element: String, _ worn: [any Worn] = [], id: String = "specimen") -> any View {
        make(element, Dressing(worn, id: id)) ?? Label("no specimen of \(element)")
    }

    /// A page holding `element`'s specimen wearing `worn` where an application puts one, `beside` it on the page. A
    /// session finds it by the id "specimen", or - a span, an arrangement - as the one element of its kind
    /// (`Session.specimen(_:)`).
    public static func page(_ element: String, _ worn: [any Worn] = [], beside: [any View] = []) -> any Page {
        let dressing = Dressing(worn)
        let others: [Element] = beside.map { $0 }
        switch element {
        case "Span":
            return VStack { [Label().spans { dressing.wear(TextSpan("Some words")) }] + others }
        case "MenuItem":
            return VStack {
                [Label("Row").contextMenu { dressing.wear(MenuItem("Copy")).id(dressing.id) }.id("row")] + others
            }
        case "ToolbarItem":
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                SessionPage(beside: others, key: "\(worn)") { page, _ in
                    page.toolbarItems = [dressing.wear(ToolbarItem("Save")).id(dressing.id)]
                }
            } destination: { _ in Label("Pushed") }
        case "TitleBar":
            return SessionPage(beside: others, key: "\(worn)") { _, window in
                window.titleBar = dressing.wear(TitleBar("Title")).id(dressing.id)
            }
        case "NavigationStack":
            return dressing.wear(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { [Label("Root")] + others }
            } destination: { _ in Label("Pushed") })
        case "SplitView":
            return dressing.wear(SplitView(State(wrappedValue: true).projectedValue) {
                Label("Sidebar")
            } detail: { VStack { [Label("Detail")] + others } })
        case "TabbedView":
            return dressing.wear(TabbedView([0, 1]) { tab in VStack { [Label("Tab \(tab)")] + (tab == 0 ? others : []) } })
        default:
            return VStack { [view(element, worn)] + others }
        }
    }

    /// Every element wearing `tier`, in the library's order.
    public static func wearing(_ tier: any Contract.Type) -> [String] {
        LibraryContracts.elements
            .filter { element in element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) } }
            .map { $0.nodeType.name }
    }
}

/// A page that writes its page's and its window's sessions - a toolbar's items, a title bar - as it is made and
/// again whenever what it writes changes, over words and what stands beside them.
public struct SessionPage: ContentView {
    /// What stands beside its words.
    let beside: [Element]

    /// What it writes, said as words: a change in them writes the sessions again.
    let key: String

    /// What it writes.
    let write: @Sendable (PageSession, WindowSession) -> Void

    @Environment private var page: PageSession
    @Environment private var window: WindowSession

    /// A page writing its sessions as `write` says - again whenever `key` changes - `beside` its words.
    public init(
        beside: [Element] = [], key: String = "", _ write: @escaping @Sendable (PageSession, WindowSession) -> Void
    ) {
        self.beside = beside
        self.key = key
        self.write = write
    }

    public var content: any View {
        let (write, page, window) = (self.write, self.page, self.window)
        return VStack { [Label("Page")] + beside }
            .onCreated { write(page, window) }
            .onChanged(key) { write(page, window) }
    }
}
