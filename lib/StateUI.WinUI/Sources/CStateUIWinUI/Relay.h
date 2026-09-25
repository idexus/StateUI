// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the relay's files share: the projection, the host's callbacks, and the
// three ways a handle crosses. No C++ exception leaves a function of the relay.
// Design: docs/design/platforms/winui/relay.md#the-c-surface
#pragma once

#define NOMINMAX
#include <windows.h>
#include <unknwn.h>
// winbase.h's macro would rewrite a WinRT method of the same name.
#undef GetCurrentTime

#include <cstdio>
#include <string_view>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.Numerics.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

#include "CStateUIWinUI.h"

namespace stateui {
    namespace xaml = winrt::Microsoft::UI::Xaml;
    namespace controls = winrt::Microsoft::UI::Xaml::Controls;
    using winrt::Windows::Foundation::IInspectable;

    /// The host's callbacks, set once by run or embed.
    extern StateUIWinUICallbacks callbacks;

    /// Runs `work` on the UI thread, in its turn; from any thread.
    void post(void (*work)());

    /// WinUI's own brush for a brush as the host hands it; null for none.
    xaml::Media::Brush brush(StateUIBrush const &brush);

    /// Whether the view numbered `view` listens for taps; and a press assistive technology made on it, told as
    /// a tap.
    bool hearsTaps(int64_t view);
    void press(int64_t view);

    /// Whether the keyboard's focus is on `element` or on what stands in it.
    bool holdsFocus(xaml::UIElement const &element);

    /// Reads the control's theme again, so its template takes the resources written into the control.
    void readThemeAgain(xaml::FrameworkElement const &control);

    /// Paints a panel clear while its view listens for the user or offers a context menu, so it is hit across its
    /// bounds and not only where its children stand; takes that away once neither holds. An author's background
    /// stays.
    void holdHitArea(xaml::UIElement const &element, int64_t view);

    /// WinUI's input scope for StateUI's `InputPurpose`: the on-screen keyboard a field brings up.
    xaml::Input::InputScope inputScope(int32_t purpose);

    /// Whether the window whose root is `root` presents sheets over its pages.
    bool showsSheets(controls::Grid const &root);

    /// Says what failed on standard error, where the host's log goes.
    inline void report(winrt::hresult_error const &error, char const *where) {
        std::fprintf(stderr, "StateUI WinUI: %s failed: 0x%08x %ls\n", where,
                     static_cast<unsigned>(error.code().value), error.message().c_str());
        std::fflush(stderr);
    }

    /// Hands a projected object's default interface to the host, AddRef'd.
    template <typename T>
    StateUIObjectRef detach(T object) {
        return static_cast<StateUIObjectRef>(winrt::detach_abi(object));
    }

    /// The object a handle holds, as the type it was made as: no QueryInterface.
    template <typename T>
    T borrow(StateUIObjectRef handle) {
        T object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object;
    }

    /// The object a handle holds, as any of its interfaces: one QueryInterface.
    template <typename T>
    T as(StateUIObjectRef handle) {
        IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object.as<T>();
    }

    /// UTF-8 from the host as WinRT's string.
    inline winrt::hstring text(char const *utf8) {
        return winrt::to_hstring(std::string_view(utf8 ? utf8 : ""));
    }

    /// A grid of rows, each given its height: `Auto` for one sized to what stands in it, a star for the rest.
    inline controls::Grid rows(std::initializer_list<bool> automatic) {
        controls::Grid grid;
        for (bool sized : automatic) {
            controls::RowDefinition row;
            row.Height(sized ? xaml::GridLengthHelper::Auto() : xaml::GridLengthHelper::FromValueAndType(1, xaml::GridUnitType::Star));
            grid.RowDefinitions().Append(row);
        }
        return grid;
    }

    /// Stands `element` in `row` of `grid` in place of what stood there; nothing for null.
    inline void standInRow(controls::Grid const &grid, int32_t row, StateUIObjectRef element) {
        auto children = grid.Children();
        auto next = element ? as<xaml::FrameworkElement>(element) : xaml::FrameworkElement{nullptr};
        for (uint32_t index = children.Size(); index-- > 0;) {
            auto child = children.GetAt(index).as<xaml::FrameworkElement>();
            if (controls::Grid::GetRow(child) != row) continue;
            if (child == next) return;
            children.RemoveAt(index);
        }
        if (!next) return;
        controls::Grid::SetRow(next, row);
        children.Append(next);
    }
}
