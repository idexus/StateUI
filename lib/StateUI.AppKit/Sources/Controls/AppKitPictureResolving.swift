// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A view that draws the application's pictures, given the renderer's way to resolve a file name.
/// Design: docs/design/platforms/appkit/views.md#pictures
@MainActor
protocol AppKitPictureResolving: NSView {
    /// The picture for a file name; nil where the application has no such file.
    var picture: ((String) -> NSImage?)? { get set }
}

#endif
