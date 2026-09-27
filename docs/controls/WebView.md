<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# WebView

A view showing web content - a page fetched by URL, or HTML written here.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven by every test of it that ran on that host · ☑️ proven, the host recording what is missing · – never on that host's family, which meets the contract there · ❌ a test of it failed · ◐ some of its tests proved it, another could not run or read · 🪞 proven only through the host's own entry or record, not the toolkit's · · the driver cannot yet do or read what its test needs · ⏸ its test waits on a member the host does not realize · ⌛ said by a run of other sources than these · empty: not realized, or no run - the note says which. See [the dictionary](README.md).

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `WKWebView` | not realized |
| UIKit | ⌛ |  | `WKWebView` | a run of other sources said: ✅ |
| Android Views | ⌛ |  | `WebView` | a run of other sources said: ✅ |
| WinUI 3 | ⌛ |  | `WebView2` | a run of other sources said: not realized |
| GTK 4 |  |  | WebKitGTK `WebKitWebView` | no run of it on these sources |
| Web |  |  | `<iframe>` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/WebViewContract.swift`.

## WebView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `canGoBackChanged` | event | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `canGoForwardChanged` | event | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `evaluateJavaScript` | act | `(String) -> String?` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ◐ cannot read userAgent of WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `goBack` | act | `() -> Void` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `goForward` | act | `() -> Void` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onNavigated` (`navigated`) | event | `(WebNavigationResult, WebNavigationEvent, String)` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: · cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `onNavigating` (`navigating`) | event | `(WebNavigationEvent, String)` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ◐ cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: a run of other sources said: ◐ cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `onProcessTerminated` (`processTerminated`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: endContent on WebView: the navigation delegate told, no web process ended; Android Views: a run of other sources said: · cannot endContent on WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `reload` | act | `() -> Void` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `source` | property | `WebViewSource` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: · cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: a run of other sources said: · cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |
| `userAgent` | property | `String` | adaptive |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot read userAgent of WebView - Android's driver has no path for it yet; WinUI 3: a run of other sources said: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: · cannot read a heading's level - UIKit marks a heading, not its level; Android Views: a run of other sources said: · cannot read a heading's level - Android marks a heading, not its level; WinUI 3: a run of other sources said: not realized |
| `accessibilityHint` | property | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `accessibilityLabel` | property | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `background` | property | `Background` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `focus` | act | `() -> Bool` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot focus WebView: it takes no keyboard focus here; WinUI 3: a run of other sources said: not realized |
| `frame` | property | `Rect` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `height` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `ignoresInput` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `isEnabled` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `isFocusedChanged` | event | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot focus WebView: it takes no keyboard focus here; WinUI 3: a run of other sources said: not realized |
| `isVisible` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `maximumHeight` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `maximumWidth` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `minimumHeight` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `minimumWidth` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `opacity` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `pivotX` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotX of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `pivotY` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read pivotY of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `rotation` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read rotation of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `rotationX` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationX of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `rotationY` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read rotationY of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `scale` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read scale of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `scaleX` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleX of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `scaleY` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read scaleY of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `style` | property | `Name` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `translationX` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read translationX of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `translationY` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: read translationY of WebView: the host's own transform, checked against the layer it composed itself; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `unfocus` | act | `() -> Void` |  |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: · cannot focus WebView: it takes no keyboard focus here; WinUI 3: a run of other sources said: not realized |
| `width` | property | `Double` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `zIndex` | property | `Int` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `area` | property | `Area` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `canDrag` | property | `Bool` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragStarting` | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `dragText` | property | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDrop` (`drop`) | event | `String` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: not realized; Android Views: a run of other sources said: not realized; WinUI 3: a run of other sources said: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `gridColumn` | property | `Int` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `gridColumnSpan` | property | `Int` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `gridRow` | property | `Int` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `gridRowSpan` | property | `Int` | stateUI |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `horizontalAlignment` | property | `Alignment` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `margin` | property | `Insets` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `panTouchCount` | property | `Int` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `panXChannel` | property | `Int` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `panYChannel` | property | `Int` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pinch on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `swipeThreshold` | property | `Double` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `tapCount` | property | `Int` | structure |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `onTapped` (`tapped`) | event |  | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: 🪞 only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
| `verticalAlignment` | property | `Alignment` | native |  | ⌛ | ⌛ | ⌛ |  |  | not realized; UIKit: a run of other sources said: ✅; Android Views: a run of other sources said: ✅; WinUI 3: a run of other sources said: not realized |
