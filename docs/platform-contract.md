# Platform contract

This document is the shared delivery contract for AppKit, UIKit, GTK 4,
Android Views, WinUI 3, and Web DOM/CSS. It records the StateUI surface and the
implementation evidence for each host.

## Reading the matrix

- ✅ means the member is implemented by that host and exercised by its host
  test suite.
- — means the implementation is absent, incomplete, or not yet verified. It
  is deliberately not an estimate of how difficult the work will be.
- A control-level ✅ means the host recognizes and tests the node. Native and
  adaptive nodes create and retain their platform surface; structural nodes
  are interpreted without inventing a platform control. It does not imply that
  every property has been completed; member rows state that separately.
- A grouped member row receives ✅ only when every member named in that row is
  implemented. Inseparable overloads may share one row.

The matrix describes observable StateUI semantics. Platform classes are
implementation details. A host may choose another native class when it
preserves the same state, event, accessibility, lifetime, and motion contract.

## Target hosts

| Platform | Runtime | Boundary | Native toolkit |
| --- | --- | --- | --- |
| macOS | Swift | typed `HostPatch` | AppKit |
| iOS and iPadOS | Swift | typed `HostPatch` | UIKit |
| Linux desktop | Swift with the C API | typed `HostPatch` | GTK 4 |
| Android | Kotlin with thin JNI | Wire encoding of `HostPatch` | Android Views |
| Windows | C++/WinRT | Wire encoding of `HostPatch` | WinUI 3 |
| Browser | JavaScript or TypeScript | Wire encoding of `HostPatch` | DOM and CSS |

Web is last in the implementation order. The native desktop and mobile hosts
settle the common semantics before they are mapped to the browser.

## Admission rule

A base control remains in StateUI only when it has one honest semantic contract
across the target toolkits or is derived once in StateUI from smaller accepted
primitives. An optional capability belongs to a provider package. A control,
property, or event that meets neither rule does not remain as an inert API.

A contract change is vertical. Public Swift API, host vocabulary, every
applicable host, tests, Gallery example, and documentation change together.
The core owns identity, state, diffing, and composition; the host is kept thin.

## Control creation

| StateUI surface | Owner | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `Application` / `Scene` | structure | ✅ | — | — | — | — | — |
| `Window` | structure | ✅ | — | — | — | — | — |
| `ContentPage` | adaptive shell | ✅ | — | — | — | — | — |
| `NavigationPage` | adaptive shell | ✅ | — | — | — | — | — |
| `TabbedPage` | adaptive shell | ✅ | — | — | — | — | — |
| `FlyoutPage` | adaptive shell | ✅ | — | — | — | — | — |
| `ModalStack` | structure | ✅ | — | — | — | — | — |
| `Overlay` | structure | ✅ | — | — | — | — | — |
| `TitleBar` | adaptive shell | ✅ | — | — | — | — | — |
| `ContextFlyout`, `MenuBarItems`, `MenuBarItem`, `MenuFlyoutItem`, `MenuFlyoutSeparator`, `MenuFlyoutSubItem` | structure | ✅ | — | — | — | — | — |
| `ToolbarItems` / `ToolbarItem` | structure | ✅ | — | — | — | — | — |
| `AbsoluteLayout` | native primitive | ✅ | — | — | — | — | — |
| `VerticalStackLayout` / `HorizontalStackLayout` | native primitive | ✅ | — | — | — | — | — |
| `Grid` | StateUI-owned layout contract | ✅ | — | — | — | — | — |
| `ScrollView` | native primitive | ✅ | — | — | — | — | — |
| `Border` | native primitive | — | — | — | — | — | — |
| `Label` / `FormattedString` / `Span` | native primitive / structure | ✅ | — | — | — | — | — |
| `Button` | native primitive | ✅ | — | — | — | — | — |
| `ImageButton` | StateUI-owned composition contract | ✅ | — | — | — | — | — |
| `Image` | native primitive | ✅ | — | — | — | — | — |
| `BoxView` | native primitive | ✅ | — | — | — | — | — |
| `Entry` | native primitive | ✅ | — | — | — | — | — |
| `Editor` | native primitive | ✅ | — | — | — | — | — |
| `SearchBar` | native primitive | ✅ | — | — | — | — | — |
| `Picker` | native primitive | ✅ | — | — | — | — | — |
| `DatePicker` | native primitive | ✅ | — | — | — | — | — |
| `TimePicker` | native primitive | ✅ | — | — | — | — | — |
| `Switch` | native primitive | ✅ | — | — | — | — | — |
| `CheckBox` | StateUI-owned choice contract | ✅ | — | — | — | — | — |
| `RadioButton` | StateUI-owned choice contract | ✅ | — | — | — | — | — |
| `Slider` | native primitive | ✅ | — | — | — | — | — |
| `Stepper` | native primitive | ✅ | — | — | — | — | — |
| `ProgressBar` | native primitive | ✅ | — | — | — | — | — |
| `ActivityIndicator` | native primitive | ✅ | — | — | — | — | — |
| `GraphicsView` | native drawing primitive | ✅ | — | — | — | — | — |
| `Rectangle` / `RoundRectangle` / `Ellipse` | StateUI-owned drawing contract | ✅ | — | — | — | — | — |
| `Line` / `Path` / `Polygon` / `Polyline` | StateUI-owned drawing contract | ✅ | — | — | — | — | — |
| `IndicatorView` | StateUI-owned composition | — | — | — | — | — | — |
| `RefreshView` | StateUI-owned interaction | — | — | — | — | — | — |
| `SwipeView` | StateUI-owned interaction | — | — | — | — | — | — |
| `SwipeItems` / `SwipeItem` | structure | — | — | — | — | — | — |
| `WebView` | native primitive | — | — | — | — | — | — |
| `Map` / `Pin` | optional provider | — | — | — | — | — | — |
| native virtualized collection | native primitive | — | — | — | — | — | — |
| `Content`, `LeadingContent`, `TrailingContent`, `NavigationPageTitleView` | structure | — | — | — | — | — | — |
| `Setters`, `VisualState`, `Composed` | structure resolved by StateUI | — | — | — | — | — | — |

The AppKit flyout uses `NSSplitViewController`. A future native collection maps
to `NSCollectionView` or `NSTableView`, `UICollectionView`, `GtkListView` or
`GtkGridView`, `RecyclerView`, `ItemsView`, and a semantic DOM list/grid. The
collection API is not admitted until item identity, reuse, selection,
activation, accessibility, and programmatic scrolling form one complete
contract.

`ForEach`, `FrameReader`, `ScrollReader`, `PlacedLayout`, and `GalleryView` are
StateUI compositions or readers rather than additional platform controls. The
core implements them once; their platform behavior depends only on the
primitive rows they use.

## Shared state, patch, and motion capabilities

| Capability | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| sparse `HostRender` / `HostPatch` application | ✅ | — | — | — | — | — |
| stable element identity and arranged children | ✅ | — | — | — | — | — |
| driven state modes and typed channel kinds | ✅ | — | — | — | — | — |
| native input committed before handler dispatch | ✅ | — | — | — | — | — |
| silent application writes | ✅ | — | — | — | — | — |
| host-driven Journey interpolation with eased and spring motion | ✅ | — | — | — | — | — |
| host-driven Journey retargeting with standing velocity | ✅ | — | — | — | — | — |
| sparse property transitions through `HostPatch.transitions` | — | — | — | — | — | — |
| layout motion through `HostPatch.motion` and `MotionLanes` | — | — | — | — | — | — |
| Journey completion and interruption | ✅ | — | — | — | — | — |
| Journey stop and snap | — | — | — | — | — | — |
| StateUI display-cycle engines | — | — | — | — | — | — |
| element teardown releases external native attachments | ✅ | — | — | — | — | — |

## Standard environment

These rows record complete, live host mappings for StateUI's seven standard
environment domains. A host that only seeds some fields, does not keep changing
facts current, or lacks direct tests remains unmarked for that domain.

| Surface | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `Battery` | `chargeLevel`, `state`, `powerSource`, `energySaverStatus` | — | — | — | — | — | — |
| `Connectivity` | `networkAccess`, `connectionProfiles` | — | — | — | — | — | — |
| `DeviceDisplay` | `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate` | — | — | — | — | — | — |
| `LocaleInfo` | `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric` | — | — | — | — | — | — |
| `DeviceInfo` | `idiom`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `deviceType` | — | — | — | — | — | — |
| `AppInfo` | `name`, `packageName`, `versionString`, `buildString`, `requestedTheme` | — | — | — | — | — | — |
| `ApplicationSession` | `phase` | ✅ | — | — | — | — | — |

The public provider and its fallback values exist independently of a check
mark. [Environment](environment.md) defines that schema; this table says which
host supplies and maintains it completely.

## Host time services

Calendar values are portable StateUI values. Reading the current clock or time
zone is a host action because the host owns the active locale and zone database.

| Surface | Host act | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `ClockTime.now()` | `dateTimeNow` | — | — | — | — | — | — |
| `TimeZoneInfo.local()` | `localTimeZone` | — | — | — | — | — | — |
| `TimeZoneInfo.getUtcOffset(of:on:)` | `getUtcOffset` | — | — | — | — | — | — |

## Shared view members

These rows apply to every eligible control. A missing check means the shared
guarantee is not yet complete across all such AppKit controls even when an
individual control already uses that member.

| Member kind | StateUI members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| identity | `id` | ✅ | — | — | — | — | — |
| aimed control methods | `aim` | — | — | — | — | — | — |
| core reactions | `onCreated`, `onDestroying`, `onChanged`, `samples`, `engine` | — | — | — | — | — | — |
| motion selection | `motion`, `MotionValues`, `MotionLanes` | — | — | — | — | — | — |
| visibility and opacity | `isVisible`, `opacity` | — | — | — | — | — | — |
| flat background | `backgroundColor` | — | — | — | — | — | — |
| brush background on every view | `background` | — | — | — | — | — | — |
| enabled state on every eligible view | `isEnabled` | — | — | — | — | — | — |
| hit testing on every eligible view | `inputTransparent`, `cascadeInputTransparent` | — | — | — | — | — | — |
| layout direction | `flowDirection` | — | — | — | — | — | — |
| requested size | `widthRequest`, `heightRequest`, `minimumWidthRequest`, `minimumHeightRequest`, `maximumWidthRequest`, `maximumHeightRequest` | — | — | — | — | — | — |
| parent placement | `margin`, `horizontalOptions`, `verticalOptions` | — | — | — | — | — | — |
| drawing order | `zIndex` | — | — | — | — | — | — |
| planar transform | `rotation`, `scale`, `scaleX`, `scaleY`, `translationX`, `translationY` | — | — | — | — | — | — |
| spatial transform and pivot | `rotationX`, `rotationY`, `anchorX`, `anchorY` | — | — | — | — | — | — |
| accessibility | `automationId`, `automationIsInAccessibleTree`, `automationExcludedWithChildren`, `semanticDescription`, `semanticHint`, `semanticHeadingLevel` | ✅ | — | — | — | — | — |
| frame feed/event | `frame`, `frameChanged` | ✅ | — | — | — | — | — |
| focus and size feeds/events | `isFocused`, `width`, `height`, `isFocusedChanged`, `widthChanged`, `heightChanged` | — | — | — | — | — | — |
| tap | `numberOfTapsRequired`, `onTapped` (`tapped`) | ✅ | — | — | — | — | — |
| swipe gesture | `swipeDirection`, `swipeThreshold`, `onSwiped` (`swiped`) | ✅ | — | — | — | — | — |
| pan and pinch | `panXChannel`, `panYChannel`, `panTouchCount`, `onPanUpdated` (`panUpdated`), `onPinchUpdated` (`pinchUpdated`) | ✅ | — | — | — | — | — |
| pointer | `onPointerEntered` (`pointerEntered`), `onPointerExited` (`pointerExited`), `onPointerMoved` (`pointerMoved`), `onPointerPressed` (`pointerPressed`), `onPointerReleased` (`pointerReleased`) | ✅ | — | — | — | — | — |
| drag and drop | `canDrag`, `allowDrop`, `dragText`, `dragStarting`, `onDropCompleted` (`dropCompleted`), `onDrop` (`drop`), `onDragOver` (`dragOver`), `onDragLeave` (`dragLeave`) | — | — | — | — | — | — |

## Control properties and handlers

Each row is part of the common StateUI contract. Property names are modifier
names; a handler shows its public `on…` spelling followed by the host event
token in parentheses.

| Surface | Kind | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `Application` / `Scene` / `Window` | sessions | multiple scenes, owned windows, restoration, focus, close | ✅ | — | — | — | — | — |
| `Window` | properties | `title`, `x`, `y`, `width`, `height`, `minimumWidth`, `minimumHeight`, `maximumWidth`, `maximumHeight`, `isMaximizable`, `isMinimizable` | — | — | — | — | — | — |
| `WindowGroup` / `Window` | session metadata | `windowType`, `windowValue`, `autoHide`, `floatsOnTop` | — | — | — | — | — | — |
| `Window` | handlers | `created`, `activated`, `deactivated`, `stopped`, `resumed`, `destroying` | ✅ | — | — | — | — | — |
| `Scene` | handlers | `activated`, `deactivated`, `stopped`, `destroying`, `windowClosed`, `windowRestored` | — | — | — | — | — | — |
| `ContentPage` | properties | `title`, `iconImageSource`, `padding`, `backgroundColor`, `navigationPageBackButtonTitle`, `navigationPageHasBackButton`, `navigationPageHasNavigationBar`, toolbar and menu slots | ✅ | — | — | — | — | — |
| `ContentPage` | properties | `backgroundImageSource`, `hideSoftInputOnTapped`, `useSafeArea`, `modalPresentationStyle`, `navigationPageIconColor`, `navigationPageTitleIconImageSource` | — | — | — | — | — | — |
| `ContentPage` | handlers | `appearing`, `disappearing`, `navigatingFrom`, `navigatedFrom`, `navigatedTo` | ✅ | — | — | — | — | — |
| `NavigationPage` | state | bound path and committed native back (`popped`) | ✅ | — | — | — | — | — |
| `NavigationPage` | properties | `barBackgroundColor` | ✅ | — | — | — | — | — |
| `NavigationPage` | properties | `barTextColor` | — | — | — | — | — | — |
| `NavigationPage` | properties | `barBackground` | — | — | — | — | — | — |
| `TabbedPage` | state/events | bound `currentPage` (`currentPageChanged`) | ✅ | — | — | — | — | — |
| `TabbedPage` | properties | `barBackgroundColor`, `selectedTabColor`, `unselectedTabColor` | — | — | — | — | — | — |
| `TabbedPage` | properties | `barBackground`, `barTextColor` | — | — | — | — | — | — |
| `FlyoutPage` | state/events | bound `isPresented` (`isPresentedChanged`) | ✅ | — | — | — | — | — |
| `FlyoutPage` | properties | `flyoutLayoutBehavior`, `isGestureEnabled` | — | — | — | — | — | — |
| `ModalStack` | state/events | bound modal stack (`modalPopped`) | ✅ | — | — | — | — | — |
| menus / toolbar | properties | `text`, `iconImageSource`, `isDestructive`, `isEnabled`, `order`, `priority` | — | — | — | — | — | — |
| menus / toolbar | handlers | `onClicked` (`clicked`) | ✅ | — | — | — | — | — |
| `TitleBar` | properties/slots | `title`, `subtitle`, `icon`, `foregroundColor`, `backgroundColor`, leading/content/trailing slots | ✅ | — | — | — | — | — |
| stack layouts | properties | `padding`, `spacing` | ✅ | — | — | — | — | — |
| `Grid` | properties | `rowDefinitions`, `columnDefinitions`, `rowSpacing`, `columnSpacing`, child `gridRow`, `gridColumn`, `gridRowSpan`, `gridColumnSpan` | — | — | — | — | — | — |
| `AbsoluteLayout` | properties | child `absoluteLayoutBounds`, `absoluteLayoutFlags` | — | — | — | — | — | — |
| layouts | properties | `isClippedToBounds`, `safeAreaEdges` | — | — | — | — | — | — |
| `ScrollView` | properties | `orientation`, `verticalScrollBarVisibility`, `horizontalScrollBarVisibility`, `scroll`, `snapInterval`, `snapFrom`, `snapsAtMost`, `scrollMomentum` | ✅ | — | — | — | — | — |
| `ScrollView` | events | `scrollXChanged`, `scrollYChanged`, `snapItemChanged`, `onScrollStopped` (`scrollStopped`) | ✅ | — | — | — | — | — |
| `Border` | properties | `stroke`, `strokeThickness`, `strokeShape`, `background`, `backgroundColor` | — | — | — | — | — | — |
| `Border` | properties | `strokeDashArray`, `strokeDashOffset`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit` | — | — | — | — | — | — |
| `Label` / `TextSpan` | properties | `text`, `textColor`, `characterSpacing`, `textTransform`, `fontSize`, `fontFamily`, `fontAttributes`, `lineBreakMode`, `lineHeight`, `maxLines`, `textDecorations`, formatted text | ✅ | — | — | — | — | — |
| `Label` | properties | `horizontalTextAlignment`, `verticalTextAlignment`, `padding` | ✅ | — | — | — | — | — |
| `Button` | properties | `text`, `imageSource`, `contentLayout`, `lineBreakMode`, `padding`, `borderColor`, `borderWidth`, `cornerRadius` | ✅ | — | — | — | — | — |
| `Button` | handlers | `onClicked` (`clicked`), `onPressed` (`pressed`), `onReleased` (`released`) | ✅ | — | — | — | — | — |
| `ImageButton` | properties | `source`, `aspect`, `padding`, `borderColor`, `borderWidth`, `cornerRadius` | ✅ | — | — | — | — | — |
| `ImageButton` | handlers | `onClicked` (`clicked`), `onPressed` (`pressed`), `onReleased` (`released`) | ✅ | — | — | — | — | — |
| `Image` | properties | `source`, `aspect`, `isAnimationPlaying` | ✅ | — | — | — | — | — |
| `BoxView` | properties | `color`, `cornerRadius` | ✅ | — | — | — | — | — |
| text inputs | properties | two-way `text`, `placeholder`, `placeholderColor`, `textColor`, `fontSize`, `fontFamily`, `fontAttributes`, `horizontalTextAlignment`, `isReadOnly`, `maxLength`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `cursorPosition`, `selectionLength` | ✅ | — | — | — | — | — |
| text inputs | properties | `keyboard`, `verticalTextAlignment`, `characterSpacing`, `textTransform`, `fontAutoScalingEnabled` | — | — | — | — | — | — |
| text inputs | handlers | `onTextChanged` (`textChanged`) | ✅ | — | — | — | — | — |
| `Entry` | properties | `isPassword` | ✅ | — | — | — | — | — |
| `Entry` | properties | `returnType`, `clearButtonVisibility` | — | — | — | — | — | — |
| `Entry` | handlers | `onCompleted` (`completed`) | ✅ | — | — | — | — | — |
| `Editor` | properties/handlers | `autoSize`, `onCompleted` (`completed`) | ✅ | — | — | — | — | — |
| `SearchBar` | properties | `returnType`, `cancelButtonColor`, `searchIconColor` | — | — | — | — | — | — |
| `SearchBar` | handlers | `onSearchButtonPressed` (`searchButtonPressed`) | ✅ | — | — | — | — | — |
| `Picker` | properties | `itemsSource`, `selectedIndex`, `title`, `titleColor`, `isOpen` | ✅ | — | — | — | — | — |
| `Picker` | handlers | `onSelectedIndexChanged` (`selectedIndexChanged`), `onOpened` (`opened`), `onClosed` (`closed`) | ✅ | — | — | — | — | — |
| `DatePicker` | properties | `date`, `minimumDate`, `maximumDate` | ✅ | — | — | — | — | — |
| `DatePicker` | properties | `format`, `isOpen` | — | — | — | — | — | — |
| `DatePicker` | handlers | `onDateSelected` (`dateSelected`) | ✅ | — | — | — | — | — |
| `DatePicker` | handlers | `onOpened` (`opened`), `onClosed` (`closed`) | — | — | — | — | — | — |
| `TimePicker` | properties | `time` | ✅ | — | — | — | — | — |
| `TimePicker` | properties | `format`, `isOpen` | — | — | — | — | — | — |
| `TimePicker` | handlers | `onTimeSelected` (`timeSelected`) | ✅ | — | — | — | — | — |
| `TimePicker` | handlers | `onOpened` (`opened`), `onClosed` (`closed`) | — | — | — | — | — | — |
| `Switch` | properties/events | two-way `isToggled`, `onToggled` (`toggled`) | ✅ | — | — | — | — | — |
| `Switch` | properties | `onColor`, `offColor`, `thumbColor` | — | — | — | — | — | — |
| `CheckBox` | properties/events | two-way `isChecked`, `color`, `onCheckedChanged` (`checkedChanged`) | ✅ | — | — | — | — | — |
| `RadioButton` | properties/events | `text`, two-way `isChecked`, `groupName`, `onCheckedChanged` (`checkedChanged`) | ✅ | — | — | — | — | — |
| `Slider` | properties | two-way `value`, `minimum`, `maximum`, `minimumTrackColor` | ✅ | — | — | — | — | — |
| `Slider` | properties | `maximumTrackColor`, `thumbColor`, `thumbImageSource` | — | — | — | — | — | — |
| `Slider` | handlers | `onValueChanged` (`valueChanged`), `onDragStarted` (`dragStarted`), `onDragCompleted` (`dragCompleted`) | ✅ | — | — | — | — | — |
| `Stepper` | properties/events | two-way `value`, `minimum`, `maximum`, `increment`, `onValueChanged` (`valueChanged`) | ✅ | — | — | — | — | — |
| `ProgressBar` | properties | `progress` | ✅ | — | — | — | — | — |
| `ProgressBar` | properties | `progressColor` | — | — | — | — | — | — |
| `ActivityIndicator` | properties | `isRunning` | ✅ | — | — | — | — | — |
| `ActivityIndicator` | properties | `color` | — | — | — | — | — | — |
| `GraphicsView` | properties/events | `drawable`, `onStartInteraction` (`startInteraction`), `onDragInteraction` (`dragInteraction`), `onEndInteraction` (`endInteraction`) | ✅ | — | — | — | — | — |
| shapes | properties | `fill`, `stroke`, `strokeThickness`, `strokeDashArray`, `strokeDashOffset`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit`, `aspect`, `renderTransform` | — | — | — | — | — | — |
| `Rectangle` | properties | `radiusX`, `radiusY` | — | — | — | — | — | — |
| `RoundRectangle` | properties | `cornerRadius` | — | — | — | — | — | — |
| `Line` | properties | `x1`, `y1`, `x2`, `y2` | ✅ | — | — | — | — | — |
| `Path` | properties | `data` | ✅ | — | — | — | — | — |
| `Polygon` / `Polyline` | properties | `points`, `fillRule` | ✅ | — | — | — | — | — |
| `IndicatorView` | properties | `count`, `position`, `indicatorColor`, `selectedIndicatorColor`, `indicatorSize`, `maximumVisible`, `indicatorsShape`, `hideSingle` | — | — | — | — | — | — |
| `RefreshView` | properties/events | two-way `isRefreshing`, `isRefreshEnabled`, `refreshColor`, `onRefreshing` (`refreshing`) | — | — | — | — | — | — |
| `SwipeView` | properties/events | `threshold`, item `side`, `swipeBehaviorOnInvoked`, `onSwipeStarted` (`swipeStarted`), `onSwipeChanging` (`swipeChanging`), `onSwipeEnded` (`swipeEnded`) | — | — | — | — | — | — |
| `SwipeItem` | properties/events | `text`, `iconImageSource`, `backgroundColor`, `isDestructive`, `isEnabled`, `isVisible`, `onInvoked` (`invoked`) | — | — | — | — | — | — |
| `RefreshView` | state event | `isRefreshingChanged` | — | — | — | — | — | — |
| `WebView` | properties/events | `source`, `userAgent`, `canGoBackChanged`, `canGoForwardChanged` | — | — | — | — | — | — |
| `WebView` | handlers | `onNavigating` (`navigating`), `onNavigated` (`navigated`), `onProcessTerminated` (`processTerminated`) | — | — | — | — | — | — |
| `Map` / `Pin` | provider properties | `region`, `mapType`, `isScrollEnabled`, `isZoomEnabled`, `isTrafficEnabled`, `isShowingUser`, pin `label`, `address`, `location`, `type` | — | — | — | — | — | — |
| `Map` / `Pin` | provider handlers | `mapClicked`, `markerClicked`, `infoWindowClicked` | — | — | — | — | — | — |
| host metadata | structural/adaptive | `content`, `group`, `mode`, `name`, `style`, `isOpaque`, `scrollStep`, `textType`, `visualStateChanged` | — | — | — | — | — | — |

## Complete host vocabulary

The following inventory is intentionally mechanical. It lets tests detect a
built-in token that entered the code without entering this contract. Ownership
is defined by `HostContract`; the tables above give the public grouping and
host status.

### Controls and structural nodes

`AbsoluteLayout`, `ActivityIndicator`, `Application`, `Border`, `BoxView`,
`Button`, `CheckBox`, `Content`, `ContentPage`, `ContextFlyout`, `DatePicker`,
`Editor`, `Ellipse`, `Entry`, `FlyoutPage`, `FormattedString`, `GraphicsView`,
`Grid`, `HorizontalStackLayout`, `Image`, `ImageButton`, `IndicatorView`,
`Label`, `LeadingContent`, `Line`, `Map`, `MenuBarItem`, `MenuBarItems`,
`MenuFlyoutItem`, `MenuFlyoutSeparator`, `MenuFlyoutSubItem`, `ModalStack`,
`NavigationPage`, `NavigationPageTitleView`, `Overlay`, `Path`, `Picker`, `Pin`,
`Polygon`, `Polyline`, `ProgressBar`, `RadioButton`, `Rectangle`, `RefreshView`,
`RoundRectangle`, `Scene`, `ScrollView`, `SearchBar`, `Setters`, `Slider`,
`Span`, `Stepper`, `SwipeItem`, `SwipeItems`, `SwipeView`, `Switch`,
`TabbedPage`, `TimePicker`, `TitleBar`, `ToolbarItem`, `ToolbarItems`,
`TrailingContent`, `VerticalStackLayout`, `VisualState`, `WebView`, `Window`,
`Composed`.

### Properties

`absoluteLayoutBounds`, `absoluteLayoutFlags`, `address`, `allowDrop`,
`anchorX`, `anchorY`, `aspect`, `automationExcludedWithChildren`,
`automationId`, `automationIsInAccessibleTree`, `autoHide`, `autoSize`,
`background`, `backgroundColor`, `backgroundImageSource`, `barBackground`,
`barBackgroundColor`, `barTextColor`, `borderColor`, `borderWidth`,
`cancelButtonColor`, `canDrag`, `cascadeInputTransparent`, `characterSpacing`,
`clearButtonVisibility`, `color`, `columnDefinitions`, `columnSpacing`,
`content`, `contentLayout`, `cornerRadius`, `count`, `currentPage`,
`cursorPosition`, `data`, `date`, `dragText`, `drawable`, `fill`, `fillRule`,
`floatsOnTop`, `flowDirection`, `flyoutLayoutBehavior`, `fontAttributes`,
`fontAutoScalingEnabled`, `fontFamily`, `fontSize`, `foregroundColor`, `format`,
`frame`, `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`, `group`,
`groupName`, `height`, `heightRequest`, `hideSingle`, `hideSoftInputOnTapped`,
`horizontalOptions`, `horizontalScrollBarVisibility`,
`horizontalTextAlignment`, `icon`, `iconImageSource`, `imageSource`,
`increment`, `indicatorColor`, `indicatorSize`, `indicatorsShape`,
`inputTransparent`, `isAnimationPlaying`, `isChecked`, `isClippedToBounds`,
`isDestructive`, `isEnabled`, `isGestureEnabled`, `isMaximizable`,
`isMinimizable`, `isOpaque`, `isOpen`, `isPassword`, `isPresented`,
`isReadOnly`, `isRefreshEnabled`, `isRefreshing`, `isRunning`,
`isScrollEnabled`, `isShowingUser`, `isSpellCheckEnabled`,
`isTextPredictionEnabled`, `isToggled`, `isTrafficEnabled`, `isVisible`,
`isZoomEnabled`, `itemsSource`, `keyboard`, `label`, `lineBreakMode`,
`lineHeight`, `location`, `mapType`, `margin`, `maximum`, `maximumDate`,
`maximumHeight`, `maximumHeightRequest`, `maximumTrackColor`, `maximumVisible`,
`maximumWidth`, `maximumWidthRequest`, `maxLength`, `maxLines`, `minimum`,
`minimumDate`, `minimumHeight`, `minimumHeightRequest`, `minimumTrackColor`,
`minimumWidth`, `minimumWidthRequest`, `modalPresentationStyle`, `mode`, `name`,
`navigationPageBackButtonTitle`, `navigationPageHasBackButton`,
`navigationPageHasNavigationBar`, `navigationPageIconColor`,
`navigationPageTitleIconImageSource`, `numberOfTapsRequired`, `offColor`,
`onColor`, `opacity`, `order`, `orientation`, `padding`, `panTouchCount`,
`panXChannel`, `panYChannel`, `placeholder`, `placeholderColor`, `points`,
`position`, `priority`, `progress`, `progressColor`, `radiusX`, `radiusY`,
`refreshColor`, `region`, `renderTransform`, `returnType`, `rotation`,
`rotationX`, `rotationY`, `rowDefinitions`, `rowSpacing`, `safeAreaEdges`,
`scale`, `scaleX`, `scaleY`, `scrollMomentum`, `scroll`, `scrollStep`,
`searchIconColor`, `selectedIndex`, `selectedIndicatorColor`, `selectedTabColor`,
`selectionLength`, `semanticDescription`, `semanticHeadingLevel`, `semanticHint`,
`side`, `snapFrom`, `snapInterval`, `snapsAtMost`, `source`, `spacing`, `stroke`,
`strokeDashArray`, `strokeDashOffset`, `strokeLineCap`, `strokeLineJoin`,
`strokeMiterLimit`, `strokeShape`, `strokeThickness`, `style`, `subtitle`,
`swipeBehaviorOnInvoked`, `swipeDirection`, `swipeThreshold`, `text`,
`textColor`, `textDecorations`, `textTransform`, `textType`, `threshold`,
`thumbColor`, `thumbImageSource`, `time`, `title`, `titleColor`, `translationX`,
`translationY`, `type`, `unselectedTabColor`, `userAgent`, `useSafeArea`,
`value`, `verticalOptions`, `verticalScrollBarVisibility`,
`verticalTextAlignment`, `width`, `widthRequest`, `windowType`, `windowValue`,
`x`, `x1`, `x2`, `y`, `y1`, `y2`, `zIndex`.

### Events

`activated`, `appearing`, `canGoBackChanged`, `canGoForwardChanged`,
`checkedChanged`, `clicked`, `closed`, `completed`, `created`,
`currentPageChanged`, `dateSelected`, `deactivated`, `destroying`,
`disappearing`, `dragCompleted`, `dragInteraction`, `dragLeave`, `dragOver`,
`dragStarted`, `dragStarting`, `drop`, `dropCompleted`, `endInteraction`,
`frameChanged`, `heightChanged`, `infoWindowClicked`, `invoked`,
`isFocusedChanged`, `isPresentedChanged`, `isRefreshingChanged`, `mapClicked`,
`markerClicked`, `modalPopped`, `navigated`, `navigatedFrom`, `navigatedTo`,
`navigating`, `navigatingFrom`, `opened`, `panUpdated`, `pinchUpdated`, `pointerEntered`,
`pointerExited`, `pointerMoved`, `pointerPressed`, `pointerReleased`, `popped`,
`pressed`, `processTerminated`, `refreshing`, `released`, `resumed`,
`scrollStopped`, `scrollXChanged`, `scrollYChanged`, `searchButtonPressed`,
`selectedIndexChanged`, `snapItemChanged`, `startInteraction`, `stopped`,
`swipeChanging`, `swipeEnded`, `swipeStarted`, `swiped`, `tapped`, `textChanged`,
`timeSelected`, `toggled`, `valueChanged`, `visualStateChanged`, `widthChanged`,
`windowClosed`, `windowRestored`.
