// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WinUI started on the calling thread - its own loop, or embedded in a thread
// with none - the doorbell's post onto the UI thread's queue, and the frames.
// Design: docs/design/platforms/winui/runtime.md#starting

#include "Relay.h"

#include <chrono>

#include <winrt/Windows.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.XamlTypeInfo.h>

namespace stateui {
    StateUIWinUICallbacks callbacks{};

    namespace {
        winrt::Microsoft::UI::Dispatching::DispatcherQueue queue{nullptr};
        winrt::event_token rendering{};
        bool holding = false;

        /// The application: WinUI's control resources and their type information, with no XAML file.
        /// Design: docs/design/platforms/winui/runtime.md#an-application-with-no-xaml
        struct StateUIApplication : xaml::ApplicationT<StateUIApplication, xaml::Markup::IXamlMetadataProvider> {
            explicit StateUIApplication(bool embedded) : embedded(embedded) {}

            void OnLaunched(xaml::LaunchActivatedEventArgs const &) {
                if (embedded) return;
                Resources().MergedDictionaries().Append(controls::XamlControlsResources());
                queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
                callbacks.launched();
            }

            xaml::Markup::IXamlType GetXamlType(winrt::Windows::UI::Xaml::Interop::TypeName const &type) {
                return provider().GetXamlType(type);
            }

            xaml::Markup::IXamlType GetXamlType(winrt::hstring const &name) {
                return provider().GetXamlType(name);
            }

            winrt::com_array<xaml::Markup::XmlnsDefinition> GetXmlnsDefinitions() {
                return provider().GetXmlnsDefinitions();
            }

            /// Made on the first question, as the XAML compiler's own provider is.
            xaml::XamlTypeInfo::XamlControlsXamlMetaDataProvider provider() {
                if (!types) types = xaml::XamlTypeInfo::XamlControlsXamlMetaDataProvider();
                return types;
            }

            bool embedded;
            xaml::XamlTypeInfo::XamlControlsXamlMetaDataProvider types{nullptr};
        };

        /// Loads the Windows App SDK's runtime the application carries, which registers its classes.
        void loadRuntime() {
            auto runtime = LoadLibraryExW(L"Microsoft.WindowsAppRuntime.dll", nullptr, 0);
            if (!runtime) winrt::throw_last_error();
            using EnsureIsLoaded = HRESULT(__stdcall *)();
            auto ensure = reinterpret_cast<EnsureIsLoaded>(GetProcAddress(runtime, "WindowsAppRuntime_EnsureIsLoaded"));
            if (ensure) winrt::check_hresult(ensure());
        }
    }
}

using namespace stateui;

extern "C" int32_t stateui_winui_run(StateUIWinUICallbacks const *given) {
    callbacks = *given;
    try {
        loadRuntime();
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        xaml::Application::Start([](auto &&) { winrt::make<StateUIApplication>(false); });
        return 0;
    } catch (winrt::hresult_error const &error) {
        report(error, "starting WinUI");
        return error.code();
    }
}

extern "C" int32_t stateui_winui_embed(StateUIWinUICallbacks const *given) {
    callbacks = *given;
    try {
        static bool embedded = false;
        if (embedded) return 0;
        loadRuntime();
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        static auto controller = winrt::Microsoft::UI::Dispatching::DispatcherQueueController::CreateOnCurrentThread();
        // The application first: InitializeForCurrentThread takes its type information, and calls its OnLaunched.
        static auto application = winrt::make<StateUIApplication>(true);
        static auto manager = xaml::Hosting::WindowsXamlManager::InitializeForCurrentThread();
        application.Resources().MergedDictionaries().Append(controls::XamlControlsResources());
        queue = controller.DispatcherQueue();
        embedded = true;
        return 0;
    } catch (winrt::hresult_error const &error) {
        report(error, "embedding WinUI");
        return error.code();
    }
}

extern "C" void stateui_winui_pump(double seconds) {
    auto until = std::chrono::steady_clock::now() + std::chrono::duration<double>(seconds);
    MSG message;
    do {
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        MsgWaitForMultipleObjects(0, nullptr, FALSE, 5, QS_ALLINPUT);
    } while (std::chrono::steady_clock::now() < until);
}

extern "C" void stateui_winui_post_turn(void) {
    try {
        if (queue) queue.TryEnqueue([] { callbacks.turn(); });
    } catch (winrt::hresult_error const &error) {
        report(error, "posting a turn");
    }
}

extern "C" void stateui_winui_hold_frames(bool hold) {
    if (hold == holding) return;
    holding = hold;
    try {
        if (hold) {
            rendering = xaml::Media::CompositionTarget::Rendering(
                [](IInspectable const &, IInspectable const &) { callbacks.frame(); });
        } else {
            xaml::Media::CompositionTarget::Rendering(rendering);
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "holding the frames");
    }
}

extern "C" void stateui_winui_release(StateUIObjectRef object) {
    if (object) reinterpret_cast<::IUnknown *>(object)->Release();
}
