// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the user shares, in Windows' own share sheet over a window: its words and its link handed over as the sheet
// asks for them, and the answer - shared, cancelled - told once, on the UI thread.
// Design: docs/design/platforms/winui/runtime.md#sharing

#include "Relay.h"

#include <memory>
#include <optional>
#include <string>

#include <shobjidl_core.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.Foundation.h>

using namespace stateui;
namespace transfer = winrt::Windows::ApplicationModel::DataTransfer;

extern "C" void stateui_winui_share(
    StateUIObjectRef handle, char const *text, char const *link, void *context, void (*answered)(void *, int32_t)) {
    // Told once, whichever of the sheet's ends comes first.
    auto told = std::make_shared<bool>(false);
    auto tell = [told, context, answered](int32_t shared) {
        runOnUIThread([told, context, answered, shared] {
            if (*told) return;
            *told = true;
            answered(context, shared);
        });
    };
    try {
        auto window = reinterpret_cast<HWND>(borrow<xaml::Window>(handle).AppWindow().Id().Value);
        auto interop = winrt::get_activation_factory<transfer::DataTransferManager, IDataTransferManagerInterop>();
        transfer::DataTransferManager manager{nullptr};
        winrt::check_hresult(interop->GetForWindow(
            window, winrt::guid_of<transfer::DataTransferManager>(), winrt::put_abi(manager)));
        std::optional<std::string> words = text ? std::optional(std::string(text)) : std::nullopt;
        std::optional<std::string> address = link ? std::optional(std::string(link)) : std::nullopt;
        auto requested = std::make_shared<winrt::event_token>();
        *requested = manager.DataRequested(guarded("handling DataRequested",
            [requested, words, address, tell](transfer::DataTransferManager const &sender,
                                              transfer::DataRequestedEventArgs const &arguments) {
                sender.DataRequested(*requested);
                auto data = arguments.Request().Data();
                data.Properties().Title(winrt::to_hstring(words.value_or(address.value_or(""))));
                if (words) data.SetText(winrt::to_hstring(*words));
                if (address) data.SetWebLink(winrt::Windows::Foundation::Uri(winrt::to_hstring(*address)));
                data.ShareCompleted(
                    guarded("handling ShareCompleted", [tell](auto const &, auto const &) { tell(1); }));
                data.ShareCanceled(guarded("handling ShareCanceled", [tell](auto const &, auto const &) { tell(0); }));
            }));
        winrt::check_hresult(interop->ShowShareUIForWindow(window));
    } catch (...) {
        report("offering what the user shares");
        tell(-1);
    }
}
