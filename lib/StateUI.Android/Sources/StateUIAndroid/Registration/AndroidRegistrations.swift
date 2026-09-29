// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it reports.
@MainActor
enum AndroidRegistrations {
    /// The registry, built once.
    static let registry: Registry<AndroidView> = {
        let registry = Registry<AndroidView>()

        text(registry)
        buttons(registry)
        toggles(registry)
        pickers(registry)
        dates(registry)
        values(registry)
        fields(registry)
        layouts(registry)
        pictures(registry)
        shapes(registry)
        drawing(registry)
        indicators(registry)
        web(registry)
        items(registry)
        shared(registry)

        return registry
    }()

    /// The acts this host performs, whichever element each is aimed at; the host layer's performer
    /// (`HostActPerformer`) answers exactly these, and refuses every other by name.
    static let acts: [any ContractMember] = [
        VisualElementContract.focus, VisualElementContract.unfocus,
        ApplicationContract.alert, ApplicationContract.announce, ApplicationContract.chooseAction,
        ApplicationContract.confirm, ApplicationContract.currentTime, ApplicationContract.currentTimeZone,
        ApplicationContract.handlerFailed, ApplicationContract.hideOnScreenKeyboard, ApplicationContract.persistValue,
        ApplicationContract.prompt, ApplicationContract.utcOffset,
        WebViewContract.evaluateJavaScript, WebViewContract.goBack, WebViewContract.goForward, WebViewContract.reload,
        ItemsViewContract.scrollTo,
    ]

    /// What `AndroidElement` puts on every view wearing each member's contract, by the host layer's rules.
    static func shared(_ registry: Registry<AndroidView>) {
        registry.everyElementMeetsAssistiveTechnology()
        registry.everyElementHearsTheUser()
        registry.everyElementTakesItsPlace()
        registry.everyElementIsDrawnOverItsPlace()
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.background)
        registry.everyElementRaises(VisualElementContract.isFocusedChanged)
    }

    /// Puts `TextMembers.members` on a text view: its words in their case, their look, and the room around them.
    static func applyText<Realized: ElementContract>(_ view: AndroidTextView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { view.setText(words) }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
