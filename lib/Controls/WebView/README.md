# WebView

A page of the web in the tree: one fetched from an address, or a document
written in place. WebView is a component - a library of its own beside
StateUI - so an application that shows no web page links neither it nor its
platform's web engine.

## Adding it to an application

The application's module imports the view, and each head registers the web
view's backend for its host before it runs:

```text
Package.swift
  dependencies:  .package(path: "<StateUI>/lib/Controls/WebView")
                 .package(path: "<StateUI>/lib/Controls/WebView/WebView.<Host>")   for each head
  the module:    .product(name: "StateUIWebView", package: "StateUIWebView")
  each head:     .product(name: "StateUIWebView<Host>", package: "StateUIWebView<Host>")

Platforms/<Host>/main.swift
  StateUIWebView<Host>.register()         before the host runs
```

On Android the application's Gradle build also compiles the backend's Java,
`WebView.Android/Java`. On GTK the backend needs WebKitGTK 6.0
(`libwebkitgtk-6.0-dev` on Ubuntu, `webkitgtk-6.0` on Arch).

## Showing a page

```swift
import StateUIWebView

WebView("https://example.com")
```

A document written in place shows without the network. Its relative links
resolve against the address given beside it, where one is:

```swift
import StateUIWebView

WebView().source(html: "<h1>Offline</h1><p>Written in place.</p>")
```

The web content scrolls itself, so give it room of its own - a Grid row, or a
page without a scroller - rather than a place inside a ScrollView.

## Back, forward, again, and a script

What the view is told to do is an act called through its aim; whether there
is a page behind and ahead arrives in a binding:

```swift
import StateUIWebView

@Aim(WebView.self) var browser
@State var canGoBack = false
@State var title = ""

Grid {
    HStack {
        Button("Back")
            .isEnabled(canGoBack)
            .onClicked { try await browser.goBack() }
        Button("Reload")
            .onClicked { try await browser.reload() }
        Button("Title?")
            .onClicked { title = try await browser.evaluateJavaScript("document.title") }
    }
    WebView("https://example.com")
        .canGoBack($canGoBack)
        .aim(browser)
        .gridRow(1)
}
.rows(.auto, .fill)
```

A script answers what it evaluated to as text: words as they are, a number as
it is written, anything else as JSON, and nothing for no value.

## What the page does

A navigation is heard as it starts, with why - a new page, back, forward, the
page again - and as it ends, with how; the web process ending under the view
is heard too, and `reload()` brings the page back:

```swift
import StateUIWebView

@State var status = "nothing has loaded yet"

WebView("https://example.com")
    .onNavigating { navigation in status = "going to \(navigation.url)" }
    .onNavigated { navigated in status = "\(navigated.result): \(navigated.url)" }
    .onProcessTerminated { status = "the page's process ended" }
```

## On each platform

| Host | The web view |
| --- | --- |
| AppKit | none yet |
| UIKit | WebKit's `WKWebView` |
| Android Views | Android's `WebView` |
| WinUI 3 | WinUI's `WebView2`, over the system's WebView2 runtime |
| GTK 4 | WebKitGTK 6.0's `WebKitWebView` |
| Web | not yet |

What each host proves stands in the [platform contract's components
table](../../../docs/platform-contract.md#components), read from this
folder's `exports`.
