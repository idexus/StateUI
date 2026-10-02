// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The web view's WinUI relay: WinUI's WebView2 over the system's WebView2
// runtime. What the page does is told through the callbacks - a navigation
// starting and ending, the way back and forward, the web process ending; a
// script answers through `answered` under its ticket, as the JSON its value is
// written in. A document written in place is what its address answers, served
// by the view.
// Design: docs/design/platforms/winui/controls.md#a-web-view

#include "Relay.h"

#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>

#include <shcore.h>
#include <shlwapi.h>

#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Microsoft.Web.WebView2.Core.h>

using namespace webview;

WebViewWinUICallbacks webview::callbacks{};
namespace core = winrt::Microsoft::Web::WebView2::Core;
namespace streams = winrt::Windows::Storage::Streams;

namespace {
    /// Why the platform says a navigation began, as StateUI's WebNavigationType: the page again (4), a step
    /// through the history it does not tell apart (0), a new page (3).
    int32_t told(core::CoreWebView2NavigationKind kind) {
        switch (kind) {
        case core::CoreWebView2NavigationKind::Reload: return 4;
        case core::CoreWebView2NavigationKind::BackOrForward: return 0;
        default: return 3;
        }
    }

    /// How a navigation ended, as StateUI's WebNavigationResult: arrived (1), called off (2), timed out (3), failed
    /// (4).
    int32_t ended(bool arrived, core::CoreWebView2WebErrorStatus status) {
        if (arrived) return 1;
        switch (status) {
        case core::CoreWebView2WebErrorStatus::OperationCanceled: return 2;
        case core::CoreWebView2WebErrorStatus::Timeout: return 3;
        default: return 4;
        }
    }

    std::string addressOf(controls::WebView2 const &web) {
        auto shown = web.CoreWebView2() ? winrt::hstring(web.CoreWebView2().Source())
                                        : web.Source() ? web.Source().AbsoluteUri() : winrt::hstring();
        return winrt::to_string(shown);
    }

    /// A stream reading `bytes`, held in memory.
    streams::IRandomAccessStream reading(std::string const &bytes) {
        winrt::com_ptr<IStream> memory;
        memory.attach(SHCreateMemStream(reinterpret_cast<BYTE const *>(bytes.data()), static_cast<UINT>(bytes.size())));
        if (!memory) winrt::throw_hresult(E_OUTOFMEMORY);
        streams::IRandomAccessStream stream{nullptr};
        winrt::check_hresult(CreateRandomAccessStreamOverStream(
            memory.get(), BSOS_DEFAULT, winrt::guid_of<streams::IRandomAccessStream>(), winrt::put_abi(stream)));
        return stream;
    }

    /// The documents each web view shows written in place, by its number and the address each is shown at.
    std::unordered_map<int64_t, std::unordered_map<std::wstring, std::shared_ptr<std::string>>> served;

    /// The agent each web view's runtime names itself by, as its CoreWebView2 stood: what an agent taken away gives back.
    std::unordered_map<int64_t, winrt::hstring> ownAgents;

    /// Names the view `view` by `agent`, or by the runtime's own for an empty one.
    void name(core::CoreWebView2 const &page, int64_t view, winrt::hstring const &agent) {
        auto own = ownAgents.find(view);
        auto named = agent.empty() && own != ownAgents.end() ? own->second : agent;
        if (!named.empty() && page.Settings().UserAgent() != named) page.Settings().UserAgent(named);
    }

    /// The document the web view `view` shows written in place at `address`; empty for none.
    std::string servedAt(int64_t view, std::string const &address) {
        auto documents = served.find(view);
        if (documents == served.end()) return {};
        auto document = documents->second.find(std::wstring(winrt::to_hstring(address)));
        return document == documents->second.end() ? std::string() : *document->second;
    }

    /// Hears the history of the web view `view` shows, and answers what it asks for with its documents written in
    /// place - once its CoreWebView2 stands.
    void hear(core::CoreWebView2 const &page, int64_t view) {
        ownAgents[view] = page.Settings().UserAgent();
        page.HistoryChanged(guarded("handling HistoryChanged",
            [view](core::CoreWebView2 const &sender, winrt::Windows::Foundation::IInspectable const &) {
            callbacks.history(view, sender.CanGoBack(), sender.CanGoForward());
        }));
        page.WebResourceRequested(guarded("handling WebResourceRequested", [view](core::CoreWebView2 const &sender,
                                         core::CoreWebView2WebResourceRequestedEventArgs const &args) {
            auto documents = served.find(view);
            if (documents == served.end()) return;
            auto document = documents->second.find(std::wstring(args.Request().Uri()));
            if (document == documents->second.end()) return;
            args.Response(sender.Environment().CreateWebResourceResponse(
                reading(*document->second), 200, L"OK", L"Content-Type: text/html; charset=utf-8"));
        }));
    }

    /// Goes to `address` asking as `agent`; where `document` is given, it is what the address answers, whenever
    /// the view asks for it again, and nothing is fetched.
    void go(core::CoreWebView2 const &page, int64_t view, winrt::hstring const &address,
            std::shared_ptr<std::string> const &document, winrt::hstring const &agent) {
        name(page, view, agent);
        if (document) {
            served[view][std::wstring(address)] = document;
            page.AddWebResourceRequestedFilter(address, core::CoreWebView2WebResourceContext::Document);
        }
        page.Navigate(address);
    }
}

extern "C" WebViewObjectRef stateui_webview_winui_make(int64_t view) {
    try {
        controls::WebView2 web;
        web.CoreWebView2Initialized(guarded("handling CoreWebView2Initialized",
            [view](controls::WebView2 const &sender, auto const &) {
            if (auto page = sender.CoreWebView2()) hear(page, view);
        }));
        web.NavigationStarting(guarded("handling NavigationStarting", [view](controls::WebView2 const &,
                                      core::CoreWebView2NavigationStartingEventArgs const &args) {
            callbacks.navigating(view, told(args.NavigationKind()), winrt::to_string(args.Uri()).c_str());
        }));
        web.NavigationCompleted(guarded("handling NavigationCompleted", [view](controls::WebView2 const &sender,
                                       core::CoreWebView2NavigationCompletedEventArgs const &args) {
            callbacks.navigated(view, ended(args.IsSuccess(), args.WebErrorStatus()), addressOf(sender).c_str());
        }));
        web.CoreProcessFailed(guarded("handling CoreProcessFailed",
            [view](controls::WebView2 const &, core::CoreWebView2ProcessFailedEventArgs const &args) {
            auto kind = args.ProcessFailedKind();
            if (kind == core::CoreWebView2ProcessFailedKind::RenderProcessExited ||
                kind == core::CoreWebView2ProcessFailedKind::BrowserProcessExited)
                callbacks.ended(view);
        }));
        return detach(web);
    } catch (...) {
        report("making a web view");
        return nullptr;
    }
}

extern "C" void stateui_webview_winui_show(WebViewObjectRef handle, int64_t view, char const *address,
                                       char const *document, char const *agent) {
    try {
        auto web = as<controls::WebView2>(handle);
        auto at = text(address);
        auto held = document ? std::make_shared<std::string>(document) : nullptr;
        auto asking = text(agent);
        if (auto page = web.CoreWebView2()) return go(page, view, at, held, asking);
        // Its CoreWebView2 stands a moment after it is asked for: the page is gone to then, in the order asked.
        auto token = std::make_shared<winrt::event_token>();
        *token = web.CoreWebView2Initialized(
            guarded("handling CoreWebView2Initialized",
                [token, view, at, held, asking](controls::WebView2 const &sender, auto const &) {
                sender.CoreWebView2Initialized(*token);
                if (auto page = sender.CoreWebView2()) go(page, view, at, held, asking);
            }));
        web.EnsureCoreWebView2Async();
    } catch (...) {
        report("showing a page");
    }
}

extern "C" void stateui_webview_winui_set_callbacks(WebViewWinUICallbacks const *given) {
    callbacks = *given;
}

extern "C" void stateui_webview_winui_release(WebViewObjectRef handle, int64_t view) {
    try {
        served.erase(view);
        ownAgents.erase(view);
        winrt::Windows::Foundation::IInspectable object{nullptr};
        winrt::attach_abi(object, handle);
    } catch (...) {
        report("letting go of a web view");
    }
}

extern "C" void stateui_webview_winui_set_agent(WebViewObjectRef handle, int64_t view, char const *agent) {
    try {
        if (auto page = as<controls::WebView2>(handle).CoreWebView2()) name(page, view, text(agent));
    } catch (...) {
        report("naming a web view's agent");
    }
}

extern "C" void stateui_webview_winui_step(WebViewObjectRef handle, int32_t step) {
    try {
        auto web = as<controls::WebView2>(handle);
        if (step == 1) web.GoBack();
        else if (step == 2) web.GoForward();
        else web.Reload();
    } catch (...) {
        report("stepping a web view");
    }
}

extern "C" void stateui_webview_winui_evaluate(WebViewObjectRef handle, char const *script, int64_t ticket) {
    try {
        auto web = as<controls::WebView2>(handle);
        auto queue = web.DispatcherQueue();
        web.ExecuteScriptAsync(text(script)).Completed(
            guarded("handling Completed",
                [ticket, queue](auto const &operation, winrt::Windows::Foundation::AsyncStatus status) {
                auto done = status == winrt::Windows::Foundation::AsyncStatus::Completed;
                auto json = done ? winrt::to_string(operation.GetResults()) : std::string();
                queue.TryEnqueue(guarded("handling TryEnqueue", [ticket, done, json] {
                    callbacks.answered(ticket, done, done ? json.c_str() : nullptr);
                }));
            }));
    } catch (...) {
        report("running a script");
        callbacks.answered(ticket, false, nullptr);
    }
}

extern "C" int32_t stateui_webview_winui_read(
    WebViewObjectRef handle, int64_t view, char const *what, char *utf8, int32_t capacity
) {
    try {
        auto web = as<controls::WebView2>(handle);
        std::string_view asked(what ? what : "");
        auto address = addressOf(web);
        std::string read = asked == "address" ? address
            : asked == "agent" && web.CoreWebView2() ? winrt::to_string(web.CoreWebView2().Settings().UserAgent())
            : asked == "document" ? servedAt(view, address)
            : std::string();
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(read.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, read.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(read.size());
    } catch (...) {
        report("reading a web view");
        return 0;
    }
}

extern "C" bool stateui_webview_winui_end_content(WebViewObjectRef handle) {
    try {
        // What the system does to a web process it ends: each process drawing pages, ended from outside.
        auto page = as<controls::WebView2>(handle).CoreWebView2();
        if (!page) return false;
        bool ended = false;
        for (auto const &process : page.Environment().GetProcessInfos()) {
            if (process.Kind() != core::CoreWebView2ProcessKind::Renderer) continue;
            if (auto running = OpenProcess(PROCESS_TERMINATE, FALSE, static_cast<DWORD>(process.ProcessId()))) {
                ended = TerminateProcess(running, 1) || ended;
                CloseHandle(running);
            }
        }
        return ended;
    } catch (...) {
        report("ending a web view's content");
        return false;
    }
}
