// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation

/// The artwork a program carries, which `StateUIAppKit.run()` shows where it is handed none: the `Images` in the
/// program's bundle, else in the `Resources` beside it, where `.scripts/AppKit/deploy.sh` lays a deployed copy's;
/// and the icon beside it - a bundle shows its own.
struct CarriedArtwork {
    /// Where the pictures are; nil where the program carries none.
    let images: URL?

    /// The complete image shown for the running application; nil where the program carries none beside it.
    let icon: URL?

    /// What `program` carries, its bundle's resources at `bundleResources`.
    init(program: URL?, bundleResources: URL?) {
        let beside = program?.deletingLastPathComponent().appendingPathComponent("Resources", isDirectory: true)
        let stands = { (url: URL) in FileManager.default.fileExists(atPath: url.path) }

        images = [bundleResources, beside]
            .compactMap { $0?.appendingPathComponent("Images", isDirectory: true) }
            .first(where: stands)
        icon = beside.map { $0.appendingPathComponent("AppIcon/appicon_macos.svg") }.flatMap { stands($0) ? $0 : nil }
    }
}
#endif
