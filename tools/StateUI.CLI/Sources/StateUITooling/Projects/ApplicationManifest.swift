// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application's manifests - its own `Package.swift` and each head's, `Platforms/<Host>/Package.swift` - as the tool
/// rewrites them, each naming a StateUI checkout by the path from its own folder.
/// Design: docs/design/tooling/projects.md#a-library-changed
enum ApplicationManifest {
    /// The manifests of `application` naming `checkout`, each with its new text; those naming it already left out.
    static func naming(_ checkout: URL, in application: URL) throws -> [(manifest: URL, text: String)] {
        try manifests(of: application).compactMap { try naming(checkout, manifest: $0) }
    }

    /// The application's own manifest, then each of its heads'.
    static func manifests(of application: URL) -> [URL] {
        let heads = HostFamily.allCases.map {
            application.appendingPathComponent("Platforms").appendingPathComponent($0.folder).appendingPathComponent("Package.swift")
        }
        return [application.appendingPathComponent("Package.swift")]
            + heads.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// `manifest` naming `checkout`, and its new text; nil where it names it already.
    private static func naming(_ checkout: URL, manifest: URL) throws -> (manifest: URL, text: String)? {
        let text = try String(contentsOf: manifest, encoding: .utf8)
        guard let old = text.firstMatch(of: /\.package\(name: "StateUIRoot", path: "([^"]*)"\)/)?.output.1 else {
            throw ToolingError(
                .invalidConfiguration,
                "\(manifest.path) names no checkout as `.package(name: \"StateUIRoot\", path: ...)`; name it by hand.")
        }
        let new = ApplicationMaker.relativePath(from: manifest.deletingLastPathComponent(), to: checkout)
        // One pass: a new path that begins as the old one did is never read again.
        let named = "path: \"" + NSRegularExpression.escapedPattern(for: String(old)) + "(?=[\"/])"
        let renamed = try NSRegularExpression(pattern: named).stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: "path: \"\(new)"))
        return renamed == text ? nil : (manifest, renamed)
    }
}
