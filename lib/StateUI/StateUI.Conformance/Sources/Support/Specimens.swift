// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One element of each kind the library declares, as small as it can be and standing where an application puts
/// one: a control in a stack, a span in a label's words, a menu's item in a view's menu, a toolbar's on its page's
/// bar, an arrangement as the page. What a tier's cases dress, so a case written once
/// covers its member on every element wearing the tier.
/// Design: docs/design/host/conformance.md#a-tiers-cases
@MainActor
@_spi(Host) public enum Specimens {
    /// The control a specimen stands for, by its node type's name, dressed; nil for an element that stands
    /// nowhere in a stack.
    public static func make(_ element: String, _ dressing: Dressing) -> (any View)? {
        switch element {
        case "Spinner": return dressing.dress(Spinner(true))
        case "Button": return dressing.dress(Button())
        case "Canvas": return dressing.dress(Canvas())
        case "Capsule": return dressing.dress(Capsule())
        case "CheckBox": return dressing.dress(CheckBox())
        case "DatePicker": return dressing.dress(DatePicker())
        case "Separator": return dressing.dress(Separator())
        case "Ellipse": return dressing.dress(Ellipse())
        case "Grid": return dressing.dress(Grid())
        case "HStack": return dressing.dress(HStack())
        case "Image": return dressing.dress(Image())
        case "ItemsView": return dressing.dress(ItemsView(0..<20) { Text("Item \($0)") }.width(240).height(160))
        case "LayoutEngine":
            return dressing.dress(AnyView(LayoutEngine([Int]()) { _ in Space() } placements: { _, _ in [] }))
        case "Text": return dressing.dress(Text())
        case "Line": return dressing.dress(Line())
        case "Map": return dressing.dress(Map())
        case "Path": return dressing.dress(Path())
        case "Picker": return dressing.dress(Picker())
        case "Polygon": return dressing.dress(Polygon())
        case "Polyline": return dressing.dress(Polyline())
        case "ProgressBar": return dressing.dress(ProgressBar())
        case "Rectangle": return dressing.dress(Rectangle())
        case "Fill": return dressing.dress(Fill())
        case "ScrollView": return dressing.dress(ScrollView())
        case "SearchField": return dressing.dress(SearchField())
        case "Slider": return dressing.dress(Slider())
        case "Space": return dressing.dress(Space())
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
    public static func view(_ element: String, _ worn: [any Worn] = [], id: String = "specimen") -> AnyView {
        // Chosen by name, so held as `any View` and handed on as its node.
        let view: any View = make(element, Dressing(worn, id: id)) ?? Text("no specimen of \(element)")
        return AnyView(view)
    }

    /// The layout `layout` - a stack, a grid, a ZStack or a scroll view - holding `child`, wearing `worn`, found by
    /// the id "specimen"; words naming the layout for any other element, which the case finding it then fails on.
    public static func holding(_ layout: String, _ child: some View, _ worn: [any Worn] = []) -> AnyView {
        let dressing = Dressing(worn)
        let view: any View = switch layout {
        case "Grid": dressing.dress(Grid { child })
        case "HStack": dressing.dress(HStack { child })
        case "ScrollView": dressing.dress(ScrollView { child })
        case "VStack": dressing.dress(VStack { child })
        case "ZStack": dressing.dress(ZStack { child })
        case "LayoutEngine": dressing.dress(AnyView(Specimens.engine(holding: child)))
        default: Text("no layout \(layout) holding a child")
        }
        return AnyView(view)
    }

    /// A layout engine holding `child` across its whole room, as a ZStack holds a child naming no area.
    public static func engine(holding child: some View) -> some View {
        LayoutEngine([0]) { _ in child } placements: { room, _ in [Placement(room)] }
    }

    /// A page holding `element`'s specimen wearing `worn` where an application puts one, `beside` it on the page. A
    /// session finds it by the id "specimen", or - a span, an arrangement - as the one element of its kind
    /// (`Session.specimen(_:)`).
    public static func page(_ element: String, _ worn: [any Worn] = [], beside: [any View] = []) -> AnyView {
        // Chosen by name, so held as `any View` and handed on as its node.
        AnyView(chosen(element, worn, beside: beside))
    }

    /// The page `page(_:_:beside:)` shows, chosen by name.
    private static func chosen(_ element: String, _ worn: [any Worn], beside: [any View]) -> any View {
        let dressing = Dressing(worn)
        let others: [any View] = beside
        switch element {
        case "TextSpan":
            return VStack { Beside([Text().spans { dressing.wear(TextSpan("Some words")) }] + others) }
        case "MenuItem":
            return VStack {
                Beside([Text("Row").contextMenu { dressing.wear(MenuItem("Copy")).id(dressing.id) }.id("row")] + others)
            }
        case "ToolbarButton":
            return NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                DeclaringPage(beside: others, key: "\(worn)") { [dressing.wear(ToolbarButton("Save")).id(dressing.id)] }
            } destination: { _ in Text("Pushed") }
        case "NavigationStack":
            return dressing.wear(NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                VStack { Beside([Text("Root")] + others) }
            } destination: { _ in Text("Pushed") })
        case "SplitView":
            return dressing.wear(SplitView(State(wrappedValue: true).projectedValue) {
                Text("Sidebar")
            } detail: { VStack { Beside([Text("Detail")] + others) } })
        case "TabView":
            return dressing.wear(TabView([0, 1]) { tab in VStack { Beside([Text("Tab \(tab)")] + (tab == 0 ? others : [])) } })
        default:
            return VStack { Beside([view(element, worn)] + others) }
        }
    }

    /// Every element wearing `tier`, in the library's order.
    public static func wearing(_ tier: any Contract.Type) -> [String] {
        LibraryContracts.elements
            .filter { element in element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) } }
            .map { $0.nodeType.name }
    }
}

/// A page that writes its window's session - a title, a size - as it is made and again whenever what it writes
/// changes, over words and what stands beside them.
public struct WindowSessionPage: View {
    /// What stands beside its words.
    let beside: [any View]

    /// What it writes, said as words: a change in them writes the session again.
    let key: String

    /// What it writes.
    let write: @MainActor (WindowSession) -> Void

    @Environment(\.window) private var window

    /// A page writing its window's session as `write` says - again whenever `key` changes - `beside` its words.
    public init(beside: [any View] = [], key: String = "", _ write: @escaping @MainActor (WindowSession) -> Void) {
        self.beside = beside
        self.key = key
        self.write = write
    }

    public var body: some View {
        let (write, window) = (self.write, self.window)
        return VStack { Beside([Text("Page")] + beside) }
            .onCreated { write(window) }
            .onChanged(key) { write(window) }
    }
}

/// A page declaring a group of `items` for its bar - at `side`, in `order`, joining the group `group` names - and a
/// title view, over words and what stands beside them; built again whenever `key` changes or a state it reads is
/// written.
public struct DeclaringPage: View {
    /// What stands beside its words.
    let beside: [any View]

    /// What it declares, said as words: a change in them builds it again.
    let key: String

    /// The view it declares in its title's place; nil for none.
    let title: (any View)?

    /// Its items, each standing where its own placement says.
    let items: @MainActor () -> [ToolbarButton]

    /// A page declaring `items` and `title`, `beside` its words.
    public init(
        beside: [any View] = [], key: String = "", title: (any View)? = nil,
        _ items: @escaping @MainActor () -> [ToolbarButton] = { [] }
    ) {
        self.beside = beside
        self.key = key
        self.title = title
        self.items = items
    }

    public var body: some View {
        let (items, words) = (self.items, VStack { Beside([Text("Page")] + beside) })
        let declared = words.toolbar { items() }
        guard let title else { return declared }
        return declared.titleView { AnyView(title) }
    }
}

/// Views written as a list, beside the one a case dresses: what a page places in order, matched by their places.
@MainActor
struct Beside: Views {
    let nodes: [Node]

    init(_ views: [any View]) {
        nodes = views.map(\.node)
    }
}
