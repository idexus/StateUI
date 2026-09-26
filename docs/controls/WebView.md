<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# WebView

A view showing web content - a page fetched by URL, or HTML written here.

Layer: `native`. Every base host presents it with its native toolkit.

Inherits: [PropertyContainer](tiers/PropertyContainer.md) · [VisualElement](tiers/VisualElement.md) · [View](tiers/View.md)

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet. See [the dictionary](README.md).

Declared in `lib/StateUI/Sources/Contracts/Elements/Controls/WebViewContract.swift`.

## WebView's own members

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `canGoBackChanged` | event | `Bool` | native |  |  |  | ✅ |  |  |  |
| `canGoForwardChanged` | event | `Bool` | native |  |  |  | ✅ |  |  |  |
| `evaluateJavaScript` | act | `(String) -> String?` |  |  |  |  | ✅ |  |  |  |
| `goBack` | act | `() -> Void` |  |  |  |  | ✅ |  |  |  |
| `goForward` | act | `() -> Void` |  |  |  |  | ✅ |  |  |  |
| `onNavigated` (`navigated`) | event | `(WebNavigationResult, WebNavigationEvent, String)` | native |  |  |  | ✅ |  |  |  |
| `onNavigating` (`navigating`) | event | `(WebNavigationEvent, String)` | native |  |  |  | ✅ |  |  |  |
| `onProcessTerminated` (`processTerminated`) | event |  | native |  |  |  |  |  |  | Android Views: cannot endContent on WebView - Android's driver has no path for it yet |
| `reload` | act | `() -> Void` |  |  |  |  | ✅ |  |  |  |
| `source` | property | `WebViewSource` | native |  |  |  |  |  |  | Android Views: cannot read source of WebView - Android's driver has no path for it yet |
| `userAgent` | property | `String` | adaptive |  |  |  |  |  |  | Android Views: cannot read userAgent of WebView - Android's driver has no path for it yet |

Realization:

- **AppKit**: `WKWebView`
- **UIKit**: `WKWebView`
- **GTK 4**: WebKitGTK `WebKitWebView`
- **Android Views**: `WebView`
- **WinUI 3**: `WebView2`
- **Web**: `<iframe>` (?)

## From [PropertyContainer](tiers/PropertyContainer.md)

What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityIdentifier` | property | `String` | native |  |  |  |  |  |  | Android Views: cannot read accessibilityIdentifier of WebView - Android's driver has no path for it yet |

## From [VisualElement](tiers/VisualElement.md)

What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `accessibilityHeadingLevel` | property | `HeadingLevel` | native |  |  |  |  |  |  | Android Views: cannot read accessibilityHeadingLevel of WebView - Android's driver has no path for it yet |
| `accessibilityHint` | property | `String` | native |  |  |  |  |  |  | Android Views: cannot read accessibilityHint of WebView - Android's driver has no path for it yet |
| `accessibilityLabel` | property | `String` | native |  |  |  |  |  |  | Android Views: cannot read accessibilityLabel of WebView - Android's driver has no path for it yet |
| `automationExcludedWithChildren` | property | `Bool` | native |  |  |  |  |  |  | Android Views: cannot read automationExcludedWithChildren of WebView - Android's driver has no path for it yet |
| `background` | property | `Background` | native |  |  |  |  |  |  | Android Views: cannot read background of WebView - Android's driver has no path for it yet |
| `focus` | act | `() -> Bool` |  |  |  |  | ✅ |  |  |  |
| `frame` | property | `Rect` | structure |  |  |  | ✅ |  |  |  |
| `height` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `ignoresInput` | property | `Bool` | native |  |  |  |  |  |  |  |
| `isAccessibilityHidden` | property | `Bool` | native |  |  |  |  |  |  | Android Views: cannot read isAccessibilityHidden of WebView - Android's driver has no path for it yet |
| `isEnabled` | property | `Bool` | native |  |  |  |  |  |  |  |
| `isFocusedChanged` | event | `Bool` | native |  |  |  | ✅ |  |  |  |
| `isVisible` | property | `Bool` | native |  |  |  | ✅ |  |  |  |
| `layoutDirection` | property | `LayoutDirection` | native |  |  |  |  |  |  |  |
| `maximumHeight` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `maximumWidth` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `minimumHeight` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `minimumWidth` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `opacity` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `pivotX` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read pivotX of WebView - Android's driver has no path for it yet |
| `pivotY` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read pivotY of WebView - Android's driver has no path for it yet |
| `rotation` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read rotation of WebView - Android's driver has no path for it yet |
| `rotationX` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read rotationX of WebView - Android's driver has no path for it yet |
| `rotationY` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read rotationY of WebView - Android's driver has no path for it yet |
| `scale` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read scale of WebView - Android's driver has no path for it yet |
| `scaleX` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read scaleX of WebView - Android's driver has no path for it yet |
| `scaleY` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read scaleY of WebView - Android's driver has no path for it yet |
| `style` | property | `Name` | structure |  |  |  |  |  |  |  |
| `translationX` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read translationX of WebView - Android's driver has no path for it yet |
| `translationY` | property | `Double` | native |  |  |  |  |  |  | Android Views: cannot read translationY of WebView - Android's driver has no path for it yet |
| `unfocus` | act | `() -> Void` |  |  |  |  | ✅ |  |  |  |
| `width` | property | `Double` | native |  |  |  | ✅ |  |  |  |
| `zIndex` | property | `Int` | native |  |  |  |  |  |  |  |

## From [View](tiers/View.md)

What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.

| Member | Kind | Value | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| `allowDrop` | property | `Bool` | native |  |  |  |  |  |  |  |
| `area` | property | `Area` | structure |  |  |  | ✅ |  |  |  |
| `canDrag` | property | `Bool` | native |  |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | event |  | native |  |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | event |  | native |  |  |  |  |  |  |  |
| `dragStarting` | event |  | native |  |  |  |  |  |  |  |
| `dragText` | property | `String` | native |  |  |  |  |  |  |  |
| `onDrop` (`drop`) | event | `String` | native |  |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | event |  | native |  |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | event | `[Double]` | native |  |  |  | ✅ |  |  |  |
| `gridColumn` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridColumnSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridRow` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `gridRowSpan` | property | `Int` | stateUI |  |  |  | ✅ |  |  |  |
| `horizontalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  |  |
| `margin` | property | `Insets` | native |  |  |  | ✅ |  |  |  |
| `panTouchCount` | property | `Int` | structure |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `onPanUpdated` (`panUpdated`) | event | `(GesturePhase, Double, Double)` | native |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `panXChannel` | property | `Int` | structure |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `panYChannel` | property | `Int` | structure |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `onPinchUpdated` (`pinchUpdated`) | event | `(GesturePhase, Double, Point)` | native |  |  |  |  |  |  | Android Views: cannot pinch on WebView - Android's driver has no path for it yet |
| `onPointerEntered` (`pointerEntered`) | event |  | native |  |  |  |  |  |  | Android Views: cannot hover on WebView - Android's driver has no path for it yet |
| `onPointerExited` (`pointerExited`) | event |  | native |  |  |  |  |  |  | Android Views: cannot hover on WebView - Android's driver has no path for it yet |
| `onPointerMoved` (`pointerMoved`) | event | `Point?` | native |  |  |  |  |  |  | Android Views: cannot hover on WebView - Android's driver has no path for it yet |
| `onPointerPressed` (`pointerPressed`) | event | `Point?` | native |  |  |  |  |  |  | Android Views: cannot hover on WebView - Android's driver has no path for it yet |
| `onPointerReleased` (`pointerReleased`) | event | `Point?` | native |  |  |  |  |  |  | Android Views: cannot hover on WebView - Android's driver has no path for it yet |
| `swipeDirection` | property | `SwipeDirection` | structure |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `swipeThreshold` | property | `Double` | structure |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `onSwiped` (`swiped`) | event | `SwipeDirection` | native |  |  |  |  |  |  | Android Views: cannot pan on WebView - Android's driver has no path for it yet |
| `tapCount` | property | `Int` | structure |  |  |  |  |  |  | Android Views: cannot tap on WebView - Android's driver has no path for it yet |
| `onTapped` (`tapped`) | event |  | native |  |  |  |  |  |  | Android Views: cannot tap on WebView - Android's driver has no path for it yet |
| `verticalAlignment` | property | `Alignment` | native |  |  |  | ✅ |  |  |  |
