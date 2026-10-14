// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

@_spi(Host) import StateUIHost

/// A view that draws pictures, given the renderer's way to resolve one - a file, an icon or bytes.
/// Design: docs/design/platforms/appkit/views.md#pictures
@MainActor
protocol AppKitPictureResolving: NSView {
    /// The native image for a picture; nil where there is none such.
    var picture: ((HostPicture) -> NSImage?)? { get set }
}

#endif
