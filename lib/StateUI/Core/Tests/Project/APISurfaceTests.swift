// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The public API is recorded: every public declaration of `StateUI`, a line each, in
/// `lib/StateUI/exports/api/StateUI.txt`, which `STATEUI_UPDATE_EXPORTS=1` writes.
/// Design: docs/design/architecture.md#the-public-surface
final class APISurfaceTests: XCTestCase {
    /// The record of the module's public declarations.
    private static let record = SourceTree.repository.appendingPathComponent("lib/StateUI/exports/api/StateUI.txt")

    /// The module this run built says what the record says.
    func testThePublicSurfaceIsTheRecordedOne() throws {
        let surface = try Self.surface()
        XCTAssertGreaterThan(surface.count, 1_000, "the symbol graph read almost nothing")
        let text = surface.joined(separator: "\n") + "\n"

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(
                at: Self.record.deletingLastPathComponent(), withIntermediateDirectories: true)
            return try text.write(to: Self.record, atomically: true, encoding: .utf8)
        }

        let recorded = try String(contentsOf: Self.record, encoding: .utf8).replacingOccurrences(of: "\r\n", with: "\n")
        let (was, now) = (Set(recorded.split(separator: "\n").map(String.init)), Set(surface))
        let added = now.subtracting(was).sorted(), removed = was.subtracting(now).sorted()
        XCTAssertTrue(added.isEmpty && removed.isEmpty, """
            The public API is not the recorded one - \(added.count) added, \(removed.count) taken away. Read the change, \
            then write it: STATEUI_UPDATE_EXPORTS=1 swift test --filter APISurfaceTests
            \((added.prefix(20).map { "+ \($0)" } + removed.prefix(20).map { "- \($0)" }).joined(separator: "\n"))
            """)
    }

    /// Every public declaration of the module this run built - its kind, its path and its declaration - sorted, from
    /// the symbol graph the toolchain beside `swift` extracts: the module's own and its extensions of other modules'.
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

        var lines: Set<String> = []
        for graph in graphs {
            // A graph named `StateUI@Swift` holds what the module adds to the standard library's types.
            let extended = graph.dropFirst("StateUI".count).dropLast(".symbols.json".count)
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: output.appendingPathComponent(graph)))
            for symbol in (json as? [String: Any])?["symbols"] as? [[String: Any]] ?? [] {
                let kind = (symbol["kind"] as? [String: Any])?["identifier"] as? String ?? "?"
                let path = (symbol["pathComponents"] as? [String] ?? []).joined(separator: ".")
                let fragments = symbol["declarationFragments"] as? [[String: Any]] ?? []
                // One line each: a declaration the compiler prints over lines, or ending in one, reads as one.
                let declaration = fragments.compactMap { $0["spelling"] as? String }.joined()
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                lines.insert("\(kind) \(extended)\(path): \(declaration)")
            }
        }
        return lines.sorted()
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

    /// The SDK the toolchain compiles against on this system, where one is needed.
    private static func sdk() throws -> String? {
        #if os(macOS)
        return try run("xcrun", ["--show-sdk-path"]).trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return nil
        #endif
    }

    /// Runs a tool found on PATH - the toolchain running these tests - and answers what it printed.
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
        guard let found else { throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: tool]) }

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
}
