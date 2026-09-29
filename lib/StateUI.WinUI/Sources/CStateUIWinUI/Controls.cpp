// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls: a text block and a button, and what the user does to them.
// Each handler names its view by number and holds nothing of the control it is
// on.

#include "Automation.h"

#include <algorithm>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;

namespace {
    /// What a label with no background is drawn over: nothing, which is still hit across its bounds.
    xaml::Media::SolidColorBrush clearGround() {
        return xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0});
    }
}

controls::TextBlock stateui::wordsOf(IInspectable const &element) {
    if (auto block = element.try_as<controls::TextBlock>()) return block;
    if (auto border = element.try_as<controls::Border>()) return border.Child().try_as<controls::TextBlock>();
    return nullptr;
}

controls::TextBlock stateui::labelWords(StateUIObjectRef handle) {
    auto words = wordsOf(as<IInspectable>(handle));
    if (!words) winrt::throw_hresult(E_INVALIDARG);
    return words;
}

xaml::UIElement stateui::metOf(IInspectable const &element) {
    if (auto border = element.try_as<controls::Border>()) {
        if (auto block = border.Child().try_as<controls::TextBlock>()) return block;
    }
    return element.as<xaml::UIElement>();
}

extern "C" StateUIObjectRef stateui_winui_text_make(void) {
    try {
        // The words stand in a border, which draws what they are drawn over and stands them across its height as
        // their alignment says: a text block does neither.
        controls::TextBlock block;
        block.TextWrapping(xaml::TextWrapping::Wrap);
        controls::Border label;
        label.Background(clearGround());
        label.Child(block);
        return detach(label);
    } catch (...) {
        report("making a label");
        return nullptr;
    }
}

extern "C" void stateui_winui_text_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        labelWords(handle).Text(text(utf8));
    } catch (...) {
        report("setting a label's words");
    }
}

extern "C" void stateui_winui_text_set_background(StateUIObjectRef handle, StateUIBrush background) {
    try {
        auto fill = brush(background);
        borrow<controls::Border>(handle).Background(fill ? fill : clearGround());
    } catch (...) {
        report("setting what a label is drawn over");
    }
}

extern "C" void stateui_winui_text_set_vertical(StateUIObjectRef handle, int32_t vertical) {
    try {
        labelWords(handle).VerticalAlignment(vertical == 1 ? xaml::VerticalAlignment::Center
                                             : vertical == 2 ? xaml::VerticalAlignment::Bottom
                                                             : xaml::VerticalAlignment::Stretch);
    } catch (...) {
        report("standing a label's words across its height");
    }
}

extern "C" StateUIObjectRef stateui_winui_button_make(int64_t view) {
    try {
        controls::Button button;
        button.Click([view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.clicked(view); });
        // Held down by a pointer or a key, and let go: what WinUI's own pressed look follows.
        button.RegisterPropertyChangedCallback(
            controls::Primitives::ButtonBase::IsPressedProperty(),
            [view](xaml::DependencyObject const &sender, xaml::DependencyProperty const &) {
                callbacks.held(view, sender.as<controls::Primitives::ButtonBase>().IsPressed());
            });
        return detach(button);
    } catch (...) {
        report("making a button");
        return nullptr;
    }
}

extern "C" void stateui_winui_button_set_look(
    StateUIObjectRef handle, StateUIBrush background, StateUIBrush stroke, double strokeWidth, double cornerRadius,
    double underPointer, double pressed
) {
    try {
        auto button = borrow<controls::Button>(handle);
        auto resources = button.Resources();
        auto keep = [&](wchar_t const *key, xaml::Media::Brush const &value) {
            auto name = winrt::box_value(key);
            if (resources.HasKey(name)) resources.Remove(name);
            if (value) resources.Insert(name, value);
        };
        // Under the pointer and pressed, the fill is drawn a little fainter each time, as WinUI's own buttons draw it.
        auto fill = brush(background);
        auto faded = [&](double opacity) {
            auto made = brush(background);
            if (made) made.Opacity(opacity);
            return made;
        };
        if (fill) button.Background(fill);
        else button.ClearValue(controls::Control::BackgroundProperty());
        keep(L"ButtonBackground", fill);
        keep(L"ButtonBackgroundPointerOver", faded(underPointer));
        keep(L"ButtonBackgroundPressed", faded(pressed));

        auto outline = strokeWidth > 0 ? brush(stroke) : xaml::Media::Brush{nullptr};
        if (outline) {
            button.BorderBrush(outline);
            button.BorderThickness({strokeWidth, strokeWidth, strokeWidth, strokeWidth});
        } else {
            button.ClearValue(controls::Control::BorderBrushProperty());
            button.ClearValue(controls::Control::BorderThicknessProperty());
        }
        keep(L"ButtonBorderBrush", outline);
        keep(L"ButtonBorderBrushPointerOver", outline);
        keep(L"ButtonBorderBrushPressed", outline);

        if (cornerRadius >= 0) button.CornerRadius({cornerRadius, cornerRadius, cornerRadius, cornerRadius});
        else button.ClearValue(controls::Control::CornerRadiusProperty());
    } catch (...) {
        report("dressing a button");
    }
}

extern "C" void stateui_winui_set_caption(StateUIObjectRef handle, char const *utf8) {
    try {
        as<controls::ContentControl>(handle).Content(winrt::box_value(text(utf8)));
    } catch (...) {
        report("setting a caption");
    }
}

extern "C" void stateui_winui_button_invoke(StateUIObjectRef handle) {
    try {
        pattern<provider::IInvokeProvider>(borrow<controls::Button>(handle), PatternInterface::Invoke).Invoke();
    } catch (...) {
        report("pressing a button");
    }
}
