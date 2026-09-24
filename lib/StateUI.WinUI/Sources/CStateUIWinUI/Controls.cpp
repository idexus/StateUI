// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls: a text block, a button, a switch, a slider and a field, and
// what the user does to them. Each handler names its view by number and holds
// nothing of the control it is on.

#include "Relay.h"

#include <algorithm>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Microsoft::UI::Xaml::Automation::Peers::PatternInterface;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    /// The control's UI Automation pattern, asked of its peer as an automation client asks.
    template <typename Provider>
    Provider pattern(xaml::UIElement const &control, PatternInterface which) {
        auto peer = xaml::Automation::Peers::FrameworkElementAutomationPeer::CreatePeerForElement(control);
        return peer.GetPattern(which).as<Provider>();
    }
}

extern "C" StateUIObjectRef stateui_winui_text_make(void) {
    try {
        controls::TextBlock block;
        block.TextWrapping(xaml::TextWrapping::Wrap);
        return detach(block);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a text block");
        return nullptr;
    }
}

extern "C" void stateui_winui_text_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        borrow<controls::TextBlock>(handle).Text(text(utf8));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a text block's words");
    }
}

extern "C" void stateui_winui_text_set_color(StateUIObjectRef handle, bool has, uint32_t argb) {
    try {
        auto block = borrow<controls::TextBlock>(handle);
        if (!has) return block.ClearValue(controls::TextBlock::ForegroundProperty());
        winrt::Windows::UI::Color color{
            static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16),
            static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)};
        block.Foreground(xaml::Media::SolidColorBrush(color));
    } catch (winrt::hresult_error const &error) {
        report(error, "colouring a text block's words");
    }
}

extern "C" StateUIObjectRef stateui_winui_button_make(int64_t view) {
    try {
        controls::Button button;
        button.Click([view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.clicked(view); });
        return detach(button);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a button");
        return nullptr;
    }
}

extern "C" void stateui_winui_button_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        borrow<controls::Button>(handle).Content(winrt::box_value(text(utf8)));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a button's caption");
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

extern "C" void stateui_winui_switch_set_on(StateUIObjectRef handle, bool on) {
    try {
        auto toggle = borrow<controls::ToggleSwitch>(handle);
        if (toggle.IsOn() != on) toggle.IsOn(on);
    } catch (winrt::hresult_error const &error) {
        report(error, "turning a switch");
    }
}

extern "C" bool stateui_winui_switch_is_on(StateUIObjectRef handle) {
    try {
        return borrow<controls::ToggleSwitch>(handle).IsOn();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a switch");
        return false;
    }
}

extern "C" void stateui_winui_switch_toggle(StateUIObjectRef handle) {
    try {
        pattern<provider::IToggleProvider>(borrow<controls::ToggleSwitch>(handle), PatternInterface::Toggle).Toggle();
    } catch (winrt::hresult_error const &error) {
        report(error, "toggling a switch");
    }
}

extern "C" StateUIObjectRef stateui_winui_slider_make(int64_t view) {
    try {
        controls::Slider slider;
        slider.ValueChanged([view](IInspectable const &, controls::Primitives::RangeBaseValueChangedEventArgs const &args) {
            callbacks.valueChanged(view, args.NewValue());
        });
        return detach(slider);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a slider");
        return nullptr;
    }
}

extern "C" void stateui_winui_slider_set(StateUIObjectRef handle, double value, double minimum, double maximum) {
    try {
        auto slider = borrow<controls::Slider>(handle);
        auto lower = std::min(minimum, maximum);
        auto upper = std::max(minimum, maximum);
        auto step = upper > lower ? (upper - lower) / 10000 : 1;
        if (slider.Minimum() != lower || slider.Maximum() != upper) {
            // Widened first, so neither end clamps the value on its way.
            slider.Minimum(std::min(lower, slider.Minimum()));
            slider.Maximum(std::max(upper, slider.Maximum()));
            slider.StepFrequency(step);
            slider.SmallChange(step);
            slider.Minimum(lower);
            slider.Maximum(upper);
        }
        auto kept = std::min(std::max(value, lower), upper);
        if (slider.Value() != kept) slider.Value(kept);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a slider");
    }
}

extern "C" double stateui_winui_slider_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::Slider>(handle).Value();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a slider");
        return 0;
    }
}

extern "C" void stateui_winui_slider_move(StateUIObjectRef handle, double value) {
    try {
        pattern<provider::IRangeValueProvider>(borrow<controls::Slider>(handle), PatternInterface::RangeValue)
            .SetValue(value);
    } catch (winrt::hresult_error const &error) {
        report(error, "moving a slider");
    }
}

extern "C" StateUIObjectRef stateui_winui_field_make(int64_t view) {
    try {
        controls::TextBox field;
        // TextChanging, not TextChanged: it is raised in the write that makes it, so a program's write is known
        // as one, where TextChanged comes later.
        field.TextChanging([view](controls::TextBox const &sender, controls::TextBoxTextChangingEventArgs const &args) {
            if (!args.IsContentChanging()) return;
            auto bytes = winrt::to_string(sender.Text());
            callbacks.textChanged(view, bytes.c_str());
        });
        field.KeyDown([view](IInspectable const &, xaml::Input::KeyRoutedEventArgs const &args) {
            if (args.Key() == winrt::Windows::System::VirtualKey::Enter) callbacks.submitted(view);
        });
        return detach(field);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a field");
        return nullptr;
    }
}

extern "C" void stateui_winui_field_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        auto field = borrow<controls::TextBox>(handle);
        auto words = text(utf8);
        if (field.Text() == words) return;
        field.Text(words);
        field.Select(static_cast<int32_t>(words.size()), 0);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a field's words");
    }
}

extern "C" void stateui_winui_field_set_placeholder(StateUIObjectRef handle, char const *utf8) {
    try {
        borrow<controls::TextBox>(handle).PlaceholderText(text(utf8));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a field's placeholder");
    }
}

extern "C" void stateui_winui_button_invoke(StateUIObjectRef handle) {
    try {
        pattern<provider::IInvokeProvider>(borrow<controls::Button>(handle), PatternInterface::Invoke).Invoke();
    } catch (winrt::hresult_error const &error) {
        report(error, "pressing a button");
    }
}
