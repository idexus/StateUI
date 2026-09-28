// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications, for the guards that read them as files: the ones under
// apps/, and a walk over one that leaves out what tools write beside the
// sources.

import Foundation
import XCTest

extension SourceTree {
    /// Whether a name is what tools write into a tree beside its sources: the
    /// builds' output, SwiftPM's scratch and resolve file, and Finder's folder
    /// settings. They belong to one machine, and a fresh clone has none of
    /// them. Every `.build*` directory is one, as .gitignore says: SwiftPM's
    /// and each host's, a host's that left included.
    static func isByproduct(_ name: String) -> Bool {
        byproducts.contains(name) || name.hasPrefix(".build") || name.hasSuffix(".user")
    }

    private static let byproducts: Set<String> = [
        "bin", "obj", ".swiftpm", "Package.resolved", ".DS_Store",
        // Gradle's beside a head, and the language server's settings the
        // editor extension writes beside each application.
        ".gradle", ".sourcekit-lsp",
        // What the editor extension's own build writes: its packages and its
        // compiled code.
        "node_modules", "out",
    ]

    /// Every application under `apps/`, sorted by name.
    ///
    /// A directory holding nothing but byproducts is no application: it is
    /// what a build leaves of an application that is gone, and naming it as a
    /// broken one sends the reader after something that does not exist.
    static func applications() throws -> [URL] {
        let apps = repository.appendingPathComponent("apps")

        return try FileManager.default.contentsOfDirectory(atPath: apps.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
            .map { apps.appendingPathComponent($0) }
            .filter { directory in
                var isDirectory: ObjCBool = false

                guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                      isDirectory.boolValue,
                      let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
                else { return false }

                return entries.contains { !SourceTree.isByproduct($0) }
            }
    }

    /// Every file under a directory, as its path relative to that directory:
    /// sorted, with forward slashes on every platform, and without anything
    /// under a name `leftOut` answers for - the byproducts, unless the caller
    /// says otherwise. A directory so named is never entered.
    ///
    /// A missing directory has no files, so a caller asserts the answer is not
    /// empty wherever emptiness would let its check pass on nothing.
    static func files(
        under directory: URL,
        leavingOut leftOut: (String) -> Bool = SourceTree.isByproduct
    ) -> [String] {
        var found: [String] = []

        func walk(_ relative: String) {
            let here = relative.isEmpty ? directory : directory.appendingPathComponent(relative)

            guard let names = try? FileManager.default.contentsOfDirectory(atPath: here.path)
            else { return }

            for name in names where !leftOut(name) {
                let path = relative.isEmpty ? name : relative + "/" + name
                var isDirectory: ObjCBool = false

                guard FileManager.default.fileExists(
                    atPath: here.appendingPathComponent(name).path, isDirectory: &isDirectory)
                else { continue }

                if isDirectory.boolValue {
                    walk(path)
                } else {
                    found.append(path)
                }
            }
        }

        walk("")
        return found.sorted()
    }

    /// A file of HelloWorld's as it reads under another name: the name
    /// replaced wherever it appears, and its lower-case spelling - the
    /// application identifier's - likewise. What is not text is left as it is.
    static func helloWorld(_ contents: Data, renamedTo name: String) -> Data {
        guard let text = String(data: contents, encoding: .utf8) else { return contents }

        return Data(
            text.replacingOccurrences(of: "HelloWorld", with: name)
                .replacingOccurrences(of: "helloworld", with: name.lowercased())
                .utf8)
    }
}

/// Fails when two files differ, showing both as text where they are text - a
/// byte count says nothing about which line moved.
func assertSameFile(
    _ written: Data,
    _ expected: Data,
    _ message: @autoclosure () -> String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard written != expected else { return }

    if let text = String(data: written, encoding: .utf8),
       let wanted = String(data: expected, encoding: .utf8),
       text != wanted {
        XCTAssertEqual(text, wanted, message(), file: file, line: line)
    } else {
        XCTFail(message(), file: file, line: line)
    }
}
