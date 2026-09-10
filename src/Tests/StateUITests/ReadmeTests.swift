// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// README's Swift examples COMPILE.
///
/// Every fenced `swift` block in README.md is type-checked against the library
/// this package just built, so an example that names a member which has gone,
/// spells a modifier wrongly or hands a part of a state where a whole one is wanted
/// fails the suite and names its line. The document is the compendium a reader
/// starts from, and a listing in it that does not compile is worse than none.
///
/// A block is compiled as the BODY OF A FUNCTION, which is what lets a listing
/// read as it would inside a page - `@State var counter = 0` beside a
/// `Label("\(counter)")` - without every example carrying a `struct` around it:
/// local types, local property wrappers, statements and `try await` are all
/// allowed there. `private` is dropped first, because a local variable cannot
/// wear it and a listing is not asked to know that. A block declaring what
/// only a file can hold - an `extension`, a `protocol`, a `public` type,
/// an `import` - is compiled at file scope instead.
///
/// The blocks are type-checked in parallel, one `swiftc -typecheck` each,
/// against the `.swiftmodule` this package's own build wrote - so the check
/// costs seconds, and needs nothing installed beyond the toolchain running it.
final class ReadmeTests: XCTestCase {
    /// A fenced block of README, with the line its fence opens on.
    struct Example {
        let line: Int
        let source: String
        var fileScope: Bool {
            source.split(separator: "\n").contains { line in
                let head = line.trimmingCharacters(in: .whitespaces)
                // A listing's model - a class of `@State` properties - is
                // declared at file scope, where an application declares one.
                return ["extension ", "protocol ", "@_cdecl", "@main", "public ", "open ",
                        "final class ", "class ", "private final class ", "private class "]
                    .contains { head.hasPrefix($0) }
            }
        }
    }

    /// What the lanes write their failures into.
    ///
    /// A CLASS rather than a captured `var`, because a lane is a concurrently
    /// executing closure and Swift refuses to let one MUTATE a variable it
    /// captured - which is an error and not a warning, so the suite would not
    /// compile at all on Windows while the same source built on a Mac. The
    /// lock is the type's own, so one place knows how this is shared.
    private final class Failures: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [(Int, String)] = []

        /// Writes down one listing that would not compile.
        func add(_ line: Int, _ output: String) {
            lock.lock()
            defer { lock.unlock() }
            items.append((line, output))
        }

        /// Every failure, by the line its listing opens on.
        var sorted: [(Int, String)] {
            lock.lock()
            defer { lock.unlock() }
            return items.sorted { $0.0 < $1.0 }
        }
    }

    func testEveryReadmeExampleCompiles() throws {
        let readme = Fixtures.repository.appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        let examples = Self.swiftBlocks(in: text)
        XCTAssertGreaterThan(examples.count, 100, "README has lost its examples")

        guard let module = Self.builtModuleDirectory() else {
            throw XCTSkip("no StateUI.swiftmodule under src/Tests/.build - build the package first")
        }
        let sdk = try Self.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-readme-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // One file per block, then every file type-checked at once - each in
        // its own process so a failure names one listing and not the lot.
        let failures = Failures()
        let group = DispatchGroup()
        let lanes = DispatchSemaphore(value: max(2, ProcessInfo.processInfo.activeProcessorCount - 1))

        for example in examples {
            let file = scratch.appendingPathComponent("readme_\(example.line).swift")
            // WRITTEN STRAIGHT, never atomically: an atomic write goes to a
            // temporary beside the file and renames it, and on Windows that
            // rename loses a race often enough to see - `Win32Error(code: 32)`,
            // a sharing violation, on one listing in a run of a hundred and
            // thirty. The path is fresh and nobody is reading it, so there is
            // nothing for atomicity to protect.
            try Data(Self.wrap(example).utf8).write(to: file)
            group.enter()
            lanes.wait()
            DispatchQueue.global().async {
                defer { lanes.signal(); group.leave() }
                let output = Self.typecheck(file, module: module, sdk: sdk)
                if let output {
                    failures.add(example.line, output)
                }
            }
        }
        group.wait()

        for (line, output) in failures.sorted {
            XCTFail("README.md:\(line) does not compile:\n\(output)")
        }
    }

    // MARK: - Reading the document

    /// Every ```swift block, with the line number of its opening fence. A fence
    /// saying more than the language - ```swift quote - is a listing QUOTED
    /// from somewhere else, a line of the library's own source or a manifest,
    /// and is not an example anybody would write; it is left alone.
    static func swiftBlocks(in text: String) -> [Example] {
        var examples: [Example] = []
        var open: Int? = nil
        var body: [String] = []
        // A fence may be indented - a listing inside a numbered list is -
        // so both fences are read trimmed, and the block's own indent goes.
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let head = line.trimmingCharacters(in: .whitespaces)
            if let start = open {
                if head.hasPrefix("```") {
                    let indent = body.filter { !$0.isEmpty }.map { $0.prefix { $0 == " " }.count }.min() ?? 0
                    let dedented = body.map { $0.isEmpty ? "" : String($0.dropFirst(indent)) }
                    examples.append(Example(line: start, source: dedented.joined(separator: "\n")))
                    open = nil; body = []
                } else {
                    body.append(String(line))
                }
            } else if head == "```swift" {
                open = index + 1
            }
        }
        return examples
    }

    /// The block as a compilable file: a function body, or file scope where
    /// the block holds what only a file can.
    static func wrap(_ example: Example) -> String {
        // `{ … }` in a listing means "whatever goes here" - a view, to the
        // compiler, which is what a builder, a page's `content` and a handler
        // all accept; an ellipsis anywhere else is the listing's own problem,
        // and it fails as it should.
        // A listing's own `import Foundation` - which an application may
        // write - is lifted to the head, where an import has to be.
        var lifted: [String] = []
        let kept = example.source.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let head = line.trimmingCharacters(in: .whitespaces)
            if head.hasPrefix("import ") { lifted.append(head); return false }
            return true
        }
        let stripped = kept.joined(separator: "\n")
            .replacingOccurrences(of: "fileprivate ", with: "")
            .replacingOccurrences(of: "private ", with: "")
            .replacingOccurrences(of: "{ … }", with: "{ Label(\"…\") }")
        // The gallery's own module, for the listings that show the gallery's
        // code - its palette, its sample protocol. Testable, because the
        // gallery's types are internal, as an application's are; the guide's
        // own listings use the library's colours and never the gallery's.
        let imports = (["import StateUI", "@testable import GalleryUI"] + lifted).joined(separator: "\n") + "\n"
        if example.fileScope {
            return "\(imports)\n\(stripped)\n"
        }
        let indented = stripped.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")
        return "\(imports)\nfunc readmeExample() async throws {\n\(indented)\n}\n"
    }

    // MARK: - Running the compiler

    /// Where this package's DEBUG build put the library's module, or nil.
    ///
    /// The debug build alone: a release directory beside it, where one exists,
    /// and the index build are other compiler modes' output, which this one
    /// refuses to read.
    static func builtModuleDirectory() -> URL? {
        let build = Fixtures.repository.appendingPathComponent("src/Tests/.build")
        guard let walk = FileManager.default.enumerator(at: build, includingPropertiesForKeys: nil) else {
            return nil
        }
        for case let url as URL in walk {
            if url.lastPathComponent == "StateUI.swiftmodule",
               !url.path.contains("index-build"),
               url.deletingLastPathComponent().path.hasSuffix("/debug/Modules") {
                return url.deletingLastPathComponent()
            }
        }
        return nil
    }

    /// The SDK the toolchain compiles against on this host, where one is needed.
    static func sdkPath() throws -> String? {
        #if os(macOS)
        return try run("/usr/bin/xcrun", ["--show-sdk-path"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return nil
        #endif
    }

    /// Type-checks one file; the compiler's output where it failed, nil where it passed.
    static func typecheck(_ file: URL, module: URL, sdk: String?) -> String? {
        var arguments = ["-typecheck", "-parse-as-library", "-I", module.path, file.path]
        if let sdk { arguments += ["-sdk", sdk] }
        // XCRUN ON A MAC, THE TOOL ITSELF EVERYWHERE ELSE. There is no
        // `/usr/bin/env` on Windows and Foundation's `Process` resolves
        // nothing itself - it opens exactly the path it is given - so a
        // launcher spelled the unix way answered `could not run swiftc`
        // for every listing, and the whole document went unchecked while
        // the suite went on running. Measured there: 132 listings, one
        // cause, and a document nobody was checking.
        #if os(macOS)
        let launcher = URL(fileURLWithPath: "/usr/bin/xcrun")
        arguments.insert("swiftc", at: 0)
        #else
        guard let launcher = onPath("swiftc") else {
            return "swiftc is not on PATH"
        }
        #endif
        let process = Process()
        process.executableURL = launcher
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return "could not run swiftc: \(error)" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return nil }
        let output = String(decoding: data, as: UTF8.self)
        // The listing's own line numbers, not the wrapper's: the body starts
        // three lines down and one indent in.
        return output
            .split(separator: "\n")
            .filter { $0.contains("error:") }
            .prefix(6)
            .joined(separator: "\n")
    }

    /// Where a tool of the toolchain is, by the same PATH a shell would search.
    ///
    /// Foundation's `Process` opens exactly the path it is handed, so the tool
    /// has to be found before it can be run - and the spelling differs: an
    /// executable is `swiftc.exe` on Windows and `swiftc` everywhere else.
    static func onPath(_ name: String) -> URL? {
        #if os(Windows)
        let divider: Character = ";"
        let spellings = [name + ".exe", name]
        #else
        let divider: Character = ":"
        let spellings = [name]
        #endif

        // WINDOWS SPELLS IT `Path`, and Foundation's environment is a Swift
        // dictionary - case-sensitive - over a block whose names are not. So
        // `environment["PATH"]` is nil there and every listing failed with
        // "swiftc is not on PATH" while the compiler stood in that very
        // directory (measured 2026-09-07: 143 of them).
        let environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"]
            ?? environment.first { $0.key.lowercased() == "path" }?.value
            ?? ""

        for directory in path.split(separator: divider) {
            for spelling in spellings {
                let tool = URL(fileURLWithPath: String(directory))
                    .appendingPathComponent(spelling)

                if FileManager.default.fileExists(atPath: tool.path) {
                    return tool
                }
            }
        }

        return nil
    }

    private static func run(_ launcher: String, _ arguments: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launcher)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
