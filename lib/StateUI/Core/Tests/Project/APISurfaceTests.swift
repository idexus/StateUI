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

    /// The types an author extending StateUI writes with, every member with them: a contract and its members, a
    /// node, the values a host is handed, a value of a state's own, and an application's acts and events.
    /// Design: docs/design/architecture.md#two-surfaces
    static let extendingTypes: Set<String> = [
        "Act", "AppliedProperties", "ApplicationTier", "Contract", "ContractMember", "ControlValues", "ElementAct",
        "ElementContract", "ElementEvent", "ElementLayer", "ElementProperty", "Event", "HostEventSubscription",
        "HostEvents", "HostRepresentable", "ItemsEntries", "LaneKind", "LaneValue", "Name", "Node", "NodeType",
        "Prop", "PropValue", "StateCarried", "StateChoice", "StateKind", "StateMode", "StateValue", "Walked",
    ]

    /// The members an author extending StateUI writes, on whatever type they stand: a view's own node, its values
    /// and handlers by contract member, and a value's conversions.
    static let extendingMembers: Set<String> = [
        "carried", "init(carried:)", "init(propValue:)", "laneKind", "lanes", "modified", "moving",
        "node", "nodes", "onEvent", "onHostEvent", "propValue", "setValue",
        "Aim.call", "ApplicationSession.call", "ApplicationSession.tell",
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
            let named = member.contains("(") ? member : member.split(separator: ".").last ?? ""
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

    /// The handbook names every public type of both surfaces - README and docs/, the design notes left out: what 1.0
    /// freezes is what the handbook promised, so a type no page names is a promise nobody made.
    func testTheHandbookNamesEveryPublicType() throws {
        let declared = try Self.recorded().split(separator: "\n").compactMap { line -> String? in
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

    /// The module this run built says what the records say, each line in the record of its surface.
    func testThePublicSurfaceIsTheRecordedOne() throws {
        let surface = try Self.surface()
        XCTAssertGreaterThan(surface.count, 1_000, "the symbol graph read almost nothing")
        let (application, extending) = Self.split(surface)

        for (record, lines) in [(Self.record, application), (Self.extendingRecord, extending)] {
            if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
                try FileManager.default.createDirectory(
                    at: record.deletingLastPathComponent(), withIntermediateDirectories: true)
                try (lines.joined(separator: "\n") + "\n").write(to: record, atomically: true, encoding: .utf8)
                continue
            }

            let recorded = try String(contentsOf: record, encoding: .utf8).replacingOccurrences(of: "\r\n", with: "\n")
            let (was, now) = (Set(recorded.split(separator: "\n").map(String.init)), Set(lines))
            let added = now.subtracting(was).sorted(), removed = was.subtracting(now).sorted()
            XCTAssertTrue(added.isEmpty && removed.isEmpty, """
                \(record.lastPathComponent) is not the recorded API - \(added.count) added, \(removed.count) taken \
                away. Read the change, then write it: STATEUI_UPDATE_EXPORTS=1 swift test --filter APISurfaceTests
                \((added.prefix(20).map { "+ \($0)" } + removed.prefix(20).map { "- \($0)" }).joined(separator: "\n"))
                """)
        }
    }

    /// Every public declaration of the module this run built - its kind, its path and its declaration - and every
    /// type's conformances, sorted, from the symbol graph the toolchain beside `swift` extracts: the module's own and
    /// its extensions of other modules'.
    private static func surface() throws -> [String] {
        // Never a skip: a check that did not run reads as one that passed.
        guard let modules = builtModules() else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSDebugDescriptionErrorKey: "no StateUI.swiftmodule beside the tests"])
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-api-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: output) }

        var arguments = ["-module-name", "StateUI", "-I", modules.path, "-target", try triple(),
                         "-minimum-access-level", "public", "-output-dir", output.path]
        if let sdk = try sdk() { arguments += ["-sdk", sdk] }
        let said = try run("swift-symbolgraph-extract", arguments)
        let graphs = try FileManager.default.contentsOfDirectory(atPath: output.path).filter { $0.hasSuffix(".json") }
        guard !graphs.isEmpty else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSDebugDescriptionErrorKey: said]) }

        let read = try graphs.map { graph -> (extended: Substring, json: [String: Any]) in
            // A graph named `StateUI@Swift` holds what the module adds to the standard library's types.
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: output.appendingPathComponent(graph)))
            return (graph.dropFirst("StateUI".count).dropLast(".symbols.json".count), json as? [String: Any] ?? [:])
        }

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
        for (extended, json) in read {
            for symbol in json["symbols"] as? [[String: Any]] ?? [] {
                // A member another module's protocol lends a StateUI type - `!=`, `hashValue`, an integer's
                // `init(bigEndian:)` - is that module's: the conformance below records it, toolchain by toolchain alike.
                // Design: docs/design/architecture.md#the-public-surface
                let lent = Self.identifier(of: symbol).components(separatedBy: "::SYNTHESIZED::")
                if lent.count > 1, !lent[0].contains("7StateUI") { continue }
                let kind = (symbol["kind"] as? [String: Any])?["identifier"] as? String ?? "?"
                let path = (symbol["pathComponents"] as? [String] ?? []).joined(separator: ".")
                let fragments = symbol["declarationFragments"] as? [[String: Any]] ?? []
                // One line each: a declaration the compiler prints over lines, or ending in one, reads as one.
                let declaration = fragments.compactMap { $0["spelling"] as? String }.joined()
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                lines.insert("\(kind) \(extended)\(path): \(declaration)")
            }
            for relationship in json["relationships"] as? [[String: Any]] ?? [] where relationship["kind"] as? String == "conformsTo" {
                guard let source = paths[relationship["source"] as? String ?? ""] else { continue }
                let target = relationship["targetFallback"] as? String ?? paths[relationship["target"] as? String ?? ""]
                    .map { "StateUI." + $0 } ?? "?"
                // What every type is unless it says otherwise, and what another module's type was before StateUI.
                if ["Swift.Copyable", "Swift.Escapable", "Swift.SendableMetatype"].contains(target) { continue }
                if !extended.isEmpty, !target.hasPrefix("StateUI.") { continue }
                let constraints = (relationship["swiftConstraints"] as? [[String: Any]] ?? []).filter { constraint in
                    !["Copyable", "Escapable"].contains(constraint["rhs"] as? String ?? "")
                }.map { constraint in
                    "\(constraint["lhs"] as? String ?? "?") \(constraint["kind"] as? String == "sameType" ? "==" : ":") \(constraint["rhs"] as? String ?? "?")"
                }
                lines.insert("swift.conformance \(source): \(target)"
                    + (constraints.isEmpty ? "" : " where " + constraints.sorted().joined(separator: ", ")))
            }
        }
        return lines.sorted()
    }

    /// A symbol's identifier in the graph.
    private static func identifier(of symbol: [String: Any]) -> String {
        (symbol["identifier"] as? [String: Any])?["precise"] as? String ?? ""
    }

    /// Where the build that made this test put the module, beside the test bundle or in a Modules folder there.
    private static func builtModules() -> URL? {
        let bundle = Bundle(for: APISurfaceTests.self).bundleURL
        for folder in [bundle, bundle.deletingLastPathComponent()] {
            for modules in [folder, folder.appendingPathComponent("Modules")]
            where FileManager.default.fileExists(atPath: modules.appendingPathComponent("StateUI.swiftmodule").path) {
                return modules
            }
        }
        return nil
    }

    /// The triple the toolchain builds for here, with the system's version - the one the module was built for.
    private static func triple() throws -> String {
        let info = try JSONSerialization.jsonObject(with: Data(try run("swiftc", ["-print-target-info"]).utf8))
        guard let triple = ((info as? [String: Any])?["target"] as? [String: Any])?["triple"] as? String else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return triple
    }

    /// The SDK the toolchain compiles against on this system, where one is needed: Xcode's on macOS, the one
    /// `SDKROOT` names elsewhere - Windows' standard library stands there; Linux names none.
    private static func sdk() throws -> String? {
        #if os(macOS)
        return try run("xcrun", ["--show-sdk-path"]).trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        let named = ProcessInfo.processInfo.environment["SDKROOT"] ?? ""
        return named.isEmpty ? nil : named
        #endif
    }

    /// Runs a tool found on PATH - the toolchain running these tests - or, where PATH holds only Xcode's `swift`,
    /// in Xcode's toolchain, and answers what it printed.
    private static func run(_ tool: String, _ arguments: [String]) throws -> String {
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
        return String(decoding: data, as: UTF8.self)
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
