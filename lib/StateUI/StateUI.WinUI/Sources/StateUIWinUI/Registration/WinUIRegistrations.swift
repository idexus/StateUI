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
        items(registry)
        shared(registry)

        return registry
    }()

    /// What `WinUIElement` puts on every view wearing each member's contract, and what the host layer's rules realize
    /// on every element WinUI shows - each view drawn moved, turned, scaled and tipped over its place.
    static func shared(_ registry: Registry<WinUIView>) {
        registry.everyElementMeetsAssistiveTechnology()
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.isEnabled)
        registry.everyElementRealizes(VisualElementContract.background)
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
        registry.everyElementHearsTheUser()
        registry.everyElementDragsAndDrops()
        registry.everyElementTakesDroppedFiles()
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }
}
