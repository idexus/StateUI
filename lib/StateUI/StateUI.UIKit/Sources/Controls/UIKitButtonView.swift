// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Button: UIKit's own, its configuration what the tree says - its caption and their look, an icon beside it, the
/// box behind them and the room inside it; a tap is its click, and the press is heard as it goes down and is let go.
@MainActor
final class UIKitButtonView: UIButton {
    /// What the button does when the user taps it, and as a press goes down and is let go.
    var onClicked: (() -> Void)?
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var look = TextLook()

    /// The room between the button's edge and what it shows, as the tree gives it.
    private var padding = UIButton.Configuration.plain().contentInsets

    /// The arrow of a button holding a menu: a split button's at its trailing edge set off by a line, opening the
    /// menu; a mark after the words of a button whose tap opens it. Nil for a plain button.
    private var arrow: Arrow?

    /// An arrow pointing down, a button of UIKit's own, and the line setting a split button's apart.
    private struct Arrow {
        let button: UIButton
        let line: UIView
        var splits: Bool
    }

    /// How wide a split button's arrow stands, and how wide the mark after the words, a gap before it.
    private static let arrowWidth: CGFloat = 32
    private static let markWidth: CGFloat = 12
    private static let markGap: CGFloat = 6

    init() {
        super.init(frame: .zero)
        configuration = .plain()
        followTextSize()
        addAction(UIAction { [weak self] _ in self?.onClicked?() }, for: .primaryActionTriggered)
        addAction(UIAction { [weak self] _ in self?.onPressed?() }, for: .touchDown)
        addAction(UIAction { [weak self] _ in self?.onReleased?() }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitButtonView is made in code")
    }

    /// The button's words.
    func setText(_ text: String) {
        configuration?.title = text.isEmpty ? nil : text
        showLook()
    }

    /// Changes the words' look; what it leaves unsaid is the button's own.
    func setLook(_ change: (inout TextLook) -> Void) {
        change(&look)
        showLook()
    }

    /// The icon, where it stands beside the words, and the room between them.
    func setIcon(_ icon: UIImage?, position: IconPosition, spacing: Double?) {
        configuration?.image = icon
        configuration?.imagePlacement = switch position {
        case .leading: .leading
        case .top: .top
        case .trailing: .trailing
        case .bottom: .bottom
        }
        configuration?.imagePadding = spacing ?? 8
    }

    /// The outline the button's box follows, its corners rounded as the button is laid out.
    private var boxShape = ContainerShape.rectangle

    /// What fills the button's box, its outline and its shape (`BoxArithmetic`): the configuration's background,
    /// but for an oval, which its corners cannot draw - a face of the button's own then. A capsule's corners are half
    /// its shorter side, as everywhere: UIKit's own capsule makes a button showing a picture alone a circle, whatever
    /// its padding.
    func setBox(background: HostValue?, stroke: HostValue?, width: Double?, shape: HostValue?) {
        let fill = background.flatMap(UIColor.init(stateUI:))
        let outline = BoxArithmetic.outlineWidth(stroke: stroke, width: width)
        let line = outline > 0 ? UIKitBrush(stroke).lineColor : nil
        let outlined = BoxArithmetic.outline(shape)
        let oval = outlined == .ellipse
        configuration?.background.customView = oval ? UIKitOvalFace(fill: fill, stroke: line, width: outline) : nil
        configuration?.background.backgroundColor = oval ? .clear : fill
        configuration?.background.strokeWidth = oval ? 0 : outline
        configuration?.background.strokeColor = oval ? .clear : line
        boxShape = outlined
        configuration?.cornerStyle = .fixed
        roundCorners()
    }

    /// Rounds the box's corners as its outline says in the button's bounds.
    private func roundCorners() {
        let radius = CGFloat(BoxArithmetic.cornerRadius(of: boxShape, width: bounds.width, height: bounds.height))
        if configuration?.background.cornerRadius != radius { configuration?.background.cornerRadius = radius }
    }

    /// The room between the button's edge and what it shows.
    func setPadding(_ insets: Insets?) {
        padding = insets.map {
            NSDirectionalEdgeInsets(top: $0.top, leading: $0.left, bottom: $0.bottom, trailing: $0.right)
        } ?? UIButton.Configuration.plain().contentInsets
        showPadding()
    }

    /// Offers `menu` as `opening` says: opened by a tap, an arrow pointing down after the words where `showsArrow`;
    /// by a split button's arrow, the tap the button's own; or held, as UIKit opens a button's menu, no arrow.
    /// Design: docs/design/platforms/uikit/controls.md#a-buttons-menu
    func offer(_ menu: UIMenu?, opening: ButtonMenuOpening, showsArrow: Bool) {
        let opensOnTap = opening == .click
        self.menu = opening == .click || opening == .hold ? menu : nil
        showsMenuAsPrimaryAction = opensOnTap && menu != nil
        if let menu, opening == .arrow || opensOnTap && showsArrow {
            var arrow = self.arrow ?? makeArrow()
            arrow.splits = !opensOnTap
            arrow.button.menu = opensOnTap ? nil : menu
            arrow.button.isUserInteractionEnabled = !opensOnTap
            arrow.button.isAccessibilityElement = !opensOnTap
            arrow.line.isHidden = opensOnTap
            self.arrow = arrow
            setNeedsLayout()
        } else if let arrow {
            arrow.button.removeFromSuperview()
            arrow.line.removeFromSuperview()
            self.arrow = nil
        }
        showPadding()
        showLook()
    }

    /// The menu the button offers - opened by its tap or held, or by a split button's arrow; nil for none.
    var offeredMenu: UIMenu? {
        menu ?? arrow?.button.menu
    }

    /// Whether the button shows the arrow pointing down after its words, its tap opening the menu.
    var showsMenuMark: Bool {
        arrow.map { !$0.splits } ?? false
    }

    /// A split button's arrow: a chevron opening the menu with a tap, and the line setting it off.
    private func makeArrow() -> Arrow {
        var face = UIButton.Configuration.plain()
        face.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        face.contentInsets = .zero
        let button = UIButton(configuration: face)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "More"
        let line = UIView()
        line.isUserInteractionEnabled = false
        addSubview(line)
        addSubview(button)
        return Arrow(button: button, line: line, splits: true)
    }

    /// Rounds the box's corners, and stands a split button's arrow at the trailing edge, the whole height, and its
    /// line beside it; a mark inside the padding after the words.
    override func layoutSubviews() {
        super.layoutSubviews()
        roundCorners()
        guard let arrow else { return }
        let leading = effectiveUserInterfaceLayoutDirection == .rightToLeft
        guard arrow.splits else {
            let width = Self.markWidth
            let edge = leading ? padding.trailing : bounds.width - padding.trailing - width
            arrow.button.frame = CGRect(x: edge, y: 0, width: width, height: bounds.height)
            return
        }
        let width = Self.arrowWidth
        arrow.button.frame = CGRect(x: leading ? 0 : bounds.width - width, y: 0, width: width, height: bounds.height)
        let thickness = 1 / max(traitCollection.displayScale, 1)
        let inset = (bounds.height / 4).rounded()
        arrow.line.frame = CGRect(
            x: leading ? width : bounds.width - width - thickness, y: inset,
            width: thickness, height: max(bounds.height - 2 * inset, 0))
    }

    /// The room inside the button, a split button's arrow kept clear of its words.
    private func showPadding() {
        var room = padding
        if let arrow { room.trailing += arrow.splits ? Self.arrowWidth : Self.markWidth + Self.markGap }
        configuration?.contentInsets = room
    }

    /// How the words break.
    func setLineBreak(_ breaking: LineBreak) {
        configuration?.titleLineBreakMode = switch breaking {
        case .noWrap: .byClipping
        case .wordWrap: .byWordWrapping
        case .characterWrap: .byCharWrapping
        case .headTruncation: .byTruncatingHead
        case .tailTruncation: .byTruncatingTail
        case .middleTruncation: .byTruncatingMiddle
        }
    }

    private func showLook() {
        configuration?.titleTextAttributesTransformer = look.titleTransformer(color: tintColor)
        // An icon is drawn in the words' colour where the tree writes one, with words or alone; so is the arrow.
        let words = look.color.flatMap(UIColor.init(stateUI:))
        configuration?.imageColorTransformer = words.map { color in UIConfigurationColorTransformer { _ in color } }
        guard let arrow else { return }
        arrow.button.configuration?.baseForegroundColor = words
        arrow.line.backgroundColor = (words ?? tintColor).withAlphaComponent(0.35)
    }
}
#endif
