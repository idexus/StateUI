// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A native AppKit switch with a strict program-write/user-write boundary.
@MainActor
final class AppKitSwitchView: NSSwitch {
    var onToggled: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(changed(_:))
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSwitchView is created in code")
    }

    func apply(toggled: Bool, enabled: Bool) {
        ProgramWrite.perform {
            state = toggled ? .on : .off
            isEnabled = enabled
        }
    }

    @objc private func changed(_ sender: NSSwitch) {
        guard !ProgramWrite.isWriting else { return }
        onToggled?(state == .on)
    }

    func toggleForTesting() {
        state = state == .on ? .off : .on
        changed(self)
    }
}

/// A native checkbox with the same one-report boundary as the switch.
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

    func apply(checked: Bool, enabled: Bool, tint: NSColor?) {
        ProgramWrite.perform {
            state = checked ? .on : .off
            isEnabled = enabled
            contentTintColor = tint
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
