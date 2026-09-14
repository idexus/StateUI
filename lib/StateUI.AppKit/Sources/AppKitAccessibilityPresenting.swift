// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A host view that wraps one native control, and so hands assistive
/// technology that control in its own place: the author's words, role and
/// participation are written where VoiceOver meets the control, not on the
/// view around it.
@MainActor
protocol AppKitAccessibilityPresenting: NSView {
    /// The native control assistive technology meets for this view.
    var presentedControl: NSView { get }
}

#endif
