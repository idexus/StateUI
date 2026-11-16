// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application's `Package.swift` as the tool rewrites it, naming a StateUI checkout by the path from it.
/// Design: docs/design/tooling/projects.md#a-library-changed
enum ApplicationManifest {
    /// The manifest of `application` naming `checkout`, and its new text; nil where it names it already.
    static func naming(_ checkout: URL, in application: URL) throws -> (manifest: URL, text: String)? {
        let manifest = application.appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        guard let old = text.firstMatch(of: /\.package\(name: "StateUIRoot", path: "([^"]*)"\)/)?.output.1 else {
            throw ToolingError(
                .invalidConfiguration,
                "\(manifest.path) names no checkout as `.package(name: \"StateUIRoot\", path: ...)`; name it by hand.")
        }
        let new = ApplicationMaker.relativePath(from: application, to: checkout)
        let renamed = text.replacingOccurrences(of: "path: \"\(old)\"", with: "path: \"\(new)\"")
            .replacingOccurrences(of: "path: \"\(old)/", with: "path: \"\(new)/")
        return renamed == text ? nil : (manifest, renamed)
    }
}
