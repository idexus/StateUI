// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window: its title, and a root of four rows - the window's chrome, its
// menu bar, the row of tabs, and the arrangement of pages - with the overlays
// laid over the page, shown and closed; its activation and its minimizing
// told as the application's phase.
// Design: docs/design/platforms/winui/pages.md#the-windows-chrome

#include "Relay.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#include <winrt/Windows.System.h>
#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Composition.SystemBackdrops.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::System::VirtualKey;
using winrt::Windows::System::VirtualKeyModifiers;

namespace windowing = winrt::Microsoft::UI::Windowing;
namespace backdrops = winrt::Microsoft::UI::Composition::SystemBackdrops;
using winrt::Microsoft::UI::Composition::ICompositionSupportsSystemBackdrop;

namespace {
    /// The desktop acrylic of the thin kind or the base one in the theme's colour, its luminosity hiding `opacity`
    /// of the desktop and its tint `tintOpacity`; XAML's own configuration has it follow the window's activation.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-backdrop
    struct StateUIAcrylic : xaml::Media::SystemBackdropT<StateUIAcrylic> {
        StateUIAcrylic(bool thin, float opacity, float tintOpacity, uint32_t argb)
            : thin(thin), opacity(opacity), tintOpacity(tintOpacity), argb(argb) {}

        void OnTargetConnected(ICompositionSupportsSystemBackdrop const &target, xaml::XamlRoot const &root) {
            SystemBackdropT::OnTargetConnected(target, root);
            controller = backdrops::DesktopAcrylicController();
            controller.Kind(thin ? backdrops::DesktopAcrylicKind::Thin : backdrops::DesktopAcrylicKind::Base);
            // Every colour written: a controller given one value keeps none of the theme's own.
            auto colour = winrt::Windows::UI::Color{255, static_cast<uint8_t>(argb >> 16),
                static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)};
            controller.TintColor(colour);
            controller.TintOpacity(tintOpacity);
            controller.LuminosityOpacity(opacity);
            controller.FallbackColor(colour);
            controller.SetSystemBackdropConfiguration(GetDefaultSystemBackdropConfiguration(target, root));
            controller.AddSystemBackdropTarget(target);
        }

        void OnTargetDisconnected(ICompositionSupportsSystemBackdrop const &target) {
            SystemBackdropT::OnTargetDisconnected(target);
            if (!controller) return;
            controller.RemoveSystemBackdropTarget(target);
            controller.Close();
            controller = nullptr;
        }

        bool const thin;
        float const opacity;
        float const tintOpacity;
        uint32_t const argb;
        backdrops::DesktopAcrylicController controller{nullptr};
    };

    /// The window's acrylic; nil where it shows Mica.
    StateUIAcrylic *acrylic(xaml::Window const &window) {
        auto backdrop = window.SystemBackdrop();
        if (!backdrop || backdrop.try_as<xaml::Media::MicaBackdrop>()) return nullptr;
        return winrt::get_self<StateUIAcrylic>(backdrop.as<xaml::Media::ISystemBackdropOverrides>());
    }

    controls::Grid root(xaml::Window const &window) {
        return window.Content().as<controls::Grid>();
    }

    /// The window's way back - the mouse's back button, Alt+Left and the Back key - chosen on its chrome as -1; and
    /// Escape, which takes a sheet away.
    void takeTheWayBack(controls::Grid const &grid, int64_t chrome) {
        // The window's keys, not a control's: no tip says them under the pointer over everything it holds.
        grid.KeyboardAcceleratorPlacementMode(xaml::Input::KeyboardAcceleratorPlacementMode::Hidden);
        grid.AddHandler(
            xaml::UIElement::PointerPressedEvent(),
            winrt::box_value(xaml::Input::PointerEventHandler(guarded("handling PointerPressed",
                [chrome](IInspectable const &sender, xaml::Input::PointerRoutedEventArgs const &args) {
                    auto point = args.GetCurrentPoint(sender.as<xaml::UIElement>());
                    if (!point.Properties().IsXButton1Pressed()) return;
                    callbacks.chosen(chrome, -1);
                    args.Handled(true);
                }))),
            true);
        auto accelerate = [&](VirtualKey key, VirtualKeyModifiers modifiers) {
            xaml::Input::KeyboardAccelerator accelerator;
            accelerator.Key(key);
            accelerator.Modifiers(modifiers);
            accelerator.Invoked(guarded("handling Invoked",
                [chrome](auto const &, xaml::Input::KeyboardAcceleratorInvokedEventArgs const &args) {
                callbacks.chosen(chrome, -1);
                args.Handled(true);
            }));
            grid.KeyboardAccelerators().Append(accelerator);
        };
        accelerate(VirtualKey::Left, VirtualKeyModifiers::Menu);
        accelerate(VirtualKey::GoBack, VirtualKeyModifiers::None);

        // Escape takes the top sheet away, chosen on the chrome as -3; with no sheet it is left to whatever has it.
        xaml::Input::KeyboardAccelerator escape;
        escape.Key(VirtualKey::Escape);
        escape.Invoked(guarded("handling Invoked",
            [chrome](auto const &, xaml::Input::KeyboardAcceleratorInvokedEventArgs const &args) {
            auto root = args.Element().try_as<controls::Grid>();
            if (!root || !showsSheets(root)) return;
            callbacks.chosen(chrome, -3);
            args.Handled(true);
        }));
        grid.KeyboardAccelerators().Append(escape);
    }

    /// Whether `window` stands minimized.
    bool minimized(windowing::AppWindow const &window) {
        auto presenter = window.Presenter().try_as<windowing::OverlappedPresenter>();
        return presenter && presenter.State() == windowing::OverlappedPresenterState::Minimized;
    }

    /// Whether `window` stands off the screen: minimized, or hidden.
    bool offScreen(windowing::AppWindow const &window) {
        return minimized(window) || !window.IsVisible();
    }
}

extern "C" bool stateui_winui_window_shows_keys(StateUIObjectRef handle) {
    try {
        return root(as<xaml::Window>(handle)).KeyboardAcceleratorPlacementMode() !=
               xaml::Input::KeyboardAcceleratorPlacementMode::Hidden;
    } catch (...) {
        report("reading whether a window shows its keys");
        return false;
    }
}

extern "C" StateUIObjectRef stateui_winui_window_make(int64_t number) {
    try {
        xaml::Window window;
        window.SystemBackdrop(xaml::Media::MicaBackdrop());
        window.Content(rows({true, true, true, false}));
        // The window's state is read at each of them: a minimized window is also told it lost its activation, and
        // one hidden - with the window it belongs to, or by its scene - stands off the screen as a minimized one.
        window.Activated(guarded("handling Activated",
            [number](IInspectable const &sender, xaml::WindowActivatedEventArgs const &args) {
            auto activated = args.WindowActivationState() != xaml::WindowActivationState::Deactivated;
            // A window UI Automation closes is told it lost its activation once its AppWindow is gone: off the screen.
            auto hidden = true;
            try {
                hidden = offScreen(sender.as<xaml::Window>().AppWindow());
            } catch (winrt::hresult_invalid_argument const &) {
            }
            callbacks.windowStateChanged(number, hidden, activated);
        }));
        window.AppWindow().Changed(
            guarded("handling Changed",
                [number](windowing::AppWindow const &sender, windowing::AppWindowChangedEventArgs const &args) {
                if (args.DidVisibilityChange()) {
                    auto active = GetActiveWindow() == reinterpret_cast<HWND>(sender.Id().Value);
                    callbacks.windowStateChanged(number, offScreen(sender), active && sender.IsVisible());
                    return;
                }
                if (!args.DidPresenterChange() && !args.DidSizeChange()) return;
                if (minimized(sender)) callbacks.windowStateChanged(number, true, false);
            }));
        window.Closed(guarded("handling Closed", [number](IInspectable const &, xaml::WindowEventArgs const &) {
            callbacks.windowClosed(number);
        }));
        return detach(window);
    } catch (...) {
        report("making a window");
        return nullptr;
    }
}

extern "C" void stateui_winui_window_set_title(StateUIObjectRef handle, char const *title) {
    try {
        borrow<xaml::Window>(handle).Title(text(title));
    } catch (...) {
        report("titling a window");
    }
}

extern "C" void stateui_winui_window_set_content(StateUIObjectRef handle, StateUIObjectRef content) {
    try {
        standInRow(root(borrow<xaml::Window>(handle)), 3, content);
    } catch (...) {
        report("filling a window");
    }
}

extern "C" void stateui_winui_window_set_overlays(StateUIObjectRef handle, StateUIObjectRef const *overlays, int32_t count) {
    try {
        auto children = root(borrow<xaml::Window>(handle)).Children();
        controls::Grid layer{nullptr};
        for (auto const &child : children)
            if (auto grid = child.try_as<controls::Grid>(); grid && winrt::unbox_value_or<winrt::hstring>(grid.Tag(), L"") == L"overlay")
                layer = grid;
        if (!layer && count == 0) return;
        if (!layer) {
            // Where the page stands, over it and over its sheets' layer; with no background, a click beside what it
            // holds goes on to them.
            layer = controls::Grid();
            layer.Tag(winrt::box_value(L"overlay"));
            controls::Grid::SetRow(layer, 3);
            controls::Canvas::SetZIndex(layer, 2);
            children.Append(layer);
        }
        layer.Children().Clear();
        for (int32_t i = 0; i < count; ++i) layer.Children().Append(as<xaml::UIElement>(overlays[i]));
        if (uint32_t index; count == 0 && children.IndexOf(layer, index)) children.RemoveAt(index);
    } catch (...) {
        report("laying the overlays over a window");
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
    } catch (...) {
        report("dressing a window");
    }
}

extern "C" void stateui_winui_window_activate(StateUIObjectRef handle) {
    try {
        borrow<xaml::Window>(handle).Activate();
    } catch (...) {
        report("showing a window");
    }
}

extern "C" void stateui_winui_window_close(StateUIObjectRef handle) {
    try {
        borrow<xaml::Window>(handle).Close();
    } catch (...) {
        report("closing a window");
    }
}

extern "C" void stateui_winui_window_show_as_user(StateUIObjectRef handle, int32_t command) {
    try {
        ShowWindow(reinterpret_cast<HWND>(borrow<xaml::Window>(handle).AppWindow().Id().Value), command);
    } catch (...) {
        report("minimizing or restoring a window as the user");
    }
}

extern "C" void stateui_winui_window_set_shown(StateUIObjectRef handle, bool shown) {
    try {
        auto app = borrow<xaml::Window>(handle).AppWindow();
        if (shown) app.Show(false);
        else app.Hide();
    } catch (...) {
        report("showing or hiding a window");
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
    } catch (...) {
        report("placing a window");
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
    } catch (...) {
        report("bounding a window");
    }
}

extern "C" void stateui_winui_window_set_traits(
    StateUIObjectRef handle, bool maximizable, bool minimizable, bool floats
) {
    try {
        auto window = borrow<xaml::Window>(handle);
        if (auto presenter = window.AppWindow().Presenter().try_as<windowing::OverlappedPresenter>()) {
            presenter.IsMaximizable(maximizable);
            presenter.IsMinimizable(minimizable);
            presenter.IsAlwaysOnTop(floats);
        }
    } catch (...) {
        report("setting what a window is");
    }
}

extern "C" void stateui_winui_window_set_backdrop(
    StateUIObjectRef handle, bool blurred, bool thin, float opacity, float tintOpacity, uint32_t argb
) {
    try {
        auto window = borrow<xaml::Window>(handle);
        // The backdrop is made again only where it turns.
        auto shown = acrylic(window);
        if (!blurred) {
            if (shown || !window.SystemBackdrop()) window.SystemBackdrop(xaml::Media::MicaBackdrop());
            return;
        }
        if (shown && shown->thin == thin && shown->opacity == opacity && shown->tintOpacity == tintOpacity &&
            shown->argb == argb) return;
        window.SystemBackdrop(winrt::make<StateUIAcrylic>(thin, opacity, tintOpacity, argb));
    } catch (...) {
        report("setting a window's backdrop");
    }
}

extern "C" bool stateui_winui_window_acrylic(StateUIObjectRef handle, bool *thin, float *opacity) {
    try {
        auto shown = acrylic(borrow<xaml::Window>(handle));
        if (!shown) return false;
        // What the desktop acrylic holds, once the window stands; what it was made for until then.
        auto &controller = shown->controller;
        *thin = controller ? controller.Kind() == backdrops::DesktopAcrylicKind::Thin : shown->thin;
        *opacity = controller ? controller.LuminosityOpacity() : shown->opacity;
        return true;
    } catch (...) {
        report("reading a window's acrylic");
        return false;
    }
}

extern "C" void stateui_winui_window_set_background(StateUIObjectRef handle, bool written, uint32_t argb) {
    try {
        auto root = borrow<xaml::Window>(handle).Content().try_as<xaml::Controls::Panel>();
        if (!root) return;
        if (!written) return root.Background(nullptr);
        root.Background(xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{static_cast<uint8_t>(argb >> 24),
            static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8), static_cast<uint8_t>(argb)}));
    } catch (...) {
        report("painting a window's background");
    }
}

namespace {
    /// The card a navigation view lays over its detail, cleared: no fill, its edge the theme's divider - one
    /// dictionary for each theme, so the edge follows the theme by itself.
    xaml::ResourceDictionary clearedCard() {
        std::wstring brushes = L"<SolidColorBrush x:Key=\"NavigationViewContentBackground\" Color=\"#00000000\"/>"
                               L"<SolidColorBrush x:Key=\"NavigationViewContentGridBorderBrush\""
                               L" Color=\"{ThemeResource DividerStrokeColorDefault}\"/>";
        std::wstring written = L"<ResourceDictionary"
                               L" xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
                               L" xmlns:x=\"http://schemas.microsoft.com/winfx/2006/xaml\">"
                               L"<ResourceDictionary.ThemeDictionaries>";
        for (auto theme : {L"Light", L"Dark"})
            written += std::wstring(L"<ResourceDictionary x:Key=\"") + theme + L"\">" + brushes + L"</ResourceDictionary>";
        written += L"</ResourceDictionary.ThemeDictionaries></ResourceDictionary>";
        return xaml::Markup::XamlReader::Load(written).as<xaml::ResourceDictionary>();
    }

    /// Whether `merged` is the cleared card.
    bool isClearedCard(xaml::ResourceDictionary const &merged) {
        auto dark = merged.ThemeDictionaries().TryLookup(winrt::box_value(L"Dark")).try_as<xaml::ResourceDictionary>();
        return dark && ownBrush(dark, L"NavigationViewContentBackground");
    }
}

extern "C" void stateui_winui_window_clear_detail(StateUIObjectRef handle, bool clear) {
    try {
        // Written into the window's root, which every navigation view in the window reads on its way up.
        // Design: docs/design/platforms/winui/runtime.md#a-windows-backdrop
        auto grid = root(borrow<xaml::Window>(handle));
        auto merged = grid.Resources().MergedDictionaries();
        for (uint32_t at = 0; at < merged.Size(); ++at) {
            if (!isClearedCard(merged.GetAt(at))) continue;
            if (clear) return;
            merged.RemoveAt(at);
            return readThemeAgain(grid);
        }
        if (!clear) return;
        merged.Append(clearedCard());
        readThemeAgain(grid);
    } catch (...) {
        report("clearing the card over a window's detail");
    }
}

extern "C" bool stateui_winui_window_background(StateUIObjectRef handle, uint32_t *argb) {
    try {
        auto root = borrow<xaml::Window>(handle).Content().try_as<xaml::Controls::Panel>();
        auto brush = root ? root.Background().try_as<xaml::Media::SolidColorBrush>() : nullptr;
        if (!brush) return false;
        auto colour = brush.Color();
        *argb = uint32_t(colour.A) << 24 | uint32_t(colour.R) << 16 | uint32_t(colour.G) << 8 | colour.B;
        return true;
    } catch (...) {
        report("reading a window's background");
        return false;
    }
}

extern "C" void stateui_winui_window_set_theme(StateUIObjectRef handle, int32_t scheme) {
    try {
        auto root = borrow<xaml::Window>(handle).Content().try_as<xaml::FrameworkElement>();
        if (!root) return;
        root.RequestedTheme(scheme == 1 ? xaml::ElementTheme::Light
                            : scheme == 2 ? xaml::ElementTheme::Dark : xaml::ElementTheme::Default);
    } catch (...) {
        report("showing a window in a theme");
    }
}

extern "C" int32_t stateui_winui_window_actual_theme(StateUIObjectRef handle) {
    try {
        auto root = borrow<xaml::Window>(handle).Content().try_as<xaml::FrameworkElement>();
        return root && root.ActualTheme() == xaml::ElementTheme::Dark ? 2 : 1;
    } catch (...) {
        report("reading a window's theme");
        return 1;
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
        values[10] = acrylic(window) ? 1 : 0;
        values[11] = presenter && presenter.IsAlwaysOnTop() ? 1 : 0;
        values[12] = app.IsVisible() ? 1 : 0;
    } catch (...) {
        report("reading a window's frame");
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
    } catch (...) {
        report("reading a window's name");
        return 0;
    }
}
