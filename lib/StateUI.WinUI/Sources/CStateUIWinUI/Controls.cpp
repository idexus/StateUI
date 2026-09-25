// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls: a text block, a button and a field, and what the user does to
// them. Each handler names its view by number and holds nothing of the control
// it is on.

#include "Automation.h"

#include <algorithm>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;

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

extern "C" void stateui_winui_button_set_look(
    StateUIObjectRef handle, StateUIBrush background, StateUIBrush stroke, double strokeWidth, double cornerRadius
) {
    try {
        auto button = borrow<controls::Button>(handle);
        auto resources = button.Resources();
        auto keep = [&](wchar_t const *key, xaml::Media::Brush const &value) {
            auto name = winrt::box_value(key);
            if (resources.HasKey(name)) resources.Remove(name);
            if (value) resources.Insert(name, value);
        };
        // Under the pointer and pressed, WinUI's own buttons draw their fill a little fainter each time.
        auto fill = brush(background);
        auto faded = [&](double opacity) {
            auto made = brush(background);
            if (made) made.Opacity(opacity);
            return made;
        };
        if (fill) button.Background(fill);
        else button.ClearValue(controls::Control::BackgroundProperty());
        keep(L"ButtonBackground", fill);
        keep(L"ButtonBackgroundPointerOver", faded(0.9));
        keep(L"ButtonBackgroundPressed", faded(0.8));

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
    } catch (winrt::hresult_error const &error) {
        report(error, "dressing a button");
    }
}

extern "C" void stateui_winui_set_caption(StateUIObjectRef handle, char const *utf8) {
    try {
        as<controls::ContentControl>(handle).Content(winrt::box_value(text(utf8)));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a caption");
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
