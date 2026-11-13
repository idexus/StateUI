// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A StateUI checkout on disk: the library's repository, cloned by hand or as a release.
/// Design: docs/design/tooling/projects.md#a-checkout
struct Checkout: Sendable {
    /// Its root.
    let root: URL

    /// The checkout at `directory`, where one stands: the library's manifest, its heads' package and the starter.
    init?(at directory: URL) {
        let files = FileManager.default
        let marks = ["Package.swift", "lib/StateUI.Head/Package.swift", "apps/HelloWorld/Package.swift"]
        guard marks.allSatisfy({ files.fileExists(atPath: directory.appendingPathComponent($0).path) }) else {
            return nil
        }
        root = directory
    }

    /// The checkout `folder` stands in: itself, or the nearest folder above it that is one.
    static func holding(_ folder: URL) -> Checkout? {
        var current = RealPath.of(folder)
        while true {
            if let checkout = Checkout(at: current) { return checkout }
            guard let parent = Folders.parent(of: current) else { return nil }
            current = parent
        }
    }

    /// The release the library states: its `ApplicationInfo.libraryVersion`.
    var release: String? {
        let home = root.appendingPathComponent("lib/StateUI/Core/Sources/Types/Environment/ApplicationInfo.swift")
        guard let text = try? String(contentsOf: home, encoding: .utf8),
              let start = text.range(of: "libraryVersion = \""),
              let end = text[start.upperBound...].firstIndex(of: "\"")
        else { return nil }
        return String(text[start.upperBound..<end])
    }

    /// The checkout as a library: its release, and the commit it stands at with whether it differs, where Git says.
    func library(runner: ProcessRunner, tools: ToolResolver) async -> Library {
        let revision = await Self.lines(runner, tools, ["-C", root.path, "rev-parse", "HEAD"])?.first
        let changes = revision == nil
            ? nil : await Self.lines(runner, tools, ["-C", root.path, "status", "--porcelain", "--untracked-files=no"])
        return Library(rootUri: FileURI.string(root), release: release, revision: revision, dirty: changes.map { !$0.isEmpty })
    }

    private static func lines(_ runner: ProcessRunner, _ tools: ToolResolver, _ arguments: [String]) async -> [String]? {
        let output = Gathered()
        let request = ProcessRequest(tools.git, arguments: arguments, timeout: .seconds(30))
        guard let outcome = try? await runner.run(request, output: output.add), outcome.succeeded else { return nil }
        return output.lines(of: .standardOutput)
    }
}
