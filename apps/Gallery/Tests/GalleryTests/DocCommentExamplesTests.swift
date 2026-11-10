// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every example of the libraries' `///` documentation - what an editor shows on `.` - names the library as it stands.
/// Design: docs/design/README.md#the-examples-of-a-doc-comment
@MainActor
final class DocCommentExamplesTests: XCTestCase {
    /// An example of a doc comment: the source file it stands in, its first line there, its code.
    struct Example {
        let file: String
        let line: Int
        let source: String

        /// Whether it is a chain of modifiers with no view before it.
        var isFragment: Bool {
            source.drop { $0 == " " || $0 == "\n" }.first == "."
        }
    }

    /// The libraries whose examples this build compiles - every module it holds that an application imports - by
    /// their sources' folder.
    static let compiled = ["lib/StateUI/Core/Sources", "lib/StateUI/StateUI.Testing/Sources"]

    /// The surfaces those libraries record, which their fragments are held to.
    static let compiledSurfaces = ["StateUI.txt", "StateUI.extending.txt", "StateUITesting.txt"]

    /// The libraries this build does not hold - each host's facade, each backend - by their sources' folder, with
    /// the surface each records.
    static let recorded = [
        ("lib/StateUI/StateUI.AppKit/Sources", "StateUIAppKit.txt"),
        ("lib/StateUI/StateUI.UIKit/Sources", "StateUIUIKit.txt"),
        ("lib/StateUI/StateUI.Android/Sources", "StateUIAndroid.txt"),
        ("lib/StateUI/StateUI.WinUI/Sources", "StateUIWinUI.txt"),
        ("lib/StateUI/StateUI.GTK/Sources", "StateUIGTK.txt"),
        ("lib/StateUI/StateUI.Web/Sources", "StateUIWeb.txt"),
        ("lib/Backends/WebView.GTK/Sources", "StateUIWebViewGTK.txt"),
        ("lib/Backends/WebView.WinUI/Sources", "StateUIWebViewWinUI.txt"),
    ]

    /// What a compiler says only where the library no longer holds what an example names: a member gone or out of
    /// reach, an argument it no longer takes or now needs. Every other error is the example leaning on what its page
    /// declares.
    static let libraryChanged = [
        "is inaccessible due to", "has no member", "missing argument", "extra argument", "incorrect argument label",
        "no exact matches in call", "argument passed to call that takes no arguments",
    ]

    func testEveryExampleCompilesAgainstTheLibraryAsItStands() throws {
        let examples = try Self.compiled.flatMap { try Self.examples(under: $0) }.filter { !$0.isFragment }
        XCTAssertGreaterThan(examples.count, 400, "the libraries' doc comments have lost their examples")

        guard let module = DocumentationExamplesTests.builtModuleDirectory() else {
            return XCTFail("no StateUI.swiftmodule beside the test bundle - no example was compiled")
        }
        let sdk = try DocumentationExamplesTests.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-doc-comments-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let outputs = CompilerOutputs(count: examples.count)
        let group = DispatchGroup()
        let lanes = DispatchSemaphore(value: max(2, ProcessInfo.processInfo.activeProcessorCount - 1))
        for (index, example) in examples.enumerated() {
            let file = scratch.appendingPathComponent("example_\(index).swift")
            try Data(Self.wrap(example).utf8).write(to: file)
            group.enter()
            lanes.wait()
            DispatchQueue.global().async {
                defer { lanes.signal(); group.leave() }
                outputs.set(index, DocumentationExamplesTests.compile(file, module: module, sdk: sdk, errorLines: .max))
            }
        }
        group.wait()

        for (index, example) in examples.enumerated() {
            let changed = (outputs.value(index) ?? "").split(separator: "\n")
                .filter { line in line.contains(".swift:") && Self.libraryChanged.contains { line.contains($0) } }
                .map { $0.split(separator: "error: ", maxSplits: 1).last.map(String.init) ?? String($0) }
            guard !changed.isEmpty else { continue }
            XCTFail("\(example.file):\(example.line) names what the library no longer holds:\n"
                + changed.joined(separator: "\n"))
        }
    }

    func testEveryFragmentAndFacadeExampleCallsWhatTheLibraryRecords() throws {
        let exports = GallerySources.repository.appendingPathComponent("lib/StateUI/exports/api")
        let library = try RecordedSurface(files: Self.compiledSurfaces.map { exports.appendingPathComponent($0) })
        let fragments = try Self.compiled.flatMap { try Self.examples(under: $0) }.filter(\.isFragment)
        XCTAssertGreaterThan(fragments.count, 30, "the libraries' doc comments have lost their fragments")
        for fragment in fragments {
            for call in ExampleCall.modifiers(in: fragment.source) where !library.takes(call) {
                XCTFail("\(fragment.file):\(fragment.line + call.line) calls \(call.said), which the library does not "
                    + "declare")
            }
        }

        var checked = 0
        for (folder, surface) in Self.recorded {
            let facade = try RecordedSurface(
                files: (Self.compiledSurfaces + [surface]).map { exports.appendingPathComponent($0) })
            for example in try Self.examples(under: folder) {
                for call in ExampleCall.qualified(in: example.source, types: facade.types) {
                    checked += 1
                    guard !facade.takes(call) else { continue }
                    XCTFail("\(example.file):\(example.line + call.line) calls \(call.said), which \(surface) does "
                        + "not record")
                }
            }
        }
        XCTAssertGreaterThan(checked, 30, "the facades' doc comments call nothing of theirs")
    }

    /// The examples of every doc comment in the Swift files under `folder` of the repository.
    static func examples(under folder: String) throws -> [Example] {
        try GallerySources.files(under: folder, extensions: ["swift"], in: GallerySources.repository)
            .flatMap { examples(in: $0.text, file: $0.path) }
    }

    /// The examples of the doc comments in `text`: each run of `///` lines indented as code after a blank one -
    /// indented further after words, a line goes on with them - blank `///` lines within it kept.
    static func examples(in text: String, file: String) -> [Example] {
        var examples: [Example] = []
        var code: [String] = []
        var start = 0
        var afterWords = false
        func close() {
            while code.last == "" { code.removeLast() }
            if !code.isEmpty { examples.append(Example(file: file, line: start, source: code.joined(separator: "\n"))) }
            code = []
        }
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let comment = line.drop { $0 == " " }
            let blank = comment.hasPrefix("///") && comment.dropFirst(3).allSatisfy { $0 == " " }
            if comment.hasPrefix("///     "), !code.isEmpty || !afterWords {
                if code.isEmpty { start = index + 1 }
                code.append(String(comment.dropFirst(8)))
            } else if !code.isEmpty, blank {
                code.append("")
            } else {
                close()
                afterWords = comment.hasPrefix("///") && !blank
            }
        }
        close()
        return examples
    }

    /// The example as a file to compile, beside the names examples lean on (`DocCommentPrelude`): a function's body,
    /// or the file itself where the example holds what only a file can.
    static func wrap(_ example: Example) -> String {
        let source = example.source
            .replacingOccurrences(of: "fileprivate ", with: "")
            .replacingOccurrences(of: "private ", with: "")
            .replacingOccurrences(of: "{ … }", with: "{}")
        let head = "import StateUI\nimport StateUITesting\n\n" + DocCommentPrelude.text + "\n"
        if DocumentationExamplesTests.Example(document: example.file, line: example.line, source: source).fileScope {
            return head + source + "\n"
        }
        let body = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")
        return head + "@MainActor func docCommentExample() async throws {\n\(body)\n}\n"
    }
}
