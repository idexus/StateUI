// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control's keyboard shortcut: WinUI's own accelerator on it, which
// presses it while its window is in front - but for one giving way to typing,
// while a field the user types into holds the keyboard; and keys sent as the
// system sends them, as a test presses a shortcut.
// Design: docs/design/types/keyboard.md#on-each-platform

#include "Relay.h"

#include <vector>

#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Windows.System.h>

using namespace stateui;
using winrt::Windows::System::VirtualKey;
using winrt::Windows::System::VirtualKeyModifiers;

namespace {
    /// Whether a field the user types into holds the keyboard in `element`'s window.
    bool typing(xaml::UIElement const &element) {
        auto root = element.XamlRoot();
        if (!root) return false;
        auto held = xaml::Input::FocusManager::GetFocusedElement(root);
        return held && (held.try_as<controls::TextBox>() || held.try_as<controls::PasswordBox>()
            || held.try_as<controls::RichEditBox>());
    }

    /// The modifiers down, the key down and up, the modifiers up - as the system sends a shortcut's keys.
    void sendKeys(int32_t key, int32_t modifiers) {
        std::vector<INPUT> inputs;
        auto add = [&](WORD virtualKey, bool up) {
            INPUT input{};
            input.type = INPUT_KEYBOARD;
            input.ki.wVk = virtualKey;
            input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
            inputs.push_back(input);
        };
        // The modifiers' bits are VirtualKeyModifiers': Control 1, Menu (Alt) 2, Shift 4.
        WORD const held[] = {VK_CONTROL, VK_MENU, VK_SHIFT};
        for (int bit = 0; bit < 3; ++bit)
            if (modifiers & (1 << bit)) add(held[bit], false);
        add(static_cast<WORD>(key), false);
        add(static_cast<WORD>(key), true);
        for (int bit = 2; bit >= 0; --bit)
            if (modifiers & (1 << bit)) add(held[bit], true);
        SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
    }
}

extern "C" void stateui_winui_set_shortcut(
    StateUIObjectRef handle, int32_t key, int32_t modifiers, bool givesWayToTyping
) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto accelerators = element.KeyboardAccelerators();
        accelerators.Clear();
        if (key == 0) return;
        xaml::Input::KeyboardAccelerator accelerator;
        accelerator.Key(static_cast<VirtualKey>(key));
        accelerator.Modifiers(static_cast<VirtualKeyModifiers>(modifiers));
        if (givesWayToTyping) {
            accelerator.Invoked(guarded("handling Invoked",
                [](xaml::Input::KeyboardAccelerator const &, xaml::Input::KeyboardAcceleratorInvokedEventArgs const &args) {
                // Handled here, the accelerator presses nothing: the key is the field's.
                auto owner = args.Element().try_as<xaml::UIElement>();
                if (owner && typing(owner)) args.Handled(true);
            }));
        }
        accelerators.Append(accelerator);
    } catch (...) {
        report("giving a control its shortcut");
    }
}

extern "C" bool stateui_winui_shortcut(StateUIObjectRef handle, int32_t *key, int32_t *modifiers) {
    try {
        auto accelerators = as<xaml::UIElement>(handle).KeyboardAccelerators();
        if (accelerators.Size() == 0) return false;
        auto first = accelerators.GetAt(0);
        *key = static_cast<int32_t>(first.Key());
        *modifiers = static_cast<int32_t>(first.Modifiers());
        return true;
    } catch (...) {
        report("reading a control's shortcut");
        return false;
    }
}

extern "C" void stateui_winui_send_keys(int32_t key, int32_t modifiers) {
    try {
        sendKeys(key, modifiers);
    } catch (...) {
        report("sending keys");
    }
}
