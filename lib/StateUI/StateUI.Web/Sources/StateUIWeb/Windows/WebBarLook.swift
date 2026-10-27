// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebDOMView {
    /// Shows what the application says of a bar's button or group over the bar's own look: its box - what fills it,
    /// its outline, its shape, the room inside it - and its words' font and color, each as `value` reads it; what it
    /// leaves unsaid stands as the bar's look has it.
    /// Design: docs/design/platforms/web/pages.md#a-bars-items-in-the-applications-look
    func showBarLook(_ value: (Prop) -> HostValue?) {
        let material = HostMaterial(value(.background))
        setBox(WebBox(
            fill: material.paint, stroke: value(.stroke), lineWidth: value(.lineWidth)?.number, shape: value(.shape),
            material: material.blur == nil ? nil : material))
        setPadding(value(.padding).flatMap(Insets.init(propValue:)))
        for (name, said) in WebCSS.font(TextMembers.look(reading: value)) { style(name, said) }
    }
}

extension WebElement {
    /// The pointer over the bar's item coming or going, told as a view's is - a finger hovering over nothing - or a
    /// press on it beginning or ending.
    func hearOnBar(_ event: Event) {
        guard let host, element.handler(event) != nil else { return }
        if event == .pressed || event == .released { return send(event, []) }
        _ = element.hear(.pointer(event, Point(x: 0, y: 0), byFinger: WebRelay.eventPointer.kind == .touch), in: host.runtime)
    }
}
