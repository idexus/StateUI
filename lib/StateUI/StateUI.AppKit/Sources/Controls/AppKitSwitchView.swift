// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native AppKit switch and the words it says beside it: the words at its start, the switch at its end, as macOS
/// stands a switch in its settings. A click on the words flips it, and the switch carries them as its name; the
/// program's writes report nothing.
/// Design: docs/design/platforms/appkit/views.md#a-switchs-words
@MainActor
final class AppKitSwitchView: NSView, AppKitAccessibilityPresenting {
    var onToggled: ((Bool) -> Void)?

    /// The switch itself, which the user and assistive technology act on.
    let control = NSSwitch()

    /// The words beside it; hidden where it says none.
    let caption = NSTextField(labelWithString: "")

    /// The room between the words and the switch.
    private static let gap: CGFloat = 8

    var presentedControl: NSView { control }

    /// The name the author gives the switch for assistive technology; nil leaves it named by its words.
    var authoredLabel: String? {
        didSet { name() }
    }

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        control.target = self
        control.action = #selector(changed(_:))
        caption.isHidden = true
        caption.lineBreakMode = .byTruncatingTail
        caption.setAccessibilityElement(false)
        caption.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(captionClicked)))
        addSubview(caption)
        addSubview(control)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSwitchView is created in code")
    }

    /// Whether the switch is on.
    var state: NSControl.StateValue { control.state }

    func apply(toggled: Bool, enabled: Bool, text: String, textColor: NSColor?) {
        ProgramWrite.perform {
            control.state = toggled ? .on : .off
            control.isEnabled = enabled
        }
        caption.stringValue = text
        caption.textColor = enabled ? textColor ?? .labelColor : .disabledControlTextColor
        caption.isHidden = text.isEmpty
        name()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        let toggle = control.intrinsicContentSize
        guard !caption.isHidden else { return toggle }
        let words = caption.intrinsicContentSize
        return NSSize(width: words.width + Self.gap + toggle.width, height: max(words.height, toggle.height))
    }

    /// The switch at the end, the words in the rest from the start - the end and the start as the view lays out.
    override func layout() {
        super.layout()
        let toggle = control.intrinsicContentSize
        let words = caption.intrinsicContentSize
        let rightToLeft = userInterfaceLayoutDirection == .rightToLeft
        let room = max(0, bounds.width - toggle.width - Self.gap)
        control.frame = NSRect(
            x: rightToLeft ? 0 : bounds.width - toggle.width, y: (bounds.height - toggle.height) / 2,
            width: toggle.width, height: toggle.height)
        caption.frame = NSRect(
            x: rightToLeft ? bounds.width - room : 0, y: (bounds.height - words.height) / 2,
            width: room, height: words.height)
    }

    /// The switch named for assistive technology by the author's label, else by its words.
    private func name() {
        control.setAccessibilityLabel(authoredLabel ?? (caption.isHidden ? nil : caption.stringValue))
    }

    @objc private func changed(_ sender: NSSwitch) {
        guard !ProgramWrite.isWriting else { return }
        onToggled?(control.state == .on)
    }

    @objc private func captionClicked() {
        guard control.isEnabled else { return }
        control.performClick(nil)
    }

    func toggleForTesting() {
        control.state = control.state == .on ? .off : .on
        changed(control)
    }

    func clickWordsForTesting() {
        captionClicked()
    }
}

/// A native checkbox and the words it says beside its box, with the same one-report boundary as the switch.
@MainActor
final class AppKitCheckBoxView: NSButton {
    var onToggled: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.switch)
        title = ""
        target = self
        action = #selector(changed(_:))
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitCheckBoxView is created in code")
    }

    /// The box, and the words it says beside it - in the colour the tree gives them, else the platform's: a tint
    /// colours the box alone, where AppKit's content tint would draw the words in it too.
    func apply(checked: Bool, enabled: Bool, tint: NSColor?, text: String, textColor: NSColor?) {
        ProgramWrite.perform {
            state = checked ? .on : .off
            isEnabled = enabled
            contentTintColor = tint
            let plain: NSColor? = tint == nil ? nil : enabled ? .controlTextColor : .disabledControlTextColor
            if let textColor = textColor ?? plain {
                attributedTitle = NSAttributedString(string: text, attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize), .foregroundColor: textColor,
                ])
            } else {
                title = text
            }
        }
    }

    @objc private func changed(_ sender: NSButton) {
        guard !ProgramWrite.isWriting else { return }
        onToggled?(state == .on)
    }

    func toggleForTesting() {
        state = state == .on ? .off : .on
        changed(self)
    }
}

#endif
