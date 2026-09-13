// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native AppKit switch with a strict program-write/user-write boundary.
@MainActor
final class AppKitSwitchView: NSSwitch {
    var onToggled: ((Bool) -> Void)?
    private var applying = false

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
        applying = true
        state = toggled ? .on : .off
        isEnabled = enabled
        applying = false
    }

    @objc private func changed(_ sender: NSSwitch) {
        guard !applying else { return }
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
    var onCheckedChanged: ((Bool) -> Void)?
    private var applying = false

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

    func apply(checked: Bool, enabled: Bool, color: NSColor?) {
        applying = true
        state = checked ? .on : .off
        isEnabled = enabled
        contentTintColor = color
        applying = false
    }

    @objc private func changed(_ sender: NSButton) {
        guard !applying else { return }
        onCheckedChanged?(state == .on)
    }

    func toggleForTesting() {
        state = state == .on ? .off : .on
        changed(self)
    }
}

#endif
