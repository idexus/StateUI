// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The web view's WinUI relay: WinUI's WebView2 over the system's WebView2 runtime, C++/WinRT behind these C
// functions, which the backend's Swift half calls. The element is handed over as a WinUI host's handle is - its
// default interface, AddRef'd - and tells what its page does by the number its Swift half gave it.
#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A WebView2: its default interface, AddRef'd; let go with `stateui_webview_winui_release`.
typedef struct WebViewObject *WebViewObjectRef;

/// What the web views tell their Swift halves, each naming its view by the number it was made with.
typedef struct {
    /// A page began to be gone to, for the reason the platform says (StateUI's WebNavigationType), at `address`.
    void (*navigating)(int64_t view, int32_t told, char const *address);

    /// Its navigation ended (StateUI's WebNavigationResult) at `address`.
    void (*navigated)(int64_t view, int32_t result, char const *address);

    /// Its history changed: whether there is a page behind and ahead.
    void (*history)(int64_t view, bool back, bool forward);

    /// Its web process ended, leaving it blank.
    void (*ended)(int64_t view);

    /// The script waiting under `ticket` ran, or did not: the JSON its value is written in.
    void (*answered)(int64_t ticket, bool ran, char const *json);
} WebViewWinUICallbacks;

/// Hands the relay what it tells; said once, before any web view is made.
void stateui_webview_winui_set_callbacks(WebViewWinUICallbacks const *callbacks);

/// A web view: it goes to `address` asking as `agent` - the runtime's own for an empty one - where `document` is
/// given, that is what the address answers whenever the view asks for it, and nothing is fetched; its CoreWebView2 stands a
/// moment after it is first asked. A step goes back (1), forward (2) or loads the page again. Let go of, with its
/// documents, by `stateui_webview_winui_release`.
WebViewObjectRef stateui_webview_winui_make(int64_t view);
void stateui_webview_winui_release(WebViewObjectRef web, int64_t view);
void stateui_webview_winui_show(
    WebViewObjectRef web, int64_t view, char const *address, char const *document, char const *agent);
void stateui_webview_winui_set_agent(WebViewObjectRef web, int64_t view, char const *agent);
void stateui_webview_winui_step(WebViewObjectRef web, int32_t step);
void stateui_webview_winui_evaluate(WebViewObjectRef web, char const *script, int64_t ticket);

/// What a test reads of the web view `view` - "address" the page's, "document" the one written in place it shows
/// there, "agent" what it calls itself - in UTF-8; the length.
int32_t stateui_webview_winui_read(WebViewObjectRef web, int64_t view, char const *what, char *utf8, int32_t capacity);

/// Ends the processes drawing its pages, as the system ends a web process; whether any was ended. What a test does.
bool stateui_webview_winui_end_content(WebViewObjectRef web);

#ifdef __cplusplus
}
#endif
