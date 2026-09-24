// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What every element takes: its measure and place, which a panel's pass asks
// for, whether it shows, how opaque it is drawn, and a control's enabled state.

#include "Relay.h"

#include <cstring>

#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::Foundation::Rect;
using winrt::Windows::Foundation::Size;

extern "C" void stateui_winui_measure(StateUIObjectRef handle, double width, double height, double *size) {
    try {
        auto element = as<xaml::UIElement>(handle);
        element.Measure(Size(static_cast<float>(width), static_cast<float>(height)));
        auto desired = element.DesiredSize();
        size[0] = desired.Width;
        size[1] = desired.Height;
    } catch (winrt::hresult_error const &error) {
        report(error, "measuring");
    }
}

extern "C" void stateui_winui_arrange(StateUIObjectRef handle, double x, double y, double width, double height) {
    try {
        as<xaml::UIElement>(handle).Arrange(Rect(
            static_cast<float>(x), static_cast<float>(y), static_cast<float>(width), static_cast<float>(height)));
    } catch (winrt::hresult_error const &error) {
        report(error, "arranging");
    }
}

extern "C" void stateui_winui_invalidate_measure(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).InvalidateMeasure();
    } catch (winrt::hresult_error const &error) {
        report(error, "invalidating a measure");
    }
}

extern "C" void stateui_winui_set_shown(StateUIObjectRef handle, bool shown) {
    try {
        as<xaml::UIElement>(handle).Visibility(shown ? xaml::Visibility::Visible : xaml::Visibility::Collapsed);
    } catch (winrt::hresult_error const &error) {
        report(error, "showing");
    }
}

extern "C" void stateui_winui_set_opacity(StateUIObjectRef handle, double opacity) {
    try {
        as<xaml::UIElement>(handle).Opacity(opacity);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting the opacity");
    }
}

extern "C" void stateui_winui_frame(StateUIObjectRef handle, double *frame) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto offset = element.ActualOffset();
        auto size = element.ActualSize();
        frame[0] = offset.x;
        frame[1] = offset.y;
        frame[2] = size.x;
        frame[3] = size.y;
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a frame");
    }
}

extern "C" void stateui_winui_set_enabled(StateUIObjectRef handle, bool enabled) {
    try {
        as<controls::Control>(handle).IsEnabled(enabled);
    } catch (winrt::hresult_error const &error) {
        report(error, "enabling");
    }
}

extern "C" int32_t stateui_winui_text(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto object = as<IInspectable>(handle);
        winrt::hstring words;
        if (auto block = object.try_as<controls::TextBlock>()) {
            words = block.Text();
        } else if (auto content = object.try_as<controls::ContentControl>()) {
            words = winrt::unbox_value_or<winrt::hstring>(content.Content(), L"");
        }
        auto bytes = winrt::to_string(words);
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading the words");
        return 0;
    }
}
