// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI `Button`: its caption and its picture, its look, whether it takes a press, and the click it raises.
/// Design: docs/design/platforms/winui/controls.md#a-button
@MainActor
final class WinUIButtonView: WinUIView {
    /// The role the tree gave the button; nil for none.
    private(set) var role: ButtonRole?

    /// What the button stands for: the window's main action wears WinUI's accent style. WinUI has no look for the way
    /// out or for a destructive action.
    func setRole(_ role: ButtonRole?) {
        guard role != self.role else { return }
        self.role = role
        stateui_winui_button_set_accent(handle, role == .primary)
    }

    /// Stands the words in the theme's critical colour, as WinUI marks a destructive entry, or in the button's own.
    func setCritical(_ critical: Bool) {
        stateui_winui_button_set_critical(handle, critical)
    }

    /// Whether the words stand in the theme's critical colour.
    var isCritical: Bool { stateui_winui_button_critical(handle) }

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

    /// How the button opens its menu, which WinUI makes a control of its own of.
    let opening: ButtonMenuOpening

    /// A button - or, holding a menu, WinUI's DropDownButton opening it where it shows its arrow, a Button opening its
    /// flyout where it shows none, its SplitButton, its click its own and its menu behind the arrow, or a Button
    /// holding it as its context menu: press and hold, or the mouse's other button.
    /// Design: docs/design/platforms/winui/controls.md#a-buttons-menu
    init(menu opening: ButtonMenuOpening = .none, showsArrow: Bool = false) {
        self.opening = opening
        let kind: StateUIButtonKind = switch opening {
        case .arrow: .split
        case .click where showsArrow: .dropDown
        case .none, .click, .hold: .button
        }
        super.init { number in stateui_winui_button_make(number, kind) }
    }

    /// The menu a button holding one opens, or holds as its context menu; its items' actions are the view's.
    func setMenu(_ menu: WinUIMenu) {
        switch opening {
        case .none: return
        case .hold: setContextMenu(menu)
        case .click, .arrow:
            menuActions = menu.actions
            menu.relayed { stateui_winui_button_set_menu(handle, number, $0, $1, $2, $3, $4, $5, $6, $7, $8, $9) }
        }
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

    /// What fills the button, its outline and its shape; nil for the platform's own. Its corners round as far as
    /// its size holds them (`BoxArithmetic.cornerRadius`), a capsule's by half its shorter side; an oval, which a
    /// button's corners cannot draw, is a brush holding the fill and the outline at its size.
    func setLook(background: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let outlined = shape.map(BoxArithmetic.outline)
        let (fill, outline) = (WinUIBrush(background), WinUIBrush(stroke))
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        let rounds = outlined.map { $0 != .rectangle } ?? false
        paint(.look, followsSize: fill.followsSize || outline.followsSize || rounds) { [handle] size in
            let radius = outlined.map {
                BoxArithmetic.cornerRadius(of: $0, width: size.width, height: size.height)
            } ?? -1
            fill.withRelayBrush(over: size) { fill in
                outline.withRelayBrush(over: size) { outline in
                    stateui_winui_button_set_look(
                        handle, fill, outline, width, radius, outlined == .ellipse, size.width, size.height,
                        PressedFill.underPointer, PressedFill.pressed)
                }
            }
        }
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
