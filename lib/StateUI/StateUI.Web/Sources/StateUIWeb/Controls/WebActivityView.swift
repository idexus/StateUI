// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ActivityIndicator: a ring turning while work goes on, a busy progress bar for assistive technology; stopped,
/// it shows nothing and keeps its room.
/// Design: docs/design/platforms/web/controls.md#indicators
@MainActor
final class WebActivityView: WebDOMView {
    init() {
        super.init(tag: "div")
        attribute("class", "stateui-activity")
        attribute("role", "progressbar")
        setRunning(false)
    }

    override var role: String? { "progressbar" }

    func setRunning(_ running: Bool) {
        attribute("data-running", running ? "" : nil)
        attribute("aria-busy", running ? "true" : "false")
    }

    /// The ring's colour; nil for the page's accent.
    func setTint(_ tint: HostValue?) {
        style("--stateui-on", WebCSS.color(tint))
    }
}
