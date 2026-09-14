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
| `Page` | adaptive shell | ✅ | — | — | — | — | — |
| `NavigationStack` | adaptive shell | ✅ | — | — | — | — | — |
| `TabbedView` | adaptive shell | ✅ | — | — | — | — | — |
| `SplitView` | adaptive shell | ✅ | — | — | — | — | — |
| `ModalStack` | structure | ✅ | — | — | — | — | — |
| `Overlay` | structure | ✅ | — | — | — | — | — |
| `TitleBar` | adaptive shell | ✅ | — | — | — | — | — |
| `ContextMenu`, `MenuBarItems`, `MenuBarItem`, `MenuFlyoutItem`, `MenuFlyoutSeparator`, `MenuFlyoutSubItem` | structure | ✅ | — | — | — | — | — |
| `ToolbarItems` / `ToolbarItem` | structure | ✅ | — | — | — | — | — |
| `AbsoluteLayout` | native primitive | ✅ | — | — | — | — | — |
| `VStack` / `HStack` | native primitive | ✅ | — | — | — | — | — |
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
| `ItemsView` (planned) | native primitive | — | — | — | — | — | — |
| `Content`, `LeadingContent`, `TrailingContent`, `TitleView` | structure | — | — | — | — | — | — |
| `Setters`, `VisualState`, `Composed` | structure resolved by StateUI | — | — | — | — | — | — |

The AppKit split view uses `NSSplitViewController`.

Page arrangements expose an optional flat `barBackgroundColor`. A
`NavigationStack` additionally exposes `barTextColor` for its title and native
action affordances. A tab selector keeps the toolkit's selected and unselected
appearance. An unwritten background retains the native material; StateUI does
not ask a host to rasterize an arbitrary brush into page chrome.

`ItemsView` is the reserved public name for the native virtualized collection.
It presents identified items without constraining them to a list or grid. Its
host adapters map to `NSCollectionView` or a strict one-column `NSTableView`,
`UICollectionView`, `GtkListView` or `GtkGridView`, `RecyclerView`, WinUI
`ItemsView`, and a semantic DOM list/grid. The control remains planned rather
than part of the active host vocabulary until stable identity, native reuse,
list/grid layout, selection, activation, accessibility, and programmatic
scrolling form one complete contract. A platform receives ✅ only after that
entire surface works through its native items control.

`ForEach`, `FrameReader`, `ScrollReader`, `PlacedLayout`, and `GalleryView` are
StateUI compositions or readers rather than additional platform controls. The
core implements them once; their platform behavior depends only on the
primitive rows they use.

## Native control mapping

The table names the native class or API that each host adapts for a StateUI
surface. It records no implementation status; the ✅ tables keep that. Where the
AppKit host already creates a node, its column names the class it uses.
`composed by StateUI` marks a surface StateUI derives from other rows,
`structure` a node that creates no native object, `—` a toolkit without an
honest native counterpart, and `(?)` a mapping that is not yet confirmed. A host
may still choose another class that preserves the same contract.

| StateUI surface | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | --- | --- | --- | --- | --- |
| `Application` / `Scene` | `NSApplication` / structure | `UIApplication` / `UIWindowScene` | `GtkApplication` / structure | `Application` / structure | `Application` / structure | `document` / structure |
| `Window` | `NSWindow` | `UIWindow` | `GtkApplicationWindow` | `Activity` | `Window` | browser `window` |
| `Page` | custom `NSView` | `UIViewController` | custom `GtkWidget` | custom `ViewGroup` | `Page` | `<section>` |
| `NavigationStack` | custom `NSView` stack; title, back and actions in the window's `NSToolbar` | `UINavigationController` | `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView` | custom `ViewGroup` stack + `Toolbar` | `Frame` | History API |
| `TabbedView` | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it | `UITabBarController` | `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack` | Material Components `BottomNavigationView` (?) | `NavigationView` with a top pane | ARIA `tablist` |
| `SplitView` | `NSSplitViewController` | `UISplitViewController` | `GtkPaned`; libadwaita `AdwOverlaySplitView` | AndroidX `DrawerLayout` | `SplitView` | `<aside>` |
| `ModalStack` | sheet `NSWindow` | `present(_:animated:)` | modal `GtkWindow`; libadwaita `AdwDialog` | full-screen `Dialog` (?) | `ContentDialog` (?) | `<dialog>` with `showModal()` |
| `Overlay` | pass-through `NSView` above the page | pass-through `UIView` above the page | `GtkOverlay` | top child of a `FrameLayout` | top layer of a root `Grid` | positioned element above the page |
| `TitleBar` | slots in `NSToolbar`; title in a trailing `NSTitlebarAccessoryViewController` | — | `GtkHeaderBar` | — | `TitleBar` | — |
| `ContextMenu`, `MenuBarItems`, `MenuBarItem`, `MenuFlyoutItem`, `MenuFlyoutSeparator`, `MenuFlyoutSubItem` | `NSMenu` / `NSMenuItem` | `UIMenu` / `UIAction` | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | `PopupMenu` / `MenuItem`; no menu bar | `MenuFlyout` / `MenuBar` | ARIA `menu` / `menubar` (?) |
| `ToolbarItems` / `ToolbarItem` | `NSToolbarItem`; `NSMenuToolbarItem` overflow | `UIBarButtonItem` | `GtkButton` in `GtkHeaderBar` | `Toolbar` `MenuItem` | `CommandBar` `AppBarButton` | `<button>` in an ARIA `toolbar` |
| `AbsoluteLayout` | custom `NSView` | custom `UIView` | `GtkFixed` | custom `ViewGroup` | `Canvas` | `position: absolute` |
| `VStack` / `HStack` | custom `NSView` | custom `UIView` | `GtkBox` | custom `ViewGroup` | `StackPanel` | flexbox |
| `Grid` | custom `NSView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `ScrollView` | `NSScrollView` | `UIScrollView` | `GtkScrolledWindow` | `ScrollView` / `HorizontalScrollView` | `ScrollViewer` | `overflow: auto` |
| `Border` | custom `NSView` drawing `NSBezierPath` | `UIView` + `CAShapeLayer` | custom `GtkWidget` snapshot | `FrameLayout` + `GradientDrawable` | `Border` | `<div>` + CSS `border` |
| `Label` / `FormattedString` / `Span` | `NSTextField` label; `NSAttributedString` runs | `UILabel`; `NSAttributedString` runs | `GtkLabel`; `PangoAttrList` runs | `TextView`; `SpannableString` spans | `TextBlock`; `Run` inlines | text element; `<span>` runs |
| `Button` | `NSButton` | `UIButton` | `GtkButton` | `Button` | `Button` | `<button>` |
| `ImageButton` | `NSButton` with an image | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `Image` | `NSImageView` | `UIImageView` | `GtkPicture` | `ImageView` | `Image` | `<img>` |
| `BoxView` | custom `NSView` drawing | `UIView` + `CALayer` | custom `GtkWidget` snapshot | `View` + `GradientDrawable` | `Border` | `<div>` |
| `Entry` | `NSTextField` / `NSSecureTextField` | `UITextField` | `GtkEntry` / `GtkPasswordEntry` | `EditText` | `TextBox` / `PasswordBox` | `<input>` |
| `Editor` | `NSTextView` in an `NSScrollView` | `UITextView` | `GtkTextView` | multi-line `EditText` | multi-line `TextBox` | `<textarea>` |
| `SearchBar` | `NSSearchField` | `UISearchBar` | `GtkSearchEntry` | `SearchView` | `AutoSuggestBox` | `<input type=search>` |
| `Picker` | `NSPopUpButton` | pop-up `UIButton` menu | `GtkDropDown` | `Spinner` | `ComboBox` | `<select>` |
| `DatePicker` | `NSDatePicker` | `UIDatePicker` | `GtkCalendar` in a `GtkPopover` | `DatePickerDialog` | `CalendarDatePicker` | `<input type=date>` |
| `TimePicker` | `NSDatePicker` in time mode | `UIDatePicker` in time mode | — | `TimePickerDialog` | `TimePicker` | `<input type=time>` |
| `Switch` | `NSSwitch` | `UISwitch` | `GtkSwitch` | `Switch` | `ToggleSwitch` | checkbox `<input>` with `role=switch` |
| `CheckBox` | `NSButton` checkbox | composed by StateUI | `GtkCheckButton` | `CheckBox` | `CheckBox` | `<input type=checkbox>` |
| `RadioButton` | `NSButton` radio | composed by StateUI | grouped `GtkCheckButton` | `RadioButton` | `RadioButton` | `<input type=radio>` |
| `Slider` | `NSSlider` | `UISlider` | `GtkScale` | `SeekBar` | `Slider` | `<input type=range>` |
| `Stepper` | `NSStepper` | `UIStepper` | `GtkSpinButton` | custom `NumberPicker`-based view | `NumberBox` | `<input type=number>` |
| `ProgressBar` | `NSProgressIndicator` bar | `UIProgressView` | `GtkProgressBar` | horizontal `ProgressBar` | `ProgressBar` | `<progress>` |
| `ActivityIndicator` | spinning `NSProgressIndicator` | `UIActivityIndicatorView` | `GtkSpinner` | indeterminate `ProgressBar` | `ProgressRing` | indeterminate `<progress>` |
| `GraphicsView` | custom `NSView` drawing | `UIView` `draw(_:)` | `GtkDrawingArea` | `View` `onDraw(Canvas)` | Win2D `CanvasControl` (?) | `<canvas>` |
| `Rectangle` / `RoundRectangle` / `Ellipse` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `Line` / `Path` / `Polygon` / `Polyline` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `IndicatorView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `RefreshView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `SwipeView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `SwipeItems` / `SwipeItem` | structure | structure | structure | structure | structure | structure |
| `WebView` | `WKWebView` | `WKWebView` | WebKitGTK `WebKitWebView` | `WebView` | `WebView2` | `<iframe>` (?) |
| `Map` / `Pin` | `MKMapView` / `MKAnnotation` | `MKMapView` / `MKAnnotation` | libshumate `ShumateMap` / `ShumateMarker` | Google Play services `MapView` / `Marker` (?) | `MapControl` (?) | — |
| `ItemsView` (planned) | `NSCollectionView` / `NSTableView` | `UICollectionView` | `GtkListView` / `GtkGridView` | AndroidX `RecyclerView` | `ItemsView` | semantic list or grid |
| `Content`, `LeadingContent`, `TrailingContent`, `TitleView` | structure | structure | structure | structure | structure | structure |
| `Setters`, `VisualState`, `Composed` | structure | structure | structure | structure | structure | structure |

### Completeness

Every `NodeType` in `HostContract.controls` appears exactly once in the first
column: its 67 built-in node types occupy 45 rows, and the planned `ItemsView`
adds one row without a host token.

These surfaces lack an honest native counterpart on at least one target:

- `NavigationStack`: Android Views and GTK 4 without libadwaita have no page-stack control.
- `TabbedView`: Android Views has no framework tab bar; Web has no tab element.
- `SplitView`: Android Views depends on AndroidX `DrawerLayout`; Web has no native pane.
- `ModalStack`: Android Views has no modal page presentation; WinUI 3 shows one `ContentDialog` at a time.
- `TitleBar`: UIKit, Android Views, and Web have no window title bar.
- Menus: Android Views has no menu bar; Web has no native menu element.
- `Grid`: AppKit, UIKit, and GTK 4 have no container with star and auto tracks.
- `CheckBox` and `RadioButton`: UIKit has neither control.
- `Stepper`: Android Views has no stepper; `NumberPicker` is an integer wheel.
- `DatePicker`: GTK 4 has `GtkCalendar` but no date field.
- `TimePicker`: GTK 4 has no time picker.
- `Switch`: Web has no switch element.
- `ActivityIndicator`: Web has no spinner; an indeterminate `<progress>` draws a bar.
- `GraphicsView`: WinUI 3 has no immediate-mode canvas without Win2D.
- `IndicatorView`: AppKit, Android Views, and Web have no page indicator.
- `RefreshView`: AppKit, GTK 4, and Web have no pull-to-refresh control.
- `SwipeView`: AppKit, UIKit, GTK 4, Android Views, and Web have no standalone swipe-action container.
- `WebView`: GTK 4 depends on WebKitGTK; Web cannot observe navigation or set a user agent in a cross-origin `<iframe>`.
- `Map` / `Pin`: Web has no map element; GTK 4, Android Views, and WinUI 3 depend on libshumate, Google Play services, and a map service.
- `ItemsView`: Android Views depends on AndroidX `RecyclerView`; Web has no native virtualized list.

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
| hit testing on every eligible view | `ignoresInput`, `letsInputThrough` | — | — | — | — | — | — |
| layout direction | `layoutDirection` | — | — | — | — | — | — |
| requested size | `width`, `height`, `minimumWidth`, `minimumHeight`, `maximumWidth`, `maximumHeight` | — | — | — | — | — | — |
| parent placement | `margin`, `horizontalAlignment`, `verticalAlignment` | — | — | — | — | — | — |
| drawing order | `zIndex` | — | — | — | — | — | — |
| planar transform | `rotation`, `scale`, `scaleX`, `scaleY`, `translationX`, `translationY` | — | — | — | — | — | — |
| spatial transform and pivot | `rotationX`, `rotationY`, `pivotX`, `pivotY` | — | — | — | — | — | — |
| accessibility | `automationId`, `automationIsInAccessibleTree`, `automationExcludedWithChildren`, `semanticDescription`, `semanticHint`, `semanticHeadingLevel` | ✅ | — | — | — | — | — |
| frame feed/event | `frame`, `frameChanged` | ✅ | — | — | — | — | — |
| focus feed and event | `isFocused`, `isFocusedChanged` | — | — | — | — | — | — |
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
| `Window` | properties | `title`, `x`, `y`, `width`, `height`, `minimumWidth`, `minimumHeight`, `maximumWidth`, `maximumHeight`, `isMaximizable`, `isMinimizable` | ✅ | — | — | — | — | — |
| `WindowGroup` / `Window` | session metadata | `windowType`, `windowValue`, `autoHide`, `floatsOnTop` | ✅ | — | — | — | — | — |
| `Window` | handlers | `created`, `activated`, `deactivated`, `stopped`, `resumed`, `destroying` | ✅ | — | — | — | — | — |
| `Scene` | handlers | `activated`, `deactivated`, `stopped`, `destroying`, `windowClosed`, `windowRestored` | ✅ | — | — | — | — | — |
| `Page` | properties | `title`, `iconImageSource`, `padding`, `backgroundColor`, `backButtonTitle`, `hasBackButton`, `hasNavigationBar`, `titleView`, toolbar and menu slots | ✅ | — | — | — | — | — |
| `Page` | handlers | `appearing`, `disappearing`, `navigatingFrom`, `navigatedFrom`, `navigatedTo` | ✅ | — | — | — | — | — |
| `NavigationStack` | state | bound path and committed native back (`popped`) | ✅ | — | — | — | — | — |
| `NavigationStack` | properties | `barBackgroundColor` | ✅ | — | — | — | — | — |
| `NavigationStack` | properties | `barTextColor` | ✅ | — | — | — | — | — |
| `TabbedView` | state/events | bound `currentPage` (`currentPageChanged`) | ✅ | — | — | — | — | — |
| `TabbedView` | properties | `barBackgroundColor`; native selected/unselected appearance | ✅ | — | — | — | — | — |
| `SplitView` | state/events | bound `isSidebarVisible` (`isSidebarVisibleChanged`) | ✅ | — | — | — | — | — |
| `SplitView` | native presentation | adaptive native pane and native platform affordances | ✅ | — | — | — | — | — |
| `ModalStack` | state/events | bound modal stack (`modalPopped`) | ✅ | — | — | — | — | — |
| menu items | properties | `text`, `iconImageSource`, `isDestructive`, `isEnabled` | ✅ | — | — | — | — | — |
| toolbar items | properties | `text`, `iconImageSource`, `isDestructive`, `isEnabled`, `order`, `priority` | ✅ | — | — | — | — | — |
| menu / toolbar items | handlers | `onClicked` (`clicked`) | ✅ | — | — | — | — | — |
| `TitleBar` | properties/slots | `title`, `subtitle`, `icon`, `foregroundColor`, `backgroundColor`, leading/content/trailing slots | ✅ | — | — | — | — | — |
| stack layouts | properties | `padding`, `spacing` | ✅ | — | — | — | — | — |
| `Grid` | properties | `rowDefinitions`, `columnDefinitions`, `rowSpacing`, `columnSpacing`, child `gridRow`, `gridColumn`, `gridRowSpan`, `gridColumnSpan` | — | — | — | — | — | — |
| `AbsoluteLayout` | properties | child `absoluteLayoutBounds`, `absoluteLayoutFlags` | — | — | — | — | — | — |
| layouts | properties | `clipsContent`, `safeAreaEdges` | — | — | — | — | — | — |
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

A one-axis `ScrollView` owns input along its enabled axis. When it is nested,
a dominant input on its disabled axis passes to the nearest enclosing scroller.
This behavior is part of the shared contract and must be proved before a host's
`ScrollView` rows receive ✅.

## Complete host vocabulary

The following inventory is intentionally mechanical. It lets tests detect a
built-in token that entered the code without entering this contract. Ownership
is defined by `HostContract`; the tables above give the public grouping and
host status.

### Controls and structural nodes

`AbsoluteLayout`, `ActivityIndicator`, `Application`, `Border`, `BoxView`,
`Button`, `CheckBox`, `Composed`, `Content`, `ContextMenu`, `DatePicker`,
`Editor`, `Ellipse`, `Entry`, `FormattedString`, `GraphicsView`, `Grid`,
`HStack`, `Image`, `ImageButton`, `IndicatorView`, `Label`, `LeadingContent`,
`Line`, `Map`, `MenuBarItem`, `MenuBarItems`, `MenuFlyoutItem`,
`MenuFlyoutSeparator`, `MenuFlyoutSubItem`, `ModalStack`, `NavigationStack`,
`Overlay`, `Page`, `Path`, `Picker`, `Pin`, `Polygon`, `Polyline`,
`ProgressBar`, `RadioButton`, `Rectangle`, `RefreshView`, `RoundRectangle`,
`Scene`, `ScrollView`, `SearchBar`, `Setters`, `Slider`, `Span`, `SplitView`,
`Stepper`, `SwipeItem`, `SwipeItems`, `SwipeView`, `Switch`, `TabbedView`,
`TimePicker`, `TitleBar`, `TitleView`, `ToolbarItem`, `ToolbarItems`,
`TrailingContent`, `VisualState`, `VStack`, `WebView`, `Window`.

### Properties

`absoluteLayoutBounds`, `absoluteLayoutFlags`, `address`, `allowDrop`,
`aspect`, `autoHide`, `automationExcludedWithChildren`, `automationId`,
`automationIsInAccessibleTree`, `autoSize`, `backButtonTitle`, `background`,
`backgroundColor`, `barBackgroundColor`, `barTextColor`, `borderColor`,
`borderWidth`, `cancelButtonColor`, `canDrag`, `characterSpacing`,
`clearButtonVisibility`, `clipsContent`, `color`, `columnDefinitions`,
`columnSpacing`, `content`, `contentLayout`, `cornerRadius`, `count`,
`currentPage`, `cursorPosition`, `data`, `date`, `dragText`, `drawable`,
`fill`, `fillRule`, `floatsOnTop`, `fontAttributes`, `fontAutoScalingEnabled`,
`fontFamily`, `fontSize`, `foregroundColor`, `format`, `frame`, `gridColumn`,
`gridColumnSpan`, `gridRow`, `gridRowSpan`, `group`, `groupName`,
`hasBackButton`, `hasNavigationBar`, `height`, `hideSingle`,
`horizontalAlignment`, `horizontalScrollBarVisibility`,
`horizontalTextAlignment`, `icon`, `iconImageSource`, `ignoresInput`,
`imageSource`, `increment`, `indicatorColor`, `indicatorSize`,
`indicatorsShape`, `isAnimationPlaying`, `isChecked`, `isDestructive`,
`isEnabled`, `isMaximizable`, `isMinimizable`, `isOpaque`, `isOpen`,
`isPassword`, `isReadOnly`, `isRefreshEnabled`, `isRefreshing`, `isRunning`,
`isScrollEnabled`, `isShowingUser`, `isSidebarVisible`, `isSpellCheckEnabled`,
`isTextPredictionEnabled`, `isToggled`, `isTrafficEnabled`, `isVisible`,
`isZoomEnabled`, `itemsSource`, `keyboard`, `label`, `layoutDirection`,
`letsInputThrough`, `lineBreakMode`, `lineHeight`, `location`, `mapType`,
`margin`, `maximum`, `maximumDate`, `maximumHeight`, `maximumTrackColor`,
`maximumVisible`, `maximumWidth`, `maxLength`, `maxLines`, `minimum`,
`minimumDate`, `minimumHeight`, `minimumTrackColor`, `minimumWidth`, `mode`,
`name`, `numberOfTapsRequired`, `offColor`, `onColor`, `opacity`, `order`,
`orientation`, `padding`, `panTouchCount`, `panXChannel`, `panYChannel`,
`pivotX`, `pivotY`, `placeholder`, `placeholderColor`, `points`, `position`,
`priority`, `progress`, `progressColor`, `radiusX`, `radiusY`, `refreshColor`,
`region`, `renderTransform`, `returnType`, `rotation`, `rotationX`,
`rotationY`, `rowDefinitions`, `rowSpacing`, `safeAreaEdges`, `scale`,
`scaleX`, `scaleY`, `scroll`, `scrollMomentum`, `scrollStep`,
`searchIconColor`, `selectedIndex`, `selectedIndicatorColor`,
`selectionLength`, `semanticDescription`, `semanticHeadingLevel`,
`semanticHint`, `side`, `snapFrom`, `snapInterval`, `snapsAtMost`, `source`,
`spacing`, `stroke`, `strokeDashArray`, `strokeDashOffset`, `strokeLineCap`,
`strokeLineJoin`, `strokeMiterLimit`, `strokeShape`, `strokeThickness`,
`style`, `subtitle`, `swipeBehaviorOnInvoked`, `swipeDirection`,
`swipeThreshold`, `text`, `textColor`, `textDecorations`, `textTransform`,
`textType`, `threshold`, `thumbColor`, `thumbImageSource`, `time`, `title`,
`titleColor`, `translationX`, `translationY`, `type`, `userAgent`, `value`,
`verticalAlignment`, `verticalScrollBarVisibility`, `verticalTextAlignment`,
`width`, `windowType`, `windowValue`, `x`, `x1`, `x2`, `y`, `y1`, `y2`,
`zIndex`.

### Events

`activated`, `appearing`, `canGoBackChanged`, `canGoForwardChanged`,
`checkedChanged`, `clicked`, `closed`, `completed`, `created`,
`currentPageChanged`, `dateSelected`, `deactivated`, `destroying`,
`disappearing`, `dragCompleted`, `dragInteraction`, `dragLeave`, `dragOver`,
`dragStarted`, `dragStarting`, `drop`, `dropCompleted`, `endInteraction`,
`frameChanged`, `infoWindowClicked`, `invoked`, `isFocusedChanged`,
`isRefreshingChanged`, `isSidebarVisibleChanged`, `mapClicked`,
`markerClicked`, `modalPopped`, `navigated`, `navigatedFrom`, `navigatedTo`,
`navigating`, `navigatingFrom`, `opened`, `panUpdated`, `pinchUpdated`,
`pointerEntered`, `pointerExited`, `pointerMoved`, `pointerPressed`,
`pointerReleased`, `popped`, `pressed`, `processTerminated`, `refreshing`,
`released`, `resumed`, `scrollStopped`, `scrollXChanged`, `scrollYChanged`,
`searchButtonPressed`, `selectedIndexChanged`, `snapItemChanged`,
`startInteraction`, `stopped`, `swipeChanging`, `swiped`, `swipeEnded`,
`swipeStarted`, `tapped`, `textChanged`, `timeSelected`, `toggled`,
`valueChanged`, `visualStateChanged`, `windowClosed`, `windowRestored`.
