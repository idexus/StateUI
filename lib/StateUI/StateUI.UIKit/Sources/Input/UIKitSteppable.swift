// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI

/// A view StateUI draws, which VoiceOver steps up and down while its element says it is adjustable.
/// Design: docs/design/platforms/uikit/controls.md#accessibility
@MainActor
protocol UIKitSteppable: UIView {
    /// What a reader's step up or down performs; nil while the element is not adjustable.
    var stepAction: ((AccessibilityAdjustment) -> Void)? { get set }
}
#endif
