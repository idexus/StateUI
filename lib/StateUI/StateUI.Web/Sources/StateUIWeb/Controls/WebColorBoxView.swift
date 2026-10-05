// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ColorBox: a `<div>` of one colour, its corners rounded as it says.
@MainActor
final class WebColorBoxView: WebDOMView {
    init() {
        super.init(tag: "div")
    }

    func apply(color: HostValue?, corners: CornerRadius?) {
        style("background", WebCSS.color(color))
        let radii = BoxArithmetic.clockwise(corners)
        style("border-radius", radii.allSatisfy({ $0 == 0 }) ? nil : radii.map { WebCSS.pixels($0)! }.joined(separator: " "))
    }
}
