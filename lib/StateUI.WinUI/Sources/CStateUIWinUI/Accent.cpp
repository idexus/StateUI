// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control's one accent colour: a progress bar's and a spinner's foreground,
// and otherwise the brushes a template takes from the system's accent, written
// into the control's own resources - the default, under the pointer and
// pressed, as WinUI's accent brushes are - and the control's theme read again
// so its template takes them.
// Design: docs/design/platforms/winui/controls.md#a-controls-accent

#include "Relay.h"

#include <string>
#include <vector>

#include <winrt/Windows.UI.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// A resource a control's template fills with the accent, and whether it is named again for under the pointer
    /// and pressed.
    struct Accented {
        std::wstring name;
        bool varies = true;
    };

    /// The resources a control's template fills with the accent; none for a control that takes no accent.
    std::vector<Accented> accentResources(IInspectable const &control) {
        if (control.try_as<controls::CheckBox>())
            return {{L"CheckBoxCheckBackgroundFillChecked"}, {L"CheckBoxCheckBackgroundStrokeChecked"}};
        if (control.try_as<controls::ToggleSwitch>()) return {{L"ToggleSwitchFillOn"}, {L"ToggleSwitchStrokeOn"}};
        if (control.try_as<controls::Slider>()) return {{L"SliderThumbBackground"}, {L"SliderTrackValueFill"}};
        if (control.try_as<controls::ComboBox>()) return {{L"ComboBoxItemPillFillBrush", false}};
        return {};
    }
}

extern "C" void stateui_winui_set_tint(StateUIObjectRef handle, uint32_t argb, bool tinted) {
    try {
        auto control = as<xaml::FrameworkElement>(handle);
        if (auto shows = control.try_as<controls::Control>();
            shows && (control.try_as<controls::ProgressBar>() || control.try_as<controls::ProgressRing>())) {
            auto colour = winrt::Windows::UI::Color{static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16),
                                                    static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)};
            if (tinted) shows.Foreground(media::SolidColorBrush(colour));
            else shows.ClearValue(controls::Control::ForegroundProperty());
            return;
        }
        auto resources = control.Resources();
        // WinUI's accent brushes: the colour, then nine tenths of it under the pointer and eight tenths pressed.
        struct Variant { wchar_t const *suffix; double opacity; };
        Variant const variants[] = {{L"", 1}, {L"PointerOver", 0.9}, {L"Pressed", 0.8}};
        for (auto const &accented : accentResources(control)) {
            for (auto const &variant : variants) {
                if (!accented.varies && *variant.suffix) continue;
                auto key = winrt::box_value(winrt::hstring(accented.name + variant.suffix));
                if (!tinted) {
                    if (resources.HasKey(key)) resources.Remove(key);
                    continue;
                }
                auto alpha = static_cast<uint8_t>(((argb >> 24) & 0xFF) * variant.opacity + 0.5);
                resources.Insert(key, media::SolidColorBrush(winrt::Windows::UI::Color{
                    alpha, static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)}));
            }
        }
        readThemeAgain(control);
    } catch (winrt::hresult_error const &error) {
        report(error, "tinting a control");
    }
}

void stateui::readThemeAgain(xaml::FrameworkElement const &control) {
    // A template reads its resources as its theme is read.
    auto requested = control.RequestedTheme();
    control.RequestedTheme(control.ActualTheme() == xaml::ElementTheme::Dark ? xaml::ElementTheme::Light
                                                                           : xaml::ElementTheme::Dark);
    control.RequestedTheme(requested);
}
