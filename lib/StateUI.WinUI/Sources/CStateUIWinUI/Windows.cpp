// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window: its title, its content, shown and closed.

#include "Relay.h"

using namespace stateui;

extern "C" StateUIObjectRef stateui_winui_window_make(void) {
    try {
        return detach(xaml::Window());
    } catch (winrt::hresult_error const &error) {
        report(error, "making a window");
        return nullptr;
    }
}

extern "C" void stateui_winui_window_set_title(StateUIObjectRef handle, char const *title) {
    try {
        borrow<xaml::Window>(handle).Title(text(title));
    } catch (winrt::hresult_error const &error) {
        report(error, "titling a window");
    }
}

extern "C" void stateui_winui_window_set_content(StateUIObjectRef handle, StateUIObjectRef content) {
    try {
        borrow<xaml::Window>(handle).Content(content ? as<xaml::UIElement>(content) : xaml::UIElement{nullptr});
    } catch (winrt::hresult_error const &error) {
        report(error, "filling a window");
    }
}

extern "C" void stateui_winui_window_activate(StateUIObjectRef handle) {
    try {
        borrow<xaml::Window>(handle).Activate();
    } catch (winrt::hresult_error const &error) {
        report(error, "showing a window");
    }
}

extern "C" void stateui_winui_window_close(StateUIObjectRef handle) {
    try {
        borrow<xaml::Window>(handle).Close();
    } catch (winrt::hresult_error const &error) {
        report(error, "closing a window");
    }
}
