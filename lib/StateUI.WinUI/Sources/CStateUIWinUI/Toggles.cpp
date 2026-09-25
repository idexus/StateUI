// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls that are on or off: a switch, a check box and a radio button,
// each turn told through `toggled`. Which of a radio button's set loses its
// check is the host's: each button stands in a group of its own.
// Design: docs/design/platforms/winui/controls.md#on-or-off

#include "Automation.h"

#include <string>

using namespace stateui;
namespace primitives = winrt::Microsoft::UI::Xaml::Controls::Primitives;

namespace {
    /// Tells the view `view` of each check and uncheck of `button`.
    void hear(primitives::ToggleButton const &button, int64_t view) {
        button.Checked([view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.toggled(view, true); });
        button.Unchecked([view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.toggled(view, false); });
    }
}

extern "C" StateUIObjectRef stateui_winui_switch_make(int64_t view) {
    try {
        controls::ToggleSwitch toggle;
        toggle.Toggled([view](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            callbacks.toggled(view, sender.as<controls::ToggleSwitch>().IsOn());
        });
        return detach(toggle);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a switch");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_check_box_make(int64_t view) {
    try {
        // The box and nothing else: a check box has no caption, so it takes no caption's room.
        controls::CheckBox box;
        box.MinWidth(0);
        box.Padding({0, 0, 0, 0});
        hear(box, view);
        return detach(box);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a check box");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_radio_make(int64_t view) {
    try {
        controls::RadioButton radio;
        radio.GroupName(L"StateUI " + std::to_wstring(view));
        hear(radio, view);
        return detach(radio);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a radio button");
        return nullptr;
    }
}

extern "C" void stateui_winui_toggle_set_on(StateUIObjectRef handle, bool on) {
    try {
        auto control = as<IInspectable>(handle);
        if (auto toggle = control.try_as<controls::ToggleSwitch>()) {
            if (toggle.IsOn() != on) toggle.IsOn(on);
            return;
        }
        auto button = control.as<primitives::ToggleButton>();
        auto checked = button.IsChecked();
        if (!checked || checked.Value() != on) button.IsChecked(on);
    } catch (winrt::hresult_error const &error) {
        report(error, "turning a control on or off");
    }
}

extern "C" bool stateui_winui_toggle_is_on(StateUIObjectRef handle) {
    try {
        auto control = as<IInspectable>(handle);
        if (auto toggle = control.try_as<controls::ToggleSwitch>()) return toggle.IsOn();
        auto checked = control.as<primitives::ToggleButton>().IsChecked();
        return checked && checked.Value();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading whether a control is on");
        return false;
    }
}

extern "C" void stateui_winui_toggle_press(StateUIObjectRef handle) {
    try {
        auto control = as<xaml::UIElement>(handle);
        if (control.try_as<controls::RadioButton>())
            pattern<provider::ISelectionItemProvider>(control, PatternInterface::SelectionItem).Select();
        else
            pattern<provider::IToggleProvider>(control, PatternInterface::Toggle).Toggle();
    } catch (winrt::hresult_error const &error) {
        report(error, "turning a control as the user");
    }
}
