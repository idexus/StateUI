// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control's one accent colour: a progress bar's and a spinner's foreground,
// and otherwise the brushes a template takes from the system's accent, written
// into the control's own resources - the default, under the pointer and
// pressed, as WinUI's accent brushes are. A new colour takes the brushes
// standing there in place; a brush coming or going has the theme read again.
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

extern "C" void stateui_winui_set_tint(
    StateUIObjectRef handle, uint32_t argb, bool tinted, double underPointer, double pressed
) {
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
        // WinUI's accent brushes: the colour, then fainter under the pointer and pressed.
        struct Variant { wchar_t const *suffix; double opacity; };
        Variant const variants[] = {{L"", 1}, {L"PointerOver", underPointer}, {L"Pressed", pressed}};
        std::vector<std::pair<std::wstring, xaml::Media::Brush>> brushes;
        for (auto const &accented : accentResources(control)) {
            for (auto const &variant : variants) {
                if (!accented.varies && *variant.suffix) continue;
                auto alpha = static_cast<uint8_t>(((argb >> 24) & 0xFF) * variant.opacity + 0.5);
                brushes.emplace_back(accented.name + variant.suffix, tinted ? media::SolidColorBrush(winrt::Windows::UI::Color{
                    alpha, static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)})
                    : xaml::Media::Brush{nullptr});
            }
        }
        writeResources(control, brushes);
    } catch (...) {
        report("tinting a control");
    }
}

namespace {
    int32_t themesReadAgain = 0;

    /// The brush the control's own resources hold under `name`; null for none. `HasKey` and `Lookup` look on into
    /// the application's theme, whose brushes every control shares: only a walk of the dictionary finds its own.
    xaml::Media::Brush own(xaml::ResourceDictionary const &resources, std::wstring const &name) {
        for (auto const &pair : resources)
            if (winrt::unbox_value_or<winrt::hstring>(pair.Key(), L"") == name)
                return pair.Value().try_as<xaml::Media::Brush>();
        return nullptr;
    }

    /// Reads the control's theme again, so its template takes the resources written into the control.
    void readThemeAgain(xaml::FrameworkElement const &control) {
        ++themesReadAgain;
        auto requested = control.RequestedTheme();
        control.RequestedTheme(control.ActualTheme() == xaml::ElementTheme::Dark ? xaml::ElementTheme::Light
                                                                               : xaml::ElementTheme::Dark);
        control.RequestedTheme(requested);
    }
}

extern "C" int32_t stateui_winui_themes_read_again(void) {
    try {
        return themesReadAgain;
    } catch (...) {
        report("reading how often a theme was read again");
        return 0;
    }
}

void stateui::writeResources(xaml::FrameworkElement const &control,
                             std::vector<std::pair<std::wstring, xaml::Media::Brush>> const &brushes) {
    auto resources = control.Resources();
    bool read = false;
    for (auto const &[name, brush] : brushes) {
        auto key = winrt::box_value(winrt::hstring(name));
        auto held = own(resources, name);
        auto standing = held ? held.try_as<media::SolidColorBrush>() : nullptr;
        auto solid = brush ? brush.try_as<media::SolidColorBrush>() : nullptr;
        if (standing && solid) {
            if (standing.Color() != solid.Color()) standing.Color(solid.Color());
            if (standing.Opacity() != solid.Opacity()) standing.Opacity(solid.Opacity());
            continue;
        }
        if (!held && !brush) continue;
        if (held) resources.Remove(key);
        if (brush) resources.Insert(key, brush);
        read = true;
    }
    if (read) readThemeAgain(control);
}
