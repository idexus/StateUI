// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the gallery relay's files share: the projection, the callbacks, how a handle crosses, and the one report of a
// failure - no C++ exception leaves a function of the relay.
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
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

#include "CGalleryWinUI.h"

namespace gallery {
    namespace xaml = winrt::Microsoft::UI::Xaml;
    namespace controls = winrt::Microsoft::UI::Xaml::Controls;

    /// What the elements tell their Swift halves.
    extern GalleryWinUICallbacks callbacks;

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
        std::fprintf(stderr, "Gallery WinUI: %s failed: %s\n", where, words.c_str());
        std::fflush(stderr);
    }

    /// Hands a projected object's default interface to Swift, AddRef'd.
    template <typename T>
    GalleryObjectRef detach(T object) {
        return static_cast<GalleryObjectRef>(winrt::detach_abi(object));
    }

    /// The object a handle holds, as any of its interfaces.
    template <typename T>
    T as(GalleryObjectRef handle) {
        winrt::Windows::Foundation::IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        return object.as<T>();
    }

    /// A solid brush of a colour, its channels 0 through 255.
    inline xaml::Media::SolidColorBrush brush(uint8_t red, uint8_t green, uint8_t blue) {
        return xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{255, red, green, blue});
    }
}
