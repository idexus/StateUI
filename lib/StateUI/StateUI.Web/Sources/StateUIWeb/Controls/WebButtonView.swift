// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Button: the browser's `<button>`, its look the browser's own until the application gives its box a fill, an
/// outline or a shape.
/// Design: docs/design/platforms/web/controls.md#a-button
@MainActor
final class WebButtonView: WebDOMView, WebWordsView {
    var onClicked: () -> Void = {}

    init() {
        super.init(tag: "button")
        attribute("type", "button")
        listen("click") { [weak self] in self?.onClicked() }
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The box the application draws in place of the browser's: its fill, its outline and its shape; with none of
    /// them, the browser's own button.
    func setBox(fill: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let drawn = fill != nil || stroke != nil || shape != nil
        style("background", drawn ? WebCSS.fill(fill) ?? "transparent" : nil)
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        style("border", drawn ? (width > 0 ? "\(WebCSS.pixels(width)!) solid \(WebCSS.fill(stroke) ?? "currentColor")" : "none") : nil)
        style("border-radius", drawn ? WebCSS.corners(BoxArithmetic.outline(shape)) : nil)
    }
}
