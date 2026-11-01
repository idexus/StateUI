// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A picture as pixels or as a drawing.
extension NSImage {
    /// Whether the picture is a file's drawing - an SVG's, a PDF's - rather than pixels; an icon - a template - AppKit
    /// tints, and one drawn by code may draw on the main thread alone: both stand as they are.
    var isDrawing: Bool {
        !isTemplate && !representations.isEmpty
            && !representations.contains { $0 is NSBitmapImageRep || $0 is NSCustomImageRep }
    }

    /// The pixels the picture holds: its largest bitmap's; a drawing holds none.
    var pixels: Int {
        representations.compactMap { $0 as? NSBitmapImageRep }.map { $0.pixelsWide * $0.pixelsHigh }.max() ?? 0
    }
}
#endif
