// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The folder a package is laid in: made anew only where none stands, where it stands empty, or where a package was
/// laid before - its mark says so - and never a folder holding the application, the project or the checkout.
/// Design: docs/design/tooling/builds.md#a-package
enum PackageOutput {
    /// The file a laid package's folder holds, saying which head was laid there.
    static let mark = ".stateui-package"

    /// Refuses `output` before any build: one that is, or holds, a folder of `keeping`, or one holding what no
    /// package laid.
    ///
    /// - Throws: ``ToolingError`` - `INVALID_CONFIGURATION` for a folder holding one kept, `ALREADY_EXISTS` for one
    ///   holding something else.
    static func check(_ output: URL, keeping: [URL]) throws(ToolingError) {
        let target = RealPath.of(output).pathComponents
        for kept in keeping {
            let held = RealPath.of(kept).pathComponents
            if held.starts(with: target) {
                throw ToolingError(
                    .invalidConfiguration,
                    "A package is not laid in \(output.path): it holds \(kept.path). Name a folder of its own.")
            }
        }
        let files = FileManager.default
        var folder: ObjCBool = false
        guard files.fileExists(atPath: output.path, isDirectory: &folder) else { return }
        let held = (try? files.contentsOfDirectory(atPath: output.path)) ?? []
        guard folder.boolValue, held.isEmpty || held.contains(mark) else {
            throw ToolingError(
                .alreadyExists,
                "\(output.path) holds what no package laid; empty it, or name another folder for the package.")
        }
    }

    /// `output` made anew for `head`, its mark in it.
    static func lay(_ output: URL, head: String) throws {
        let files = FileManager.default
        if files.fileExists(atPath: output.path) { try files.removeItem(at: output) }
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        try Data("\(head)\n".utf8).write(to: output.appendingPathComponent(mark))
    }
}
