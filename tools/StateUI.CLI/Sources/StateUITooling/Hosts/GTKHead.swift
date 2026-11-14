// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// An application's GTK head, laid out from what SwiftPM built: the program, every library SwiftPM laid beside it -
/// which it finds there - and the application's `Resources/Images` as they are, since GTK draws SVG.
/// Design: docs/design/tooling/gtk-heads.md
struct GTKHead {
    var application: URL
    /// The product SwiftPM built: `GalleryGTK`.
    var product: String
    /// The folder SwiftPM laid the product and the libraries in.
    var binaries: URL

    /// Lays the head in `staging`.
    func assemble(in staging: URL) throws {
        let files = FileManager.default
        try files.copyItem(at: binaries.appendingPathComponent(product), to: staging.appendingPathComponent(product))
        for library in try files.contentsOfDirectory(atPath: binaries.path).sorted() where library.hasSuffix(".so") {
            try files.copyItem(at: binaries.appendingPathComponent(library), to: staging.appendingPathComponent(library))
        }
        let images = application.appendingPathComponent("Resources/Images")
        if files.fileExists(atPath: images.path) {
            try files.copyItem(at: images, to: staging.appendingPathComponent("Images"))
        }
    }

    /// The application ID the head runs as - `GTKHost.run(applicationID: "com.stateui.gallery")` - which names its
    /// desktop entry and icon; `nil` where the head names none.
    static func applicationID(of application: URL) -> String? {
        let head = application.appendingPathComponent("Platforms/GTK/main.swift")
        guard let text = try? String(contentsOf: head, encoding: .utf8) else { return nil }
        return text.firstMatch(of: /applicationID: "([^"]+)"/).map { String($0.1) }
    }
}
