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

    init() {
        super.init(frame: .zero)
        configuration = .plain()
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

    /// What fills the button's box, its outline and its shape (`BoxArithmetic`).
    func setBox(background: HostValue?, stroke: HostValue?, width: Double?, shape: HostValue?) {
        configuration?.background.backgroundColor = background.flatMap(UIColor.init(stateUI:))
        let outline = BoxArithmetic.outlineWidth(stroke: stroke, width: width)
        configuration?.background.strokeWidth = outline
        configuration?.background.strokeColor = outline > 0 ? UIKitBrush(stroke).lineColor : nil
        switch BoxArithmetic.outline(shape) {
        case .rectangle:
            configuration?.cornerStyle = .fixed
            configuration?.background.cornerRadius = 0
        case .roundedRectangle(let radius):
            configuration?.cornerStyle = .fixed
            configuration?.background.cornerRadius = radius
        case .ellipse:
            configuration?.cornerStyle = .capsule
        }
    }

    /// The room between the button's edge and what it shows.
    func setPadding(_ insets: Insets?) {
        configuration?.contentInsets = insets.map {
            NSDirectionalEdgeInsets(top: $0.top, leading: $0.left, bottom: $0.bottom, trailing: $0.right)
        } ?? UIButton.Configuration.plain().contentInsets
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
        configuration?.titleTextAttributesTransformer =
            look.titleTransformer(standing: .preferredFont(forTextStyle: .body), color: tintColor)
    }
}
#endif
