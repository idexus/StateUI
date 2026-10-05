// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ProgressBar: the browser's `<progress>`, its share of the work done from 0 to 1.
/// Design: docs/design/platforms/web/controls.md#indicators
@MainActor
final class WebProgressView: WebDOMView {
    init() {
        super.init(tag: "progress")
        attribute("max", "1")
        setProgress(0)
    }

    func setProgress(_ progress: Double) {
        WebRelay.setNumber(node, "value", ValueArithmetic.share(progress))
    }

    /// The colour of the work done; nil for the page's accent.
    func setTint(_ tint: HostValue?) {
        style("accent-color", WebCSS.color(tint))
        style("--stateui-on", WebCSS.color(tint))
    }
}
