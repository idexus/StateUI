// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window: its title, and a root of four rows - the window's chrome, its
// menu bar, the row of tabs, and the arrangement of pages - with the overlay
// laid over the page, shown and closed; its activation and its minimizing
// told as the application's phase.
// Design: docs/design/platforms/winui/pages.md#the-windows-chrome

#include "Relay.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#include <winrt/Windows.System.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::System::VirtualKey;
using winrt::Windows::System::VirtualKeyModifiers;

namespace windowing = winrt::Microsoft::UI::Windowing;

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

    /// The application's phase as `window` stands: minimized, else in use where it is `activated`, else behind
    /// another.
    int32_t phase(windowing::AppWindow const &window, bool activated) {
        auto presenter = window.Presenter().try_as<windowing::OverlappedPresenter>();
        if (presenter && presenter.State() == windowing::OverlappedPresenterState::Minimized) return 2;
        return activated ? 0 : 1;
    }
}

extern "C" StateUIObjectRef stateui_winui_window_make(int64_t number) {
    try {
        xaml::Window window;
        window.SystemBackdrop(xaml::Media::MicaBackdrop());
        window.Content(rows({true, true, true, false}));
        // The window's state is read at each of them: a minimized window is also told it lost its activation.
        window.Activated([number](IInspectable const &sender, xaml::WindowActivatedEventArgs const &args) {
            auto activated = args.WindowActivationState() != xaml::WindowActivationState::Deactivated;
            callbacks.phaseChanged(number, phase(sender.as<xaml::Window>().AppWindow(), activated));
        });
        window.AppWindow().Changed(
            [number](windowing::AppWindow const &sender, windowing::AppWindowChangedEventArgs const &args) {
                if (!args.DidPresenterChange() && !args.DidSizeChange()) return;
                if (phase(sender, false) == 2) callbacks.phaseChanged(number, 2);
            });
        window.Closed([number](IInspectable const &, xaml::WindowEventArgs const &) { callbacks.windowClosed(number); });
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
        standInRow(root(borrow<xaml::Window>(handle)), 3, content);
    } catch (winrt::hresult_error const &error) {
        report(error, "filling a window");
    }
}

extern "C" void stateui_winui_window_set_overlay(StateUIObjectRef handle, StateUIObjectRef overlay) {
    try {
        auto children = root(borrow<xaml::Window>(handle)).Children();
        controls::Grid layer{nullptr};
        for (auto const &child : children)
            if (auto grid = child.try_as<controls::Grid>(); grid && winrt::unbox_value_or<winrt::hstring>(grid.Tag(), L"") == L"overlay")
                layer = grid;
        if (!layer && !overlay) return;
        if (!layer) {
            // Where the page stands, over it and over its sheets; with no background, a click beside what it holds
            // goes on to them.
            layer = controls::Grid();
            layer.Tag(winrt::box_value(L"overlay"));
            controls::Grid::SetRow(layer, 3);
            controls::Canvas::SetZIndex(layer, 1);
            children.Append(layer);
        }
        layer.Children().Clear();
        if (overlay) layer.Children().Append(as<xaml::UIElement>(overlay));
        else if (uint32_t index; children.IndexOf(layer, index)) children.RemoveAt(index);
    } catch (winrt::hresult_error const &error) {
        report(error, "laying the overlay over a window");
    }
}

extern "C" void stateui_winui_window_set_chrome(
    StateUIObjectRef handle, StateUIObjectRef titleBar, StateUIObjectRef menuBar, StateUIObjectRef tabs
) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto grid = root(window);
        standInRow(grid, 0, titleBar);
        standInRow(grid, 1, menuBar);
        standInRow(grid, 2, tabs);
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

namespace {
    /// How many pixels a DIP is in `window`, known before its content is laid out: a window's id is its HWND.
    double scale(xaml::Window const &window) {
        auto dpi = GetDpiForWindow(reinterpret_cast<HWND>(window.AppWindow().Id().Value));
        return dpi ? dpi / 96.0 : 1.0;
    }

    /// The work area of the display `window` stands on, in pixels.
    winrt::Windows::Graphics::RectInt32 workArea(xaml::Window const &window) {
        auto area = windowing::DisplayArea::GetFromWindowId(window.AppWindow().Id(), windowing::DisplayAreaFallback::Nearest);
        return area.WorkArea();
    }
}

extern "C" void stateui_winui_window_set_frame(StateUIObjectRef handle, bool const *has, double const *values) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto app = window.AppWindow();
        auto pixels = scale(window);
        if (has[0] || has[1]) {
            auto area = workArea(window);
            auto at = app.Position();
            if (has[0]) at.X = area.X + static_cast<int32_t>(std::lround(values[0] * pixels));
            if (has[1]) at.Y = area.Y + static_cast<int32_t>(std::lround(values[1] * pixels));
            app.Move(at);
        }
        if (has[2] || has[3]) {
            // The content covers the title bar, which ResizeClient would add again: the frame is what stands now.
            auto outer = app.Size();
            auto client = app.ClientSize();
            if (has[2]) outer.Width += static_cast<int32_t>(std::lround(values[2] * pixels)) - client.Width;
            if (has[3]) outer.Height += static_cast<int32_t>(std::lround(values[3] * pixels)) - client.Height;
            app.Resize(outer);
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "placing a window");
    }
}

extern "C" void stateui_winui_window_set_limits(StateUIObjectRef handle, double const *limits) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto presenter = window.AppWindow().Presenter().try_as<windowing::OverlappedPresenter>();
        if (!presenter) return;
        auto pixels = scale(window);
        auto size = [&](double dips) -> winrt::Windows::Foundation::IReference<int32_t> {
            if (dips <= 0) return nullptr;
            return static_cast<int32_t>(std::lround(dips * pixels));
        };
        presenter.PreferredMinimumWidth(size(limits[0]));
        presenter.PreferredMinimumHeight(size(limits[1]));
        presenter.PreferredMaximumWidth(size(limits[2]));
        presenter.PreferredMaximumHeight(size(limits[3]));
    } catch (winrt::hresult_error const &error) {
        report(error, "bounding a window");
    }
}

extern "C" void stateui_winui_window_set_buttons(StateUIObjectRef handle, bool maximizable, bool minimizable) {
    try {
        auto presenter = borrow<xaml::Window>(handle).AppWindow().Presenter().try_as<windowing::OverlappedPresenter>();
        if (!presenter) return;
        presenter.IsMaximizable(maximizable);
        presenter.IsMinimizable(minimizable);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a window's buttons");
    }
}

extern "C" void stateui_winui_window_set_translucent(StateUIObjectRef handle, bool translucent) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto acrylic = window.SystemBackdrop().try_as<xaml::Media::DesktopAcrylicBackdrop>();
        if (translucent == static_cast<bool>(acrylic)) return;
        if (translucent) window.SystemBackdrop(xaml::Media::DesktopAcrylicBackdrop());
        else window.SystemBackdrop(xaml::Media::MicaBackdrop());
    } catch (winrt::hresult_error const &error) {
        report(error, "making a window translucent");
    }
}

extern "C" void stateui_winui_window_frame(StateUIObjectRef handle, double *values) {
    try {
        auto window = borrow<xaml::Window>(handle);
        auto app = window.AppWindow();
        auto pixels = scale(window);
        auto area = workArea(window);
        auto at = app.Position();
        auto size = app.ClientSize();
        values[0] = (at.X - area.X) / pixels;
        values[1] = (at.Y - area.Y) / pixels;
        values[2] = size.Width / pixels;
        values[3] = size.Height / pixels;
        auto presenter = app.Presenter().try_as<windowing::OverlappedPresenter>();
        auto dips = [&](winrt::Windows::Foundation::IReference<int32_t> const &value) {
            return value ? value.Value() / pixels : 0.0;
        };
        values[4] = presenter ? dips(presenter.PreferredMinimumWidth()) : 0;
        values[5] = presenter ? dips(presenter.PreferredMinimumHeight()) : 0;
        values[6] = presenter ? dips(presenter.PreferredMaximumWidth()) : 0;
        values[7] = presenter ? dips(presenter.PreferredMaximumHeight()) : 0;
        values[8] = presenter && presenter.IsMaximizable() ? 1 : 0;
        values[9] = presenter && presenter.IsMinimizable() ? 1 : 0;
        values[10] = window.SystemBackdrop().try_as<xaml::Media::DesktopAcrylicBackdrop>() ? 1 : 0;
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a window's frame");
    }
}

extern "C" int32_t stateui_winui_window_system_title(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto bytes = winrt::to_string(borrow<xaml::Window>(handle).AppWindow().Title());
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a window's name");
        return 0;
    }
}
