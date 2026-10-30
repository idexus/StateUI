// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The roads the public API closes, each beside the one it offers.
///
/// A member is reached through its contract, never by a token and a list of
/// values; a view stands where a view stands, never among a text's runs or a
/// map's markers; a scene is made of windows, and an application of scenes; a
/// modifier is offered only where it can be honored. Each closed road is written here
/// the way an application would write it, and must NOT compile against the
/// library's public module; the open road beside it must. The pair is what makes
/// the refusal mean something: the two listings differ in that one spelling, so
/// a failure is the spelling's and never a typo's.
///
/// Compiled as an application compiles - a plain `import StateUI` - with the
/// compiler and the module the handbook's examples are checked against; a
/// road a host takes, as its registrations do, with `@_spi(Host)`.
@MainActor
final class ContractRoadsTests: XCTestCase {
    /// A road the API closes, and the road it offers to the same place.
    private struct Road {
        let name: String
        let closed: String
        let open: String
        var host = false
    }

    /// An application's own control, acts and event - what every listing leans
    /// on, declared the way an application declares them.
    private static let declarations = """
        enum BeaconContract: ElementContract {
            static let nodeType: NodeType = "Maps.Beacon"
            static let tiers: [any Contract.Type] = [ViewContract.self]

            static let title = ElementProperty<Self, String>("title")
            static let level = ElementProperty<Self, Double>("level")
            static let tapped = ElementEvent<Self, Int>("tapped")

            static let members: [any ContractMember] = [title, level, tapped]
        }

        struct Beacon: ElementView {
            var node = Node(contract: BeaconContract.self)
        }

        enum NotesContract: ApplicationTier {
            static let name = "Notes"

            static let export = ElementAct<Self, String, String>("Notes.Export")
            static let log = ElementAct<Self, String, Void>("Notes.Log")
            static let changed = ElementEvent<Self, Bool>("Notes.Changed")

            static let members: [any ContractMember] = [export, log, changed]
        }
        """

    /// Each road the API closes, beside the one it offers.
    private static let roads = [
        Road(
            name: "a property set by its token",
            closed: #"_ = Text("Hi").setValue(Prop("fontSize"), .number(20))"#,
            open: #"_ = Text("Hi").setValue(FontElementContract.fontSize, 20)"#),
        Road(
            name: "a property driven from a state by its token",
            closed: """
                @State var level = 0.5
                _ = Beacon().setValue(Prop("level"), on: $level, mode: .inOut, kind: .property)
                """,
            open: """
                @State var level = 0.5
                _ = Beacon().setValue(BeaconContract.level, on: $level, mode: .inOut, kind: .property)
                """),
        Road(
            name: "text from a state through a door for numbers",
            closed: """
                @State var title = "Harbour"
                _ = Beacon().setValue(BeaconContract.title, on: $title, mode: .out, kind: .plain)
                """,
            open: """
                @State var title = "Harbour"
                _ = Beacon().setValue(BeaconContract.title, on: $title, mode: .out)
                """),
        Road(
            name: "an event heard by its token",
            closed: #"_ = Beacon().onEvent(Event("tapped")) { payload in _ = payload }"#,
            open: "_ = Beacon().onEvent(BeaconContract.tapped) { index in _ = index }"),
        Road(
            name: "an act called by its token",
            closed: #"_ = try await stateUICall(Act("Notes.Export"), [.string("draft")])"#,
            open: #"_ = try await stateUICall(NotesContract.export, "draft")"#),
        Road(
            name: "an act sent by its token",
            closed: #"stateUISend(Act("Notes.Log"), [.string("opened")])"#,
            open: #"stateUISend(NotesContract.log, "opened")"#),
        Road(
            name: "an application's event heard by its token",
            closed: #"_ = HostEvents.on(Event("Notes.Changed")) { payload in _ = payload }"#,
            open: "_ = HostEvents.on(NotesContract.changed) { online in _ = online }"),
        Road(
            name: "an aim's identity taken to aim by hand",
            closed: "_ = try Aim(TextField.self).target",
            open: "try await Aim(TextField.self).call(FocusElementContract.unfocus)"),
        Road(
            name: "a list scrolled to an identity of another type",
            closed: #"try await Aim(ItemsView<Int>.self).scrollTo("500")"#,
            open: "try await Aim(ItemsView<Int>.self).scrollTo(500)"),
        Road(
            name: "a fact of the host's written by the application",
            closed: "Device().battery.chargeLevel = 1",
            open: "_ = Device(battery: Battery(chargeLevel: 1)).battery.chargeLevel"),
        Road(
            name: "a provided object replaced from below",
            closed: "Environment<ApplicationSession>().projectedValue.wrappedValue = ApplicationSession()",
            open: "_ = Environment<ApplicationSession>().projectedValue.motion"),
        Road(
            name: "a style asked for by a name as words",
            closed: #"_ = Text("x").style("Headline")"#,
            open: #"_ = Text("x").style(StyleKey<Text>("Headline"))"#),
        Road(
            name: "a style key of another control",
            closed: #"_ = Text("x").style(StyleKey<Button>("Cta"))"#,
            open: #"_ = Button("x").style(StyleKey<Button>("Cta"))"#),
        Road(
            name: "a node of a type named by hand",
            closed: #"_ = Node(type: "Maps.Beacon")"#,
            open: "_ = Node(contract: BeaconContract.self)"),
        Road(
            name: "a property written into a node by its token",
            closed: """
                var node = Node(contract: BeaconContract.self)
                node.props[Prop("title")] = .string("Harbour")
                _ = node
                """,
            open: #"_ = Beacon().setValue(BeaconContract.title, "Harbour")"#),
        Road(
            name: "a node's type written over",
            closed: """
                var node = Node(contract: BeaconContract.self)
                node.type = "Maps.Marker"
                _ = node
                """,
            open: "_ = Node(contract: BeaconContract.self).type"),
        Road(
            name: "a handler put into a node by its token",
            closed: """
                var node = Node(contract: BeaconContract.self)
                node.events[Event("tapped")] = {}
                _ = node
                """,
            open: "_ = Beacon().onEvent(BeaconContract.tapped) { _ in }"),
        Road(
            name: "a visual state by a name of the author's own",
            closed: #"_ = Button("Save").visualState(VisualState("Hovered")) { $0.opacity(0.5) }"#,
            open: #"_ = Button("Save").visualState(.pointerOver) { $0.opacity(0.5) }"#),
        Road(
            name: "an action standing in a stack",
            closed: #"_ = VStack { ToolbarButton("Save") }"#,
            open: #"_ = VStack { Text("Notes") }.toolbar { ToolbarButton("Save") }"#),
        Road(
            name: "a group inside a group",
            closed: #"_ = Text("Notes").toolbar { ToolbarGroup { ToolbarGroup { ToolbarButton("Bold") } } }"#,
            open: #"_ = Text("Notes").toolbar { ToolbarGroup { ToolbarButton("Bold") } }"#),
        Road(
            name: "a run of text standing in a stack",
            closed: #"_ = VStack { TextSpan("Hi") }"#,
            open: #"_ = VStack { Text().spans { TextSpan("Hi") } }"#),
        Road(
            name: "a window that may show nothing",
            closed: "struct Lone: Scene { var body: some Scene { WindowGroup { if Bool.random() { Text(\"a\") } } } }",
            open: "struct Lone: Scene { var body: some Scene { WindowGroup { if Bool.random() { Text(\"a\") } else { Text(\"b\") } } } }"),
        Road(
            name: "a view standing among a scene's windows",
            closed: "struct Notes: Scene { var body: some Scene { WindowGroup { Text(\"a\") }; Text(\"b\") } }",
            open: "struct Notes: Scene { var body: some Scene { WindowGroup { Text(\"a\") }; Window(.debugInspector) { Text(\"b\") } } }"),
        Road(
            name: "a scene standing in a scene",
            closed: "struct Tools: Scene { var body: some Scene { Window(.debugInspector) { Text(\"a\") } } }; struct Notes: Scene { var body: some Scene { Tools() } }",
            open: "struct Tools: Scene { var body: some Scene { Window(.debugInspector) { Text(\"a\") } } }; struct Notes: Application { var body: some Scene { Tools() } }"),
        Road(
            name: "a view standing among an application's scenes",
            closed: "struct Notes: Application { var body: some Scene { WindowGroup { Text(\"a\") }; Text(\"b\") } }",
            open: "struct Notes: Application { var body: some Scene { WindowGroup { Text(\"a\") }; Window(.debugInspector) { Text(\"b\") } } }"),
        Road(
            name: "two views in the title's place",
            closed: #"_ = Text("Notes").titleView { Button("Back"); Button("Next") }"#,
            open: #"_ = Text("Notes").titleView { HStack { Button("Back"); Button("Next") } }"#),
        Road(
            name: "two views as a composed view's content",
            closed: "struct Pair: View { var body: some View { Text(\"a\"); Text(\"b\") } }",
            open: "struct Pair: View { var body: some View { VStack { Text(\"a\"); Text(\"b\") } } }"),
        Road(
            name: "a view standing among a label's runs",
            closed: #"_ = Text().spans { Text("Hi") }"#,
            open: #"_ = Text().spans { TextSpan("Hi") }"#),
        Road(
            name: "a view standing among a map's markers",
            closed: #"_ = Map(region: MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: 500)).markers { Text("Castle") }"#,
            open: #"_ = Map(region: MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: 500)).markers { Marker(at: Location(latitude: 52, longitude: 21)) }"#),
        Road(
            name: "a tab selection of another type than the tabs",
            closed: #"_ = TabView([1, 2], selection: Binding<String>.Proxy(get: { "a" }, set: { _ in })) { Text("\($0)") }"#,
            open: #"_ = TabView([1, 2], selection: Binding<Int>.Proxy(get: { 1 }, set: { _ in })) { Text("\($0)") }"#),
        Road(
            name: "a view standing on the menu bar",
            closed: #"_ = Text("Notes").menuBar { Text("File") }"#,
            open: #"_ = Text("Notes").menuBar { Menu("File") { MenuItem("New") } }"#),
        Road(
            name: "a view standing in a menu",
            closed: #"_ = Menu("File") { Text("New") }"#,
            open: #"_ = Menu("File") { MenuItem("New") }"#),
        Road(
            name: "keys taken by a view that never holds the keyboard",
            closed: #"_ = Text("Row").onKeyPressed(.upArrow) { _ in }"#,
            open: #"_ = VStack { Text("Row") }.onKeyPressed(.upArrow) { _ in }"#),
        Road(
            name: "the keyboard heard on a view that never takes it",
            closed: """
                @State var focused = false
                _ = Text("Name").isFocused($focused)
                """,
            open: """
                @State var focused = false
                _ = TextField("Name").isFocused($focused)
                """),
        Road(
            name: "the keyboard put on a view that never takes it",
            closed: "_ = try await Aim(Text.self).focus()",
            open: "_ = try await Aim(TextField.self).focus()"),
        Road(
            name: "a fill inside a line",
            closed: "_ = Line().x2(40).fill(.red)",
            open: "_ = Polyline([Point(0, 0), Point(40, 0)]).fill(.red)"),
        Road(
            name: "a corner's join on an ellipse",
            closed: "_ = Ellipse().lineJoin(.round)",
            open: "_ = Rectangle().lineJoin(.round)"),
        Road(
            name: "a line's height on a run of text",
            closed: #"_ = Text().spans { TextSpan("Hi").lineHeight(1.2) }"#,
            open: #"_ = Text().spans { TextSpan("Hi") }.lineHeight(1.2)"#),
        Road(
            name: "a name for automation on a run of text",
            closed: #"_ = Text().spans { TextSpan("Hi").accessibilityIdentifier("greeting") }"#,
            open: #"_ = Text().spans { TextSpan("Hi") }.accessibilityIdentifier("greeting")"#),
        Road(
            name: "a name for automation on a style",
            closed: #"_ = Style<Button>().accessibilityIdentifier("save")"#,
            open: #"_ = Button("Save").accessibilityIdentifier("save")"#),
        Road(
            name: "a field's words aligned down its box",
            closed: #"_ = TextField("Name").verticalTextAlignment(.center)"#,
            open: #"_ = Text("Name").verticalTextAlignment(.center)"#),
        Road(
            name: "the letters of a field's words spaced",
            closed: #"_ = TextField("Name").tracking(1)"#,
            open: #"_ = Text("Name").tracking(1)"#),
        Road(
            name: "an accent on a search field",
            closed: #"_ = SearchField("Name").tint(.red)"#,
            open: #"_ = CheckBox(true).tint(.red)"#),
        Road(
            name: "an outline around a check box",
            closed: #"_ = CheckBox(true).text("Small").stroke(.gray)"#,
            open: #"_ = Button("Small").stroke(.gray)"#),
        Road(
            name: "a stack's line in a menu",
            closed: #"_ = Menu("File") { MenuItem("New"); Separator() }"#,
            open: #"_ = Menu("File") { MenuItem("New"); MenuSeparator() }"#),
        Road(
            name: "a menu's separator in a stack",
            closed: "_ = VStack { MenuSeparator() }",
            open: "_ = VStack { Separator() }"),
        Road(
            name: "an event among the properties a view takes together",
            closed: """
                final class Lamp {}
                Registry<Lamp>().add(BeaconContract.self, create: { _ in Lamp() }) { beacon in
                    beacon.applies(BeaconContract.title, BeaconContract.tapped) { _, _ in }
                }
                """,
            open: """
                final class Lamp {}
                Registry<Lamp>().add(BeaconContract.self, create: { _ in Lamp() }) { beacon in
                    beacon.applies(BeaconContract.title, BeaconContract.level) { _, _ in }
                }
                """,
            host: true),
        Road(
            name: "an event in a list of properties",
            closed: "_ = PropertyList(BeaconContract.title, BeaconContract.tapped)",
            open: "_ = PropertyList(BeaconContract.title, BeaconContract.level)",
            host: true),
        Road(
            name: "an act among a child's events",
            closed: """
                final class Lamp {}
                Registry<Lamp>().add(BeaconContract.self, create: { _ in Lamp() }) { beacon in
                    beacon.children(BeaconContract.self, events: NotesContract.export) { _, _ in }
                }
                """,
            open: """
                final class Lamp {}
                Registry<Lamp>().add(BeaconContract.self, create: { _ in Lamp() }) { beacon in
                    beacon.children(BeaconContract.self, events: BeaconContract.tapped) { _, _ in }
                }
                """,
            host: true),
        Road(
            name: "a property's key made from its name",
            closed: #"_ = Prop("fontSize")"#,
            open: "_ = FontElementContract.fontSize"),
        Road(
            name: "an event's key made from its name",
            closed: #"_ = Event("tapped")"#,
            open: "_ = BeaconContract.tapped"),
        Road(
            name: "an act's key made from its name",
            closed: #"_ = Act("Notes.Export")"#,
            open: "_ = NotesContract.export"),
        Road(
            name: "a type of an application's own taken as properties",
            closed: "struct Lamps: AppliedProperties {}",
            open: "struct Lamps {}"),
        Road(
            name: "a part of a state followed by an engine",
            closed: """
                struct Room { var width = 0.0 }
                @State var room = Room()
                _ = Text("x").engine(following: $room.width) { _ in }
                """,
            open: """
                @State var width = 0.0
                _ = Text("x").engine(following: $width) { _ in }
                """),
        Road(
            name: "a part of a state followed by a motion layout",
            closed: """
                struct Room { var width = 0.0 }
                @State var phase = 0.0
                @State var room = Room()
                _ = MotionLayout([1], parameters: $phase) { Text("\\($0)") } placements: { _, _ in [] }
                    .following($room.width)
                """,
            open: """
                @State var phase = 0.0
                @State var width = 0.0
                _ = MotionLayout([1], parameters: $phase) { Text("\\($0)") } placements: { _, _ in [] }
                    .following($width)
                """),
        Road(
            name: "a part of a state on a journey",
            closed: """
                @State var levels = [0.2, 0.5]
                _ = $levels[1].journey
                """,
            open: """
                @State var level = 0.5
                _ = $level.journey
                """),
        Road(
            name: "a part of a state driving a property",
            closed: """
                struct Room { var width = 0.0 }
                @State var room = Room()
                _ = Text("x").minimumWidth($room.width)
                """,
            open: """
                @State var width = 0.0
                _ = Text("x").minimumWidth($width)
                """),
        Road(
            name: "a part of a state converted",
            closed: """
                struct Room { var width = 0.0 }
                @State var room = Room()
                _ = $room.width.convert { $0 * 2 }
                """,
            open: """
                @State var width = 0.0
                _ = $width.convert { $0 * 2 }
                """),
        Road(
            name: "a part of a state lent to a child borrowing a whole state",
            closed: """
                struct Room { var name = "" }
                struct NameRow: View {
                    @Binding var name: String
                    var body: some View { TextField($name) }
                }
                @State var room = Room()
                _ = NameRow(name: $room.name)
                """,
            open: """
                struct Room { var name = "" }
                struct NameRow: View {
                    @Binding.Proxy var name: String
                    var body: some View { TextField($name) }
                }
                @State var room = Room()
                _ = NameRow(name: $room.name)
                """),
        Road(
            name: "closures taken for a whole state",
            closed: "_ = Slider(Binding(get: { 0.5 }, set: { _ in }))",
            open: "_ = Slider(Binding.Proxy(get: { 0.5 }, set: { _ in }))"),
    ]

    /// Each closed road fails to compile, and the open road beside it compiles.
    func testEveryClosedRoadIsClosedAndItsOpenRoadOpen() throws {
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
            [(road: road.name, compiles: false, source: road.closed, host: road.host),
             (road: road.name, compiles: true, source: road.open, host: road.host)]
        }
        let files = try listings.enumerated().map { index, listing in
            let file = scratch.appendingPathComponent("road_\(index).swift")
            try Data(Self.file(around: listing.source, host: listing.host).utf8).write(to: file)
            return file
        }

        let outputs = CompilerOutputs(count: files.count)
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

    /// A listing as a file an application could hold - or a host, which imports the library's host side: the
    /// declarations, and the listing as the body of a function.
    private static func file(around listing: String, host: Bool) -> String {
        let body = listing.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")

        let library = host ? "@_spi(Host) import StateUI" : "import StateUI"
        return "\(library)\n\n\(declarations)\n\n@MainActor func road() async throws {\n\(body)\n}\n"
    }
}
