// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the web view relay's files share: the projection, the callbacks, how a handle crosses, words as WinRT takes
// them, and the one report of a failure - no C++ exception leaves a function of the relay.
#pragma once

#define NOMINMAX
#include <windows.h>
#include <unknwn.h>
// winbase.h's macro would rewrite a WinRT method of the same name.
#undef GetCurrentTime

#include <cstdio>
#include <exception>
#include <string>

#include <winrt/Windows.Foundation.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>

#include "CWebViewWinUI.h"

namespace webview {
    namespace controls = winrt::Microsoft::UI::Xaml::Controls;

    /// What the web views tell their Swift halves.
    extern WebViewWinUICallbacks callbacks;

    /// Says on standard error what failed and why, for the exception being handled. Called only inside a
    /// `catch (...)`.
    inline void report(char const *where) {
        std::string words;
        try {
            throw;
        } catch (winrt::hresult_error const &error) {
            words = winrt::to_string(error.message());
        } catch (std::exception const &error) {
            words = error.what();
        } catch (...) {
            words = "an exception of no kind known";
        }
        std::fprintf(stderr, "StateUI WebView WinUI: %s failed: %s\n", where, words.c_str());
        std::fflush(stderr);
    }

    /// Hands a projected object's default interface to Swift, AddRef'd.
    template <typename T>
    WebViewObjectRef detach(T object) {
        return static_cast<WebViewObjectRef>(winrt::detach_abi(object));
    }

    /// The object a handle holds, as any of its interfaces.
    template <typename T>
    T as(WebViewObjectRef handle) {
        winrt::Windows::Foundation::IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object.as<T>();
    }

    /// UTF-8 words as WinRT takes them; none for a null pointer.
    inline winrt::hstring text(char const *utf8) {
        return utf8 ? winrt::to_hstring(utf8) : winrt::hstring();
    }
}
