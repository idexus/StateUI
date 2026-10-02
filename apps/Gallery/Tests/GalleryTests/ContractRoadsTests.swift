// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// An element has ONE public road: its contract.
///
/// Every road the element contract replaced - a token and a list of values
/// where a member and its declared type now stand - and every element
/// withdrawn by decision is written here the way an application would have
/// written it, and must NOT compile against the library's public module; the
/// road through the contract, beside it, must.
/// The pair is what makes the refusal mean something: the two listings differ
/// in that one spelling, so a failure is the spelling's and never a typo's.
///
/// Compiled as an application compiles - a plain `import StateUI` - with the
/// compiler and the module the handbook's examples are checked against.
final class ContractRoadsTests: XCTestCase {
    /// A road taken away, and the contract's road to the same place.
    private struct Road {
        let name: String
        let removed: String
        let contract: String
    }

    /// An application's own control, acts and event - what every listing leans
    /// on, declared the way an application declares them.
    private static let declarations = """
        enum MarkerContract: ElementContract {
            static let nodeType: NodeType = "Maps.Marker"
            static let tiers: [any Contract.Type] = [ViewContract.self]

            static let title = ElementProperty<Self, String>("title")
            static let level = ElementProperty<Self, Double>("level")
            static let tapped = ElementEvent<Self, Int>("tapped")

            static let members: [any ContractMember] = [title, level, tapped]
        }

        struct Marker: ElementView {
            var node = Node(contract: MarkerContract.self)
        }

        enum NotesContract: ApplicationTier {
            static let name = "Notes"

            static let export = ElementAct<Self, String, String>("Notes.Export")
            static let log = ElementAct<Self, String, Void>("Notes.Log")
            static let changed = ElementEvent<Self, Bool>("Notes.Changed")

            static let members: [any ContractMember] = [export, log, changed]
        }
        """

    /// Each road the contract replaced, beside the contract's own.
    private static let roads = [
        Road(
            name: "a property set by its token",
            removed: #"_ = Text("Hi").setValue(Prop("fontSize"), .number(20))"#,
            contract: #"_ = Text("Hi").setValue(FontElementContract.fontSize, 20)"#),
        Road(
            name: "a property driven from a state by its token",
            removed: """
                @State var level = 0.5
                _ = Marker().setValue(Prop("level"), on: $level, mode: .inOut, kind: .property)
                """,
            contract: """
                @State var level = 0.5
                _ = Marker().setValue(MarkerContract.level, on: $level, mode: .inOut, kind: .property)
                """),
        Road(
            name: "an event heard by its token",
            removed: #"_ = Marker().onEvent(Event("tapped")) { payload in _ = payload }"#,
            contract: "_ = Marker().onEvent(MarkerContract.tapped) { index in _ = index }"),
        Road(
            name: "an act called by its token",
            removed: #"_ = try await stateUICall(Act("Notes.Export"), [.string("draft")])"#,
            contract: #"_ = try await stateUICall(NotesContract.export, "draft")"#),
        Road(
            name: "an act sent by its token",
            removed: #"stateUISend(Act("Notes.Log"), [.string("opened")])"#,
            contract: #"stateUISend(NotesContract.log, "opened")"#),
        Road(
            name: "an application's event heard by its token",
            removed: #"_ = HostEvents.on(Event("Notes.Changed")) { payload in _ = payload }"#,
            contract: "_ = HostEvents.on(NotesContract.changed) { online in _ = online }"),
        Road(
            name: "an aim's identity taken to aim by hand",
            removed: "_ = try Aim(TextField.self).target",
            contract: "try await Aim(TextField.self).call(VisualElementContract.unfocus)"),
        Road(
            name: "a node of a type named by hand",
            removed: #"_ = Node(type: "Maps.Marker")"#,
            contract: "_ = Node(contract: MarkerContract.self)"),
        Road(
            name: "a property written into a node by its token",
            removed: """
                var node = Node(contract: MarkerContract.self)
                node.props[Prop("title")] = .string("Harbour")
                _ = node
                """,
            contract: #"_ = Marker().setValue(MarkerContract.title, "Harbour")"#),
        Road(
            name: "a node's type written over",
            removed: """
                var node = Node(contract: MarkerContract.self)
                node.type = "Maps.Pin"
                _ = node
                """,
            contract: "_ = Node(contract: MarkerContract.self).type"),
        Road(
            name: "a handler put into a node by its token",
            removed: """
                var node = Node(contract: MarkerContract.self)
                node.events[Event("tapped")] = {}
                _ = node
                """,
            contract: "_ = Marker().onEvent(MarkerContract.tapped) { _ in }"),
        Road(
            name: "the withdrawn name ControlContract",
            removed: """
                enum LampContract: ControlContract {
                    static let nodeType: NodeType = "Test.Lamp"
                    static let members: [any ContractMember] = []
                }
                """,
            contract: """
                enum LampContract: ElementContract {
                    static let nodeType: NodeType = "Test.Lamp"
                    static let members: [any ContractMember] = []
                }
                """),
        Road(
            name: "the withdrawn SwipeView",
            removed: #"_ = SwipeView { Text("Row") }"#,
            contract: #"_ = Text("Row").onSwiped { _ in }"#),
        Road(
            name: "the withdrawn SwipeAction",
            removed: #"_ = SwipeAction("Delete")"#,
            contract: #"_ = MenuItem("Delete")"#),
        Road(
            name: "the withdrawn named store",
            removed: #"_ = PersistentStorage("Notes.Json")"#,
            contract: #"_ = PersistentKey("notes.draft", of: String.self)"#),
        Road(
            name: "the withdrawn RefreshView",
            removed: #"_ = RefreshView { ScrollView { Text("Rows") } }"#,
            contract: #"_ = ScrollView { Text("Rows") }"#),
        Road(
            name: "a button's withdrawn borderColor",
            removed: ##"_ = Button("Save").borderColor(Color("#888888"))"##,
            contract: ##"_ = Button("Save").stroke(Color("#888888"))"##),
        Road(
            name: "a button's withdrawn borderWidth",
            removed: #"_ = Button("Save").borderWidth(1)"#,
            contract: #"_ = Button("Save").strokeWidth(1)"#),
        Road(
            name: "a button's withdrawn cornerRadius",
            removed: #"_ = Button("Save").cornerRadius(8)"#,
            contract: #"_ = Button("Save").shape(.roundedRectangle(8))"#),
        Road(
            name: "the withdrawn style of the composed PositionIndicator",
            removed: "_ = Style<PositionIndicator>().selectedIndicatorColor(.red)",
            contract: "_ = PositionIndicator().selectedIndicatorColor(.red)"),
        Road(
            name: "the withdrawn PositionIndicatorContract",
            removed: "_ = PositionIndicator().setValue(PositionIndicatorContract.count, 3)",
            contract: "_ = PositionIndicator().count(3)"),
        Road(
            name: "the withdrawn Border",
            removed: ##"_ = Border { Text("Card") }.stroke(Color("#888888"))"##,
            contract: ##"_ = ZStack { Text("Card") }.shape(.roundedRectangle(8)).stroke(Color("#888888"))"##),
        Road(
            name: "the withdrawn AbsoluteLayout",
            removed: #"_ = AbsoluteLayout { Text("Corner") }"#,
            contract: #"_ = ZStack { Text("Corner") }"#),
        Road(
            name: "the withdrawn absolute bounds",
            removed: #"_ = Text("Corner").absoluteLayoutBounds(Rect(0, 0, 120, 40))"#,
            contract: #"_ = Text("Corner").area(.absolute(0, 0, 120, 40))"#),
        Road(
            name: "the withdrawn proportions",
            removed: #"_ = Text("Half").absoluteLayoutProportions(.all)"#,
            contract: #"_ = Text("Half").area(.proportional(0.5, 0, 0.5, 1))"#),
        Road(
            name: "a visual state by a name of the author's own",
            removed: #"_ = Button("Save").visualState(VisualState("Hovered")) { $0.opacity(0.5) }"#,
            contract: #"_ = Button("Save").visualState(.pointerOver) { $0.opacity(0.5) }"#),
        Road(
            name: "the window's one overlay",
            removed: "WindowSession().overlay = nil",
            contract: #"_ = Text("Notes").overlays { Text("Offline") }"#),
        Road(
            name: "a window's overlays kept by key in its session",
            removed: #"WindowSession().overlays[OverlayKey("notice")] = nil"#,
            contract: #"_ = Text("Notes").overlays { Text("Offline") }"#),
        Road(
            name: "a window's modal stack written into its session",
            removed: #"WindowSession().modalStack = nil"#,
            contract: #"_ = ModalStack(State(wrappedValue: [Int]()).projectedValue) { Text("Home") } destination: { _ in Text("Sheet") }"#),
        Road(
            name: "an action standing in a stack",
            removed: #"_ = VStack { ToolbarItem("Save") }"#,
            contract: #"_ = VStack { Text("Notes") }.toolbar { ToolbarItem("Save") }"#),
        Road(
            name: "an arrangement of pages standing in a stack",
            removed: #"_ = VStack { NavigationStack(State(wrappedValue: [Int]()).projectedValue) { Text("Home") } destination: { _ in Text("Next") } }"#,
            contract: #"_ = NavigationStack(State(wrappedValue: [Int]()).projectedValue) { VStack { Text("Home") } } destination: { _ in Text("Next") }"#),
        Road(
            name: "a run of text standing in a stack",
            removed: #"_ = VStack { TextSpan("Hi") }"#,
            contract: #"_ = VStack { Text().spans { TextSpan("Hi") } }"#),
        Road(
            name: "a page position that may show no page",
            removed: "struct Lone: Window { var page: any Page { if Bool.random() { Text(\"a\") } } }",
            contract: "struct Lone: Window { var page: any Page { if Bool.random() { Text(\"a\") } else { Text(\"b\") } } }"),
        Road(
            name: "a composed view's content as an existential",
            removed: "struct Old: View { var content: any View { Text(\"a\") } }",
            contract: "struct New: View { var body: some View { Text(\"a\") } }"),
        Road(
            name: "two views in the title's place",
            removed: #"_ = Text("Notes").titleView { Button("Back"); Button("Next") }"#,
            contract: #"_ = Text("Notes").titleView { HStack { Button("Back"); Button("Next") } }"#),
        Road(
            name: "two views as a composed view's content",
            removed: "struct Pair: View { var body: some View { Text(\"a\"); Text(\"b\") } }",
            contract: "struct Pair: View { var body: some View { VStack { Text(\"a\"); Text(\"b\") } } }"),
        Road(
            name: "a view standing among a label's runs",
            removed: #"_ = Text().spans { Text("Hi") }"#,
            contract: #"_ = Text().spans { TextSpan("Hi") }"#),
        Road(
            name: "a view standing among a map's pins",
            removed: #"_ = Map(latitude: 52, longitude: 21, radiusMeters: 500).pins { Text("Castle") }"#,
            contract: #"_ = Map(latitude: 52, longitude: 21, radiusMeters: 500).pins { Pin("Castle") }"#),
        Road(
            name: "a window's title bar written into its session",
            removed: #"WindowSession().titleBar = nil"#,
            contract: #"_ = SplitView(State(wrappedValue: true).projectedValue) { Text("Menu") } detail: { Text("Home") }.barTitle("Notes")"#),
        Road(
            name: "the withdrawn TitleBar element",
            removed: #"_ = TitleBar("Notes").subtitle("Drafts")"#,
            contract: #"_ = ModalStack(State(wrappedValue: [Int]()).projectedValue) { Text("Home") } destination: { _ in Text("Sheet") }.barSubtitle("Drafts")"#),
        Road(
            name: "a title bar's withdrawn slot",
            removed: "_ = Node(contract: TrailingContentContract.self)",
            contract: #"_ = Text("Notes").toolbar { ToolbarItem("Account") }"#),
        Road(
            name: "a stack's own bar foreground",
            removed: "_ = NavigationStackContract.barForegroundColor",
            contract: "_ = BarElementContract.barForegroundColor"),
        Road(
            name: "a page's actions written into its session",
            removed: #"PageSession().toolbarItems = [ToolbarItem("Save")]"#,
            contract: #"_ = Text("Notes").toolbar { ToolbarItem("Save") }"#),
        Road(
            name: "a page's title view written into its session",
            removed: #"PageSession().titleView = Text("Search")"#,
            contract: #"_ = Text("Notes").titleView { Text("Search") }"#),
        Road(
            name: "a page's menus written into its session",
            removed: #"PageSession().menuBar = [Menu("File") { MenuItem("New") }]"#,
            contract: #"_ = Text("Notes").menuBar { Menu("File") { MenuItem("New") } }"#),
        Road(
            name: "a view standing on the menu bar",
            removed: #"_ = Text("Notes").menuBar { Text("File") }"#,
            contract: #"_ = Text("Notes").menuBar { Menu("File") { MenuItem("New") } }"#),
        Road(
            name: "a view standing in a menu",
            removed: #"_ = Menu("File") { Text("New") }"#,
            contract: #"_ = Menu("File") { MenuItem("New") }"#),
        Road(
            name: "an item's withdrawn priority",
            removed: #"_ = ToolbarItem("Save").priority(1)"#,
            contract: #"_ = Text("Notes").toolbar(order: 1) { ToolbarItem("Save") }"#),
        Road(
            name: "the withdrawn resting state",
            removed: "_ = RadioButton.restingVisualState",
            contract: "_ = VisualState<RadioButton>.unchecked"),
        Road(
            name: "a visual state's withdrawn group",
            removed: #"_ = Switch().visualState(.on, group: "Value") { $0.opacity(0.5) }"#,
            contract: "_ = Switch().visualState(.on) { $0.opacity(0.5) }"),
        Road(
            name: "the withdrawn unfocused state",
            removed: #"_ = Button("Save").visualState(.unfocused) { $0.opacity(0.5) }"#,
            contract: #"_ = Button("Save").visualState(.focused) { $0.opacity(1) }"#),
        Road(
            name: "the withdrawn selected state",
            removed: #"_ = Text("Row").visualState(.selected) { $0.opacity(0.5) }"#,
            contract: #"_ = Text("Row").visualState(.pointerOver) { $0.opacity(0.5) }"#),
        Road(
            name: "the host's withdrawn visual state report",
            removed: #"_ = Button("Save").onEvent(VisualElementContract.visualStateChanged) { _ in }"#,
            contract: #"_ = Button("Save").onVisualStateChanged { _ in }"#),
        Road(
            name: "the withdrawn VisualState node",
            removed: "_ = Node(contract: VisualStateContract.self)",
            contract: #"_ = Button("Save").visualState(.disabled) { $0.opacity(0.5) }"#),
        Road(
            name: "the withdrawn Setters node",
            removed: "_ = Node(contract: SettersContract.self)",
            contract: #"_ = Button("Save").visualState(.disabled) { $0.opacity(0.5) }"#),
        Road(
            name: "words shown as a Label",
            removed: #"_ = Label("Total")"#,
            contract: #"_ = Text("Total")"#),
        Road(
            name: "the Label contract",
            removed: "_ = LabelContract.maximumLines",
            contract: "_ = TextContract.maximumLines"),
        Road(
            name: "a view composed as a ContentView",
            removed: #"struct Card: ContentView { var content: some View { Text("Total") } }"#,
            contract: #"struct Card: View { var body: some View { Text("Total") } }"#),
    ]

    func testEveryUntypedRoadIsClosedAndItsContractRoadOpen() throws {
        guard let module = DocumentationExamplesTests.builtModuleDirectory() else {
            // Never a skip: a check that did not run reads as one that passed.
            return XCTFail("no StateUI.swiftmodule beside the test bundle - no road was checked")
        }
        let sdk = try DocumentationExamplesTests.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-roads-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // Every listing in a file of its own, a road's two side by side.
        let listings = Self.roads.flatMap { road in
            [(road: road.name, compiles: false, source: road.removed),
             (road: road.name, compiles: true, source: road.contract)]
        }
        let files = try listings.enumerated().map { index, listing in
            let file = scratch.appendingPathComponent("road_\(index).swift")
            try Data(Self.file(around: listing.source).utf8).write(to: file)
            return file
        }

        let outputs = Outputs(count: files.count)
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            outputs.set(index, DocumentationExamplesTests.typecheck(files[index], module: module, sdk: sdk))
        }

        for (index, listing) in listings.enumerated() {
            let output = outputs.value(index)

            if listing.compiles {
                XCTAssertNil(output, "\(listing.road): the contract's road does not compile:\n\(output ?? "")")
            } else {
                XCTAssertNotNil(output, "\(listing.road) compiles again - an element is reached "
                    + "through its contract, never beside it")
            }
        }
    }

    /// A listing as a file an application could hold: the declarations, and
    /// the listing as the body of a function.
    private static func file(around listing: String) -> String {
        let body = listing.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")

        return "import StateUI\n\n\(declarations)\n\nfunc road() async throws {\n\(body)\n}\n"
    }

    /// What the compiler said about each listing, written from the lanes.
    private final class Outputs: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String?]

        init(count: Int) {
            items = Array(repeating: nil, count: count)
        }

        func set(_ index: Int, _ output: String?) {
            lock.lock()
            defer { lock.unlock() }
            items[index] = output
        }

        func value(_ index: Int) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return items[index]
        }
    }
}
