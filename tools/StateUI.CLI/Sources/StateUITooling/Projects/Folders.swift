// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Folders climbed one at a time towards the root.
/// Design: docs/design/tooling/projects.md#a-project-read
enum Folders {
    /// The folder holding `folder`, or `nil` at a root - `/`, or a drive's on Windows. Its path is never rewritten,
    /// so a real path stays real.
    static func parent(of folder: URL) -> URL? {
        let components = folder.pathComponents
        #if os(Windows)
        guard components.count > 2 else { return nil }
        #else
        guard components.count > 1 else { return nil }
        #endif
        let parent = folder.deletingLastPathComponent()
        let above = parent.pathComponents
        return above.count < components.count && Array(components.prefix(above.count)) == above ? parent : nil
    }

    /// Why nothing new can be put at `destination`, or `nil`: an empty folder or no entry at all takes it.
    static func taken(_ destination: URL) -> String? {
        let files = FileManager.default
        if let held = try? files.contentsOfDirectory(atPath: destination.path) {
            return held.isEmpty ? nil : "\(destination.path) already holds files."
        }
        return files.fileExists(atPath: destination.path) ? "\(destination.path) already exists." : nil
    }
}
