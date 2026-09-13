// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native AppKit radio control. StateUI's mounted tree owns group scope.
@MainActor
final class AppKitRadioButtonView: NSButton {
    var onSelected: (() -> Void)?
    private var applying = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.radio)
        target = self
        action = #selector(selected(_:))
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitRadioButtonView is created in code")
    }

    func apply(
        checked: Bool,
        text: String,
        font: NSFont,
        textColor: NSColor,
        enabled: Bool
    ) {
        applying = true
        state = checked ? .on : .off
        title = text
        self.font = font
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: textColor])
        isEnabled = enabled
        applying = false
    }

    func setCheckedFromGroup(_ checked: Bool) {
        applying = true
        state = checked ? .on : .off
        applying = false
    }

    @objc private func selected(_ sender: NSButton) {
        guard !applying, state == .on else { return }
        onSelected?()
    }

    func selectForTesting() {
        state = .on
        selected(self)
    }
}

#endif
