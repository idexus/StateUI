// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI `Button`: its caption and its picture, its look, whether it takes a press, and the click it raises.
/// Design: docs/design/platforms/winui/controls.md#a-button
@MainActor
final class WinUIButtonView: WinUIView {
    override var takesDirection: Bool { true }

    /// What the button does when the user clicks it, holds it down and lets it go.
    var onClicked: (() -> Void)?
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    /// What the button shows, as it was last written, and the height its picture beside the words was bounded to.
    private var shown: Shown?
    private var bounded: Double?
    private var words = ""
    private var look = Shown()

    init() {
        super.init { number in stateui_winui_button_make(number) }
    }

    /// The caption.
    func setText(_ text: String) {
        words = text
        show()
    }

    /// The picture beside the caption - the files it may stand in (`PictureArithmetic.files`), none for none -
    /// where it stands, how far from the words (nil for WinUI's own gap), and how it fills the button alone.
    func setIcon(_ icon: [String], position: IconPosition, spacing: Double?, aspect: ContentMode) {
        look.icon = icon
        look.position = position
        look.spacing = spacing
        look.aspect = aspect
        show()
    }

    /// How a caption too long for the button breaks; nil for WinUI's own, one line.
    func setLineBreak(_ lineBreak: LineBreak?) {
        look.lineBreak = lineBreak
        show()
    }

    /// Writes what the button shows: all of it where its shape changed, else the words in their place.
    private func show() {
        var next = look
        next.hasWords = !words.isEmpty
        guard next != shown else {
            stateui_winui_button_set_words(handle, words)
            return
        }
        shown = next
        bounded = nil
        stateui_winui_button_set_content(
            handle, words, WinUIStrings.lines(next.icon), next.position.rawValue, next.spacing ?? -1,
            next.aspect.rawValue, next.lineBreak?.wraps ?? false, next.lineBreak?.truncates ?? false)
    }

    /// A picture beside the words stands no taller than the button's place leaves it.
    /// Design: docs/design/platforms/winui/controls.md#a-button
    override func layout(_ place: Rect) {
        if let shown, shown.hasWords, !shown.icon.isEmpty, bounded != place.height {
            bounded = place.height
            stateui_winui_button_set_room(handle, place.height)
        }
        super.layout(place)
    }

    /// The shape of what a button shows: whether it has words, and its picture and how it stands.
    private struct Shown: Equatable {
        var hasWords = false
        var icon: [String] = []
        var position = IconPosition.leading
        var spacing: Double?
        var aspect = ContentMode.fit
        var lineBreak: LineBreak?
    }

    /// The caption the button shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    /// What fills the button, its outline and its shape; nil for the platform's own.
    func setLook(background: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let radius: Double = switch shape.map(BoxArithmetic.outline) {
        case .roundedRectangle(let radius)?: radius
        case .ellipse?: .greatestFiniteMagnitude
        case .rectangle?: 0
        case nil: -1
        }
        let (fill, outline) = (WinUIBrush(background), WinUIBrush(stroke))
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        paint("look", followsSize: fill.followsSize || outline.followsSize) { [handle] size in
            fill.withRelayBrush(over: size) { fill in
                outline.withRelayBrush(over: size) { outline in
                    stateui_winui_button_set_look(
                        handle, fill, outline, width, radius, PressedFill.underPointer, PressedFill.pressed)
                }
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
