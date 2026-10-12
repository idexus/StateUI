// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A window's keys before the widget holding the focus has them: a key controller on the window in the capture
/// phase, which asks `onPressed` whether a view takes the key (`KeyPresses`) and stops it where one does.
/// Design: docs/design/types/keyboard.md#a-views-keys
@MainActor
final class GTKWindowKeys {
    /// What a pressed key does; whether a view took it.
    var onPressed: ((KeyboardShortcut) -> Bool)?

    private let number: Int64

    init(on widget: GTKWidget) {
        number = Self.nextNumber
        Self.nextNumber += 1
        let keys = gtk_event_controller_key_new()!
        gtk_event_controller_set_propagation_phase(keys, GTK_PHASE_CAPTURE)
        connectSignal(UnsafeMutableRawPointer(keys), "key-pressed", number: number) { _, keyval, _, state, data in
            MainActor.assumeIsolated {
                GTKWindowKeys.pressed[viewNumber(data)]?(keyval, GdkModifierType(rawValue: state)) == true ? 1 : 0
            }
        }
        gtk_widget_add_controller(widget, keys)
        Self.pressed[number] = { [weak self] keyval, modifiers in
            GTKKeys.shortcut(keyval: keyval, modifiers: modifiers).map { self?.onPressed?($0) == true } ?? false
        }
    }

    isolated deinit {
        Self.pressed[number] = nil
    }

    /// A key pressed as the controller hears it; whether a view took it - what a test presses.
    func pressForTesting(_ shortcut: KeyboardShortcut) -> Bool {
        onPressed?(shortcut) == true
    }

    /// Each window's keys, by the number its controller's signal carries.
    private static var pressed: [Int64: (guint, GdkModifierType) -> Bool] = [:]
    private static var nextNumber: Int64 = 1
}
