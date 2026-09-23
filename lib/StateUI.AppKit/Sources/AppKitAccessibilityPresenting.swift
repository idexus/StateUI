// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A view wrapping one native control, which assistive technology meets in its place.
/// Design: docs/design/appkit/views.md#accessibility-on-the-control
@MainActor
protocol AppKitAccessibilityPresenting: NSView {
    /// The native control assistive technology meets for this view.
    var presentedControl: NSView { get }
}

#endif
