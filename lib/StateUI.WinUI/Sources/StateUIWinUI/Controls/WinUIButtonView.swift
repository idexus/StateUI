// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI `Button`: its caption, its look, whether it takes a press, and the click it raises.
@MainActor
final class WinUIButtonView: WinUIView {
    /// What the button does when the user clicks it, holds it down and lets it go.
    var onClicked: (() -> Void)?
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    init() {
        super.init { number in stateui_winui_button_make(number) }
    }

    /// The caption.
    func setText(_ text: String) {
        stateui_winui_set_caption(handle, text)
    }

    /// The caption the button shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    /// What fills the button, its outline and its shape; nil for the platform's own.
    func setLook(background: HostValue?, stroke: HostValue?, strokeWidth: Double?, shape: HostValue?) {
        let radius: Double = switch shape.map(BoxArithmetic.outline) {
        case .roundedRectangle(let radius)?: radius
        case .ellipse?: .greatestFiniteMagnitude
        case .rectangle?: 0
        case nil: -1
        }
        WinUIBrush(background).withRelayBrush { fill in
            WinUIBrush(stroke).withRelayBrush { outline in
                stateui_winui_button_set_look(
                    handle, fill, outline, BoxArithmetic.outlineWidth(stroke: stroke, width: strokeWidth), radius,
                    PressedFill.underPointer, PressedFill.pressed)
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func clicked() {
        onClicked?()
    }

    override func held(_ holding: Bool) {
        (holding ? onPressed : onReleased)?()
    }

    override func detach() {
        super.detach()
        onClicked = nil
        onPressed = nil
        onReleased = nil
    }
}
