// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// One of UIKit's controls StateUI makes, answering VoiceOver with what the tree says (`authored`) before its own.
/// Design: docs/design/platforms/uikit/controls.md#accessibility
@MainActor
protocol UIKitAccessibilityAuthoring: UIView {
    var authored: UIKitAuthoredAccessibility { get set }
}
#endif
