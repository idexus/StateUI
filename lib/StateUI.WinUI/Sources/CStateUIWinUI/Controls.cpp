// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls: a text block and a button, and what the user does to them.

#include "Relay.h"

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
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

extern "C" void stateui_winui_button_invoke(StateUIObjectRef handle) {
    try {
        xaml::Automation::Peers::ButtonAutomationPeer peer(borrow<controls::Button>(handle));
        peer.as<xaml::Automation::Provider::IInvokeProvider>().Invoke();
    } catch (winrt::hresult_error const &error) {
        report(error, "pressing a button");
    }
}
