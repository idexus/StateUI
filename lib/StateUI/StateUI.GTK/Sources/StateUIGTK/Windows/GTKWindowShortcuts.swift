// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The shortcuts a window holds for what has no widget of its own to hold one - a bar's item, a menu bar's entry: a
/// shortcut controller on the window, one shortcut for each, which asks `onPressed` what the keys reach.
/// Design: docs/design/types/keyboard.md#on-each-platform
@MainActor
final class GTKWindowShortcuts {
    /// What a pressed shortcut does; whether it took the keys.
    var onPressed: ((KeyboardShortcut) -> Bool)?

    private let widget: GTKWidget
    private let controller: OpaquePointer
    private let number: Int64
    private var held: [KeyboardShortcut] = []

    init(on widget: GTKWidget) {
        self.widget = widget
        controller = gtk_shortcut_controller_new()!
        gtk_widget_add_controller(widget, controller)
        number = Self.pressed.reserve()
        Self.pressed.hold({ [weak self] index in
            guard let self, self.held.indices.contains(index) else { return false }
            return self.onPressed?(self.held[index]) == true
        }, as: number)
    }

    isolated deinit {
        Self.pressed.release(number)
    }

    /// Holds `shortcuts`, in place of those held before.
    func hold(_ shortcuts: [KeyboardShortcut]) {
        guard shortcuts != held else { return }
        while g_list_model_get_n_items(controller) > 0, let first = g_list_model_get_item(controller, 0) {
            gtk_shortcut_controller_remove_shortcut(controller, OpaquePointer(first))
            g_object_unref(first)
        }
        held = shortcuts
        for (index, shortcut) in shortcuts.enumerated() {
            let spelled = GTKKeys.spelled(shortcut)
            let presses = gtk_callback_action_new({ _, arguments, data in
                let index = arguments.map { Int(g_variant_get_int32($0)) } ?? -1
                return MainActor.assumeIsolated { GTKWindowShortcuts.pressed.find(viewNumber(data))?(index) == true ? 1 : 0 }
            }, UnsafeMutableRawPointer(bitPattern: Int(number)), nil)
            let made = gtk_shortcut_new(gtk_keyval_trigger_new(spelled.keyval, spelled.modifiers), presses)!
            gtk_shortcut_set_arguments(made, g_variant_new_int32(Int32(index)))
            gtk_shortcut_controller_add_shortcut(controller, made)
        }
    }

    /// Runs the action of the shortcut held for `shortcut`, as the controller runs it for its keys; whether it took
    /// them - what a test presses.
    func runForTesting(_ shortcut: KeyboardShortcut) -> Bool {
        guard let index = held.firstIndex(of: shortcut),
              let item = g_list_model_get_item(controller, guint(index))
        else { return false }
        defer { g_object_unref(item) }
        let made = OpaquePointer(item)
        return gtk_shortcut_action_activate(
            gtk_shortcut_get_action(made), GTK_SHORTCUT_ACTION_EXCLUSIVE, widget, gtk_shortcut_get_arguments(made)) != 0
    }

    /// Each window's choice, by the number its shortcuts' actions carry.
    private static let pressed = Numbered<(Int) -> Bool>()
}
