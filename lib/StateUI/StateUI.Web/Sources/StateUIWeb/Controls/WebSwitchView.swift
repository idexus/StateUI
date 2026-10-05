// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Switch: the browser's checkbox with the role of a switch, drawn as one; a CheckBox: the checkbox as it is.
/// Each says when the user turns it.
/// Design: docs/design/platforms/web/controls.md#toggles
@MainActor
final class WebSwitchView: WebDOMView {
    /// The user turned it, to on or off.
    var onToggled: (Bool) -> Void = { _ in }

    init(switch isSwitch: Bool) {
        super.init(tag: "input")
        attribute("type", "checkbox")
        if isSwitch {
            attribute("role", "switch")
            attribute("class", "stateui-switch")
        }
        listen("change") { [weak self] in
            guard let self else { return }
            onToggled(WebRelay.flag(of: node, "checked"))
        }
    }

    override var role: String? { nil }

    func setOn(_ on: Bool) {
        WebRelay.setFlag(node, "checked", on)
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The colour it shows when on; nil for the page's accent.
    func setTint(_ tint: HostValue?) {
        style("accent-color", WebCSS.color(tint))
        style("--stateui-on", WebCSS.color(tint))
    }
}
