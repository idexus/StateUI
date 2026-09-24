# Platform contract

This document is the shared delivery contract for StateUI's hosts: AppKit,
UIKit, GTK 4, Android Views, WinUI 3, and Web DOM/CSS. It records the StateUI
surface and the implementation evidence for each host.

## Reading the matrix

- ✅ means the member is implemented by that host and exercised by its host
  test suite.
- ☑️ means the member is implemented and tested but incomplete; the
  element's page in [the control dictionary](controls/README.md) names what is
  missing.
- An empty cell means the implementation is absent, incomplete, or not yet
  verified. It is deliberately not an estimate of how difficult the work will
  be.
- An element's ✅ under [Control creation](#control-creation) means the host
  recognizes and tests the node. Native and adaptive nodes create and retain
  their platform surface; structural nodes are interpreted without inventing a
  platform control. It does not imply that every member has been completed;
  the member rows state that separately.
- A row naming several members receives ✅ only when every one is
  implemented, and ☑️ when every one is implemented and some only in part. A
  tier's member is counted on every element wearing the tier that the host
  realizes, and under [Shared view members](#shared-view-members) on every
  view; an element the host presents with no view of its own is left out.

Member by member and element by element, the marks live in [the control
dictionary](controls/README.md). Every table of marks here that a contract can
say is rendered from the contracts and from each host's declaration of what it
realizes, as the dictionary is: `STATEUI_UPDATE_DOCS=1 swift test --filter
ControlDictionaryTests` writes them, and the test fails while one differs. The
capabilities, the standard environment and the core view members name no
contract member and are written by hand.

The matrix describes observable StateUI semantics. Platform classes are
implementation details. A host may choose another native class when it
preserves the same state, event, accessibility, lifetime, and motion contract.

## Target hosts

| Platform | Runtime | Boundary | Native toolkit |
| --- | --- | --- | --- |
| macOS | Swift | typed `HostPatch` | AppKit |
| iOS and iPadOS | Swift | typed `HostPatch` | UIKit |
| Linux desktop | Swift with the C API | typed `HostPatch` | GTK 4 |
| Android | Swift with JNI | typed `HostPatch` | Android Views |
| Windows | Swift with C++/WinRT behind a C ABI | typed `HostPatch` | WinUI 3 |
| Browser | Swift compiled to WebAssembly, under a JavaScript relay | typed `HostPatch` | DOM and CSS |

Every host is Swift in the application's process. Code in a platform's own
language - Java, C++/WinRT, JavaScript - relays calls beneath it and holds no
StateUI logic.

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

Every element contract, with the layer that realizes it and a ✅ for each
host that creates or interprets it.

<!-- creation:begin -->
| Element | Layer | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `ActivityIndicator` | native | ✅ |  |  | ✅ |  |  |
| `Application` | structure | ✅ |  |  | ✅ |  |  |
| `Border` | native | ✅ |  |  | ✅ |  |  |
| `Button` | native | ✅ |  |  | ✅ |  |  |
| `Canvas` | native | ✅ |  |  | ✅ |  |  |
| `CheckBox` | stateUI | ✅ |  |  | ✅ |  |  |
| `ColorBox` | native | ✅ |  |  | ✅ |  |  |
| `Content` | structure | ✅ |  |  |  |  |  |
| `ContextMenu` | structure | ✅ |  |  | ✅ |  |  |
| `DatePicker` | native | ✅ |  |  | ✅ |  |  |
| `Ellipse` | stateUI | ✅ |  |  | ✅ |  |  |
| `Grid` | stateUI | ✅ |  |  | ✅ |  |  |
| `HStack` | native | ✅ |  |  | ✅ |  |  |
| `Image` | native | ✅ |  |  | ✅ |  |  |
| `Label` | native | ✅ |  |  | ✅ |  |  |
| `LeadingContent` | structure | ✅ |  |  |  |  |  |
| `Line` | stateUI | ✅ |  |  | ✅ |  |  |
| `Map` | provider |  |  |  |  |  |  |
| `Menu` | structure | ✅ |  |  | ✅ |  |  |
| `MenuBar` | structure | ✅ |  |  |  |  |  |
| `MenuItem` | structure | ✅ |  |  | ✅ |  |  |
| `MenuSeparator` | structure | ✅ |  |  | ✅ |  |  |
| `ModalStack` | structure | ✅ |  |  | ✅ |  |  |
| `NavigationStack` | adaptive | ✅ |  |  | ✅ |  |  |
| `Overlay` | structure | ✅ |  |  | ✅ |  |  |
| `Page` | adaptive | ✅ |  |  | ✅ |  |  |
| `Path` | stateUI | ✅ |  |  | ✅ |  |  |
| `Picker` | native | ✅ |  |  | ✅ |  |  |
| `Pin` | provider |  |  |  |  |  |  |
| `Polygon` | stateUI | ✅ |  |  | ✅ |  |  |
| `Polyline` | stateUI | ✅ |  |  | ✅ |  |  |
| `PositionIndicator` | stateUI |  |  |  |  |  |  |
| `ProgressBar` | native | ✅ |  |  | ✅ |  |  |
| `RadioButton` | stateUI | ✅ |  |  | ✅ |  |  |
| `Rectangle` | stateUI | ✅ |  |  | ✅ |  |  |
| `Scene` | structure | ✅ |  |  | ✅ |  |  |
| `ScrollView` | native | ✅ |  |  | ✅ |  |  |
| `SearchField` | native | ✅ |  |  | ✅ |  |  |
| `Setters` | structure |  |  |  |  |  |  |
| `Slider` | native | ✅ |  |  | ✅ |  |  |
| `Span` | structure | ✅ |  |  | ✅ |  |  |
| `Spans` | structure | ✅ |  |  | ✅ |  |  |
| `SplitView` | adaptive | ✅ |  |  | ✅ |  |  |
| `Stepper` | native | ✅ |  |  | ✅ |  |  |
| `Switch` | native | ✅ |  |  | ✅ |  |  |
| `TabbedView` | adaptive | ✅ |  |  | ✅ |  |  |
| `TextEditor` | native | ✅ |  |  | ✅ |  |  |
| `TextField` | native | ✅ |  |  | ✅ |  |  |
| `TimePicker` | native | ✅ |  |  | ✅ |  |  |
| `TitleBar` | adaptive | ✅ |  |  |  |  |  |
| `TitleView` | structure | ✅ |  |  | ✅ |  |  |
| `ToolbarItem` | structure | ✅ |  |  | ✅ |  |  |
| `ToolbarItems` | structure | ✅ |  |  | ✅ |  |  |
| `TrailingContent` | structure | ✅ |  |  |  |  |  |
| `VStack` | native | ✅ |  |  | ✅ |  |  |
| `VisualState` | structure |  |  |  |  |  |  |
| `WebView` | native |  |  |  | ✅ |  |  |
| `Window` | structure | ✅ |  |  | ✅ |  |  |
| `ZStack` | native | ✅ |  |  | ✅ |  |  |
<!-- creation:end -->

The AppKit split view uses `NSSplitViewController`.

Page arrangements expose an optional flat `barBackgroundColor`. A
`NavigationStack` additionally exposes `barForegroundColor` for its title and native
action affordances. A tab selector keeps the toolkit's selected and unselected
appearance. An unwritten background retains the native material; StateUI does
not ask a host to rasterize an arbitrary brush into page chrome.

On AppKit a written bar colour paints the band the title bar and toolbar cover
over the visible content - a split view's detail - and the window's
background, which shows around a floating sidebar and through its glass; an
authored `TitleBar`'s `background` paints both where no arrangement writes
one. On a translucent window the colour tints the window's material
instead, which the band, the margin around the sidebar and its glass all
show. Text on a painted band is the bar's: the page's title
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
it only after that entire surface works through its native items control.

`ForEach`, `FrameReader`, `ScrollReader`, `PlacedLayout`, and `GalleryView` are
StateUI compositions or readers rather than additional platform controls. The
core implements them once; their platform behavior depends only on the
primitive rows they use.

## Native control mapping

The table names the native class or API that each host adapts for a StateUI
surface. It records no implementation status; the ✅ tables keep that. Where a
host already creates a node, its column names the class it uses.
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
| `ContextMenu`, `MenuBar`, `Menu`, `MenuItem`, `MenuSeparator` | `NSMenu` / `NSMenuItem` | `UIMenu` / `UIAction` | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | `PopupMenu` / `MenuItem`; no menu bar | `MenuFlyout` / `MenuBar` | ARIA `menu` / `menubar` (?) |
| `ToolbarItems` / `ToolbarItem` | `NSToolbarItem`; `NSMenuToolbarItem` overflow | `UIBarButtonItem` | `GtkButton` in `GtkHeaderBar` | `Toolbar` `MenuItem` | `CommandBar` `AppBarButton` | `<button>` in an ARIA `toolbar` |
| `ZStack` | custom `NSView` | custom `UIView` | `GtkFixed` | custom `ViewGroup` | `Canvas` | `position: absolute` |
| `VStack` / `HStack` | custom `NSView` | custom `UIView` | `GtkBox` | custom `ViewGroup` | `StackPanel` | flexbox |
| `Grid` | custom `NSView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `ScrollView` | `NSScrollView` | `UIScrollView` | `GtkScrolledWindow` | `ScrollView` / `HorizontalScrollView` | `ScrollViewer` | `overflow: auto` |
| `Border` | custom `NSView` drawing `NSBezierPath` | `UIView` + `CAShapeLayer` | custom `GtkWidget` snapshot | `FrameLayout` + `GradientDrawable` | `Border` | `<div>` + CSS `border` |
| `Label` / `Spans` / `Span` | `NSTextField` label; `NSAttributedString` runs | `UILabel`; `NSAttributedString` runs | `GtkLabel`; `PangoAttrList` runs | `TextView`; `SpannableString` spans | `TextBlock`; `Run` inlines | text element; `<span>` runs |
| `Button` | `NSButton` | `UIButton` | `GtkButton` | `Button` | `Button` | `<button>` |
| `Image` | `NSImageView` | `UIImageView` | `GtkPicture` | `ImageView` | `Image` | `<img>` |
| `ColorBox` | custom `NSView` drawing | `UIView` + `CALayer` | custom `GtkWidget` snapshot | `View` + `GradientDrawable` | `Border` | `<div>` |
| `TextField` | `NSTextField` / `NSSecureTextField` | `UITextField` | `GtkEntry` / `GtkPasswordEntry` | `EditText` | `TextBox` / `PasswordBox` | `<input>` |
| `TextEditor` | `NSTextView` in an `NSScrollView` | `UITextView` | `GtkTextView` | multi-line `EditText` | multi-line `TextBox` | `<textarea>` |
| `SearchField` | `NSSearchField` | `UISearchBar` | `GtkSearchEntry` | `SearchView` | `AutoSuggestBox` | `<input type=search>` |
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
| `Canvas` | custom `NSView` drawing | `UIView` `draw(_:)` | `GtkDrawingArea` | `View` `onDraw(Canvas)` | Win2D `CanvasControl` (?) | `<canvas>` |
| `Rectangle` / `Ellipse` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `Line` / `Path` / `Polygon` / `Polyline` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `GskPath` in a snapshot | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | inline SVG |
| `PositionIndicator` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `WebView` | `WKWebView` | `WKWebView` | WebKitGTK `WebKitWebView` | `WebView` | `WebView2` | `<iframe>` (?) |
| `Map` / `Pin` | `MKMapView` / `MKAnnotation` | `MKMapView` / `MKAnnotation` | libshumate `ShumateMap` / `ShumateMarker` | Google Play services `MapView` / `Marker` (?) | `MapControl` (?) | — |
| `ItemsView` | `NSCollectionView` / `NSTableView` | `UICollectionView` | `GtkListView` / `GtkGridView` | AndroidX `RecyclerView` | `ItemsView` | semantic list or grid |
| `Content`, `LeadingContent`, `TrailingContent`, `TitleView` | structure | structure | structure | structure | structure | structure |
| `Setters`, `VisualState` | structure | structure | structure | structure | structure | structure |

### Completeness

Every element contract appears exactly once in the first column, and
`ItemsView` adds one row without a node type of its own; each element's page
in the control dictionary takes its native counterparts from here, and
`ControlDictionaryTests` holds the table to that.

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
- `WebView`: GTK 4 depends on WebKitGTK; Web cannot observe navigation or set a user agent in a cross-origin `<iframe>`.
- `Map` / `Pin`: Web has no map element; GTK 4, Android Views, and WinUI 3 depend on libshumate, Google Play services, and a map service.
- `ItemsView`: Android Views depends on AndroidX `RecyclerView`; Web has no native virtualized list.

## Shared state, patch, and motion capabilities

| Capability | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| sparse `HostRender` / `HostPatch` application | ✅ |  |  |  |  |  |
| stable element identity and arranged children | ✅ |  |  |  |  |  |
| driven state modes and typed channel kinds | ✅ |  |  |  |  |  |
| native input committed before handler dispatch | ✅ |  |  |  |  |  |
| silent application writes | ✅ |  |  |  |  |  |
| host-driven Journey interpolation with eased and spring motion | ✅ |  |  |  |  |  |
| host-driven Journey retargeting with standing velocity | ✅ |  |  |  |  |  |
| sparse property transitions through `HostPatch.transitions` | ✅ |  |  |  |  |  |
| layout motion through `HostPatch.motion` and `MotionLanes` | ✅ |  |  |  |  |  |
| Journey completion and interruption | ✅ |  |  |  |  |  |
| Journey stop and snap |  |  |  |  |  |  |
| StateUI display-cycle engines |  |  |  |  |  |  |
| element teardown releases external native attachments | ✅ |  |  |  |  |  |

## Standard environment

These rows record complete, live host mappings for StateUI's seven standard
environment domains. A host that only seeds some fields, does not keep changing
facts current, or lacks direct tests remains unmarked for that domain.

| Surface | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `Battery` | `chargeLevel`, `state`, `powerSource`, `energySaverStatus` |  |  |  |  |  |  |
| `Connectivity` | `networkAccess`, `connectionProfiles` |  |  |  |  |  |  |
| `DeviceDisplay` | `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate` |  |  |  |  |  |  |
| `LocaleInfo` | `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric` |  |  |  |  |  |  |
| `DeviceInfo` | `formFactor`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `deviceType` |  |  |  |  |  |  |
| `AppInfo` | `name`, `packageName`, `versionString`, `buildString`, `requestedTheme` |  |  |  |  |  |  |
| `ApplicationSession` | `phase` | ✅ |  |  |  |  |  |

The public provider and its fallback values exist independently of a check
mark. [Environment](environment.md) defines that schema; this table says which
host supplies and maintains it completely.

## Host acts

An act is what the application asks a host to do rather than describes: ask
the user a question, read the clock or the time zone, keep a value, take a
web view back or move a map. An act of the application's contract aims at
nothing; an element's act aims at one element of its kind. Calendar values are
portable StateUI values; reading the current clock or time zone is a host act
because the host owns the active locale and zone database - `currentTime` is
`ClockTime.now()`, `currentTimeZone` is `TimeZoneInfo.local()`, and `utcOffset`
is `TimeZoneInfo.utcOffset(of:on:)`.

<!-- acts:begin -->
| Act | Contract | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `focus` | [VisualElement](controls/tiers/VisualElement.md) | ✅ |  |  | ✅ |  |  |
| `unfocus` | [VisualElement](controls/tiers/VisualElement.md) | ✅ |  |  | ✅ |  |  |
| `alert` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `announce` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `chooseAction` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `confirm` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `currentTime` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `currentTimeZone` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `handlerFailed` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `hideOnScreenKeyboard` | [Application](controls/Application.md) | ✅ |  |  | ✅ |  |  |
| `persistSceneValue` | [Application](controls/Application.md) | ✅ |  |  |  |  |  |
| `persistValue` | [Application](controls/Application.md) | ✅ |  |  | ✅ |  |  |
| `prompt` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `utcOffset` | [Application](controls/Application.md) |  |  |  | ✅ |  |  |
| `moveToRegion` | [Map](controls/Map.md) |  |  |  |  |  |  |
| `evaluateJavaScript` | [WebView](controls/WebView.md) |  |  |  | ✅ |  |  |
| `goBack` | [WebView](controls/WebView.md) |  |  |  | ✅ |  |  |
| `goForward` | [WebView](controls/WebView.md) |  |  |  | ✅ |  |  |
| `reload` | [WebView](controls/WebView.md) |  |  |  | ✅ |  |  |
<!-- acts:end -->

## Shared view members

A property or event of the three tiers every view wears -
[PropertyContainer](controls/tiers/PropertyContainer.md),
[VisualElement](controls/tiers/VisualElement.md) and
[View](controls/tiers/View.md) - is marked for a host only when every view
that host realizes with a view of its own has it, even where one control
already realizes it. The core view members come first: StateUI's own API,
which a host serves without a member of its own.

| Core view member | StateUI API | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| identity | `id` | ✅ |  |  |  |  |  |
| aimed control methods | `aim` |  |  |  |  |  |  |
| core reactions | `onCreated`, `onDestroying`, `onChanged`, `samples`, `engine` |  |  |  |  |  |  |
| motion selection | `motion`, `MotionValues`, `MotionLanes` |  |  |  |  |  |  |
| focus feed | `isFocused` | ✅ |  |  |  |  |  |

<!-- shared:begin -->
| Member | Tier | Kind | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `accessibilityIdentifier` | [PropertyContainer](controls/tiers/PropertyContainer.md) | property | ✅ |  |  | ✅ |  |  |
| `accessibilityHeadingLevel` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ☑️ |  |  |
| `accessibilityHint` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `accessibilityLabel` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `automationExcludedWithChildren` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `background` | [VisualElement](controls/tiers/VisualElement.md) | property | ☑️ |  |  | ✅ |  |  |
| `frame` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `height` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `ignoresInput` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  |  |  |  |
| `isAccessibilityHidden` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `isEnabled` | [VisualElement](controls/tiers/VisualElement.md) | property |  |  |  |  |  |  |
| `isFocusedChanged` | [VisualElement](controls/tiers/VisualElement.md) | event | ✅ |  |  | ✅ |  |  |
| `isVisible` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `layoutDirection` | [VisualElement](controls/tiers/VisualElement.md) | property |  |  |  |  |  |  |
| `maximumHeight` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `maximumWidth` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `minimumHeight` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `minimumWidth` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `opacity` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `pivotX` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `pivotY` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `rotation` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `rotationX` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `rotationY` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `scale` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `scaleX` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `scaleY` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `style` | [VisualElement](controls/tiers/VisualElement.md) | property |  |  |  |  |  |  |
| `translationX` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `translationY` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `onVisualStateChanged` (`visualStateChanged`) | [VisualElement](controls/tiers/VisualElement.md) | event |  |  |  |  |  |  |
| `width` | [VisualElement](controls/tiers/VisualElement.md) | property | ✅ |  |  | ✅ |  |  |
| `zIndex` | [VisualElement](controls/tiers/VisualElement.md) | property |  |  |  |  |  |  |
| `allowDrop` | [View](controls/tiers/View.md) | property |  |  |  |  |  |  |
| `area` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `canDrag` | [View](controls/tiers/View.md) | property |  |  |  |  |  |  |
| `onDragLeave` (`dragLeave`) | [View](controls/tiers/View.md) | event |  |  |  |  |  |  |
| `onDragOver` (`dragOver`) | [View](controls/tiers/View.md) | event |  |  |  |  |  |  |
| `dragStarting` | [View](controls/tiers/View.md) | event |  |  |  |  |  |  |
| `dragText` | [View](controls/tiers/View.md) | property |  |  |  |  |  |  |
| `onDrop` (`drop`) | [View](controls/tiers/View.md) | event |  |  |  |  |  |  |
| `onDropCompleted` (`dropCompleted`) | [View](controls/tiers/View.md) | event |  |  |  |  |  |  |
| `onFrameChanged` (`frameChanged`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `gridColumn` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `gridColumnSpan` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `gridRow` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `gridRowSpan` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `horizontalAlignment` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `margin` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `panTouchCount` | [View](controls/tiers/View.md) | property | ☑️ |  |  | ✅ |  |  |
| `onPanUpdated` (`panUpdated`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `panXChannel` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `panYChannel` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `onPinchUpdated` (`pinchUpdated`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `onPointerEntered` (`pointerEntered`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `onPointerExited` (`pointerExited`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `onPointerMoved` (`pointerMoved`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `onPointerPressed` (`pointerPressed`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `onPointerReleased` (`pointerReleased`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `swipeDirection` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `swipeThreshold` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `onSwiped` (`swiped`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `tapCount` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
| `onTapped` (`tapped`) | [View](controls/tiers/View.md) | event | ✅ |  |  | ✅ |  |  |
| `verticalAlignment` | [View](controls/tiers/View.md) | property | ✅ |  |  | ✅ |  |  |
<!-- shared:end -->

## Control dictionary

Every control, and every part an application, its windows and its pages are made of, has its members in [the control dictionary](controls/README.md): one row per property, event and act, with a mark per platform. The counts below are rendered with it.

<!-- dictionary:begin -->
### Controls

| Control | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](controls/ActivityIndicator.md) | 69 | 54 ✅ · 2 ☑️ |  |  | 54 ✅ · 1 ☑️ |  |  |
| [Border](controls/Border.md) | 76 | 56 ✅ · 2 ☑️ |  |  | 57 ✅ · 1 ☑️ |  |  |
| [Button](controls/Button.md) | 87 | 68 ✅ · 3 ☑️ |  |  | 70 ✅ · 2 ☑️ |  |  |
| [Canvas](controls/Canvas.md) | 71 | 56 ✅ · 2 ☑️ |  |  | 56 ✅ · 1 ☑️ |  |  |
| [CheckBox](controls/CheckBox.md) | 70 | 56 ✅ · 2 ☑️ |  |  | 56 ✅ · 1 ☑️ |  |  |
| [ColorBox](controls/ColorBox.md) | 69 | 54 ✅ · 2 ☑️ |  |  | 54 ✅ · 1 ☑️ |  |  |
| [DatePicker](controls/DatePicker.md) | 81 | 61 ✅ · 2 ☑️ |  |  | 65 ✅ · 1 ☑️ |  |  |
| [Ellipse](controls/Ellipse.md) | 77 | 61 ✅ · 3 ☑️ |  |  | 62 ✅ · 1 ☑️ |  |  |
| [Grid](controls/Grid.md) | 75 | 58 ✅ · 2 ☑️ |  |  | 58 ✅ · 1 ☑️ |  |  |
| [HStack](controls/HStack.md) | 72 | 55 ✅ · 2 ☑️ |  |  | 55 ✅ · 1 ☑️ |  |  |
| [Image](controls/Image.md) | 70 | 55 ✅ · 2 ☑️ |  |  | 54 ✅ · 1 ☑️ |  |  |
| [Label](controls/Label.md) | 82 | 66 ✅ · 2 ☑️ |  |  | 66 ✅ · 1 ☑️ |  |  |
| [Line](controls/Line.md) | 81 | 65 ✅ · 3 ☑️ |  |  | 66 ✅ · 1 ☑️ |  |  |
| [Map](controls/Map.md) | 75 |  |  |  |  |  |  |
| [Path](controls/Path.md) | 78 | 62 ✅ · 3 ☑️ |  |  | 63 ✅ · 1 ☑️ |  |  |
| [Picker](controls/Picker.md) | 83 | 66 ✅ · 2 ☑️ |  |  | 65 ✅ · 2 ☑️ |  |  |
| [Polygon](controls/Polygon.md) | 79 | 63 ✅ · 3 ☑️ |  |  | 64 ✅ · 1 ☑️ |  |  |
| [Polyline](controls/Polyline.md) | 79 | 63 ✅ · 3 ☑️ |  |  | 64 ✅ · 1 ☑️ |  |  |
| [PositionIndicator](controls/PositionIndicator.md) | 75 |  |  |  |  |  |  |
| [ProgressBar](controls/ProgressBar.md) | 69 | 54 ✅ · 2 ☑️ |  |  | 54 ✅ · 1 ☑️ |  |  |
| [RadioButton](controls/RadioButton.md) | 82 | 63 ✅ · 2 ☑️ |  |  | 63 ✅ · 1 ☑️ |  |  |
| [Rectangle](controls/Rectangle.md) | 78 | 62 ✅ · 3 ☑️ |  |  | 63 ✅ · 1 ☑️ |  |  |
| [ScrollView](controls/ScrollView.md) | 75 | 60 ✅ · 2 ☑️ |  |  | 60 ✅ · 1 ☑️ |  |  |
| [SearchField](controls/SearchField.md) | 90 | 70 ✅ · 2 ☑️ |  |  | 66 ✅ · 1 ☑️ |  |  |
| [Slider](controls/Slider.md) | 74 | 60 ✅ · 2 ☑️ |  |  | 60 ✅ · 1 ☑️ |  |  |
| [Stepper](controls/Stepper.md) | 72 | 58 ✅ · 2 ☑️ |  |  | 58 ✅ · 1 ☑️ |  |  |
| [Switch](controls/Switch.md) | 70 | 56 ✅ · 2 ☑️ |  |  | 55 ✅ · 1 ☑️ |  |  |
| [TextEditor](controls/TextEditor.md) | 88 | 69 ✅ · 2 ☑️ |  |  | 65 ✅ · 1 ☑️ |  |  |
| [TextField](controls/TextField.md) | 91 | 70 ✅ · 2 ☑️ |  |  | 67 ✅ · 1 ☑️ |  |  |
| [TimePicker](controls/TimePicker.md) | 79 | 59 ✅ · 2 ☑️ |  |  | 63 ✅ · 1 ☑️ |  |  |
| [TitleBar](controls/TitleBar.md) | 71 | 4 ✅ · 1 ☑️ |  |  |  |  |  |
| [VStack](controls/VStack.md) | 72 | 55 ✅ · 2 ☑️ |  |  | 55 ✅ · 1 ☑️ |  |  |
| [WebView](controls/WebView.md) | 78 |  |  |  | 63 ✅ · 1 ☑️ |  |  |
| [ZStack](controls/ZStack.md) | 71 | 53 ✅ · 2 ☑️ |  |  | 53 ✅ · 1 ☑️ |  |  |

### Application structure

| Part | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](controls/Application.md) | 12 | 3 ✅ |  |  | 11 ✅ |  |  |
| [Content](controls/Content.md) | 0 |  |  |  |  |  |  |
| [ContextMenu](controls/ContextMenu.md) | 0 |  |  |  |  |  |  |
| [LeadingContent](controls/LeadingContent.md) | 0 |  |  |  |  |  |  |
| [Menu](controls/Menu.md) | 2 | 2 ✅ |  |  | 2 ✅ |  |  |
| [MenuBar](controls/MenuBar.md) | 0 |  |  |  |  |  |  |
| [MenuItem](controls/MenuItem.md) | 6 | 5 ✅ · 1 ☑️ |  |  | 5 ✅ |  |  |
| [MenuSeparator](controls/MenuSeparator.md) | 0 |  |  |  |  |  |  |
| [ModalStack](controls/ModalStack.md) | 0 |  |  |  |  |  |  |
| [NavigationStack](controls/NavigationStack.md) | 6 | 6 ✅ |  |  | 6 ✅ |  |  |
| [Overlay](controls/Overlay.md) | 0 |  |  |  |  |  |  |
| [Page](controls/Page.md) | 12 | 12 ✅ |  |  | 11 ✅ |  |  |
| [Pin](controls/Pin.md) | 6 |  |  |  |  |  |  |
| [Scene](controls/Scene.md) | 6 | 6 ✅ |  |  | 4 ✅ |  |  |
| [Setters](controls/Setters.md) | 0 |  |  |  |  |  |  |
| [Span](controls/Span.md) | 12 | 3 ✅ |  |  | 2 ✅ |  |  |
| [Spans](controls/Spans.md) | 0 |  |  |  |  |  |  |
| [SplitView](controls/SplitView.md) | 5 | 5 ✅ |  |  | 4 ✅ |  |  |
| [TabbedView](controls/TabbedView.md) | 6 | 6 ✅ |  |  | 5 ✅ |  |  |
| [TitleView](controls/TitleView.md) | 0 |  |  |  |  |  |  |
| [ToolbarItem](controls/ToolbarItem.md) | 8 | 7 ✅ |  |  | 8 ✅ |  |  |
| [ToolbarItems](controls/ToolbarItems.md) | 0 |  |  |  |  |  |  |
| [TrailingContent](controls/TrailingContent.md) | 0 |  |  |  |  |  |  |
| [VisualState](controls/VisualState.md) | 2 |  |  |  |  |  |  |
| [Window](controls/Window.md) | 23 | 23 ✅ |  |  | 8 ✅ |  |  |
<!-- dictionary:end -->

## Contract members

A row per contract with properties or events - the tiers, then the elements -
naming them: a property by its modifier's name, an event with the `on…`
modifier it is heard through beside it. A contract's acts are under [Host
acts](#host-acts); each member's own mark, its value and its layer are on the
contract's page in [the control dictionary](controls/README.md).

<!-- members:begin -->
| Contract | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| [PropertyContainer](controls/tiers/PropertyContainer.md) | `accessibilityIdentifier` | ☑️ |  |  | ✅ |  |  |
| [VisualElement](controls/tiers/VisualElement.md) | `accessibilityHeadingLevel`, `accessibilityHint`, `accessibilityLabel`, `automationExcludedWithChildren`, `background`, `frame`, `height`, `ignoresInput`, `isAccessibilityHidden`, `isEnabled`, `isFocusedChanged`, `isVisible`, `layoutDirection`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `opacity`, `pivotX`, `pivotY`, `rotation`, `rotationX`, `rotationY`, `scale`, `scaleX`, `scaleY`, `style`, `translationX`, `translationY`, `onVisualStateChanged` (`visualStateChanged`), `width`, `zIndex` |  |  |  |  |  |  |
| [View](controls/tiers/View.md) | `allowDrop`, `area`, `canDrag`, `onDragLeave` (`dragLeave`), `onDragOver` (`dragOver`), `dragStarting`, `dragText`, `onDrop` (`drop`), `onDropCompleted` (`dropCompleted`), `onFrameChanged` (`frameChanged`), `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`, `horizontalAlignment`, `margin`, `panTouchCount`, `onPanUpdated` (`panUpdated`), `panXChannel`, `panYChannel`, `onPinchUpdated` (`pinchUpdated`), `onPointerEntered` (`pointerEntered`), `onPointerExited` (`pointerExited`), `onPointerMoved` (`pointerMoved`), `onPointerPressed` (`pointerPressed`), `onPointerReleased` (`pointerReleased`), `swipeDirection`, `swipeThreshold`, `onSwiped` (`swiped`), `tapCount`, `onTapped` (`tapped`), `verticalAlignment` |  |  |  |  |  |  |
| [Layout](controls/tiers/Layout.md) | `avoidsSafeArea`, `clipsContent`, `letsInputThrough` |  |  |  |  |  |  |
| [StackBase](controls/tiers/StackBase.md) | `spacing` | ✅ |  |  | ✅ |  |  |
| [InputView](controls/tiers/InputView.md) | `cursorPosition`, `inputPurpose`, `isReadOnly`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `maximumLength`, `placeholder`, `placeholderColor`, `selectionLength`, `onTextChanged` (`textChanged`) |  |  |  |  |  |  |
| [Shape](controls/tiers/Shape.md) | `aspect`, `fill`, `renderTransform`, `stroke`, `strokeDashOffset`, `strokeDashPattern`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit`, `strokeWidth` | ☑️ |  |  | ✅ |  |  |
| [TextElement](controls/tiers/TextElement.md) | `text`, `textCase` |  |  |  |  |  |  |
| [TextStyleElement](controls/tiers/TextStyleElement.md) | `characterSpacing`, `textColor` |  |  |  |  |  |  |
| [FontElement](controls/tiers/FontElement.md) | `fontAttributes`, `fontAutoScalingEnabled`, `fontFamily`, `fontSize` |  |  |  |  |  |  |
| [TextAlignmentElement](controls/tiers/TextAlignmentElement.md) | `horizontalTextAlignment`, `verticalTextAlignment` |  |  |  |  |  |  |
| [LineHeightElement](controls/tiers/LineHeightElement.md) | `lineHeight` | ✅ |  |  | ✅ |  |  |
| [DecorableTextElement](controls/tiers/DecorableTextElement.md) | `textDecorations` | ✅ |  |  | ✅ |  |  |
| [PaddingElement](controls/tiers/PaddingElement.md) | `padding` |  |  |  |  |  |  |
| [BorderElement](controls/tiers/BorderElement.md) | `borderColor`, `borderWidth`, `cornerRadius` |  |  |  |  |  |  |
| [ImageElement](controls/tiers/ImageElement.md) | `aspect` | ☑️ |  |  | ☑️ |  |  |
| [TintElement](controls/tiers/TintElement.md) | `tint` | ✅ |  |  |  |  |  |
| [BarElement](controls/tiers/BarElement.md) | `barBackgroundColor` | ✅ |  |  |  |  |  |
| [MenuItemElement](controls/tiers/MenuItemElement.md) | `onClicked` (`clicked`), `icon`, `isDestructive`, `isEnabled`, `text` |  |  |  |  |  |  |
| [PageElement](controls/tiers/PageElement.md) | `icon`, `title` | ✅ |  |  | ✅ |  |  |
| [ActivityIndicator](controls/ActivityIndicator.md) | `isRunning` | ✅ |  |  | ✅ |  |  |
| [Border](controls/Border.md) | `shape`, `stroke`, `strokeDashOffset`, `strokeDashPattern`, `strokeLineCap`, `strokeLineJoin`, `strokeMiterLimit`, `strokeWidth` |  |  |  |  |  |  |
| [Button](controls/Button.md) | `onClicked` (`clicked`), `icon`, `iconPosition`, `iconSpacing`, `lineBreak`, `onPressed` (`pressed`), `onReleased` (`released`) |  |  |  | ✅ |  |  |
| [Canvas](controls/Canvas.md) | `onDragged` (`dragged`), `drawable`, `onPressed` (`pressed`), `onReleased` (`released`) | ✅ |  |  | ✅ |  |  |
| [CheckBox](controls/CheckBox.md) | `isOn`, `onToggled` (`toggled`) | ✅ |  |  | ✅ |  |  |
| [ColorBox](controls/ColorBox.md) | `color`, `cornerRadius` | ✅ |  |  | ✅ |  |  |
| [DatePicker](controls/DatePicker.md) | `onClosed` (`closed`), `date`, `onDateChanged` (`dateChanged`), `format`, `isOpen`, `maximumDate`, `minimumDate`, `onOpened` (`opened`) |  |  |  | ✅ |  |  |
| [Grid](controls/Grid.md) | `columnSpacing`, `columns`, `rowSpacing`, `rows` | ✅ |  |  | ✅ |  |  |
| [Image](controls/Image.md) | `isAnimating`, `source` | ✅ |  |  |  |  |  |
| [Label](controls/Label.md) | `lineBreak`, `maximumLines` | ✅ |  |  | ✅ |  |  |
| [Line](controls/Line.md) | `x1`, `x2`, `y1`, `y2` | ✅ |  |  | ✅ |  |  |
| [Map](controls/Map.md) | `isScrollEnabled`, `isTrafficEnabled`, `isZoomEnabled`, `onMapClicked` (`mapClicked`), `mapType`, `region`, `showsUserLocation` |  |  |  |  |  |  |
| [Menu](controls/Menu.md) | `isEnabled`, `text` | ✅ |  |  | ✅ |  |  |
| [NavigationStack](controls/NavigationStack.md) | `barForegroundColor`, `popped` | ✅ |  |  | ✅ |  |  |
| [Page](controls/Page.md) | `appearing`, `backButtonTitle`, `background`, `disappearing`, `hasBackButton`, `hasNavigationBar`, `navigatedFrom`, `navigatedTo`, `navigatingFrom`, `padding` | ✅ |  |  |  |  |  |
| [Path](controls/Path.md) | `data` | ✅ |  |  | ✅ |  |  |
| [Picker](controls/Picker.md) | `onClosed` (`closed`), `isOpen`, `onOpened` (`opened`), `options`, `selectedIndex`, `onSelectedIndexChanged` (`selectedIndexChanged`), `title` | ✅ |  |  | ☑️ |  |  |
| [Pin](controls/Pin.md) | `address`, `label`, `location`, `onPinClicked` (`pinClicked`), `onPinDetailsClicked` (`pinDetailsClicked`), `type` |  |  |  |  |  |  |
| [Polygon](controls/Polygon.md) | `fillRule`, `points` | ✅ |  |  | ✅ |  |  |
| [Polyline](controls/Polyline.md) | `fillRule`, `points` | ✅ |  |  | ✅ |  |  |
| [PositionIndicator](controls/PositionIndicator.md) | `count`, `hideSingle`, `indicatorColor`, `indicatorSize`, `indicatorsShape`, `maximumVisible`, `position`, `selectedIndicatorColor` |  |  |  |  |  |  |
| [ProgressBar](controls/ProgressBar.md) | `progress` | ✅ |  |  | ✅ |  |  |
| [RadioButton](controls/RadioButton.md) | `groupName`, `isOn`, `onToggled` (`toggled`) | ✅ |  |  | ✅ |  |  |
| [Rectangle](controls/Rectangle.md) | `cornerRadius` | ✅ |  |  | ✅ |  |  |
| [Scene](controls/Scene.md) | `activated`, `deactivated`, `destroying`, `stopped`, `windowClosed`, `windowRestored` | ✅ |  |  |  |  |  |
| [ScrollView](controls/ScrollView.md) | `horizontalScrollBarVisibility`, `orientation`, `scrollOffset`, `onScrollStopped` (`scrollStopped`), `scrollXChanged`, `scrollYChanged`, `verticalScrollBarVisibility` | ✅ |  |  | ✅ |  |  |
| [SearchField](controls/SearchField.md) | `returnKey`, `onSubmitted` (`submitted`) |  |  |  | ✅ |  |  |
| [Slider](controls/Slider.md) | `onDragCompleted` (`dragCompleted`), `onDragStarted` (`dragStarted`), `maximum`, `minimum`, `value`, `onValueChanged` (`valueChanged`) | ✅ |  |  | ✅ |  |  |
| [Span](controls/Span.md) | `background` |  |  |  |  |  |  |
| [SplitView](controls/SplitView.md) | `isSidebarVisible`, `isSidebarVisibleChanged` | ✅ |  |  |  |  |  |
| [Stepper](controls/Stepper.md) | `maximum`, `minimum`, `step`, `value`, `onValueChanged` (`valueChanged`) | ✅ |  |  | ✅ |  |  |
| [Switch](controls/Switch.md) | `isOn`, `onToggled` (`toggled`) | ✅ |  |  | ✅ |  |  |
| [TabbedView](controls/TabbedView.md) | `currentPage`, `currentPageChanged` | ✅ |  |  | ✅ |  |  |
| [TextEditor](controls/TextEditor.md) | `growsWithText` | ✅ |  |  | ✅ |  |  |
| [TextField](controls/TextField.md) | `isPassword`, `returnKey`, `showsClearButton`, `onSubmitted` (`submitted`) |  |  |  |  |  |  |
| [TimePicker](controls/TimePicker.md) | `onClosed` (`closed`), `format`, `isOpen`, `onOpened` (`opened`), `time`, `onTimeChanged` (`timeChanged`) |  |  |  | ✅ |  |  |
| [TitleBar](controls/TitleBar.md) | `barForegroundColor`, `icon`, `subtitle`, `title` | ✅ |  |  |  |  |  |
| [ToolbarItem](controls/ToolbarItem.md) | `placement`, `priority` | ✅ |  |  | ✅ |  |  |
| [VisualState](controls/VisualState.md) | `group`, `name` |  |  |  |  |  |  |
| [WebView](controls/WebView.md) | `canGoBackChanged`, `canGoForwardChanged`, `onNavigated` (`navigated`), `onNavigating` (`navigating`), `onProcessTerminated` (`processTerminated`), `source`, `userAgent` |  |  |  | ✅ |  |  |
| [Window](controls/Window.md) | `activated`, `created`, `deactivated`, `destroying`, `floatsOnTop`, `height`, `hidesWhenInactive`, `isMaximizable`, `isMinimizable`, `isTranslucent`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `modalPopped`, `resumed`, `stopped`, `title`, `width`, `windowType`, `windowValue`, `x`, `y` | ✅ |  |  |  |  |  |
<!-- members:end -->

A one-axis `ScrollView` owns input along its enabled axis. When it is nested,
a dominant input on its disabled axis passes to the nearest enclosing scroller.
This behavior is part of the shared contract and must be proved before a host's
`ScrollView` rows receive ✅.

## Complete host vocabulary

The inventory is rendered from the contracts: every node type an element
contract declares, and every name a member is declared under, so a review
sees a name enter or leave the contract. Each contract's `layer` says who
realizes the element and each of its members.

<!-- vocabulary:begin -->
### Controls and structural nodes

`ActivityIndicator`, `Application`, `Border`, `Button`, `Canvas`, `CheckBox`,
`ColorBox`, `Content`, `ContextMenu`, `DatePicker`, `Ellipse`, `Grid`, `HStack`,
`Image`, `Label`, `LeadingContent`, `Line`, `Map`, `Menu`, `MenuBar`,
`MenuItem`, `MenuSeparator`, `ModalStack`, `NavigationStack`, `Overlay`, `Page`,
`Path`, `Picker`, `Pin`, `Polygon`, `Polyline`, `PositionIndicator`,
`ProgressBar`, `RadioButton`, `Rectangle`, `Scene`, `ScrollView`, `SearchField`,
`Setters`, `Slider`, `Span`, `Spans`, `SplitView`, `Stepper`, `Switch`,
`TabbedView`, `TextEditor`, `TextField`, `TimePicker`, `TitleBar`, `TitleView`,
`ToolbarItem`, `ToolbarItems`, `TrailingContent`, `VisualState`, `VStack`,
`WebView`, `Window`, `ZStack`.

### Properties

`accessibilityHeadingLevel`, `accessibilityHint`, `accessibilityIdentifier`,
`accessibilityLabel`, `address`, `allowDrop`, `area`, `aspect`,
`automationExcludedWithChildren`, `avoidsSafeArea`, `backButtonTitle`,
`background`, `barBackgroundColor`, `barForegroundColor`, `borderColor`,
`borderWidth`, `canDrag`, `characterSpacing`, `clipsContent`, `color`,
`columns`, `columnSpacing`, `cornerRadius`, `count`, `currentPage`,
`cursorPosition`, `data`, `date`, `dragText`, `drawable`, `fill`, `fillRule`,
`floatsOnTop`, `fontAttributes`, `fontAutoScalingEnabled`, `fontFamily`,
`fontSize`, `format`, `frame`, `gridColumn`, `gridColumnSpan`, `gridRow`,
`gridRowSpan`, `group`, `groupName`, `growsWithText`, `hasBackButton`,
`hasNavigationBar`, `height`, `hideSingle`, `hidesWhenInactive`,
`horizontalAlignment`, `horizontalScrollBarVisibility`,
`horizontalTextAlignment`, `icon`, `iconPosition`, `iconSpacing`,
`ignoresInput`, `indicatorColor`, `indicatorSize`, `indicatorsShape`,
`inputPurpose`, `isAccessibilityHidden`, `isAnimating`, `isDestructive`,
`isEnabled`, `isMaximizable`, `isMinimizable`, `isOn`, `isOpen`, `isPassword`,
`isReadOnly`, `isRunning`, `isScrollEnabled`, `isSidebarVisible`,
`isSpellCheckEnabled`, `isTextPredictionEnabled`, `isTrafficEnabled`,
`isTranslucent`, `isVisible`, `isZoomEnabled`, `label`, `layoutDirection`,
`letsInputThrough`, `lineBreak`, `lineHeight`, `location`, `mapType`, `margin`,
`maximum`, `maximumDate`, `maximumHeight`, `maximumLength`, `maximumLines`,
`maximumVisible`, `maximumWidth`, `minimum`, `minimumDate`, `minimumHeight`,
`minimumWidth`, `name`, `opacity`, `options`, `orientation`, `padding`,
`panTouchCount`, `panXChannel`, `panYChannel`, `pivotX`, `pivotY`,
`placeholder`, `placeholderColor`, `placement`, `points`, `position`,
`priority`, `progress`, `region`, `renderTransform`, `returnKey`, `rotation`,
`rotationX`, `rotationY`, `rows`, `rowSpacing`, `scale`, `scaleX`, `scaleY`,
`scrollOffset`, `selectedIndex`, `selectedIndicatorColor`, `selectionLength`,
`shape`, `showsClearButton`, `showsUserLocation`, `source`, `spacing`, `step`,
`stroke`, `strokeDashOffset`, `strokeDashPattern`, `strokeLineCap`,
`strokeLineJoin`, `strokeMiterLimit`, `strokeWidth`, `style`, `subtitle`,
`swipeDirection`, `swipeThreshold`, `tapCount`, `text`, `textCase`, `textColor`,
`textDecorations`, `time`, `tint`, `title`, `translationX`, `translationY`,
`type`, `userAgent`, `value`, `verticalAlignment`,
`verticalScrollBarVisibility`, `verticalTextAlignment`, `width`, `windowType`,
`windowValue`, `x`, `x1`, `x2`, `y`, `y1`, `y2`, `zIndex`.

### Events

`activated`, `appearing`, `canGoBackChanged`, `canGoForwardChanged`, `clicked`,
`closed`, `created`, `currentPageChanged`, `dateChanged`, `deactivated`,
`destroying`, `disappearing`, `dragCompleted`, `dragged`, `dragLeave`,
`dragOver`, `dragStarted`, `dragStarting`, `drop`, `dropCompleted`,
`frameChanged`, `isFocusedChanged`, `isSidebarVisibleChanged`, `mapClicked`,
`modalPopped`, `navigated`, `navigatedFrom`, `navigatedTo`, `navigating`,
`navigatingFrom`, `opened`, `panUpdated`, `pinchUpdated`, `pinClicked`,
`pinDetailsClicked`, `pointerEntered`, `pointerExited`, `pointerMoved`,
`pointerPressed`, `pointerReleased`, `popped`, `pressed`, `processTerminated`,
`released`, `resumed`, `scrollStopped`, `scrollXChanged`, `scrollYChanged`,
`selectedIndexChanged`, `stopped`, `submitted`, `swiped`, `tapped`,
`textChanged`, `timeChanged`, `toggled`, `valueChanged`, `visualStateChanged`,
`windowClosed`, `windowRestored`.

### Acts

`alert`, `announce`, `chooseAction`, `confirm`, `currentTime`,
`currentTimeZone`, `evaluateJavaScript`, `focus`, `goBack`, `goForward`,
`handlerFailed`, `hideOnScreenKeyboard`, `moveToRegion`, `persistSceneValue`,
`persistValue`, `prompt`, `reload`, `unfocus`, `utcOffset`.
<!-- vocabulary:end -->
