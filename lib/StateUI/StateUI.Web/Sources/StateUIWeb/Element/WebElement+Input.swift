// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the user does to the element's view with a finger, a pen or the mouse, heard by the host layer's rule.
/// Design: docs/design/platforms/web/input.md
extension WebElement {
    /// Listens for what the element asks to hear, once for each kind; a kind it stops asking for is heard and let go.
    func listenForTheUser() {
        guard let view else { return }
        let hearing = element.hearing
        if hearing.contains(.taps), !listening.contains(.taps) {
            listening.insert(.taps)
            view.listen("click") { [weak self] in self?.heard(.taps, .tap(run: WebRelay.eventClicks)) }
            view.listen("activate") { [weak self] in self?.heard(.taps, .tap(run: 0)) }
        }
        if hearing.contains(.pointer), !listening.contains(.pointer) {
            listening.insert(.pointer)
            for (event, said) in Self.pointerEvents {
                view.listen(event) { [weak self] in self?.heard(.pointer, .pointer(said, WebRelay.eventPoint)) }
            }
        }
        view.isTapped = hearing.contains(.taps) && !(view is WebButtonView) && !(view is WebTextFieldView)
    }

    /// The DOM's pointer events, and what each says to the element.
    private static let pointerEvents: [(String, Event)] = [
        ("pointerenter", .pointerEntered), ("pointerleave", .pointerExited), ("pointermove", .pointerMoved),
        ("pointerdown", .pointerPressed), ("pointerup", .pointerReleased),
    ]

    private func heard(_ kind: Hearing, _ input: HeardInput) {
        guard let host, element.hearing.contains(kind) else { return }
        element.hear(input, in: host.runtime)
    }
}
