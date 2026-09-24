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

        struct Marker: View {
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
            removed: #"_ = Label("Hi").setValue(Prop("fontSize"), .number(20))"#,
            contract: #"_ = Label("Hi").setValue(FontElementContract.fontSize, 20)"#),
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
            removed: #"_ = SwipeView { Label("Row") }"#,
            contract: #"_ = Label("Row").onSwiped { _ in }"#),
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
            removed: #"_ = RefreshView { ScrollView { Label("Rows") } }"#,
            contract: #"_ = ScrollView { Label("Rows") }"#),
        Road(
            name: "the withdrawn Border",
            removed: ##"_ = Border { Label("Card") }.stroke(Color("#888888"))"##,
            contract: ##"_ = ZStack { Label("Card") }.shape(.roundedRectangle(8)).stroke(Color("#888888"))"##),
        Road(
            name: "the withdrawn AbsoluteLayout",
            removed: #"_ = AbsoluteLayout { Label("Corner") }"#,
            contract: #"_ = ZStack { Label("Corner") }"#),
        Road(
            name: "the withdrawn absolute bounds",
            removed: #"_ = Label("Corner").absoluteLayoutBounds(Rect(0, 0, 120, 40))"#,
            contract: #"_ = Label("Corner").area(.absolute(0, 0, 120, 40))"#),
        Road(
            name: "the withdrawn proportions",
            removed: #"_ = Label("Half").absoluteLayoutProportions(.all)"#,
            contract: #"_ = Label("Half").area(.proportional(0.5, 0, 0.5, 1))"#),
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
