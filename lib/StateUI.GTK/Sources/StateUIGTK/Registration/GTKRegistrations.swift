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
        fields(registry)
        layouts(registry)
        pictures(registry)
        shapes(registry)
        shared(registry)

        return registry
    }()

    /// What `GTKElement` puts on every view wearing each member's contract, and what the host layer's rules realize
    /// on every element GTK shows.
    static func shared(_ registry: Registry<GTKView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.isEnabled)
        registry.everyElementRealizes(VisualElementContract.accessibilityLabel)
        registry.everyElementRealizes(VisualElementContract.accessibilityHint)
        registry.everyElementRealizes(VisualElementContract.accessibilityHeadingLevel)
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
        registry.everyElementHearsTheUser()
    }

    /// The acts `GTKActPerformer` performs.
    static let acts: [any ContractMember] = [
        VisualElementContract.focus, VisualElementContract.unfocus,
        ApplicationContract.alert, ApplicationContract.announce, ApplicationContract.chooseAction,
        ApplicationContract.confirm, ApplicationContract.currentTime, ApplicationContract.currentTimeZone,
        ApplicationContract.handlerFailed, ApplicationContract.hideOnScreenKeyboard, ApplicationContract.persistValue,
        ApplicationContract.prompt, ApplicationContract.utcOffset,
    ]

}
