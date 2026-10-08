// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The roads the public API closes, each beside the one it offers.
///
/// A member is reached through its contract, never by a token and a list of
/// values; a view stands where a view stands, never among a text's runs or a
/// map's markers; a scene is made of windows, and an application of scenes. Each closed road is written here
/// the way an application would write it, and must NOT compile against the
/// library's public module; the open road beside it must. The pair is what makes
/// the refusal mean something: the two listings differ in that one spelling, so
/// a failure is the spelling's and never a typo's.
///
/// Compiled as an application compiles - a plain `import StateUI` - with the
/// compiler and the module the handbook's examples are checked against.
final class ContractRoadsTests: XCTestCase {
    /// A road the API closes, and the road it offers to the same place.
    private struct Road {
        let name: String
        let closed: String
        let open: String
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
            open: "try await Aim(TextField.self).call(VisualElementContract.unfocus)"),
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
            closed: #"_ = VStack { ToolbarItem("Save") }"#,
            open: #"_ = VStack { Text("Notes") }.toolbar { ToolbarItem("Save") }"#),
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
            closed: #"_ = Map(latitude: 52, longitude: 21, radiusMeters: 500).markers { Text("Castle") }"#,
            open: #"_ = Map(latitude: 52, longitude: 21, radiusMeters: 500).markers { Marker("Castle") }"#),
        Road(
            name: "a view standing on the menu bar",
            closed: #"_ = Text("Notes").menuBar { Text("File") }"#,
            open: #"_ = Text("Notes").menuBar { Menu("File") { MenuItem("New") } }"#),
        Road(
            name: "a view standing in a menu",
            closed: #"_ = Menu("File") { Text("New") }"#,
            open: #"_ = Menu("File") { MenuItem("New") }"#),
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
            [(road: road.name, compiles: false, source: road.closed),
             (road: road.name, compiles: true, source: road.open)]
        }
        let files = try listings.enumerated().map { index, listing in
            let file = scratch.appendingPathComponent("road_\(index).swift")
            try Data(Self.file(around: listing.source).utf8).write(to: file)
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

    /// A listing as a file an application could hold: the declarations, and
    /// the listing as the body of a function.
    private static func file(around listing: String) -> String {
        let body = listing.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")

        return "import StateUI\n\n\(declarations)\n\nfunc road() async throws {\n\(body)\n}\n"
    }
}
