# Platform contract

This document is the shared delivery contract for the .NET MAUI host,
AppKit, UIKit, GTK 4, Android Views, WinUI 3, and Web DOM/CSS. It records the StateUI surface and the
implementation evidence for each host.

## Reading the matrix

- ✅ means the member is implemented by that host and exercised by its host
  test suite.
- ✅* means the member is implemented and tested but incomplete; the
  control's file in [the control dictionary](controls/README.md) names what is
  missing.
- — means the implementation is absent, incomplete, or not yet verified. It
  is deliberately not an estimate of how difficult the work will be.
- A control-level ✅ means the host recognizes and tests the node. Native and
  adaptive nodes create and retain their platform surface; structural nodes
  are interpreted without inventing a platform control. It does not imply that
  every property has been completed; member rows state that separately.
- A grouped member row receives ✅ only when every member named in that row is
  implemented. Inseparable overloads may share one row.

Member by member and control by control, the marks live in [the control
dictionary](controls/README.md): a realization updates its rows there, and the
counts under [Control dictionary](#control-dictionary) are taken from its files.

The matrix describes observable StateUI semantics. Platform classes are
implementation details. A host may choose another native class when it
preserves the same state, event, accessibility, lifetime, and motion contract.

## Target hosts

| Platform | Runtime | Boundary | Native toolkit |
| --- | --- | --- | --- |
| Android, iOS, Mac Catalyst, Windows, Linux | C# | Wire encoding of `HostPatch` | .NET MAUI |
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

| StateUI surface | Owner | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Application` / `Scene` | structure | — | ✅ | — | — | — | — | — |
| `Window` | structure | — | ✅ | — | — | — | — | — |
| `Page` | adaptive shell | — | ✅ | — | — | — | — | — |
| `NavigationStack` | adaptive shell | — | ✅ | — | — | — | — | — |
| `TabbedView` | adaptive shell | — | ✅ | — | — | — | — | — |
| `SplitView` | adaptive shell | — | ✅ | — | — | — | — | — |
| `ModalStack` | structure | — | ✅ | — | — | — | — | — |
| `Overlay` | structure | — | ✅ | — | — | — | — | — |
| `TitleBar` | adaptive shell | ✅ | ✅ | — | — | — | — | — |
| `ContextMenu`, `MenuBar`, `Menu`, `MenuItem`, `MenuSeparator` | structure | — | ✅ | — | — | — | — | — |
| `ToolbarItems` / `ToolbarItem` | structure | — | ✅ | — | — | — | — | — |
| `AbsoluteLayout` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `VStack` / `HStack` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Grid` | StateUI-owned layout contract | ✅ | ✅ | — | — | — | — | — |
| `ScrollView` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Border` | native primitive | ✅ | — | — | — | — | — | — |
| `Label` / `Spans` / `Span` | native primitive / structure | — | ✅ | — | — | — | — | — |
| `Button` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Image` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `ColorBox` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `TextField` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `TextEditor` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `SearchField` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Picker` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `DatePicker` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `TimePicker` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Switch` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `CheckBox` | StateUI-owned choice contract | ✅ | ✅ | — | — | — | — | — |
| `RadioButton` | StateUI-owned choice contract | ✅ | ✅ | — | — | — | — | — |
| `Slider` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Stepper` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `ProgressBar` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `ActivityIndicator` | native primitive | ✅ | ✅ | — | — | — | — | — |
| `Canvas` | native drawing primitive | ✅ | ✅ | — | — | — | — | — |
| `Rectangle` / `Ellipse` | StateUI-owned drawing contract | ✅ | ✅ | — | — | — | — | — |
| `Line` / `Path` / `Polygon` / `Polyline` | StateUI-owned drawing contract | ✅ | ✅ | — | — | — | — | — |
| `PositionIndicator` | StateUI-owned composition | ✅ | — | — | — | — | — | — |
| `RefreshView` | StateUI-owned interaction | ✅ | — | — | — | — | — | — |
| `SwipeView` | StateUI-owned interaction | ✅ | — | — | — | — | — | — |
| `SwipeActions` / `SwipeAction` | structure | — | — | — | — | — | — | — |
| `WebView` | native primitive | ✅ | — | — | — | — | — | — |
| `Map` / `Pin` | optional provider | — | — | — | — | — | — | — |
| `ItemsView` | native primitive, planned; StateUI composition on MAUI | ✅ | — | — | — | — | — | — |
| `Content`, `LeadingContent`, `TrailingContent`, `TitleView` | structure | — | — | — | — | — | — | — |
| `Setters`, `VisualState`, `Composed` | structure resolved by StateUI | — | — | — | — | — | — | — |

The AppKit split view uses `NSSplitViewController`.

Page arrangements expose an optional flat `barBackgroundColor`. A
`NavigationStack` additionally exposes `barForegroundColor` for its title and native
action affordances. A tab selector keeps the toolkit's selected and unselected
appearance. An unwritten background retains the native material; StateUI does
not ask a host to rasterize an arbitrary brush into page chrome.

On AppKit a written bar colour paints the band the title bar and toolbar cover
over the visible content - a split view's detail, the sidebar keeping its own
glass - and an authored `TitleBar`'s `background` paints it where no
arrangement writes one. Text on a painted band is the bar's: the page's title
in the arrangement's `barForegroundColor`, the title bar's own title in the
title bar's, each falling back to the other and then to white or black by the band's lightness.
On the system's material both keep the system's colours.

`ItemsView` is the public name for the native virtualized collection. It
presents identified items without constraining them to a list or grid. Its
host adapters map to `NSCollectionView` or a strict one-column `NSTableView`,
`UICollectionView`, `GtkListView` or `GtkGridView`, `RecyclerView`, WinUI
`ItemsView`, and a semantic DOM list/grid. The native control remains planned
rather than part of the active host vocabulary until stable identity, native
reuse, list/grid layout, selection, activation, accessibility, and
programmatic scrolling form one complete contract; a platform receives ✅ for
it only after that entire surface works through its native items control. The
MAUI host has `ItemsView` today as a StateUI composition compiled under
`#if MAUI`, over `ScrollView` and `AbsoluteLayout` - see
[MAUI host](maui-host.md#lists-itemsview).

`ForEach`, `FrameReader`, `ScrollReader`, `PlacedLayout`, and `GalleryView` are
StateUI compositions or readers rather than additional platform controls. The
core implements them once; their platform behavior depends only on the
primitive rows they use.

## Native control mapping

The table names the native class or API that each host adapts for a StateUI
surface. It records no implementation status; the ✅ tables keep that. Where the
AppKit host already creates a node, its column names the class it uses; the
MAUI column names the MAUI class the host's renderer creates.
`composed by StateUI` marks a surface StateUI derives from other rows,
`structure` a node that creates no native object, `—` a toolkit without an
honest native counterpart, and `(?)` a mapping that is not yet confirmed. A host
may still choose another class that preserves the same contract.

| StateUI surface | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Application` / `Scene` | `Application` / structure | `NSApplication` / structure | `UIApplication` / `UIWindowScene` | `GtkApplication` / structure | `Application` / structure | `Application` / structure | `document` / structure |
| `Window` | `Window` | `NSWindow` | `UIWindow` | `GtkApplicationWindow` | `Activity` | `Window` | browser `window` |
| `Page` | `ContentPage` | custom `NSView` | `UIViewController` | custom `GtkWidget` | custom `ViewGroup` | `Page` | `<section>` |
| `NavigationStack` | `NavigationPage` | custom `NSView` stack; title, back and actions in the window's `NSToolbar` | `UINavigationController` | `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView` | custom `ViewGroup` stack + `Toolbar` | `Frame` | History API |
| `TabbedView` | `TabbedPage` | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it | `UITabBarController` | `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack` | Material Components `BottomNavigationView` (?) | `NavigationView` with a top pane | ARIA `tablist` |
| `SplitView` | `FlyoutPage` | `NSSplitViewController` | `UISplitViewController` | `GtkPaned`; libadwaita `AdwOverlaySplitView` | AndroidX `DrawerLayout` | `SplitView` | `<aside>` |
| `ModalStack` | modal `Page` (`PushModalAsync`) | sheet `NSWindow` | `present(_:animated:)` | modal `GtkWindow`; libadwaita `AdwDialog` | full-screen `Dialog` (?) | `ContentDialog` (?) | `<dialog>` with `showModal()` |
| `Overlay` | `IWindowOverlay` layer | pass-through `NSView` above the page | pass-through `UIView` above the page | `GtkOverlay` | top child of a `FrameLayout` | top layer of a root `Grid` | positioned element above the page |
| `TitleBar` | `TitleBar` | slots in `NSToolbar`; title in a trailing `NSTitlebarAccessoryViewController` | — | `GtkHeaderBar` | — | `TitleBar` | — |
| `ContextMenu`, `MenuBar`, `Menu`, `MenuItem`, `MenuSeparator` | `MenuFlyout` / `MenuBarItem` | `NSMenu` / `NSMenuItem` | `UIMenu` / `UIAction` | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | `PopupMenu` / `MenuItem`; no menu bar | `MenuFlyout` / `MenuBar` | ARIA `menu` / `menubar` (?) |
| `ToolbarItems` / `ToolbarItem` | `ToolbarItem` | `NSToolbarItem`; `NSMenuToolbarItem` overflow | `UIBarButtonItem` | `GtkButton` in `GtkHeaderBar` | `Toolbar` `MenuItem` | `CommandBar` `AppBarButton` | `<button>` in an ARIA `toolbar` |
| `AbsoluteLayout` | `AbsoluteLayout` | custom `NSView` | custom `UIView` | `GtkFixed` | custom `ViewGroup` | `Canvas` | `position: absolute` |
| `VStack` / `HStack` | custom `Layout` | custom `NSView` | custom `UIView` | `GtkBox` | custom `ViewGroup` | `StackPanel` | flexbox |
| `Grid` | `Grid` | custom `NSView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `ScrollView` | `ScrollView` | `NSScrollView` | `UIScrollView` | `GtkScrolledWindow` | `ScrollView` / `HorizontalScrollView` | `ScrollViewer` | `overflow: auto` |
| `Border` | `Border` | custom `NSView` drawing `NSBezierPath` | `UIView` + `CAShapeLayer` | custom `GtkWidget` snapshot | `FrameLayout` + `GradientDrawable` | `Border` | `<div>` + CSS `border` |
| `Label` / `Spans` / `Span` | `Label`; `FormattedString` / `Span` runs | `NSTextField` label; `NSAttributedString` runs | `UILabel`; `NSAttributedString` runs | `GtkLabel`; `PangoAttrList` runs | `TextView`; `SpannableString` spans | `TextBlock`; `Run` inlines | text element; `<span>` runs |
| `Button` | `Button` | `NSButton` | `UIButton` | `GtkButton` | `Button` | `Button` | `<button>` |
| `Image` | `Image` | `NSImageView` | `UIImageView` | `GtkPicture` | `ImageView` | `Image` | `<img>` |
| `ColorBox` | `BoxView` | custom `NSView` drawing | `UIView` + `CALayer` | custom `GtkWidget` snapshot | `View` + `GradientDrawable` | `Border` | `<div>` |
| `TextField` | `Entry` | `NSTextField` / `NSSecureTextField` | `UITextField` | `GtkEntry` / `GtkPasswordEntry` | `EditText` | `TextBox` / `PasswordBox` | `<input>` |
| `TextEditor` | `Editor` | `NSTextView` in an `NSScrollView` | `UITextView` | `GtkTextView` | multi-line `EditText` | multi-line `TextBox` | `<textarea>` |
| `SearchField` | `SearchBar` | `NSSearchField` | `UISearchBar` | `GtkSearchEntry` | `SearchView` | `AutoSuggestBox` | `<input type=search>` |
| `Picker` | `Picker` | `NSPopUpButton` | pop-up `UIButton` menu | `GtkDropDown` | `Spinner` | `ComboBox` | `<select>` |
| `DatePicker` | `DatePicker` | `NSDatePicker` | `UIDatePicker` | `GtkCalendar` in a `GtkPopover` | `DatePickerDialog` | `CalendarDatePicker` | `<input type=date>` |
| `TimePicker` | `TimePicker` | `NSDatePicker` in time mode | `UIDatePicker` in time mode | — | `TimePickerDialog` | `TimePicker` | `<input type=time>` |
| `Switch` | `Switch` | `NSSwitch` | `UISwitch` | `GtkSwitch` | `Switch` | `ToggleSwitch` | checkbox `<input>` with `role=switch` |
| `CheckBox` | `CheckBox` | `NSButton` checkbox | composed by StateUI | `GtkCheckButton` | `CheckBox` | `CheckBox` | `<input type=checkbox>` |
| `RadioButton` | `RadioButton` | `NSButton` radio | composed by StateUI | grouped `GtkCheckButton` | `RadioButton` | `RadioButton` | `<input type=radio>` |
| `Slider` | `Slider` | `NSSlider` | `UISlider` | `GtkScale` | `SeekBar` | `Slider` | `<input type=range>` |
| `Stepper` | `Stepper` | `NSStepper` | `UIStepper` | `GtkSpinButton` | custom `NumberPicker`-based view | `NumberBox` | `<input type=number>` |
| `ProgressBar` | `ProgressBar` | `NSProgressIndicator` bar | `UIProgressView` | `GtkProgressBar` | horizontal `ProgressBar` | `ProgressBar` | `<progress>` |
| `ActivityIndicator` | `ActivityIndicator` | spinning `NSProgressIndicator` | `UIActivityIndicatorView` | `GtkSpinner` | indeterminate `ProgressBar` | `ProgressRing` | indeterminate `<progress>` |
| `Canvas` | `GraphicsView` | custom `NSView` drawing | `UIView` `draw(_:)` | `GtkDrawingArea` | `View` `onDraw(Canvas)` | Win2D `CanvasControl` (?) | `<canvas>` |
| `Rectangle` / `Ellipse` | `Shape` over `RoundRectangle` / `Ellipse` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `Line` / `Path` / `Polygon` / `Polyline` | `Shape` over `Line` / `Path` / `Polygon` / `Polyline` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `PositionIndicator` | `IndicatorView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `RefreshView` | `RefreshView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `SwipeView` | `SwipeView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `SwipeActions` / `SwipeAction` | `SwipeItems` / `SwipeItem` | structure | structure | structure | structure | structure | structure |
| `WebView` | `WebView` | `WKWebView` | `WKWebView` | WebKitGTK `WebKitWebView` | `WebView` | `WebView2` | `<iframe>` (?) |
| `Map` / `Pin` | `Map` / `Pin` | `MKMapView` / `MKAnnotation` | `MKMapView` / `MKAnnotation` | libshumate `ShumateMap` / `ShumateMarker` | Google Play services `MapView` / `Marker` (?) | `MapControl` (?) | — |
| `ItemsView` | composed by StateUI (`#if MAUI`) | `NSCollectionView` / `NSTableView` | `UICollectionView` | `GtkListView` / `GtkGridView` | AndroidX `RecyclerView` | `ItemsView` | semantic list or grid |
| `Content`, `LeadingContent`, `TrailingContent`, `TitleView` | structure | structure | structure | structure | structure | structure | structure |
| `Setters`, `VisualState`, `Composed` | structure | structure | structure | structure | structure | structure | structure |

### Completeness

Every `NodeType` in `HostContract.controls` appears exactly once in the first
column: its 67 built-in node types occupy 45 rows, and `ItemsView`
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
- `Canvas`: WinUI 3 has no immediate-mode canvas without Win2D.
- `PositionIndicator`: AppKit, Android Views, and Web have no page indicator.
- `RefreshView`: AppKit, GTK 4, and Web have no pull-to-refresh control.
- `SwipeView`: AppKit, UIKit, GTK 4, Android Views, and Web have no standalone swipe-action container.
- `WebView`: GTK 4 depends on WebKitGTK; Web cannot observe navigation or set a user agent in a cross-origin `<iframe>`.
- `Map` / `Pin`: Web has no map element; GTK 4, Android Views, and WinUI 3 depend on libshumate, Google Play services, and a map service.
- `ItemsView`: Android Views depends on AndroidX `RecyclerView`; Web has no native virtualized list.

## Shared state, patch, and motion capabilities

| Capability | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| sparse `HostRender` / `HostPatch` application | — | ✅ | — | — | — | — | — |
| stable element identity and arranged children | — | ✅ | — | — | — | — | — |
| driven state modes and typed channel kinds | — | ✅ | — | — | — | — | — |
| native input committed before handler dispatch | — | ✅ | — | — | — | — | — |
| silent application writes | — | ✅ | — | — | — | — | — |
| host-driven Journey interpolation with eased and spring motion | — | ✅ | — | — | — | — | — |
| host-driven Journey retargeting with standing velocity | — | ✅ | — | — | — | — | — |
| sparse property transitions through `HostPatch.transitions` | — | — | — | — | — | — | — |
| layout motion through `HostPatch.motion` and `MotionLanes` | — | — | — | — | — | — | — |
| Journey completion and interruption | — | ✅ | — | — | — | — | — |
| Journey stop and snap | — | — | — | — | — | — | — |
| StateUI display-cycle engines | — | — | — | — | — | — | — |
| element teardown releases external native attachments | — | ✅ | — | — | — | — | — |

## Standard environment

These rows record complete, live host mappings for StateUI's seven standard
environment domains. A host that only seeds some fields, does not keep changing
facts current, or lacks direct tests remains unmarked for that domain.

| Surface | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Battery` | `chargeLevel`, `state`, `powerSource`, `energySaverStatus` | — | — | — | — | — | — | — |
| `Connectivity` | `networkAccess`, `connectionProfiles` | — | — | — | — | — | — | — |
| `DeviceDisplay` | `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate` | — | — | — | — | — | — | — |
| `LocaleInfo` | `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric` | — | — | — | — | — | — | — |
| `DeviceInfo` | `formFactor`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `deviceType` | — | — | — | — | — | — | — |
| `AppInfo` | `name`, `packageName`, `versionString`, `buildString`, `requestedTheme` | — | — | — | — | — | — | — |
| `ApplicationSession` | `phase` | — | ✅ | — | — | — | — | — |

The public provider and its fallback values exist independently of a check
mark. [Environment](environment.md) defines that schema; this table says which
host supplies and maintains it completely.

## Host time services

Calendar values are portable StateUI values. Reading the current clock or time
zone is a host action because the host owns the active locale and zone database.

| Surface | Host act | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `ClockTime.now()` | `currentTime` | — | — | — | — | — | — | — |
| `TimeZoneInfo.local()` | `currentTimeZone` | — | — | — | — | — | — | — |
| `TimeZoneInfo.utcOffset(of:on:)` | `utcOffset` | — | — | — | — | — | — | — |

## Shared view members

These rows apply to every eligible control. A missing check means the shared
guarantee is not yet complete across all such AppKit controls even when an
individual control already uses that member.

| Member kind | StateUI members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| identity | `id` | — | ✅ | — | — | — | — | — |
| aimed control methods | `aim` | — | — | — | — | — | — | — |
| core reactions | `onCreated`, `onDestroying`, `onChanged`, `samples`, `engine` | — | — | — | — | — | — | — |
| motion selection | `motion`, `MotionValues`, `MotionLanes` | — | — | — | — | — | — | — |
| visibility and opacity | `isVisible`, `opacity` | — | — | — | — | — | — | — |
| background, a colour or a brush, on every view | `background` | — | — | — | — | — | — | — |
| enabled state on every eligible view | `isEnabled` | — | — | — | — | — | — | — |
| hit testing on every eligible view | `ignoresInput`, `letsInputThrough` | — | — | — | — | — | — | — |
| layout direction | `layoutDirection` | — | — | — | — | — | — | — |
| requested size | `width`, `height`, `minimumWidth`, `minimumHeight`, `maximumWidth`, `maximumHeight` | — | — | — | — | — | — | — |
| parent placement | `margin`, `horizontalAlignment`, `verticalAlignment` | — | — | — | — | — | — | — |
| drawing order | `zIndex` | — | — | — | — | — | — | — |
| planar transform | `rotation`, `scale`, `scaleX`, `scaleY`, `translationX`, `translationY` | — | — | — | — | — | — | — |
| spatial transform and pivot | `rotationX`, `rotationY`, `pivotX`, `pivotY` | — | — | — | — | — | — | — |
| accessibility | `accessibilityIdentifier`, `isAccessibilityHidden`, `automationExcludedWithChildren`, `accessibilityLabel`, `accessibilityHint`, `accessibilityHeadingLevel` | — | ✅ | — | — | — | — | — |
| frame feed/event | `frame`, `frameChanged` | — | ✅ | — | — | — | — | — |
| focus feed and event | `isFocused`, `isFocusedChanged` | — | — | — | — | — | — | — |
| tap | `tapCount`, `onTapped` (`tapped`) | — | ✅ | — | — | — | — | — |
| swipe gesture | `swipeDirection`, `swipeThreshold`, `onSwiped` (`swiped`) | — | ✅ | — | — | — | — | — |
| pan and pinch | `panXChannel`, `panYChannel`, `panTouchCount`, `onPanUpdated` (`panUpdated`), `onPinchUpdated` (`pinchUpdated`) | — | ✅ | — | — | — | — | — |
| pointer | `onPointerEntered` (`pointerEntered`), `onPointerExited` (`pointerExited`), `onPointerMoved` (`pointerMoved`), `onPointerPressed` (`pointerPressed`), `onPointerReleased` (`pointerReleased`) | — | ✅ | — | — | — | — | — |
| drag and drop | `canDrag`, `allowDrop`, `dragText`, `dragStarting`, `onDropCompleted` (`dropCompleted`), `onDrop` (`drop`), `onDragOver` (`dragOver`), `onDragLeave` (`dragLeave`) | — | — | — | — | — | — | — |

## Control dictionary

Every control, and every part an application, its windows and its pages are made of, has its members in [the control dictionary](controls/README.md): one row per property and handler, with a mark per platform. The counts below are taken from its files.

<!-- dictionary:begin -->
| Control | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Label](controls/Label.md) | 78 |  | 34 ✅ · 2 ✅* |  |  |  |  |  |
| [Button](controls/Button.md) | 83 |  | 32 ✅ · 2 ✅* |  |  |  |  |  |
| [TextField](controls/TextField.md) | 87 |  | 37 ✅ · 2 ✅* |  |  |  |  |  |
| [TextEditor](controls/TextEditor.md) | 84 |  | 36 ✅ · 2 ✅* |  |  |  |  |  |
| [SearchField](controls/SearchField.md) | 86 |  | 36 ✅ · 2 ✅* |  |  |  |  |  |
| [Image](controls/Image.md) | 65 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Picker](controls/Picker.md) | 79 |  | 28 ✅ · 2 ✅* |  |  |  |  |  |
| [DatePicker](controls/DatePicker.md) | 77 |  | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [TimePicker](controls/TimePicker.md) | 75 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Switch](controls/Switch.md) | 66 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [CheckBox](controls/CheckBox.md) | 66 |  | 23 ✅ · 2 ✅* |  |  |  |  |  |
| [RadioButton](controls/RadioButton.md) | 78 |  | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [Slider](controls/Slider.md) | 70 |  | 27 ✅ · 2 ✅* |  |  |  |  |  |
| [Stepper](controls/Stepper.md) | 68 |  | 25 ✅ · 2 ✅* |  |  |  |  |  |
| [ActivityIndicator](controls/ActivityIndicator.md) | 65 |  | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [ProgressBar](controls/ProgressBar.md) | 65 |  | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [ColorBox](controls/ColorBox.md) | 65 |  | 22 ✅ · 1 ✅* |  |  |  |  |  |
| [Border](controls/Border.md) | 72 |  | 21 ✅ · 1 ✅* |  |  |  |  |  |
| [PositionIndicator](controls/PositionIndicator.md) | 71 |  |  |  |  |  |  |  |
| [VStack](controls/VStack.md) | 68 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [HStack](controls/HStack.md) | 68 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Grid](controls/Grid.md) | 71 |  | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [AbsoluteLayout](controls/AbsoluteLayout.md) | 67 |  | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [ScrollView](controls/ScrollView.md) | 68 |  | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [RefreshView](controls/RefreshView.md) | 67 |  |  |  |  |  |  |  |
| [SwipeView](controls/SwipeView.md) | 68 |  |  |  |  |  |  |  |
| [Map](controls/Map.md) | 75 |  |  |  |  |  |  |  |
| [WebView](controls/WebView.md) | 70 |  |  |  |  |  |  |  |
| [TitleBar](controls/TitleBar.md) | 66 |  | 23 ✅ · 2 ✅* |  |  |  |  |  |
| [Canvas](controls/Canvas.md) | 64 |  | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [Rectangle](controls/Rectangle.md) | 74 |  | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [Ellipse](controls/Ellipse.md) | 73 |  | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [Line](controls/Line.md) | 77 |  | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [Path](controls/Path.md) | 74 |  | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [Polygon](controls/Polygon.md) | 75 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Polyline](controls/Polyline.md) | 75 |  | 22 ✅ · 2 ✅* |  |  |  |  |  |

| Part | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Scene](controls/Scene.md) | 6 |  | 6 ✅ |  |  |  |  |  |
| [Window](controls/Window.md) | 22 |  | 22 ✅ |  |  |  |  |  |
| [Page](controls/Page.md) | 12 |  | 12 ✅ |  |  |  |  |  |
| [NavigationStack](controls/NavigationStack.md) | 6 |  | 3 ✅ |  |  |  |  |  |
| [TabbedView](controls/TabbedView.md) | 6 |  | 3 ✅ |  |  |  |  |  |
| [SplitView](controls/SplitView.md) | 4 |  | 1 ✅ |  |  |  |  |  |
| [ToolbarItem](controls/ToolbarItem.md) | 8 |  | 7 ✅ |  |  |  |  |  |
| [Menu](controls/Menu.md) | 1 |  |  |  |  |  |  |  |
| [MenuItem](controls/MenuItem.md) | 6 |  | 5 ✅ |  |  |  |  |  |
<!-- dictionary:end -->

## Control properties and handlers

Each row is part of the common StateUI contract. Property names are modifier
names; a handler shows its public `on…` spelling followed by the host event
token in parentheses.

| Surface | Kind | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Application` / `Scene` / `Window` | sessions | multiple scenes, owned windows, restoration, focus, close | — | ✅ | — | — | — | — | — |
| `Window` | properties | `title`, `x`, `y`, `width`, `height`, `minimumWidth`, `minimumHeight`, `maximumWidth`, `maximumHeight`, `isMaximizable`, `isMinimizable` | — | ✅ | — | — | — | — | — |
| `WindowGroup` / `Window` | session metadata | `windowType`, `windowValue`, `hidesWhenInactive`, `floatsOnTop` | — | ✅ | — | — | — | — | — |
| `Window` | handlers | `created`, `activated`, `deactivated`, `stopped`, `resumed`, `destroying` | — | ✅ | — | — | — | — | — |
| `Scene` | handlers | `activated`, `deactivated`, `stopped`, `destroying`, `windowClosed`, `windowRestored` | — | ✅ | — | — | — | — | — |
| `Page` | properties | `title`, `icon`, `padding`, `background`, `backButtonTitle`, `hasBackButton`, `hasNavigationBar`, `titleView`, toolbar and menu slots | — | ✅ | — | — | — | — | — |
| `Page` | handlers | `appearing`, `disappearing`, `navigatingFrom`, `navigatedFrom`, `navigatedTo` | — | ✅ | — | — | — | — | — |
| `NavigationStack` | state | bound path and committed native back (`popped`) | — | ✅ | — | — | — | — | — |
| `NavigationStack` | properties | `barBackgroundColor` | — | ✅ | — | — | — | — | — |
| `NavigationStack` | properties | `barForegroundColor` | — | ✅ | — | — | — | — | — |
| `TabbedView` | state/events | bound `currentPage` (`currentPageChanged`) | — | ✅ | — | — | — | — | — |
| `TabbedView` | properties | `barBackgroundColor`; native selected/unselected appearance | — | ✅ | — | — | — | — | — |
| `SplitView` | state/events | bound `isSidebarVisible` (`isSidebarVisibleChanged`) | — | ✅ | — | — | — | — | — |
| `SplitView` | native presentation | adaptive native pane and native platform affordances | — | ✅ | — | — | — | — | — |
| `ModalStack` | state/events | bound modal stack (`modalPopped`) | — | ✅ | — | — | — | — | — |
| menu items | properties | `text`, `icon`, `isDestructive`, `isEnabled` | — | ✅ | — | — | — | — | — |
| toolbar items | properties | `text`, `icon`, `isDestructive`, `isEnabled`, `placement`, `priority` | — | ✅ | — | — | — | — | — |
| menu / toolbar items | handlers | `onClicked` (`clicked`) | — | ✅ | — | — | — | — | — |
| `TitleBar` | properties/slots | `title`, `subtitle`, `icon`, `barForegroundColor`, `background`, leading/content/trailing slots | — | ✅ | — | — | — | — | — |
| stack layouts | properties | `padding`, `spacing` | — | ✅ | — | — | — | — | — |
| `Grid` | properties | `rows`, `columns`, `rowSpacing`, `columnSpacing`, child `gridRow`, `gridColumn`, `gridRowSpan`, `gridColumnSpan` | — | — | — | — | — | — | — |
| `AbsoluteLayout` | properties | child `absoluteLayoutBounds`, `absoluteLayoutProportions` | — | — | — | — | — | — | — |
| layouts | properties | `clipsContent`, `avoidsSafeArea` | — | — | — | — | — | — | — |
| `ScrollView` | properties | `orientation`, `verticalScrollBarVisibility`, `horizontalScrollBarVisibility`, `scrollOffset` | — | ✅ | — | — | — | — | — |
| `ScrollView` | events | `scrollXChanged`, `scrollYChanged`, `onScrollStopped` (`scrollStopped`) | — | ✅ | — | — | — | — | — |
| `Border` | properties | `stroke`, `strokeWidth`, `shape`, `background` | — | — | — | — | — | — | — |
| `Border` | properties | `strokeDashPattern`, `strokeDashOffset`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit` | — | — | — | — | — | — | — |
| `Label` / `TextSpan` | properties | `text`, `textColor`, `characterSpacing`, `textCase`, `fontSize`, `fontFamily`, `fontAttributes`, `lineBreak`, `lineHeight`, `maximumLines`, `textDecorations`, `spans` | — | ✅ | — | — | — | — | — |
| `Label` | properties | `horizontalTextAlignment`, `verticalTextAlignment`, `padding` | — | ✅ | — | — | — | — | — |
| `Button` | properties | `text`, `icon`, `iconPosition`, `aspect`, `lineBreak`, `padding`, `borderColor`, `borderWidth`, `cornerRadius` | — | ✅ | — | — | — | — | — |
| `Button` | properties | `iconSpacing` | — | — | — | — | — | — | — |
| `Button` | handlers | `onClicked` (`clicked`), `onPressed` (`pressed`), `onReleased` (`released`) | — | ✅ | — | — | — | — | — |
| `Image` | properties | `source`, `aspect`, `isAnimating` | — | ✅ | — | — | — | — | — |
| `ColorBox` | properties | `color`, `cornerRadius` | — | ✅ | — | — | — | — | — |
| text inputs | properties | two-way `text`, `placeholder`, `placeholderColor`, `textColor`, `fontSize`, `fontFamily`, `fontAttributes`, `horizontalTextAlignment`, `isReadOnly`, `maximumLength`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `cursorPosition`, `selectionLength` | — | ✅ | — | — | — | — | — |
| text inputs | properties | `inputPurpose`, `verticalTextAlignment`, `characterSpacing`, `textCase`, `fontAutoScalingEnabled` | — | — | — | — | — | — | — |
| text inputs | handlers | `onTextChanged` (`textChanged`) | — | ✅ | — | — | — | — | — |
| `TextField` | properties | `isPassword` | — | ✅ | — | — | — | — | — |
| `TextField` | properties | `returnKey`, `showsClearButton` | — | — | — | — | — | — | — |
| `TextField` | handlers | `onSubmitted` (`submitted`) | — | ✅ | — | — | — | — | — |
| `TextEditor` | properties | `growsWithText` | — | ✅ | — | — | — | — | — |
| `SearchField` | properties | `returnKey`, `tint` | — | — | — | — | — | — | — |
| `SearchField` | handlers | `onSubmitted` (`submitted`) | — | ✅ | — | — | — | — | — |
| `Picker` | properties | `options`, `selectedIndex`, `title`, `tint`, `isOpen` | — | ✅ | — | — | — | — | — |
| `Picker` | handlers | `onSelectedIndexChanged` (`selectedIndexChanged`), `onOpened` (`opened`), `onClosed` (`closed`) | — | ✅ | — | — | — | — | — |
| `DatePicker` | properties | `date`, `minimumDate`, `maximumDate` | — | ✅ | — | — | — | — | — |
| `DatePicker` | properties | `format`, `isOpen` | — | — | — | — | — | — | — |
| `DatePicker` | handlers | `onDateChanged` (`dateChanged`) | — | ✅ | — | — | — | — | — |
| `DatePicker` | handlers | `onOpened` (`opened`), `onClosed` (`closed`) | — | — | — | — | — | — | — |
| `TimePicker` | properties | `time` | — | ✅ | — | — | — | — | — |
| `TimePicker` | properties | `format`, `isOpen` | — | — | — | — | — | — | — |
| `TimePicker` | handlers | `onTimeChanged` (`timeChanged`) | — | ✅ | — | — | — | — | — |
| `TimePicker` | handlers | `onOpened` (`opened`), `onClosed` (`closed`) | — | — | — | — | — | — | — |
| `Switch` | properties/events | two-way `isOn`, `onToggled` (`toggled`) | — | ✅ | — | — | — | — | — |
| `Switch` | properties | `tint` | — | — | — | — | — | — | — |
| `CheckBox` | properties/events | two-way `isOn`, `tint`, `onToggled` (`toggled`) | — | ✅ | — | — | — | — | — |
| `RadioButton` | properties/events | `text`, two-way `isOn`, `groupName`, `onToggled` (`toggled`) | — | ✅ | — | — | — | — | — |
| `Slider` | properties | two-way `value`, `minimum`, `maximum`, `tint` | — | ✅ | — | — | — | — | — |
| `Slider` | handlers | `onValueChanged` (`valueChanged`), `onDragStarted` (`dragStarted`), `onDragCompleted` (`dragCompleted`) | — | ✅ | — | — | — | — | — |
| `Stepper` | properties/events | two-way `value`, `minimum`, `maximum`, `step`, `onValueChanged` (`valueChanged`) | — | ✅ | — | — | — | — | — |
| `ProgressBar` | properties | `progress` | — | ✅ | — | — | — | — | — |
| `ProgressBar` | properties | `tint` | — | — | — | — | — | — | — |
| `ActivityIndicator` | properties | `isRunning` | — | ✅ | — | — | — | — | — |
| `ActivityIndicator` | properties | `tint` | — | — | — | — | — | — | — |
| `Canvas` | properties/events | `drawable`, `onPressed` (`pressed`), `onDragged` (`dragged`), `onReleased` (`released`) | — | ✅ | — | — | — | — | — |
| shapes | properties | `fill`, `stroke`, `strokeWidth`, `strokeDashPattern`, `strokeDashOffset`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit`, `aspect`, `renderTransform` | — | — | — | — | — | — | — |
| `Rectangle` | properties | `cornerRadius` | — | — | — | — | — | — | — |
| `Line` | properties | `x1`, `y1`, `x2`, `y2` | — | ✅ | — | — | — | — | — |
| `Path` | properties | `data` | — | ✅ | — | — | — | — | — |
| `Polygon` / `Polyline` | properties | `points`, `fillRule` | — | ✅ | — | — | — | — | — |
| `PositionIndicator` | properties | `count`, `position`, `indicatorColor`, `selectedIndicatorColor`, `indicatorSize`, `maximumVisible`, `indicatorsShape`, `hideSingle` | — | — | — | — | — | — | — |
| `RefreshView` | properties/events | two-way `isRefreshing`, `isRefreshEnabled`, `tint`, `onRefreshRequested` (`refreshRequested`) | — | — | — | — | — | — | — |
| `SwipeView` | properties/events | `threshold`, item `side`, `swipeBehaviorOnInvoked`, `onSwipeStarted` (`swipeStarted`), `onSwipeChanging` (`swipeChanging`), `onSwipeEnded` (`swipeEnded`) | — | — | — | — | — | — | — |
| `SwipeAction` | properties/events | `text`, `icon`, `background`, `isDestructive`, `isEnabled`, `isVisible`, `onClicked` (`clicked`) | — | — | — | — | — | — | — |
| `RefreshView` | state event | `isRefreshingChanged` | — | — | — | — | — | — | — |
| `WebView` | properties/events | `source`, `userAgent`, `canGoBackChanged`, `canGoForwardChanged` | — | — | — | — | — | — | — |
| `WebView` | handlers | `onNavigating` (`navigating`), `onNavigated` (`navigated`), `onProcessTerminated` (`processTerminated`) | — | — | — | — | — | — | — |
| `Map` / `Pin` | provider properties | `region`, `mapType`, `isScrollEnabled`, `isZoomEnabled`, `isTrafficEnabled`, `showsUserLocation`, pin `label`, `address`, `location`, `type` | — | — | — | — | — | — | — |
| `Map` / `Pin` | provider handlers | `mapClicked`, `pinClicked`, `pinDetailsClicked` | — | — | — | — | — | — | — |
| host metadata | structural/adaptive | `content`, `group`, `mode`, `name`, `style`, `isOpaque`, `scrollStep`, `textType`, `visualStateChanged` | — | — | — | — | — | — | — |

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

`AbsoluteLayout`, `ActivityIndicator`, `Application`, `Border`, `Button`,
`Canvas`, `CheckBox`, `ColorBox`, `Composed`, `Content`, `ContextMenu`,
`DatePicker`, `Ellipse`, `Grid`, `HStack`, `Image`, `Label`, `LeadingContent`,
`Line`, `Map`, `Menu`, `MenuBar`, `MenuItem`, `MenuSeparator`, `ModalStack`,
`NavigationStack`, `Overlay`, `Page`, `Path`, `Picker`, `Pin`, `Polygon`,
`Polyline`, `PositionIndicator`, `ProgressBar`, `RadioButton`, `Rectangle`,
`RefreshView`, `Scene`, `ScrollView`, `SearchField`, `Setters`, `Slider`,
`Span`, `Spans`, `SplitView`, `Stepper`, `SwipeAction`, `SwipeActions`,
`SwipeView`, `Switch`, `TabbedView`, `TextEditor`, `TextField`, `TimePicker`,
`TitleBar`, `TitleView`, `ToolbarItem`, `ToolbarItems`, `TrailingContent`,
`VisualState`, `VStack`, `WebView`, `Window`.

### Properties

`absoluteLayoutBounds`, `absoluteLayoutProportions`,
`accessibilityHeadingLevel`, `accessibilityHint`, `accessibilityIdentifier`,
`accessibilityLabel`, `address`, `allowDrop`, `aspect`,
`automationExcludedWithChildren`, `avoidsSafeArea`, `backButtonTitle`,
`background`, `barBackgroundColor`, `barForegroundColor`, `borderColor`,
`borderWidth`, `canDrag`, `characterSpacing`, `clipsContent`, `color`,
`columns`, `columnSpacing`, `content`, `cornerRadius`, `count`, `currentPage`,
`cursorPosition`, `data`, `date`, `dragText`, `drawable`, `fill`, `fillRule`,
`floatsOnTop`, `fontAttributes`, `fontAutoScalingEnabled`, `fontFamily`,
`fontSize`, `format`, `frame`, `gridColumn`, `gridColumnSpan`, `gridRow`,
`gridRowSpan`, `group`, `groupName`, `growsWithText`, `hasBackButton`,
`hasNavigationBar`, `height`, `hideSingle`, `hidesWhenInactive`,
`horizontalAlignment`, `horizontalScrollBarVisibility`,
`horizontalTextAlignment`, `icon`, `iconPosition`, `iconSpacing`,
`ignoresInput`, `indicatorColor`, `indicatorSize`, `indicatorsShape`,
`inputPurpose`, `isAccessibilityHidden`, `isAnimating`, `isDestructive`,
`isEnabled`, `isMaximizable`, `isMinimizable`, `isOn`, `isOpaque`, `isOpen`,
`isPassword`, `isReadOnly`, `isRefreshEnabled`, `isRefreshing`, `isRunning`,
`isScrollEnabled`, `isSidebarVisible`, `isSpellCheckEnabled`,
`isTextPredictionEnabled`, `isTrafficEnabled`, `isVisible`, `isZoomEnabled`,
`label`, `layoutDirection`, `letsInputThrough`, `lineBreak`, `lineHeight`,
`location`, `mapType`, `margin`, `maximum`, `maximumDate`, `maximumHeight`,
`maximumLength`, `maximumLines`, `maximumVisible`, `maximumWidth`, `minimum`,
`minimumDate`, `minimumHeight`, `minimumWidth`, `mode`, `name`, `opacity`,
`options`, `orientation`, `padding`, `panTouchCount`, `panXChannel`,
`panYChannel`, `pivotX`, `pivotY`, `placeholder`, `placeholderColor`,
`placement`, `points`, `position`, `priority`, `progress`, `region`,
`renderTransform`, `returnKey`, `rotation`, `rotationX`, `rotationY`, `rows`,
`rowSpacing`, `scale`, `scaleX`, `scaleY`, `scrollOffset`,
`scrollStep`, `selectedIndex`, `selectedIndicatorColor`, `selectionLength`,
`shape`, `showsClearButton`, `showsUserLocation`, `side`,
`source`, `spacing`, `step`, `stroke`,
`strokeDashOffset`, `strokeDashPattern`, `strokeLineCap`, `strokeLineJoin`,
`strokeMiterLimit`, `strokeWidth`, `style`, `subtitle`,
`swipeBehaviorOnInvoked`, `swipeDirection`, `swipeThreshold`, `tapCount`,
`text`, `textCase`, `textColor`, `textDecorations`, `textType`, `threshold`,
`time`, `tint`, `title`, `translationX`, `translationY`, `type`, `userAgent`,
`value`, `verticalAlignment`, `verticalScrollBarVisibility`,
`verticalTextAlignment`, `width`, `windowType`, `windowValue`, `x`, `x1`, `x2`,
`y`, `y1`, `y2`, `zIndex`.

### Events

`activated`, `appearing`, `canGoBackChanged`, `canGoForwardChanged`, `clicked`,
`closed`, `created`, `currentPageChanged`, `dateChanged`, `deactivated`,
`destroying`, `disappearing`, `dragCompleted`, `dragged`, `dragLeave`,
`dragOver`, `dragStarted`, `dragStarting`, `drop`, `dropCompleted`,
`frameChanged`, `isFocusedChanged`, `isRefreshingChanged`,
`isSidebarVisibleChanged`, `mapClicked`, `modalPopped`, `navigated`,
`navigatedFrom`, `navigatedTo`, `navigating`, `navigatingFrom`, `opened`,
`panUpdated`, `pinchUpdated`, `pinClicked`, `pinDetailsClicked`,
`pointerEntered`, `pointerExited`, `pointerMoved`, `pointerPressed`,
`pointerReleased`, `popped`, `pressed`, `processTerminated`,
`refreshRequested`, `released`, `resumed`, `scrollStopped`, `scrollXChanged`,
`scrollYChanged`, `selectedIndexChanged`, `stopped`,
`submitted`, `swipeChanging`, `swiped`, `swipeEnded`, `swipeStarted`, `tapped`,
`textChanged`, `timeChanged`, `toggled`, `valueChanged`, `visualStateChanged`,
`windowClosed`, `windowRestored`.
