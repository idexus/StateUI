// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The elements UIKit realizes, each with its view and the members it takes, and what every view shares.
@MainActor
enum UIKitRegistrations {
    static let registry: Registry<UIView> = {
        let registry = Registry<UIView>()
        text(registry)
        buttons(registry)
        fields(registry)
        pictures(registry)
        toggles(registry)
        values(registry)
        indicators(registry)
        pickers(registry)
        layouts(registry)
        shared(registry)
        return registry
    }()

    /// What every view takes the same way: whether it shows, how opaque it is, whether it takes input, its words
    /// for VoiceOver, its place, and how it is drawn over it.
    static func shared(_ registry: Registry<UIView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.isEnabled)
        registry.everyElementRealizes(VisualElementContract.accessibilityLabel)
        registry.everyElementRealizes(VisualElementContract.accessibilityHint)
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
    }
}
#endif
