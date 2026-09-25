// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window: its title, and a root of three rows - the window's chrome, the
// row of tabs beneath it, and the arrangement of pages - shown and closed.
// Design: docs/design/platforms/winui/pages.md#the-windows-chrome

#include "Relay.h"

#include <winrt/Windows.System.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::System::VirtualKey;
using winrt::Windows::System::VirtualKeyModifiers;

namespace {
    controls::Grid root(xaml::Window const &window) {
        return window.Content().as<controls::Grid>();
    }

    /// The window's way back - the mouse's back button, Alt+Left and the Back key - chosen on its chrome as -1; and
    /// Escape, which takes a sheet away.
    void takeTheWayBack(controls::Grid const &grid, int64_t chrome) {
        grid.AddHandler(
            xaml::UIElement::PointerPressedEvent(),
            winrt::box_value(xaml::Input::PointerEventHandler(
                [chrome](IInspectable const &sender, xaml::Input::PointerRoutedEventArgs const &args) {
                    auto point = args.GetCurrentPoint(sender.as<xaml::UIElement>());
                    if (!point.Properties().IsXButton1Pressed()) return;
                    callbacks.chosen(chrome, -1);
                    args.Handled(true);
                })),
            true);
        auto accelerate = [&](VirtualKey key, VirtualKeyModifiers modifiers) {
            xaml::Input::KeyboardAccelerator accelerator;
            accelerator.Key(key);
            accelerator.Modifiers(modifiers);
            accelerator.Invoked([chrome](auto const &, xaml::Input::KeyboardAcceleratorInvokedEventArgs const &args) {
                callbacks.chosen(chrome, -1);
                args.Handled(true);
            });
            grid.KeyboardAccelerators().Append(accelerator);
        };
        accelerate(VirtualKey::Left, VirtualKeyModifiers::Menu);
        accelerate(VirtualKey::GoBack, VirtualKeyModifiers::None);

        // Escape takes the top sheet away, chosen on the chrome as -3; with no sheet it is left to whatever has it.
        xaml::Input::KeyboardAccelerator escape;
        escape.Key(VirtualKey::Escape);
        escape.Invoked([chrome](auto const &, xaml::Input::KeyboardAcceleratorInvokedEventArgs const &args) {
            auto root = args.Element().try_as<controls::Grid>();
            if (!root || !showsSheets(root)) return;
            callbacks.chosen(chrome, -3);
            args.Handled(true);
        });
        grid.KeyboardAccelerators().Append(escape);
    }
}

extern "C" StateUIObjectRef stateui_winui_window_make(void) {
    try {
        xaml::Window window;
        window.SystemBackdrop(xaml::Media::MicaBackdrop());
        window.Content(rows({true, true, false}));
        return detach(window);
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
        standInRow(root(borrow<xaml::Window>(handle)), 2, content);
    } catch (winrt::hresult_error const &error) {
        report(error, "filling a window");
    }
}

extern "C" void stateui_winui_window_set_chrome(StateUIObjectRef handle, StateUIObjectRef titleBar, StateUIObjectRef tabs) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto grid = root(window);
        standInRow(grid, 0, titleBar);
        standInRow(grid, 1, tabs);
        if (titleBar && !window.ExtendsContentIntoTitleBar()) {
            auto bar = as<controls::TitleBar>(titleBar);
            window.ExtendsContentIntoTitleBar(true);
            window.SetTitleBar(bar);
            window.AppWindow().TitleBar().PreferredHeightOption(winrt::Microsoft::UI::Windowing::TitleBarHeightOption::Tall);
            takeTheWayBack(grid, winrt::unbox_value<int64_t>(bar.Tag()));
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "dressing a window");
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
