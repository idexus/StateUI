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

#include "CStateUIWinUI.h"

namespace stateui {
    namespace xaml = winrt::Microsoft::UI::Xaml;
    namespace controls = winrt::Microsoft::UI::Xaml::Controls;
    using winrt::Windows::Foundation::IInspectable;

    /// The host's callbacks, set once by run or embed.
    extern StateUIWinUICallbacks callbacks;

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
}
