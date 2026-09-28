<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# WebView

A view showing web content - a page fetched by URL, or HTML written here.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |

See [the dictionary](README.md) for how a mark is given.

| Host | Created | Members (77) | Realization | Notes |
| --- | :---: | --- | --- | --- |
| AppKit |  |  | `WKWebView` | not realized |
| UIKit | ✅ | 34 ✅ | `WKWebView` |  |
| Android Views | ✅ | 54 ✅ · 1 ☑️ · 3 – | `WebView` |  |
| WinUI 3 |  |  | `WebView2` | not realized |
| GTK 4 |  |  | WebKitGTK `WebKitWebView` | not realized |
| Web |  |  | `<iframe>` (?) | no host yet |

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/WebViewContract.swift`.

## WebView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `canGoBackChanged` | event | `Bool` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `canGoForwardChanged` | event | `Bool` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `evaluateJavaScript` | act | `(String) -> String?` |  |  | ✅ | ◐ |  |  |  | not realized; Android Views: cannot read userAgent of WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `goBack` | act | `() -> Void` |  |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `goForward` | act | `() -> Void` |  |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `onNavigated` (`navigated`) | event | `(WebNavigationResult, WebNavigationEvent, String)` | native |  | · | · |  |  |  | not realized; UIKit: cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `onNavigating` (`navigating`) | event | `(WebNavigationEvent, String)` | native |  | ◐ | ◐ |  |  |  | not realized; UIKit: cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `onProcessTerminated` (`processTerminated`) | event |  | native |  | 🔌 | · |  |  |  | not realized; UIKit: only through the host's own: endContent on WebView: the navigation delegate told, no web process ended; Android Views: cannot endContent on WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `reload` | act | `() -> Void` |  |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `source` | property | `WebViewSource` | native |  | · | · |  |  |  | not realized; UIKit: cannot read source of WebView - UIKit's driver has no path for it yet; Android Views: cannot read source of WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |
| `userAgent` | property | `String` | adaptive |  | ✅ | · |  |  |  | not realized; Android Views: cannot read userAgent of WebView - Android's driver has no path for it yet; WinUI 3: not realized; GTK 4: not realized |

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  | · | · |  |  |  | not realized; UIKit: cannot read a heading's level - UIKit marks a heading, not its level; Android Views: cannot read a heading's level - Android marks a heading, not its level; WinUI 3: not realized; GTK 4: not realized |
| `accessibilityHint` | property | `String` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `accessibilityLabel` | property | `String` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `automationExcludedWithChildren` | property | `Bool` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `background` | property | `Background` | native |  |  | ✅ |  |  |  | not realized; UIKit: not realized; WinUI 3: not realized; GTK 4: not realized |
| `focus` | act | `() -> Bool` |  |  | ✅ | – |  |  |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: not realized; GTK 4: not realized |
| `frame` | property | `Rect` | structure |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `height` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isAccessibilityHidden` | property | `Bool` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `isFocusedChanged` | event | `Bool` | native |  | ✅ | – |  |  |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: not realized; GTK 4: not realized |
| `isVisible` | property | `Bool` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumHeight` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `maximumWidth` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `minimumHeight` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `minimumWidth` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `opacity` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `pivotX` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read pivotX of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `pivotY` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read pivotY of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `rotation` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read rotation of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `rotationX` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read rotationX of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `rotationY` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read rotationY of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `scale` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read scale of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `scaleX` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read scaleX of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `scaleY` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read scaleY of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `style` | property | `Name` | structure |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `translationX` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read translationX of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `translationY` | property | `Double` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: read translationY of WebView: the host's own transform, checked against the layer it composed itself; WinUI 3: not realized; GTK 4: not realized |
| `unfocus` | act | `() -> Void` |  |  | ✅ | – |  |  |  | not realized; Android Views: WebView takes no keyboard focus here: it refuses it, and nothing is heard; WinUI 3: not realized; GTK 4: not realized |
| `width` | property | `Double` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `area` | property | `Area` | structure |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragStarting` | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `dragText` | property | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  | not realized; UIKit: not realized; Android Views: not realized; WinUI 3: not realized; GTK 4: not realized |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `gridColumn` | property | `Int` | stateUI |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `gridColumnSpan` | property | `Int` | stateUI |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `gridRow` | property | `Int` | stateUI |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `gridRowSpan` | property | `Int` | stateUI |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `horizontalAlignment` | property | `Alignment` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `margin` | property | `Insets` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
| `panTouchCount` | property | `Int` | structure |  | 🔌 | ☑️ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; Android Views: The host layer hears a one-finger pan only; any other `panTouchCount` turns the pan off.; WinUI 3: not realized; GTK 4: not realized |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `panXChannel` | property | `Int` | structure |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `panYChannel` | property | `Int` | structure |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pinch on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPointerExited` (`pointerExited`) | event |  | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: hover on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `swipeDirection` | property | `SwipeDirection` | structure |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `swipeThreshold` | property | `Double` | structure |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: pan on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `tapCount` | property | `Int` | structure |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `onTapped` (`tapped`) | event |  | native |  | 🔌 | ✅ |  |  |  | not realized; UIKit: only through the host's own: tap on WebView: the view's listening handed the recognizer's states, no touch sent; WinUI 3: not realized; GTK 4: not realized |
| `verticalAlignment` | property | `Alignment` | native |  | ✅ | ✅ |  |  |  | not realized; WinUI 3: not realized; GTK 4: not realized |
