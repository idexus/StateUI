// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The public API is recorded: every public declaration of `StateUI`, a line each, in two records -
/// `lib/StateUI/exports/api/StateUI.txt`, what an application writes, and `StateUI.extending.txt`, what an author
/// adding an element, a value or an application's acts writes - which `STATEUI_UPDATE_EXPORTS=1` writes.
/// Design: docs/design/architecture.md#the-public-surface
final class APISurfaceTests: XCTestCase {
    /// The record of what an application writes.
    private static let record = SourceTree.repository.appendingPathComponent("lib/StateUI/exports/api/StateUI.txt")

    /// The record of what an author extending StateUI writes.
    private static let extendingRecord = SourceTree.repository.appendingPathComponent(
        "lib/StateUI/exports/api/StateUI.extending.txt")

    /// Both records' lines.
    static func recorded() throws -> String {
        try String(contentsOf: record, encoding: .utf8) + String(contentsOf: extendingRecord, encoding: .utf8)
    }

    /// Every record's lines: StateUI's two, and each module a host's script records - its facade, a backend, the
    /// testing module.
    static func everyRecorded() throws -> String {
        let folder = record.deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".txt") }.sorted()
            .map { try String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n")
    }

    /// The types an author extending StateUI writes with, every member with them: a contract and its members, a
    /// node, the values a host is handed, a value of a state's own, and an application's acts and events.
    /// Design: docs/design/architecture.md#two-surfaces
    static let extendingTypes: Set<String> = [
        "ApplicationTier", "Contract", "ContractMember", "ControlValues", "ElementAct", "ControlChild",
        "ControlReports", "ElementContract", "ElementEvent", "ElementLayer", "ElementProperty", "HostEventSubscription",
        "HostEvents", "HostRepresentable", "ItemsEntries", "LaneKind", "LaneValue", "Name", "Node", "NodeType",
        "PropValue", "StateCarried", "StateChoice", "StatePassage", "StateValue", "Walked",
        // Values only a contract's member, a host or a kept value's store takes.
        "CornerRadius", "KeyboardShortcut", "PersistentKind", "SelectionMode", "WebViewSource",
    ]

    /// The members an author extending StateUI writes, on whatever type they stand: a view's own node, its values
    /// and handlers by contract member, a value's conversions and wire codes, what a kept value is handed to the
    /// store as, and what a contract declares of its element.
    static let extendingMembers: Set<String> = [
        "carried", "init(carried:)", "init(propValue:)", "laneKind", "lanes", "list(from:)", "modified", "moving",
        "node", "nodes", "onEvent", "onHostEvent", "propValue", "setValue",
        "rawValue", "init(rawValue:)", "persistentKind", "persistentValue", "init(persistentValue:)",
        "nodeType", "layer", "tiers", "members",
        "Aim.call", "ApplicationSession.call", "ApplicationSession.tell", "@SwiftArray.value",
        "ApplicationContract.persistValue", "ApplicationContract.persistSceneValue",
    ]

    /// Whether a protocol's declaration is the extending surface's: a control's property half, a tier's, or what
    /// a control and a style wear - whose members, the modifiers, are an application's.
    static func isExtendingProtocol(_ name: String) -> Bool {
        name.hasSuffix("Properties") || name.hasSuffix("Element")
            || ["ElementView", "PropertyContainer", "StyleTarget"].contains(name)
    }

    /// Splits the surface's lines into what an application writes and what an author extending StateUI does.
    static func split(_ lines: [String]) -> (application: [String], extending: [String]) {
        var protocols: Set<String> = []
        for line in lines where line.hasPrefix("swift.protocol ") {
            let name = line.dropFirst("swift.protocol ".count).prefix { $0 != ":" }
            if isExtendingProtocol(String(name)) { protocols.insert(String(name)) }
        }

        var application: [String] = [], extending: [String] = []
        for line in lines {
            let fields = line.split(separator: " ", maxSplits: 2)
            let kind = fields[0], path = fields[1].hasSuffix(":") ? fields[1].dropLast() : fields[1]
            let owner = String(path.prefix { $0 != "." }), member = path.dropFirst(owner.count).dropFirst()
            // A nested type's member is named by its own last step: `Thickness.init(propValue:)` is `init(propValue:)`.
            let call = member.prefix { $0 != "(" }
            let named = member.contains("(") ? member.dropFirst(call.lastIndex(of: ".").map { call.distance(
                from: call.startIndex, to: $0) + 1 } ?? 0) : member.split(separator: ".").last ?? ""
            let bare = String(named.prefix { $0 != "(" })
            let isExtending: Bool
            if kind == "swift.conformance" {
                let target = line.components(separatedBy: ": StateUI.").dropFirst().first?.prefix { $0 != " " }
                isExtending = extendingTypes.contains(owner) || target.map {
                    extendingTypes.contains(String($0)) || protocols.contains(String($0))
                } ?? false
            } else if member.isEmpty {
                isExtending = extendingTypes.contains(owner) || protocols.contains(owner)
            } else {
                isExtending = extendingTypes.contains(owner) || extendingMembers.contains(String(named))
                    || extendingMembers.contains(bare) || extendingMembers.contains("\(owner).\(bare)")
            }
            if isExtending { extending.append(line) } else { application.append(line) }
        }
        return (application, extending)
    }

    /// A contract member's documentation sends the reader to the API that uses it - `See `Clipboard.read()``: every
    /// such name is a declaration the record holds, so a renamed one cannot leave the pointer behind.
    func testEveryContractsSeeNamesARecordedDeclaration() throws {
        let record = try Self.recorded()
        let named = try NSRegularExpression(pattern: #"`([A-Z][A-Za-z]*\.[a-z][A-Za-z]*\([A-Za-z_:]*\))`"#)
        var missing: [String] = []

        for (path, text) in try SourceTree.allSources() where path.contains("Contracts/") {
            for line in text.split(separator: "\n") where line.contains("/// See `") {
                let line = String(line)
                for match in named.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    guard let range = Range(match.range(at: 1), in: line) else { continue }
                    let name = String(line[range])
                    if !record.contains(" \(name): ") { missing.append("\(path): \(name)") }
                }
            }
        }

        XCTAssertEqual(missing, [], "a See names a declaration the API record holds")
    }

    /// The handbook names every public type of every record - README and docs/, the design notes left out: what
    /// 1.0 freezes is what the handbook promised, so a type no page names is a promise nobody made.
    func testTheHandbookNamesEveryPublicType() throws {
        let declared = try Self.everyRecorded().split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(separator: " ", maxSplits: 2)
            guard fields.count > 1, ["swift.struct", "swift.class", "swift.enum", "swift.protocol", "swift.typealias"]
                .contains(String(fields[0])), fields[1].hasSuffix(":"), !fields[1].contains(".") else { return nil }
            return String(fields[1].dropLast())
        }
        let docs = SourceTree.repository.appendingPathComponent("docs")
        var handbook = try String(contentsOf: SourceTree.repository.appendingPathComponent("README.md"), encoding: .utf8)
        for page in try SourceTree.files(under: docs, entering: { $0 != "design" }) where page.hasSuffix(".md") {
            handbook += try String(contentsOf: docs.appendingPathComponent(page), encoding: .utf8)
        }
        let words = Set(handbook.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))

        XCTAssertGreaterThan(declared.count, 300, "the records hold almost no type")
        XCTAssertEqual(Set(declared).subtracting(words).sorted(), [], "public types no handbook page names")
    }

    /// What an application writes names no value as a host is handed it and no existential but the key paths the
    /// language asks for: a wire code, a conversion, a contract's own declaration of its element stand on the
    /// extending surface.
    func testTheApplicationSurfaceNamesNoHostValue() throws {
        let application = try String(contentsOf: Self.record, encoding: .utf8).split(separator: "\n")
        let offenders = application.filter { line in
            line.contains("PropValue") || line.replacing(/any (Reference)?WritableKeyPath/, with: "").contains(" any ")
        }

        XCTAssertGreaterThan(application.count, 5_000, "the record holds almost nothing")
        XCTAssertEqual(offenders.map(String.init), [], "an application's surface names a host's value")
    }

    /// An initializer the handbook spells in its text with labels - `WindowGroup(.kind) { $value in … }`, not a
    /// label the type never had - is one the records declare with those labels: the prose is not compiled, so this
    /// holds what a reader copies out of it.
    func testTheHandbookSpellsInitializersWithTheirLabels() throws {
        let record = try Self.recorded()
        var labels: [String: [Set<String>]] = [:]
        for found in record.matches(of: /swift\.init (?:\w+\.)*(\w+)\.init\(([^)]*)\):/) {
            let named = Set(found.2.split(separator: ":").map(String.init).filter { $0 != "_" })
            labels[String(found.1), default: []].append(named)
        }
        let root = SourceTree.repository
        let handbook = try SourceTree.files(under: root, entering: { relative in
            SourceTree.entersSources(relative) && !["node_modules", "exports", "artifacts", "design", "internals"]
                .contains(relative.split(separator: "/").last.map(String.init) ?? "")
        }).filter { $0.hasSuffix(".md") && ($0.hasPrefix("docs/") || $0 == "README.md") }
        var unknown: [String] = []

        for document in handbook {
            let text = try String(contentsOf: root.appendingPathComponent(document), encoding: .utf8)
            for span in text.matches(of: /`([^`\n]+)`/) {
                for call in span.1.matches(of: /(?:^|[^\w.])([A-Z]\w*)\(([^()]*)\)/) {
                    let written = Set(call.2.matches(of: /(?:^|[,(]\s*)([a-z]\w*):/).map { String($0.1) })
                    guard !written.isEmpty, let declared = labels[String(call.1)] else { continue }
                    if !declared.contains(where: { written.isSubset(of: $0) }) { unknown.append("\(document): \(span.1)") }
                }
            }
        }

        XCTAssertGreaterThan(handbook.count, 20, "the walk read almost no page")
        XCTAssertEqual(unknown, [], "the handbook spells an initializer with a label it does not have")
    }

    /// A style carries values and states alone: no modifier of `Styling` takes a binding, which the sheet could not
    /// carry and would drop without a word.
    func testAStyleTakesNoState() throws {
        let styling = try String(contentsOf: Self.record, encoding: .utf8).split(separator: "\n")
            .filter { $0.hasPrefix("swift.method Styling.") }

        XCTAssertGreaterThan(styling.count, 100, "the record holds almost no style modifier")
        XCTAssertEqual(styling.filter { $0.contains("Binding<") }.map(String.init), [], "a style modifier takes a state")
    }

    /// A control takes its purpose value in its initializer alone: what its one-parameter initializer names -
    /// `Spinner(_ isAnimating:)`, `Canvas(drawing:)` - no method of the control or of its own properties names
    /// again. Captions and a picker's presentation still take a second road; they leave `pending` as they go.
    func testAPurposeValueHasOneRoad() throws {
        let lines = try String(contentsOf: Self.record, encoding: .utf8).split(separator: "\n").map(String.init)
        let purposes = lines.compactMap { line -> String? in
            guard let match = line.firstMatch(
                of: #/^swift\.init (\w+)\.init\((\w+|_):\): .*?init(?:<[^>]*>)?\((?:@\w+ )*(?:\w+ )?(\w+): /#)
            else { return nil }
            let name = match.2 == "_" ? match.3 : match.2
            return name == "state" ? nil : "\(match.1).\(name)"
        }
        let methods = Set(lines.compactMap { line in
            line.firstMatch(of: #/^swift\.method (\w+)\.(\w+)\(/#).map { "\($0.1).\($0.2)" }
        })
        let doubled = purposes.filter { purpose in
            let parts = purpose.split(separator: ".")
            return methods.contains(purpose) || methods.contains("\(parts[0])Properties.\(parts[1])")
        }

        XCTAssertGreaterThan(purposes.count, 40, "the record holds almost no initializer")
        XCTAssertEqual(doubled.sorted(), [], "a control takes its purpose value twice")
    }

    /// Every type of the application surface is one an application meets: one it writes itself - a protocol it
    /// adopts, an object it makes, a view, a scene, an error it catches, a namespace it calls, a contract - or one
    /// another of its declarations names. A value only a contract's member or a host takes is the extending
    /// surface's.
    /// Design: docs/design/architecture.md#two-surfaces
    func testEveryApplicationTypeIsOneAnApplicationMeets() throws {
        let lines = try String(contentsOf: Self.record, encoding: .utf8).split(separator: "\n").map(String.init)
        let fields = lines.map { line -> (kind: String, path: String, text: String) in
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            let path = parts[1].hasSuffix(":") ? String(parts[1].dropLast()) : parts[1]
            return (parts[0], path, line.components(separatedBy: ": ").dropFirst().joined(separator: ": "))
        }
        let written = ["StateUI.View", "StateUI.Views", "StateUI.ToolbarItem", "StateUI.Scene", "Swift.Error"]
        let isContract = { (path: String) in
            let owner = path.prefix { $0 != "." }
            return owner.hasSuffix("Contract") || owner.hasSuffix("Tier")
        }

        var unmet: [String] = []
        for type in fields where ["swift.struct", "swift.enum", "swift.class"].contains(type.kind) {
            let own = { (path: String) in path == type.path || path.hasPrefix(type.path + ".") }
            let isWritten = type.text.contains("class ") || isContract(type.path)
                || fields.contains { $0.kind == "swift.conformance" && $0.path == type.path && written.contains($0.text) }
                || (type.kind == "swift.enum" && !fields.contains { $0.kind == "swift.enum.case" && own($0.path) })
            let word = try Regex("(?:^|[^A-Za-z0-9_])\(type.path.split(separator: ".").last!)(?:$|[^A-Za-z0-9_])")
            let isNamed = fields.contains {
                $0.kind != "swift.conformance" && !own($0.path) && !isContract($0.path) && $0.text.contains(word)
            }
            if !isWritten && !isNamed { unmet.append(type.path) }
        }

        XCTAssertGreaterThan(fields.count, 10_000, "the record holds almost nothing")
        XCTAssertEqual(unmet.sorted(), [], "the application surface holds a type no application meets")
    }

    /// A view slot - a header, a footer, what stands in for no items, a shade - is a builder, never a view handed
    /// as a value, so a slot takes an `if` as every body does.
    func testEveryViewSlotIsABuilder() throws {
        let slots = try Self.recorded().split(separator: "\n").filter { $0.contains(/\w+: (some|any) View[,)]/) }

        XCTAssertEqual(slots.map(String.init), [], "a declaration takes a view as a value")
    }

    /// Whatever takes a `Material` takes a `Color` and a `Brush` beside it, and a state of a color where it takes
    /// one of a material: a background is written alike on a view, a page, a bar and a sidebar. A run of text is
    /// painted by the platform's text in one color, so it takes no brush. A modifier taking a brush takes a color
    /// too, so no application writes a color as a brush.
    func testWhatTakesAMaterialTakesAColorAndABrush() throws {
        let oneColor: Set = ["swift.method TextSpan.background(_:)"]
        var overloads: [String: [String]] = [:]
        for line in try Self.recorded().split(separator: "\n") {
            guard let colon = line.range(of: ": ") else { continue }
            overloads[String(line[..<colon.lowerBound]), default: []].append(String(line[colon.upperBound...]))
        }

        var missing: [String] = []
        for (name, declarations) in overloads where name.hasPrefix("swift.method ")
            && declarations.contains(where: { $0.contains(/\(_ \w+: Brush\)/) })
            && !declarations.contains(where: { $0.contains(/\(_ \w+: Color\)/) }) {
            missing.append("\(name) takes no Color")
        }
        for (name, declarations) in overloads where declarations.contains(where: { $0.contains(/\(_ \w+: Material\)/) }) {
            let takes = { (type: String) in declarations.contains { $0.contains("(_ ") && $0.contains(": \(type))") } }
            var wanted = ["Color"] + (oneColor.contains(name) ? [] : ["Brush"])
            if takes("Binding<Material>") { wanted.append("Binding<Color>") }
            missing += wanted.filter { !takes($0) }.map { "\(name) takes no \($0)" }
        }

        XCTAssertGreaterThan(overloads.count, 1000, "the records hold almost nothing")
        XCTAssertEqual(missing.sorted(), [], "a member taking a material leaves out its color or brush")
    }

    /// The module this run built says what the records say, each line in the record of its surface.
    func testThePublicSurfaceIsTheRecordedOne() throws {
        let surface = try Self.surface()
        XCTAssertGreaterThan(surface.count, 1_000, "the symbol graph read almost nothing")
        let (application, extending) = Self.split(surface)

        for (record, lines) in [(Self.record, application), (Self.extendingRecord, extending)] {
            try Self.hold(lines, to: record)
        }
    }

    /// The module a host's script names - its facade, a backend, the testing module - says what its record says,
    /// `lib/StateUI/exports/api/<Module>.txt`. The script names the module and the folder it was built in
    /// (`STATEUI_API_MODULE`, `STATEUI_API_MODULES`), and for another platform the triple, the SDK and the
    /// arguments that find its C modules (`STATEUI_API_TRIPLE`, `STATEUI_API_SDK`, `STATEUI_API_ARGUMENTS`); the
    /// core's own run names none, and is skipped saying so.
    /// Design: docs/design/architecture.md#a-hosts-modules
    func testTheModuleAHostsScriptNamesIsItsRecord() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let module = environment["STATEUI_API_MODULE"], !module.isEmpty else {
            throw XCTSkip("a host's script names the module it records, STATEUI_API_MODULE")
        }
        let said = { (name: String) in environment[name].flatMap { $0.isEmpty ? nil : $0 } }
        let modules = try XCTUnwrap(said("STATEUI_API_MODULES"), "the folder \(module) was built in")
        let surface = try Self.surface(
            module: module, directory: URL(fileURLWithPath: modules), triple: said("STATEUI_API_TRIPLE"),
            sdk: said("STATEUI_API_SDK"),
            arguments: (environment["STATEUI_API_ARGUMENTS"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init))

        XCTAssertFalse(surface.isEmpty, "the symbol graph of \(module) read nothing")
        try Self.hold(surface, to: Self.record.deletingLastPathComponent().appendingPathComponent("\(module).txt"))
    }

    /// Holds `lines` to `record`, or writes them there under `STATEUI_UPDATE_EXPORTS=1`.
    private static func hold(_ lines: [String], to record: URL) throws {
        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(at: record.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(to: record, atomically: true, encoding: .utf8)
            return
        }

        let recorded = try String(contentsOf: record, encoding: .utf8).replacingOccurrences(of: "\r\n", with: "\n")
        let (was, now) = (Set(recorded.split(separator: "\n").map(String.init)), Set(lines))
        let added = now.subtracting(was).sorted(), removed = was.subtracting(now).sorted()
        XCTAssertTrue(added.isEmpty && removed.isEmpty, """
            \(record.lastPathComponent) is not the recorded API - \(added.count) added, \(removed.count) taken \
            away. Read the change, then write it: STATEUI_UPDATE_EXPORTS=1 and the run that records it
            \((added.prefix(20).map { "+ \($0)" } + removed.prefix(20).map { "- \($0)" }).joined(separator: "\n"))
            """)
    }

    func testTheSurfaceRecordsProjectedValuesAndPublicSetterAccess() throws {
        let surface = try Self.surface()
        let setting = try XCTUnwrap(surface.first { $0.hasPrefix("swift.property ApplicationSession.colorScheme:") })
        let phase = try XCTUnwrap(surface.first { $0.hasPrefix("swift.property ApplicationSession.phase:") })

        XCTAssertTrue(setting.hasSuffix("{ get set }"), "an application's setting is writable")
        XCTAssertTrue(phase.hasSuffix("{ get }"), "a reported fact has no public setter: \(phase)")
        XCTAssertTrue(surface.contains {
            $0.hasPrefix("swift.property ApplicationSession.$colorScheme:")
                && $0.contains("@MainActor") && $0.contains("Binding<ColorScheme?>") && $0.hasSuffix("{ get }")
        }, "a setting's projected binding and its isolation are public API")
    }

    func testTheCompilerSurfaceTracksAccessProjectionAndIsolation() throws {
        let original = try Self.fixtureSurface()
        XCTAssertTrue(original.contains("swift.property Example.value: @Wrapped @MainActor var value: Int { get }"))
        XCTAssertTrue(original.contains("swift.property Example.$value: @MainActor var $value: Int { get }"),
                      "restricting the wrapped setter alone leaves the projection public")
        XCTAssertTrue(original.contains("swift.property Example.setting: @Wrapped @MainActor var setting: Int { get set }"))
        XCTAssertTrue(original.contains("swift.property Conforming.count: var count: Int { get }"),
                      "an inherited declaration keeps its public accessor")
        XCTAssertFalse(original.contains { $0.contains("Example.hidden") || $0.contains("Example.$hidden")
            || $0.contains("Example.hostValue") || $0.contains("Example.$hostValue") })

        let writable = try Self.fixtureSurface(restricted: false)
        XCTAssertTrue(writable.contains("swift.property Example.value: @Wrapped @MainActor var value: Int { get set }"))
        XCTAssertNotEqual(original, writable, "opening a setter must change the record")

        let noProjection = try Self.fixtureSurface(projected: false)
        XCTAssertFalse(noProjection.contains { $0.hasPrefix("swift.property Example.$") })
        XCTAssertNotEqual(original, noProjection, "removing a projection must change the record")

        let unisolated = try Self.fixtureSurface(isolated: false)
        XCTAssertTrue(unisolated.contains("swift.property Example.$value: var $value: Int { get }"))
        XCTAssertNotEqual(original, unisolated, "removing isolation must change the record")
    }

    private static func fixtureSurface(
        restricted: Bool = true, projected: Bool = true, isolated: Bool = true
    ) throws -> [String] {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-api-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let file = scratch.appendingPathComponent("Fixture.swift")
        let source = """
            @propertyWrapper public struct Wrapped<Value> {
                public var wrappedValue: Value
                \(projected ? "public var projectedValue: Value { wrappedValue }" : "")
                public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
            }
            \(isolated ? "@MainActor " : "")public final class Example {
                @Wrapped public \(restricted ? "private(set) " : "")var value = 1
                @Wrapped public var setting = 2
                @Wrapped private var hidden = 3
                @_spi(Host) @Wrapped public var hostValue = 4
                public init() {}
            }
            public protocol Counted {}
            extension Counted { public var count: Int { 1 } }
            public struct Conforming: Counted { public init() {} }
            """
        try source.write(to: file, atomically: true, encoding: .utf8)
        var arguments = ["-emit-module", "-parse-as-library", "-swift-version", "6", "-warnings-as-errors", "-module-name", "APIExample",
                         "-target", try triple(), file.path, "-emit-module-path", scratch.appendingPathComponent("APIExample.swiftmodule").path]
        if let sdk = try sdk() { arguments += ["-sdk", sdk] }
        _ = try run("swiftc", arguments)
        return try surface(module: "APIExample", directory: scratch)
    }

    /// Every public declaration of the module this run built - its kind, its path and its declaration - and every
    /// type's conformances, sorted, from the symbol graph the toolchain beside `swift` extracts: the module's own and
    /// its extensions of other modules'.
    private static func surface(
        module: String = "StateUI", directory: URL? = nil, triple: String? = nil, sdk given: String? = nil,
        arguments extra: [String] = []
    ) throws -> [String] {
        // Never a skip: a check that did not run reads as one that passed.
        guard let modules = directory ?? builtModules() else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSDebugDescriptionErrorKey: "no StateUI.swiftmodule beside the tests"])
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-api-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: output) }

        let target = try triple ?? Self.triple(), sdk = try given ?? Self.sdk()
        var arguments = ["-module-name", module, "-I", modules.path, "-target", target,
                         "-minimum-access-level", "public", "-output-dir", output.path] + extra
        if let sdk { arguments += ["-sdk", sdk] }
        let said = try run("swift-symbolgraph-extract", arguments)
        let graphs = try FileManager.default.contentsOfDirectory(atPath: output.path).filter { $0.hasSuffix(".json") }
        guard !graphs.isEmpty else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSDebugDescriptionErrorKey: said]) }

        let read = try graphs.map { graph -> (extended: Substring, json: [String: Any]) in
            // A graph named `StateUI@Swift` holds what the module adds to the standard library's types.
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: output.appendingPathComponent(graph)))
            return (graph.dropFirst(module.count).dropLast(".symbols.json".count), json as? [String: Any] ?? [:])
        }

        let digest = output.appendingPathComponent("accessors.json")
        var digestArguments = ["-dump-sdk", "-module", module, "-I", modules.path, "-target", target, "-o", digest.path]
            + extra
        if let sdk { digestArguments += ["-sdk", sdk] }
        _ = try run("swift-api-digester", digestArguments)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: digest))
        let properties = try APIProperties(json as? [String: Any] ?? [:], module: module)

        // Where each symbol stands, by its identifier - a type another module declares by what its members say.
        var paths: [String: String] = [:]
        for (extended, json) in read {
            let symbols = json["symbols"] as? [[String: Any]] ?? []
            var byIdentifier: [String: [String]] = [:]
            for symbol in symbols {
                let components = symbol["pathComponents"] as? [String] ?? []
                byIdentifier[Self.identifier(of: symbol)] = components
                paths[Self.identifier(of: symbol)] = extended + components.joined(separator: ".")
            }
            for relationship in json["relationships"] as? [[String: Any]] ?? [] where relationship["kind"] as? String == "memberOf" {
                guard let target = relationship["target"] as? String, paths[target] == nil,
                      let member = byIdentifier[relationship["source"] as? String ?? ""] else { continue }
                paths[target] = extended + member.dropLast().joined(separator: ".")
            }
        }

        var lines: Set<String> = []
        var declarations: [String: String] = [:]
        var wrappers: Set<String> = []
        for (extended, json) in read {
            for symbol in json["symbols"] as? [[String: Any]] ?? [] {
                // A member another module's protocol lends a StateUI type - `!=`, `hashValue`, an integer's
                // `init(bigEndian:)` - is that module's: the conformance below records it, toolchain by toolchain alike.
                // Design: docs/design/architecture.md#the-public-surface
                let lent = Self.identifier(of: symbol).components(separatedBy: "::SYNTHESIZED::")
                if lent.count > 1, !lent[0].contains("\(module.utf8.count)\(module)") { continue }
                let kind = (symbol["kind"] as? [String: Any])?["identifier"] as? String ?? "?"
                let path = (symbol["pathComponents"] as? [String] ?? []).joined(separator: ".")
                let fragments = symbol["declarationFragments"] as? [[String: Any]] ?? []
                // One line each: a declaration the compiler prints over lines, or ending in one, reads as one.
                var declaration = fragments.compactMap { $0["spelling"] as? String }.joined()
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                if kind == "swift.property" {
                    declaration = properties.declaration(declaration, of: Self.identifier(of: symbol))
                    declarations[extended + path] = declaration
                }
                if declaration.contains("@propertyWrapper "), let name = path.split(separator: ".").last {
                    wrappers.insert(String(name))
                }
                lines.insert("\(kind) \(extended)\(path): \(declaration)")
            }
            for relationship in json["relationships"] as? [[String: Any]] ?? [] where relationship["kind"] as? String == "conformsTo" {
                guard let source = paths[relationship["source"] as? String ?? ""] else { continue }
                let target = relationship["targetFallback"] as? String ?? paths[relationship["target"] as? String ?? ""]
                    .map { module + "." + $0 } ?? "?"
                // What every type is unless it says otherwise, and what another module's type was before StateUI.
                if ["Swift.Copyable", "Swift.Escapable", "Swift.SendableMetatype"].contains(target) { continue }
                if !extended.isEmpty, !target.hasPrefix(module + ".") { continue }
                let constraints = (relationship["swiftConstraints"] as? [[String: Any]] ?? []).filter { constraint in
                    !["Copyable", "Escapable"].contains(constraint["rhs"] as? String ?? "")
                }.map { constraint in
                    "\(constraint["lhs"] as? String ?? "?") \(constraint["kind"] as? String == "sameType" ? "==" : ":") \(constraint["rhs"] as? String ?? "?")"
                }
                lines.insert("swift.conformance \(source): \(target)"
                    + (constraints.isEmpty ? "" : " where " + constraints.sorted().joined(separator: ", ")))
            }
        }
        lines.formUnion(try properties.projectedLines(declarations: declarations, wrappers: wrappers))
        return lines.sorted()
    }

    /// A symbol's identifier in the graph.
    private static func identifier(of symbol: [String: Any]) -> String {
        (symbol["identifier"] as? [String: Any])?["precise"] as? String ?? ""
    }

    /// Where the build that made this test put the module, beside the test bundle or in a Modules folder there.
    static func builtModules() -> URL? {
        let bundle = Bundle(for: APISurfaceTests.self).bundleURL
        for folder in [bundle, bundle.deletingLastPathComponent()] {
            for modules in [folder, folder.appendingPathComponent("Modules")]
            where FileManager.default.fileExists(atPath: modules.appendingPathComponent("StateUI.swiftmodule").path) {
                return modules
            }
        }
        return nil
    }

    /// The triple the toolchain builds for here, at this system's own version on Apple's: the compiler's default
    /// stands below the manifests' floor, which no system running this test stands below.
    static func triple() throws -> String {
        let info = try JSONSerialization.jsonObject(with: Data(try run("swiftc", ["-print-target-info"]).utf8))
        guard let target = (info as? [String: Any])?["target"] as? [String: Any],
              let triple = target["triple"] as? String else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        #if os(macOS)
        if let unversioned = target["unversionedTriple"] as? String {
            let system = ProcessInfo.processInfo.operatingSystemVersion
            return "\(unversioned)\(system.majorVersion).\(system.minorVersion)"
        }
        #endif
        return triple
    }

    /// The SDK the toolchain compiles against on this system, where one is needed: Xcode's on macOS, the one
    /// `SDKROOT` names elsewhere - Windows' standard library stands there; Linux names none.
    static func sdk() throws -> String? {
        #if os(macOS)
        return try run("xcrun", ["--show-sdk-path"]).trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        let named = ProcessInfo.processInfo.environment["SDKROOT"] ?? ""
        return named.isEmpty ? nil : named
        #endif
    }

    /// Runs a tool found on PATH - the toolchain running these tests - or, where PATH holds only Xcode's `swift`,
    /// in Xcode's toolchain, and answers what it printed.
    static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? environment.first { $0.key.lowercased() == "path" }?.value ?? ""
        #if os(Windows)
        let (divider, spellings): (Character, [String]) = (";", [tool + ".exe", tool])
        #else
        let (divider, spellings): (Character, [String]) = (":", [tool])
        #endif
        let found = path.split(separator: divider).lazy
            .flatMap { folder in spellings.map { URL(fileURLWithPath: String(folder)).appendingPathComponent($0) } }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        guard let found = found ?? xcodeTool(tool) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: tool])
        }

        let process = Process()
        process.executableURL = found
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "StateUI.Compiler", code: Int(process.terminationStatus),
                          userInfo: [NSDebugDescriptionErrorKey: "\(tool): \(output)"])
        }
        return output
    }

    /// A tool of Xcode's toolchain, which stands off PATH beside the `/usr/bin/swift` shim; nil off macOS.
    private static func xcodeTool(_ tool: String) -> URL? {
        #if os(macOS)
        guard let found = try? run("xcrun", ["--find", tool]).trimmingCharacters(in: .whitespacesAndNewlines),
              FileManager.default.isExecutableFile(atPath: found) else { return nil }
        return URL(fileURLWithPath: found)
        #else
        return nil
        #endif
    }
}
