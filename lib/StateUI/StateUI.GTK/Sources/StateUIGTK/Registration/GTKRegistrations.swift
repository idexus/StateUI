// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The contracts this host realizes through the core's registry: how each element's view is made, which of its
/// members the view takes, and what it reports.
@MainActor
enum GTKRegistrations {
    /// The registry, built once.
    static let registry: Registry<GTKView> = {
        let registry = Registry<GTKView>()

        text(registry)
        buttons(registry)
        toggles(registry)
        values(registry)
        indicators(registry)
        pickers(registry)
        dates(registry)
        fields(registry)
        layouts(registry)
        pictures(registry)
        shapes(registry)
        canvas(registry)
        items(registry)
        shared(registry)

        return registry
    }()

    /// What `GTKElement` puts on every view wearing each member's contract, and what the host layer's rules realize
    /// on every element GTK shows.
    static func shared(_ registry: Registry<GTKView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.isEnabled)
        // GTK 4 identifies an accessible by a GtkBuilder file's id alone: it is met by its role, its label and its place.
        registry.everyElementMeetsAssistiveTechnology(identifying: false)
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
        registry.everyElementHearsTheUser()
        registry.everyElementDragsAndDrops()
        registry.everyElementTakesDroppedFiles()
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }

    /// The acts this host performs: every host's (`HostActs.performed`), the files (`HostActs.files`) and a list
    /// scrolled to an item.
    static let acts: [any ContractMember] =
        HostActs.performed + HostActs.files + [ItemsViewContract.scrollTo]

}
