// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The contracts this host realizes through the core's registry: how each element's view is made, which of its
/// members the view takes, and what it reports.
@MainActor
enum WebRegistrations {
    /// The registry, built once.
    static let registry: Registry<WebDOMView> = {
        let registry = Registry<WebDOMView>()

        words(registry)
        fields(registry)
        layouts(registry)
        pictures(registry)
        shared(registry)

        return registry
    }()

    /// What `WebElement` puts on every view wearing each member's contract.
    static func shared(_ registry: Registry<WebDOMView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.isEnabled)
    }
}
