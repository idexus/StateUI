// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native AppKit radio control. StateUI's mounted tree owns group scope.
@MainActor
final class AppKitRadioButtonView: NSButton {
    var onSelected: (() -> Void)?

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
        ProgramWrite.perform {
            state = checked ? .on : .off
            title = text
            self.font = font
            attributedTitle = NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: textColor])
            isEnabled = enabled
        }
    }

    func setCheckedFromGroup(_ checked: Bool) {
        ProgramWrite.perform {
            state = checked ? .on : .off
        }
    }

    @objc private func selected(_ sender: NSButton) {
        guard !ProgramWrite.isWriting, state == .on else { return }
        onSelected?()
    }

    func selectForTesting() {
        state = .on
        selected(self)
    }
}

#endif
