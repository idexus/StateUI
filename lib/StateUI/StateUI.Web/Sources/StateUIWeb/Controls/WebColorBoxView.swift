// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ColorBox: a swatch of one colour filling a `<div>`, its corners rounded as it says, over the box's background.
@MainActor
final class WebColorBoxView: WebDOMView {
    private let swatch = WebDOMView(tag: "span")

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-color-box")
        WebRelay.insert(swatch.node, into: node, at: 0)
    }

    func apply(color: HostValue?, corners: CornerRadius?) {
        swatch.style("background", WebCSS.color(color))
        let radii = BoxArithmetic.clockwise(corners)
        swatch.style("border-radius", radii.allSatisfy({ $0 == 0 }) ? nil : radii.map { WebCSS.pixels($0)! }.joined(separator: " "))
    }

    override func detach() {
        swatch.detach()
        super.detach()
    }
}
