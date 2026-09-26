// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it reports.
@MainActor
enum WinUIRegistrations {
    /// The registry, built once.
    static let registry: Registry<WinUIView> = {
        let registry = Registry<WinUIView>()

        text(registry)
        buttons(registry)
        toggles(registry)
        values(registry)
        indicators(registry)
        pickers(registry)
        dates(registry)
        fields(registry)
        pictures(registry)
        shapes(registry)
        drawing(registry)
        layouts(registry)
        shared(registry)

        return registry
    }()

    /// What `WinUIElement` puts on every view wearing each member's contract, and what the host layer's rules realize
    /// on every element WinUI shows. A view is drawn moved, turned and scaled flat: WinUI turns it about no other
    /// axis.
    static func shared(_ registry: Registry<WinUIView>) {
        registry.everyElementMeetsAssistiveTechnology()
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementTakesItsPlace()
        registry.everyElementRealizes(VisualElementContract.translationX)
        registry.everyElementRealizes(VisualElementContract.translationY)
        registry.everyElementRealizes(VisualElementContract.rotation)
        registry.everyElementRealizes(VisualElementContract.scale)
        registry.everyElementRealizes(VisualElementContract.scaleX)
        registry.everyElementRealizes(VisualElementContract.scaleY)
        registry.everyElementRealizes(VisualElementContract.pivotX)
        registry.everyElementRealizes(VisualElementContract.pivotY)
        registry.everyElementHearsTheUser()
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }
}
