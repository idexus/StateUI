// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A view that draws pictures the application supplies, and is given the way
/// to resolve each by its file name.
///
/// What crosses the boundary for a picture is a NAME, and the files behind it
/// belong to the renderer: it knows the resource directory and keeps the cache
/// over it, so one name is loaded once however many views draw it. A
/// registration is made once for the whole process and has no renderer to ask,
/// so the host gives every view it makes the means to resolve one.
@MainActor
protocol AppKitPictureResolving: NSView {
    /// Answers the picture for a file name - nil where the application has no
    /// such file. Given by the host where the view is made.
    var picture: ((String) -> NSImage?)? { get set }
}

#endif
