<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# WebView

A view showing web content - a page fetched by URL, or HTML written here.

```swift
@Aim(WebView.self) var browser
@State var canGoBack = false

Grid {
    Button("Back")
        .isEnabled(canGoBack)
        .onClicked { try await browser.goBack() }
    WebView("https://example.com")
        .canGoBack($canGoBack)
        .aim(browser)
        .gridRow(1)
}
.rows(.auto, .fill)
```

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `WKWebView` | not realized |
| UIKit | ✅ | 39 ✅ · 26 ✓ | `WKWebView` |  |
| Android Views | ✅ | 59 ✅ · 1 ☑️ · 3 – | `WebView` |  |
| WinUI 3 | ✅ | 20 ✅ · 15 – | `WebView2`, a backend |  |
| GTK 4 | ✅ | 52 ✅ · 12 ✓ · 1 – | WebKitGTK `WebKitWebView`, a backend |  |
| Web |  |  | `<iframe>` (?) | no host yet |

Declared in `lib/StateUI/Core/Sources/Contracts/Elements/Controls/WebViewContract.swift`.

## WebView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `canGoBackChanged` | event | `Bool` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `canGoForwardChanged` | event | `Bool` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `evaluateJavaScript` | act | `(String) -> String?` |  |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `goBack` | act | `() -> Void` |  |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `goForward` | act | `() -> Void` |  |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `onNavigated` (`navigated`) | event | `(WebNavigationResult, WebNavigationEvent, String)` | native |  | ✅ | · | ✅ | ✅ |  | not realized; Android Views: cannot read a document written in place - Android's web view gives back no address for it |
| `onNavigating` (`navigating`) | event | `(WebNavigationEvent, String)` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `onProcessTerminated` (`processTerminated`) | event |  | native |  | ✓ | ✅ | ✅ | ✅ |  | not realized; UIKit: only through the host's own: endContent on WebView: the navigation delegate told, no web process ended |
| `reload` | act | `() -> Void` |  |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `source` | property | `WebViewSource` | native |  | ✅ | · | ✅ | ✓ |  | not realized; Android Views: cannot read a document written in place - Android's web view gives back no address for it; GTK 4: only through the host's own: read source of WebView: the page the backend last asked for: WebKit gives back an address, never the document written |
| `userAgent` | property | `String` | adaptive |  | ✅ | ✅ | ✅ | ✅ |  | not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  | ✅ | ✅ |  | – |  | not realized; GTK 4: GTK 4 gives an accessible the identifier a GtkBuilder file names alone: none is set on a widget made in code. |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  | · | · |  | ✅ |  | not realized; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level |
| `accessibilityHint` | property | `String` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `accessibilityLabel` | property | `String` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `automationExcludedWithChildren` | property | `Bool` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `background` | property | `Background` | native |  |  | ✅ |  |  |  | not realized; UIKit: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  | ✅ | – |  | ✅ |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard |
| `frame` | property | `Rect` | structure |  | ✅ | ✅ |  | ✅ |  | not realized |
| `height` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `ignoresInput` | property | `Bool` | native |  | ✅ |  |  |  |  | not realized; Android Views: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  | ✅ |  | not realized; UIKit: not realized; Android Views: not realized |
| `isFocusedChanged` | event | `Bool` | native |  | ✅ | – |  | ✅ |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard |
| `isVisible` | property | `Bool` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  | ✅ | ✅ |  |  |  | not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `maximumWidth` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `minimumHeight` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `minimumWidth` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `opacity` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `pivotX` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read pivotX of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotX of WebView: the host's own transform: GTK reads back no part of one |
| `pivotY` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read pivotY of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read pivotY of WebView: the host's own transform: GTK reads back no part of one |
| `rotation` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read rotation of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotation of WebView: the host's own transform: GTK reads back no part of one |
| `rotationX` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read rotationX of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotationX of WebView: the host's own transform: GTK reads back no part of one |
| `rotationY` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read rotationY of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read rotationY of WebView: the host's own transform: GTK reads back no part of one |
| `scale` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read scale of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scale of WebView: the host's own transform: GTK reads back no part of one |
| `scaleX` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read scaleX of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleX of WebView: the host's own transform: GTK reads back no part of one |
| `scaleY` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read scaleY of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read scaleY of WebView: the host's own transform: GTK reads back no part of one |
| `style` | property | `Name` | structure |  | ✅ | ✅ |  | ✅ |  | not realized |
| `translationX` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read translationX of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationX of WebView: the host's own transform: GTK reads back no part of one |
| `translationY` | property | `Double` | native |  | ✓ | ✅ |  | ✓ |  | not realized; UIKit: only through the host's own: read translationY of WebView: the host's own transform, checked against the layer it composed itself; GTK 4: only through the host's own: read translationY of WebView: the host's own transform: GTK reads back no part of one |
| `unfocus` | act | `() -> Void` |  |  | ✅ | – |  | ✅ |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard |
| `width` | property | `Double` | native |  | ✅ | ✅ |  | ✅ |  | not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `gridColumn` | property | `Int` | stateUI |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `gridColumnSpan` | property | `Int` | stateUI |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `gridRow` | property | `Int` | stateUI |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `gridRowSpan` | property | `Int` | stateUI |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `horizontalAlignment` | property | `Alignment` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `margin` | property | `Insets` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
| `panTouchCount` | property | `Int` | structure |  | ✓ | ☑️ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `panXChannel` | property | `Int` | structure |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `panYChannel` | property | `Int` | structure |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  | ✓ | ✅ | – | ✓ |  | not realized; UIKit: only through the host's own: pinch on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls).; GTK 4: only through the host's own: pinch on WebView: the fingers' place handed to the host's recognizer as GTK's zoom would: GTK takes no touch a driver puts down |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPointerExited` (`pointerExited`) | event |  | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `swipeDirection` | property | `SwipeDirection` | structure |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `swipeThreshold` | property | `Double` | structure |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `tapCount` | property | `Int` | structure |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `onTapped` (`tapped`) | event |  | native |  | ✓ | ✅ | – | ✅ |  | not realized; UIKit: only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: WebView2 gives the user's hand to its page: listened to by WinUI, it ends the process (fail-fast in Microsoft.UI.Xaml.Controls). |
| `verticalAlignment` | property | `Alignment` | native |  | ✅ | ✅ | ✅ | ✅ |  | not realized |
