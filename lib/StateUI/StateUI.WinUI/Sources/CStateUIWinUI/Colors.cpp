// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A color: a DropDownButton showing the color in a swatch, its Flyout WinUI's
// ColorPicker; each color the picker takes told through `colorChosen` as one
// ARGB number, which the host layer hears as the user's only outside the
// program's write.
// Design: docs/design/platforms/winui/controls.md#a-color-picker

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// The picker the button's flyout holds.
    controls::ColorPicker pickerOf(controls::DropDownButton const &button) {
        return button.Flyout().as<controls::Flyout>().Content().as<controls::ColorPicker>();
    }

    /// The swatch the button shows.
    controls::Border swatchOf(controls::DropDownButton const &button) {
        return button.Content().as<controls::Border>();
    }

    uint32_t argb(winrt::Windows::UI::Color color) {
        return static_cast<uint32_t>(color.A) << 24 | static_cast<uint32_t>(color.R) << 16
            | static_cast<uint32_t>(color.G) << 8 | color.B;
    }
}

extern "C" StateUIObjectRef stateui_winui_color_make(int64_t view) {
    try {
        // The swatch's edge and corners are the theme's, so they follow it.
        auto button = xaml::Markup::XamlReader::Load(
            L"<DropDownButton xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\">"
            L"<Border Width=\"32\" Height=\"18\" BorderThickness=\"1\""
            L" CornerRadius=\"{ThemeResource ControlCornerRadius}\""
            L" BorderBrush=\"{ThemeResource ControlStrokeColorDefaultBrush}\"/>"
            L"<DropDownButton.Flyout><Flyout><ColorPicker IsAlphaEnabled=\"False\"/></Flyout></DropDownButton.Flyout>"
            L"</DropDownButton>").as<controls::DropDownButton>();
        auto swatch = swatchOf(button);
        swatch.Background(media::SolidColorBrush(winrt::Windows::UI::Color{255, 0, 0, 0}));
        pickerOf(button).ColorChanged(guarded("handling ColorChanged",
            [view, swatch](controls::ColorPicker const &, controls::ColorChangedEventArgs const &args) {
            swatch.Background(media::SolidColorBrush(args.NewColor()));
            callbacks.colorChosen(view, argb(args.NewColor()));
        }));
        return detach(button);
    } catch (...) {
        report("making a color picker");
        return nullptr;
    }
}

extern "C" void stateui_winui_color_set(StateUIObjectRef handle, uint32_t argb) {
    try {
        auto button = borrow<controls::DropDownButton>(handle);
        swatchOf(button).Background(media::SolidColorBrush(color(argb)));
        pickerOf(button).Color(color(argb));
    } catch (...) {
        report("setting a color picker's color");
    }
}

extern "C" void stateui_winui_color_set_opacity(StateUIObjectRef handle, bool chooses) {
    try {
        pickerOf(borrow<controls::DropDownButton>(handle)).IsAlphaEnabled(chooses);
    } catch (...) {
        report("setting whether a color picker chooses opacity");
    }
}

extern "C" uint32_t stateui_winui_color(StateUIObjectRef handle) {
    try {
        return argb(pickerOf(borrow<controls::DropDownButton>(handle)).Color());
    } catch (...) {
        report("reading a color picker's color");
        return 0;
    }
}

extern "C" bool stateui_winui_color_chooses_opacity(StateUIObjectRef handle) {
    try {
        return pickerOf(borrow<controls::DropDownButton>(handle)).IsAlphaEnabled();
    } catch (...) {
        report("reading whether a color picker chooses opacity");
        return false;
    }
}

extern "C" void stateui_winui_color_pick_as_user(StateUIObjectRef handle, uint32_t argb) {
    try {
        pickerOf(borrow<controls::DropDownButton>(handle)).Color(color(argb));
    } catch (...) {
        report("picking a color as the user");
    }
}
