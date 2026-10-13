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

    /// A split button's arrow, a button of UIKit's own at the trailing edge set off by a line, opening the menu; nil
    /// for any other button.
    private var arrow: (button: UIButton, line: UIView)?

    /// How wide a split button's arrow stands.
    private static let arrowWidth: CGFloat = 32

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

    /// What fills the button's box, its outline and its shape (`BoxArithmetic`): the configuration's background,
    /// but for an oval, which its corners cannot draw - a face of the button's own then.
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
        switch outlined {
        case .rectangle, .ellipse:
            configuration?.cornerStyle = .fixed
            configuration?.background.cornerRadius = 0
        case .roundedRectangle(let radius):
            configuration?.cornerStyle = .fixed
            configuration?.background.cornerRadius = radius
        case .capsule:
            configuration?.cornerStyle = .capsule
        }
    }

    /// The room between the button's edge and what it shows.
    func setPadding(_ insets: Insets?) {
        padding = insets.map {
            NSDirectionalEdgeInsets(top: $0.top, leading: $0.left, bottom: $0.bottom, trailing: $0.right)
        } ?? UIButton.Configuration.plain().contentInsets
        showPadding()
    }

    /// Offers `menu`: opened by a tap where `opensOnTap`, UIKit's menu indicator beside the words, else by a split
    /// button's arrow, the tap the button's own; nil offers none.
    /// Design: docs/design/platforms/uikit/controls.md#a-buttons-menu
    func offer(_ menu: UIMenu?, opensOnTap: Bool) {
        let opens = opensOnTap && menu != nil
        self.menu = opens ? menu : nil
        showsMenuAsPrimaryAction = opens
        configuration?.indicator = opens ? .popup : .none
        if let menu, !opensOnTap {
            let arrow = self.arrow ?? makeArrow()
            arrow.button.menu = menu
            self.arrow = arrow
        } else if let arrow {
            arrow.button.removeFromSuperview()
            arrow.line.removeFromSuperview()
            self.arrow = nil
        }
        showPadding()
        showLook()
    }

    /// The menu the button offers - opened by its tap, or by its arrow; nil for none.
    var offeredMenu: UIMenu? {
        menu ?? arrow?.button.menu
    }

    /// A split button's arrow: a chevron opening the menu with a tap, and the line setting it off.
    private func makeArrow() -> (button: UIButton, line: UIView) {
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
        return (button, line)
    }

    /// Stands a split button's arrow at the trailing edge, the whole height, and its line beside it.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let arrow else { return }
        let width = Self.arrowWidth
        let leading = effectiveUserInterfaceLayoutDirection == .rightToLeft
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
        if arrow != nil { room.trailing += Self.arrowWidth }
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
        // An icon is drawn in the words' colour where the tree writes one, with words or alone; so are the menu's marks.
        let words = look.color.flatMap(UIColor.init(stateUI:))
        configuration?.imageColorTransformer = words.map { color in UIConfigurationColorTransformer { _ in color } }
        configuration?.indicatorColorTransformer = configuration?.imageColorTransformer
        guard let arrow else { return }
        arrow.button.configuration?.baseForegroundColor = words
        arrow.line.backgroundColor = (words ?? tintColor).withAlphaComponent(0.35)
    }
}
#endif
