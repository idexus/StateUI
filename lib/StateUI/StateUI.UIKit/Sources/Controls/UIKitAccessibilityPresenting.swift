// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A view composing one native control, its `presentedControl`, which VoiceOver meets in its place.
/// Design: docs/design/platforms/uikit/controls.md#accessibility
@MainActor
protocol UIKitAccessibilityPresenting: UIView {
    var presentedControl: UIView { get }
}
#endif
