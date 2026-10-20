// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls that are on or off: a switch and a check box, each turn told
// through `toggled`, the words it says and what they are drawn over.
// Design: docs/design/platforms/winui/controls.md#on-or-off

#include "Automation.h"

#include <string>
#include <vector>

#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace primitives = winrt::Microsoft::UI::Xaml::Controls::Primitives;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// Tells the view `view` of each check and uncheck of `button`.
    void hear(primitives::ToggleButton const &button, int64_t view) {
        button.Checked(guarded("handling Checked",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.toggled(view, true); }));
        button.Unchecked(guarded("handling Unchecked",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.toggled(view, false); }));
    }
}

extern "C" StateUIObjectRef stateui_winui_switch_make(int64_t view) {
    try {
        // The track and its header: WinUI's "On" and "Off" beside the track are left out, and the room its style
        // keeps for them with them.
        controls::ToggleSwitch toggle;
        toggle.OnContent(winrt::box_value(L""));
        toggle.OffContent(winrt::box_value(L""));
        toggle.MinWidth(0);
        toggle.Toggled(guarded("handling Toggled", [view](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            callbacks.toggled(view, sender.as<controls::ToggleSwitch>().IsOn());
        }));
        return detach(toggle);
    } catch (...) {
        report("making a switch");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_check_box_make(int64_t view) {
    try {
        // The box alone until it says words: WinUI's style keeps the width of words beside it.
        controls::CheckBox box;
        box.MinWidth(0);
        box.Padding({0, 0, 0, 0});
        hear(box, view);
        return detach(box);
    } catch (...) {
        report("making a check box");
        return nullptr;
    }
}

extern "C" void stateui_winui_toggle_set_words(StateUIObjectRef handle, char const *utf8, bool has, uint32_t argb) {
    try {
        auto words = text(utf8);
        auto shown = words.empty() ? nullptr : winrt::box_value(words);
        auto brush = has ? media::Brush(media::SolidColorBrush(winrt::Windows::UI::Color{
                               static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16),
                               static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)}))
                         : media::Brush{nullptr};
        auto control = as<controls::Control>(handle);
        // The colour goes where the control's style reads its words' colour, in every state that keeps them.
        std::vector<std::pair<std::wstring, media::Brush>> brushes;
        if (auto toggle = control.try_as<controls::ToggleSwitch>()) {
            toggle.Header(shown);
            brushes.emplace_back(L"ToggleSwitchHeaderForeground", brush);
        } else {
            auto box = control.as<controls::CheckBox>();
            box.Content(shown);
            if (words.empty()) box.Padding({0, 0, 0, 0});
            else box.ClearValue(controls::Control::PaddingProperty());
            for (std::wstring state : {L"Unchecked", L"Checked", L"Indeterminate"})
                for (std::wstring under : {L"", L"PointerOver", L"Pressed"})
                    brushes.emplace_back(L"CheckBoxForeground" + state + under, brush);
        }
        writeResources(control, brushes);
    } catch (...) {
        report("setting a toggle's words");
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
    } catch (...) {
        report("turning a control on or off");
    }
}

extern "C" bool stateui_winui_toggle_is_on(StateUIObjectRef handle) {
    try {
        auto control = as<IInspectable>(handle);
        if (auto toggle = control.try_as<controls::ToggleSwitch>()) return toggle.IsOn();
        auto checked = control.as<primitives::ToggleButton>().IsChecked();
        return checked && checked.Value();
    } catch (...) {
        report("reading whether a control is on");
        return false;
    }
}

extern "C" void stateui_winui_toggle_press(StateUIObjectRef handle) {
    try {
        auto control = as<xaml::UIElement>(handle);
        pattern<provider::IToggleProvider>(control, PatternInterface::Toggle).Toggle();
    } catch (...) {
        report("turning a control as the user");
    }
}

