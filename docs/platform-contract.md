# Platform contract

This document is the shared delivery contract for StateUI's hosts: AppKit,
UIKit, Android Views, WinUI 3, GTK 4, and Web DOM/CSS. It records the StateUI
surface and the implementation evidence for each host.

## Reading the matrix

Every mark is the verdict of a test: each host's suite runs the conformance
families - one a contract, a case for every cell - and writes what each said
under `lib/StateUI/exports/marks/<host>/`, which the tables are rendered from. A case says
what it proves apart from what it only needs - a button whose click makes the
change - and its outcome is the verdict of what it proves alone. Nothing a
host merely implements or declares by hand earns a mark.

| Mark | Meaning |
| :---: | --- |
| ✅ | Every test of the member that ran on that host passed. |
| ☑️ | The member is proven by its tests, but the host's register records what is still missing; the element's page in [the control dictionary](controls/README.md) names it. |
| ✓ | Its tests passed only through the host's own entry or record - an act the driver hands past the toolkit's input, a read of what the host keeps rather than what the toolkit holds - which the driver names. The member works and its effect is proven, by weaker evidence than ✅: it counts as met, in a row of its own in each total. |
| – | The member will never be met by that host's family - a phone with no menu bar, a desktop whose keyboard captions no return key, a view that takes no keyboard focus - and meets the contract there: the host's register, or the case that proved it absent, says why, and the Gallery shows that family no example of it. |
| 🧩 | Left to the application: the platform ships no control for it - a map on Android Views, WinUI 3 and GTK 4, where each provider needs the application's own key - so the host makes none, and the application registers its own control with the host, as each host's page shows ([Android Views](hosts/android.md#controls-acts-and-events-registered-in-swift)). Shown in each total, it is not counted as met: what the user gets there is the application's. |
| ❌ | A test of the member failed on that host's last run; the note gives the first failure. |
| ◐ | Some of its tests proved it and another could not run or read; the note says which. |
| · | The host realizes it, but its driver cannot yet do or read what the test needs. |
| ⏸ | Its test waits on another member the host does not realize. |
| ⌛ | The verdict was written at another revision of its family than it stands at: each run writes its family's revision over its verdicts, and a change that changes what a family's cases prove raises the family's in `lib/StateUI/StateUI.Conformance/revisions.txt`, so a verdict of another is stale until the host's suite runs the family again. It carries no note: what that run said is no verdict of the family as it stands. |
| empty | Not realized on that host, or no run of it; the note says which. It is deliberately not an estimate of how difficult the work will be. |

A host's totals count its ✅, ✓ and –, a row each, and their sum is what it
meets; its 🧩 stand in a row of their own, apart from the sum. An element's ✅ under
[Control creation](#control-creation) means that host's own test proved it
makes the element. It does not imply that every member has been completed;
the member rows state that separately.

An element's row under [Contract members](#contract-members) counts its
members by mark. A tier's member and an act are marked only on the page of
each element that has it: one element may realize what another does not, so
no one mark says it for a host, and the tables naming them here carry none.

Member by member and element by element, the marks live in [the control
dictionary](controls/README.md). Every table of marks here that a contract can
say is rendered from the contracts and from each host's verdicts, as the
dictionary is: `STATEUI_UPDATE_DOCS=1 swift test --filter
ControlDictionaryTests` writes them, and the test fails while one differs -
also once a source a verdict rests on changes and the verdict turns stale. The
capabilities, the standard environment and the core view members name no
contract member and carry no mark.

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
host whose own passing test proved it makes the element. An empty cell is not
proven there yet: the element's page says what it is on each host, how many
of its members each meets, and why a cell is empty.

<!-- creation:begin -->
| Element | Layer | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](controls/ActivityIndicator.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](controls/Application.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Button](controls/Button.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Canvas](controls/Canvas.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [CheckBox](controls/CheckBox.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ColorBox](controls/ColorBox.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](controls/ContextMenu.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [DatePicker](controls/DatePicker.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Divider](controls/Divider.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Ellipse](controls/Ellipse.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Grid](controls/Grid.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [HStack](controls/HStack.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Image](controls/Image.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ItemsView](controls/ItemsView.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Line](controls/Line.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Map](controls/Map.md) | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 | 🧩 |
| [Marker](controls/Marker.md) | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 | 🧩 |
| [Menu](controls/Menu.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuBar](controls/MenuBar.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuItem](controls/MenuItem.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ModalStack](controls/ModalStack.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [NavigationStack](controls/NavigationStack.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Overlay](controls/Overlay.md) | structure | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](controls/Page.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Path](controls/Path.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Picker](controls/Picker.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Polygon](controls/Polygon.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Polyline](controls/Polyline.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ProgressBar](controls/ProgressBar.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [RadioButton](controls/RadioButton.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Rectangle](controls/Rectangle.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Scene](controls/Scene.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ScrollView](controls/ScrollView.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [SearchField](controls/SearchField.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Slider](controls/Slider.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [SplitView](controls/SplitView.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Stepper](controls/Stepper.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Switch](controls/Switch.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TabView](controls/TabView.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Text](controls/Text.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TextEditor](controls/TextEditor.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TextField](controls/TextField.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TextSpan](controls/TextSpan.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TextSpans](controls/TextSpans.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TimePicker](controls/TimePicker.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](controls/TitleView.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](controls/ToolbarItem.md) | structure | ✓ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItemGroup](controls/ToolbarItemGroup.md) | structure | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [VStack](controls/VStack.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [WebView](controls/WebView.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Window](controls/Window.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ZStack](controls/ZStack.md) | native | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
<!-- creation:end -->

The AppKit split view uses `NSSplitViewController`.

Every arrangement exposes an optional flat `barBackgroundColor` and a
`barForegroundColor` for its bar's title and native action affordances, and the
application's name, the line under the title and its mark (`barTitle`,
`barSubtitle`, `barIcon`); a page's bar takes each from the nearest arrangement
around it that declares one. A split view's bar is both its panes': a sidebar
with a bar of its own wears what its split view declares, and nothing from
around the split view. A tab selector keeps the toolkit's selected and unselected
appearance. An unwritten background retains the native material; StateUI does
not ask a host to rasterize an arbitrary brush into page chrome.

On AppKit a written bar colour paints the band the title bar and toolbar cover
over the visible content - a split view's detail - and the window's
background, which shows around a floating sidebar and through its glass. On a
translucent window the colour tints the window's material instead, which the
band, the margin around the sidebar and its glass all show. Text on a painted
band - the page's title, and the application's name and line at the trailing
edge - is in the declared `barForegroundColor`, else white or black by the
band's lightness.
On the system's material both keep the system's colours.

`ItemsView` is the native virtualized collection. It presents identified
items as a list, a row or a grid, and StateUI builds an item only when the
platform's collection shows it. Its host adapters map to `NSCollectionView`,
`UICollectionView`, `RecyclerView`, WinUI `ItemsView`, `GtkListView` or
`GtkGridView`, and a semantic DOM list/grid; each member's mark is its case's
verdict on that host, as for every element.

`ForEach`, `GeometryReader`, `ScrollReader`, `PlacedLayout`, and `GalleryView` are
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

| StateUI surface | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | --- | --- | --- | --- | --- | --- |
| `Application` / `Scene` | `NSApplication` / structure | `UIApplication` / `UIWindowScene` | `Application` / structure | `Application` / structure | `GtkApplication` / structure | `document` / structure |
| `Window` | `NSWindow` | `UIWindow` | `Activity` | `Window` | `GtkApplicationWindow` | browser `window` |
| `Page` | custom `NSView` | `UIViewController` | custom `ViewGroup` | `Page` | custom `GtkWidget` | `<section>` |
| `NavigationStack` | custom `NSView` stack; title, back and actions in the window's `NSToolbar` | `UINavigationController` | custom `ViewGroup` stack + `Toolbar` | `Frame` | `GtkStack` + `GtkHeaderBar`; libadwaita `AdwNavigationView` | History API |
| `TabView` | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` on macOS 26 and later, else the title bar's bottom accessory - with top tabs where no window serves it | `UITabBarController` | custom `LinearLayout` tab row | `NavigationView` with a top pane | `GtkStack` + `GtkStackSwitcher`; libadwaita `AdwViewStack` | ARIA `tablist` |
| `SplitView` | `NSSplitViewController` | `UISplitViewController` | custom `ViewGroup`: a drawer where narrow, beside where wide | `SplitView` | `GtkPaned`; libadwaita `AdwOverlaySplitView` | `<aside>` |
| `ModalStack` | sheet `NSWindow` | `present(_:animated:)` | full-screen `Dialog` (?) | `ContentDialog` (?) | modal `GtkWindow`; libadwaita `AdwDialog` | `<dialog>` with `showModal()` |
| `Overlay` | pass-through `NSView` above the page | pass-through `UIView` above the page | top child of a `FrameLayout` | top layer of a root `Grid` | `GtkOverlay` | positioned element above the page |
| `ContextMenu`, `MenuBar`, `Menu`, `MenuItem`, `Divider` | `NSMenu` / `NSMenuItem` | `UIMenu` / `UIAction` | `PopupMenu` / `MenuItem`; no menu bar | `MenuFlyout` / `MenuBar` | `GMenu` in `GtkPopoverMenu` / `GtkPopoverMenuBar` | ARIA `menu` / `menubar` (?) |
| `ToolbarItemGroup` / `ToolbarItem` | `NSToolbarItem`; `NSMenuToolbarItem` overflow | `UIBarButtonItem` | `Toolbar` `MenuItem` | `CommandBar` `AppBarButton` | `GtkButton` in `GtkHeaderBar` | `<button>` in an ARIA `toolbar` |
| `ZStack` | custom `NSView` | custom `UIView` | custom `ViewGroup` | `Canvas` | `GtkFixed` | `position: absolute` |
| `VStack` / `HStack` | custom `NSView` | custom `UIView` | custom `ViewGroup` | `StackPanel` | `GtkBox` | flexbox |
| `Grid` | custom `NSView` | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI | composed by StateUI |
| `ScrollView` | `NSScrollView` | `UIScrollView` | `ScrollView` / `HorizontalScrollView` | `ScrollViewer` | `GtkScrolledWindow` | `overflow: auto` |
| `Text` / `TextSpans` / `TextSpan` | `NSTextField` label; `NSAttributedString` runs | `UILabel`; `NSAttributedString` runs | `TextView`; `SpannableString` spans | `TextBlock`; `Run` inlines | `GtkLabel`; `PangoAttrList` runs | text element; `<span>` runs |
| `Button` | `NSButton` | `UIButton` | `Button` | `Button` | `GtkButton` | `<button>` |
| `Image` | `NSImageView` | `UIImageView` | `ImageView` | `Image` | `GtkPicture` | `<img>` |
| `ColorBox` | custom `NSView` drawing | `UIView` + `CALayer` | `View` + `GradientDrawable` | `Border` | custom `GtkWidget` snapshot | `<div>` |
| `TextField` | `NSTextField` / `NSSecureTextField` | `UITextField` | `EditText` | `TextBox` / `PasswordBox` | `GtkEntry` / `GtkPasswordEntry` | `<input>` |
| `TextEditor` | `NSTextView` in an `NSScrollView` | `UITextView` | multi-line `EditText` | multi-line `TextBox` | `GtkTextView` | `<textarea>` |
| `SearchField` | `NSSearchField` | `UISearchBar` | `SearchView` | `AutoSuggestBox` | `GtkSearchEntry` | `<input type=search>` |
| `Picker` | `NSPopUpButton` | pop-up `UIButton` menu | `Spinner` | `ComboBox` | `GtkDropDown` | `<select>` |
| `DatePicker` | `NSDatePicker` | `UIDatePicker` | `DatePickerDialog` | `CalendarDatePicker` | `GtkCalendar` in a `GtkPopover` | `<input type=date>` |
| `TimePicker` | `NSDatePicker` in time mode | `UIDatePicker` in time mode | `TimePickerDialog` | `TimePicker` | an hour's and a minute's `GtkSpinButton` in a `GtkPopover` | `<input type=time>` |
| `Switch` | `NSSwitch` | `UISwitch` | `Switch` | `ToggleSwitch` | `GtkSwitch` | checkbox `<input>` with `role=switch` |
| `CheckBox` | `NSButton` checkbox | composed by StateUI | `CheckBox` | `CheckBox` | `GtkCheckButton` | `<input type=checkbox>` |
| `RadioButton` | `NSButton` radio | composed by StateUI | `RadioButton` | `RadioButton` | grouped `GtkCheckButton` | `<input type=radio>` |
| `Slider` | `NSSlider` | `UISlider` | `SeekBar` | `Slider` | `GtkScale` | `<input type=range>` |
| `Stepper` | `NSStepper` | `UIStepper` | custom `NumberPicker`-based view | `NumberBox` | `GtkSpinButton` | `<input type=number>` |
| `ProgressBar` | `NSProgressIndicator` bar | `UIProgressView` | horizontal `ProgressBar` | `ProgressBar` | `GtkProgressBar` | `<progress>` |
| `ActivityIndicator` | spinning `NSProgressIndicator` | `UIActivityIndicatorView` | indeterminate `ProgressBar` | `ProgressRing` | `GtkSpinner` | indeterminate `<progress>` |
| `Canvas` | custom `NSView` drawing | `UIView` `draw(_:)` | `View` `onDraw(Canvas)` | Direct2D in a `SurfaceImageSource` | `GtkDrawingArea` | `<canvas>` |
| `Rectangle` / `Ellipse` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | `GskPath` in a snapshot | inline SVG |
| `Line` / `Path` / `Polygon` / `Polyline` | `NSView` drawing `NSBezierPath` | `UIView` drawing `UIBezierPath` | `View` drawing `Path` | `Microsoft.UI.Xaml.Shapes` | `GskPath` in a snapshot | inline SVG |
| `Map` / `Marker` | `MKMapView` / `MKAnnotation` | `MKMapView` / `MKAnnotation` | the application's own, registered | the application's own, registered | the application's own, registered | — |
| `WebView` | `WKWebView` | `WKWebView` | `WebView` | `WebView2`, a backend | WebKitGTK `WebKitWebView`, a backend | `<iframe>` (?) |
| `ItemsView` | `NSCollectionView` / `NSTableView` | `UICollectionView` | AndroidX `RecyclerView` | `ItemsView` | `GtkListView` / `GtkGridView` | semantic list or grid |
| `TitleView` | structure | structure | structure | structure | structure | structure |

### Completeness

Every element contract appears exactly once in the first column; each
element's page in the control dictionary takes its native counterparts from
here, and `ControlDictionaryTests` holds the table to that.

These surfaces lack an honest native counterpart on at least one target:

- `NavigationStack`: Android Views and GTK 4 without libadwaita have no page-stack control.
- `TabView`: Android Views has no framework tab bar; Web has no tab element.
- `SplitView`: Android Views depends on AndroidX `DrawerLayout`; Web has no native pane.
- `ModalStack`: Android Views has no modal page presentation; WinUI 3 shows one `ContentDialog` at a time, so its host stacks sheets of a dialog's look over the window.
- The application's name and mark in the bar (`barTitle`, `barIcon`): UIKit, Android Views and GTK 4 give each page a bar of its own that names that page.
- Menus: Android Views has no menu bar; Web has no native menu element.
- `Grid`: AppKit, UIKit, and GTK 4 have no container with star and auto tracks.
- `CheckBox` and `RadioButton`: UIKit has neither control.
- `Stepper`: Android Views has no stepper; `NumberPicker` is an integer wheel.
- `DatePicker`: GTK 4 has `GtkCalendar` but no date field.
- `TimePicker`: GTK 4 has no time picker; its host sets a time as GNOME's applications do, with spin buttons.
- `Switch`: Web has no switch element.
- `ActivityIndicator`: Web has no spinner; an indeterminate `<progress>` draws a bar.
- `Map` / `Marker`: Android Views, WinUI 3 and GTK 4 have no map of the platform's own - Google Play services, Azure Maps and libshumate each need a provider and its key - so the application registers its own with the host, the pins as the map's children; Web has no map element.
- `ItemsView`: Android Views depends on AndroidX `RecyclerView`; Web has no native virtualized list.
- `WebView`: WinUI 3 and GTK 4 depend on an engine their toolkit does not ship - the WebView2 runtime, WebKitGTK - so their web view is a backend the application registers (`lib/Backends`); Web cannot observe navigation or set a user agent in a cross-origin `<iframe>`.

## Shared state, patch, and motion capabilities

What every host does with the renderer's patch and the motion it carries.
These carry no mark: no conformance case gives a verdict for a capability
as such, so none is claimed for any host.

- sparse `HostRender` / `HostPatch` application
- stable element identity and arranged children
- driven state modes and typed channel kinds
- native input committed before handler dispatch
- silent application writes
- host-driven Journey interpolation with eased and spring motion
- host-driven Journey retargeting with standing velocity
- sparse property transitions through `HostPatch.transitions`
- layout motion through `HostPatch.motion` and `MotionLanes`
- Journey completion and interruption
- Journey stop and snap
- StateUI display-cycle engines
- element teardown releases external native attachments

## Standard environment

The facts a host supplies and keeps current, read through the environment by
name - `\.device`, `\.locale`, `\.application`. These carry no mark: no
conformance case gives a verdict for a set of facts as a whole, so none is
claimed for any host.

- `device.battery`: `chargeLevel`, `state`, `powerSource`, `energySaverStatus`
- `device.connectivity`: `networkAccess`, `connectionProfiles`
- `device.display`: `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate`
- `device.info`: `formFactor`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `deviceType`
- `locale`: `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric`
- `application.info`: `name`, `packageName`, `versionString`, `buildString`, `colorScheme`
- `application`: `phase`

The public provider and its fallback values exist whatever a host supplies.
[Environment](concepts/environment.md) defines that schema; the hosts' pages
say what each host supplies.

## Host acts

An act is what the application asks a host to do rather than describes: ask
the user a question or for a file, launch an address, read the clock or the
time zone, keep a value, take a web view back or move a map. An act of the
application's contract aims at nothing; an element's act aims at one element
of its kind. Calendar values are
portable StateUI values; reading the current clock or time zone is a host act
because the host owns the active locale and zone database - `currentTime` is
`ClockTime.now()`, `currentTimeZone` is `TimeZoneInfo.local()`, and `utcOffset`
is `TimeZoneInfo.utcOffset(of:on:)`. The table names each act; its marks are
on the page of its element - a tier's act on the page of each element wearing
the tier.

<!-- acts:begin -->
| Act | Contract |
| --- | --- |
| `focus` | [VisualElement](controls/tiers/VisualElement.md) |
| `unfocus` | [VisualElement](controls/tiers/VisualElement.md) |
| `alert` | [Application](controls/Application.md) |
| `announce` | [Application](controls/Application.md) |
| `chooseAction` | [Application](controls/Application.md) |
| `confirm` | [Application](controls/Application.md) |
| `currentTime` | [Application](controls/Application.md) |
| `currentTimeZone` | [Application](controls/Application.md) |
| `handlerFailed` | [Application](controls/Application.md) |
| `hideOnScreenKeyboard` | [Application](controls/Application.md) |
| `launchFile` | [Application](controls/Application.md) |
| `launchLink` | [Application](controls/Application.md) |
| `openFiles` | [Application](controls/Application.md) |
| `persistSceneValue` | [Application](controls/Application.md) |
| `persistValue` | [Application](controls/Application.md) |
| `prompt` | [Application](controls/Application.md) |
| `readFile` | [Application](controls/Application.md) |
| `saveFile` | [Application](controls/Application.md) |
| `utcOffset` | [Application](controls/Application.md) |
| `scrollTo` | [ItemsView](controls/ItemsView.md) |
| `moveToRegion` | [Map](controls/Map.md) |
| `evaluateJavaScript` | [WebView](controls/WebView.md) |
| `goBack` | [WebView](controls/WebView.md) |
| `goForward` | [WebView](controls/WebView.md) |
| `reload` | [WebView](controls/WebView.md) |
<!-- acts:end -->

## Shared view members

A property or event of the three tiers every view wears -
[PropertyContainer](controls/tiers/PropertyContainer.md),
[VisualElement](controls/tiers/VisualElement.md) and
[View](controls/tiers/View.md) - is named here and marked on the page of each
view: every view realizes it apart, and one may have what another lacks. The
core view members are StateUI's own API, which a host serves without a member
of its own; no case gives them a verdict of their own, so no page marks them:

- identity: `id`
- aimed control methods: `aim`
- core reactions: `onCreated`, `onDestroying`, `onChanged`, `samples`, `engine`
- motion selection: `motion`, `MotionValues`, `MotionLanes`
- focus feed: `isFocused`

<!-- shared:begin -->
| Member | Tier | Kind |
| --- | --- | --- |
| `accessibilityIdentifier` | [PropertyContainer](controls/tiers/PropertyContainer.md) | property |
| `accessibilityHeading` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityHint` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityLabel` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `automationExcludedWithChildren` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `background` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `frame` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `height` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `ignoresInput` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `isAccessibilityHidden` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `isEnabled` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `isFocusedChanged` | [VisualElement](controls/tiers/VisualElement.md) | event |
| `isVisible` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `layoutDirection` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `maximumHeight` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `maximumWidth` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `minimumHeight` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `minimumWidth` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `opacity` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `pivotX` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `pivotY` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `rotation` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `rotationX` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `rotationY` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `scale` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `scaleX` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `scaleY` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `style` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `translationX` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `translationY` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `width` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `zIndex` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `allowsDrop` | [View](controls/tiers/View.md) | property |
| `area` | [View](controls/tiers/View.md) | property |
| `canDrag` | [View](controls/tiers/View.md) | property |
| `onDragLeave` (`dragLeave`) | [View](controls/tiers/View.md) | event |
| `onDragOver` (`dragOver`) | [View](controls/tiers/View.md) | event |
| `dragStarting` | [View](controls/tiers/View.md) | event |
| `dragText` | [View](controls/tiers/View.md) | property |
| `onDrop` (`drop`) | [View](controls/tiers/View.md) | event |
| `onDragEnded` (`dragEnded`) | [View](controls/tiers/View.md) | event |
| `onFrameChanged` (`frameChanged`) | [View](controls/tiers/View.md) | event |
| `gridColumn` | [View](controls/tiers/View.md) | property |
| `gridColumnSpan` | [View](controls/tiers/View.md) | property |
| `gridRow` | [View](controls/tiers/View.md) | property |
| `gridRowSpan` | [View](controls/tiers/View.md) | property |
| `horizontalAlignment` | [View](controls/tiers/View.md) | property |
| `margin` | [View](controls/tiers/View.md) | property |
| `panTouchCount` | [View](controls/tiers/View.md) | property |
| `onPanUpdated` (`panUpdated`) | [View](controls/tiers/View.md) | event |
| `panXChannel` | [View](controls/tiers/View.md) | property |
| `panYChannel` | [View](controls/tiers/View.md) | property |
| `onPinchUpdated` (`pinchUpdated`) | [View](controls/tiers/View.md) | event |
| `onPointerEntered` (`pointerEntered`) | [View](controls/tiers/View.md) | event |
| `onPointerExited` (`pointerExited`) | [View](controls/tiers/View.md) | event |
| `onPointerMoved` (`pointerMoved`) | [View](controls/tiers/View.md) | event |
| `onPointerPressed` (`pointerPressed`) | [View](controls/tiers/View.md) | event |
| `onPointerReleased` (`pointerReleased`) | [View](controls/tiers/View.md) | event |
| `swipeDirection` | [View](controls/tiers/View.md) | property |
| `swipeThreshold` | [View](controls/tiers/View.md) | property |
| `onSwiped` (`swiped`) | [View](controls/tiers/View.md) | event |
| `tapCount` | [View](controls/tiers/View.md) | property |
| `onTapped` (`tapped`) | [View](controls/tiers/View.md) | event |
| `verticalAlignment` | [View](controls/tiers/View.md) | property |
<!-- shared:end -->

## Control dictionary

Every control, and every part an application, its windows and its pages are made of, has its members in [the control dictionary](controls/README.md): one row per property, event and act, with a mark per platform. The counts below are rendered with it.

<!-- dictionary:begin -->
### Controls

| Control | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](controls/ActivityIndicator.md) | 68 | 26 ✅ · 1 ☑️ · 34 ✓ · 3 – | 28 ✅ · 33 ✓ · 3 – | 52 ✅ · 1 ☑️ · 8 ✓ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 45 ✅ · 18 ✓ |
| [Button](controls/Button.md) | 86 | 41 ✅ · 1 ☑️ · 35 ✓ · 1 – | 43 ✅ · 35 ✓ · 3 – | 60 ✅ · 1 ☑️ · 8 ✓ · 3 – | 73 ✅ · 2 ✓ | 55 ✅ · 18 ✓ · 1 – | 55 ✅ · 18 ✓ |
| [Canvas](controls/Canvas.md) | 70 | 27 ✅ · 1 ☑️ · 36 ✓ · 3 – | 27 ✅ · 36 ✓ · 3 – | 54 ✅ · 1 ☑️ · 8 ✓ · 3 – | 53 ✅ · 3 ✓ · 3 – | 44 ✅ · 11 ✓ · 4 – | 47 ✅ · 18 ✓ |
| [CheckBox](controls/CheckBox.md) | 69 | 33 ✅ · 1 ☑️ · 33 ✓ | 28 ✅ · 34 ✓ · 3 – | 54 ✅ · 1 ☑️ · 8 ✓ · 3 – | 58 ✅ · 2 ✓ | 45 ✅ · 12 ✓ · 1 – | 46 ✅ · 18 ✓ |
| [ColorBox](controls/ColorBox.md) | 68 | 28 ✅ · 33 ✓ · 3 – | 28 ✅ · 33 ✓ · 3 – | 51 ✅ · 1 ☑️ · 8 ✓ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 45 ✅ · 18 ✓ |
| [DatePicker](controls/DatePicker.md) | 80 | 37 ✅ · 1 ☑️ · 34 ✓ · 1 – | 31 ✅ · 33 ✓ · 3 – | 59 ✅ · 1 ☑️ · 11 ✓ · 3 – | 65 ✅ · 1 ☑️ · 2 ✓ | 52 ✅ · 1 ☑️ · 13 ✓ · 1 – | 50 ✅ · 18 ✓ |
| [Ellipse](controls/Ellipse.md) | 76 | 26 ✅ · 1 ☑️ · 33 ✓ · 3 – | 28 ✅ · 33 ✓ · 3 – | 50 ✅ · 1 ☑️ · 8 ✓ · 3 – | 58 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 53 ✅ · 18 ✓ |
| [Grid](controls/Grid.md) | 77 | 33 ✅ · 33 ✓ · 3 – | 35 ✅ · 33 ✓ · 3 – | 56 ✅ · 1 ☑️ · 8 ✓ · 3 – | 59 ✅ · 3 ✓ · 3 – | 48 ✅ · 11 ✓ · 4 – | 54 ✅ · 18 ✓ |
| [HStack](controls/HStack.md) | 74 | 30 ✅ · 33 ✓ · 3 – | 32 ✅ · 33 ✓ · 3 – | 53 ✅ · 1 ☑️ · 8 ✓ · 3 – | 56 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 51 ✅ · 18 ✓ |
| [Image](controls/Image.md) | 69 | 28 ✅ · 1 ☑️ · 33 ✓ · 3 – | 28 ✅ · 33 ✓ · 3 – | 51 ✅ · 1 ☑️ · 8 ✓ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 44 ✅ · 18 ✓ |
| [ItemsView](controls/ItemsView.md) | 76 | 34 ✅ · 1 ☑️ · 37 ✓ | 31 ✅ · 37 ✓ · 3 – | 61 ✅ · 1 ☑️ · 9 ✓ | 62 ✅ · 2 ✓ | 52 ✅ · 11 ✓ · 1 – | 51 ✅ · 19 ✓ |
| [Line](controls/Line.md) | 80 | 30 ✅ · 1 ☑️ · 33 ✓ · 3 – | 32 ✅ · 33 ✓ · 3 – | 54 ✅ · 1 ☑️ · 8 ✓ · 3 – | 62 ✅ · 3 ✓ · 3 – | 49 ✅ · 11 ✓ · 4 – | 57 ✅ · 18 ✓ |
| [Map](controls/Map.md) | 74 | 33 ✅ · 1 ☑️ · 34 ✓ · 3 – | 33 ✅ · 34 ✓ · 3 – | 74 🧩 | 74 🧩 | 74 🧩 | 74 🧩 |
| [Path](controls/Path.md) | 77 | 27 ✅ · 1 ☑️ · 33 ✓ · 3 – | 29 ✅ · 33 ✓ · 3 – | 51 ✅ · 1 ☑️ · 8 ✓ · 3 – | 59 ✅ · 3 ✓ · 3 – | 46 ✅ · 11 ✓ · 4 – | 54 ✅ · 18 ✓ |
| [Picker](controls/Picker.md) | 82 | 39 ✅ · 1 ☑️ · 34 ✓ · 1 – | 28 ✅ · 36 ✓ · 3 – | 54 ✅ · 1 ☑️ · 9 ✓ · 3 – | 67 ✅ · 2 ✓ | 50 ✅ · 11 ✓ · 7 – | 48 ✅ · 18 ✓ |
| [Polygon](controls/Polygon.md) | 78 | 28 ✅ · 1 ☑️ · 33 ✓ · 3 – | 30 ✅ · 33 ✓ · 3 – | 52 ✅ · 1 ☑️ · 8 ✓ · 3 – | 60 ✅ · 3 ✓ · 3 – | 47 ✅ · 11 ✓ · 4 – | 55 ✅ · 18 ✓ |
| [Polyline](controls/Polyline.md) | 78 | 28 ✅ · 1 ☑️ · 33 ✓ · 3 – | 30 ✅ · 33 ✓ · 3 – | 52 ✅ · 1 ☑️ · 8 ✓ · 3 – | 60 ✅ · 3 ✓ · 3 – | 47 ✅ · 11 ✓ · 4 – | 55 ✅ · 18 ✓ |
| [ProgressBar](controls/ProgressBar.md) | 68 | 27 ✅ · 1 ☑️ · 33 ✓ · 3 – | 28 ✅ · 33 ✓ · 3 – | 52 ✅ · 1 ☑️ · 8 ✓ · 3 – | 52 ✅ · 2 ✓ · 3 – | 41 ✅ · 12 ✓ · 4 – | 45 ✅ · 18 ✓ |
| [RadioButton](controls/RadioButton.md) | 81 | 39 ✅ · 1 ☑️ · 33 ✓ · 1 – | 36 ✅ · 34 ✓ · 3 – | 60 ✅ · 1 ☑️ · 8 ✓ · 3 – | 65 ✅ · 2 ✓ | 52 ✅ · 12 ✓ · 1 – | 50 ✅ · 18 ✓ |
| [Rectangle](controls/Rectangle.md) | 77 | 27 ✅ · 1 ☑️ · 33 ✓ · 3 – | 29 ✅ · 33 ✓ · 3 – | 51 ✅ · 1 ☑️ · 8 ✓ · 3 – | 59 ✅ · 3 ✓ · 3 – | 46 ✅ · 11 ✓ · 4 – | 54 ✅ · 18 ✓ |
| [ScrollView](controls/ScrollView.md) | 77 | 33 ✅ · 2 ☑️ · 35 ✓ · 3 – | 35 ✅ · 33 ✓ · 3 – | 53 ✅ · 1 ☑️ · 8 ✓ · 3 – | 61 ✅ · 3 ✓ · 3 – | 51 ✅ · 11 ✓ · 1 – | 55 ✅ · 18 ✓ |
| [SearchField](controls/SearchField.md) | 89 | 42 ✅ · 34 ✓ · 3 – | 48 ✅ · 33 ✓ | 70 ✅ · 1 ☑️ · 8 ✓ · 1 – | 66 ✅ · 1 ☑️ · 2 ✓ | 60 ✅ · 12 ✓ · 1 – | 60 ✅ · 18 ✓ |
| [Slider](controls/Slider.md) | 73 | 35 ✅ · 1 ☑️ · 33 ✓ | 32 ✅ · 35 ✓ · 3 – | 56 ✅ · 1 ☑️ · 8 ✓ · 3 – | 59 ✅ · 2 ✓ | 47 ✅ · 12 ✓ · 3 – | 48 ✅ · 18 ✓ |
| [Stepper](controls/Stepper.md) | 71 | 32 ✅ · 1 ☑️ · 33 ✓ | 29 ✅ · 33 ✓ · 3 – | 51 ✅ · 1 ☑️ · 8 ✓ · 3 – | 59 ✅ · 2 ✓ | 48 ✅ · 11 ✓ · 1 – | 48 ✅ · 18 ✓ |
| [Switch](controls/Switch.md) | 69 | 32 ✅ · 1 ☑️ · 33 ✓ | 29 ✅ · 33 ✓ · 3 – | 53 ✅ · 1 ☑️ · 8 ✓ · 3 – | 58 ✅ · 2 ✓ | 45 ✅ · 12 ✓ · 1 – | 46 ✅ · 18 ✓ |
| [Text](controls/Text.md) | 81 | 39 ✅ · 1 ☑️ · 33 ✓ · 4 – | 41 ✅ · 33 ✓ · 3 – | 62 ✅ · 1 ☑️ · 8 ✓ · 3 – | 65 ✅ · 2 ✓ · 3 – | 53 ✅ · 13 ✓ · 4 – | 58 ✅ · 18 ✓ |
| [TextEditor](controls/TextEditor.md) | 87 | 47 ✅ · 1 ☑️ · 34 ✓ · 1 – | 48 ✅ · 33 ✓ | 69 ✅ · 1 ☑️ · 8 ✓ · 1 – | 72 ✅ · 2 ✓ | 59 ✅ · 1 ☑️ · 12 ✓ · 1 – | 61 ✅ · 18 ✓ |
| [TextField](controls/TextField.md) | 90 | 43 ✅ · 1 ☑️ · 34 ✓ · 3 – | 50 ✅ · 33 ✓ | 71 ✅ · 1 ☑️ · 8 ✓ · 2 – | 71 ✅ · 1 ☑️ · 2 ✓ | 61 ✅ · 12 ✓ · 1 – | 63 ✅ · 18 ✓ |
| [TimePicker](controls/TimePicker.md) | 78 | 35 ✅ · 1 ☑️ · 34 ✓ · 1 – | 32 ✅ · 33 ✓ | 59 ✅ · 1 ☑️ · 9 ✓ · 3 – | 60 ✅ · 2 ✓ | 51 ✅ · 12 ✓ · 1 – | 48 ✅ · 18 ✓ |
| [VStack](controls/VStack.md) | 74 | 30 ✅ · 33 ✓ · 3 – | 32 ✅ · 33 ✓ · 3 – | 53 ✅ · 1 ☑️ · 8 ✓ · 3 – | 56 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 51 ✅ · 18 ✓ |
| [WebView](controls/WebView.md) | 77 | 39 ✅ · 1 ☑️ · 34 ✓ | 39 ✅ · 34 ✓ | 61 ✅ · 1 ☑️ · 8 ✓ · 3 – | 45 ✅ · 3 ✓ · 18 – | 54 ✅ · 11 ✓ · 1 – | 51 ✅ · 18 ✓ |
| [ZStack](controls/ZStack.md) | 73 | 29 ✅ · 33 ✓ · 3 – | 31 ✅ · 33 ✓ · 3 – | 52 ✅ · 1 ☑️ · 8 ✓ · 3 – | 55 ✅ · 3 ✓ · 3 – | 44 ✅ · 11 ✓ · 4 – | 50 ✅ · 18 ✓ |
| ✅ |  | 1057 | 1060 | 1737 | 1845 | 1508 | 1598 |
| ✓ |  | 1076 | 1074 | 254 | 78 | 361 | 559 |
| – |  | 67 | 81 | 85 | 69 | 87 | 0 |
| **Met** | 2447 | **2200** | **2215** | **2076** | **1992** | **1956** | **2157** |
| 🧩 |  | 0 | 0 | 74 | 74 | 74 | 74 |

### Application structure

| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](controls/Application.md) | 17 | 7 ✅ · 10 ✓ | 7 ✅ · 10 ✓ | 6 ✅ · 9 ✓ | 15 ✅ · 2 ✓ | 11 ✅ · 1 ✓ | 12 ✅ · 5 ✓ |
| [ContextMenu](controls/ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Divider](controls/Divider.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](controls/Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](controls/Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](controls/MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](controls/MenuItem.md) | 6 | 3 ✅ · 1 ☑️ | 6 ✅ | 4 ✅ · 2 – | 6 ✅ | 3 ✅ · 3 – | 6 ✅ |
| [ModalStack](controls/ModalStack.md) | 6 | 4 ✅ | 4 ✅ · 2 – | 3 ✅ · 2 – | 6 ✅ | 4 ✅ · 2 – | 5 ✅ · 1 – |
| [NavigationStack](controls/NavigationStack.md) | 9 | 4 ✅ · 1 ✓ | 7 ✅ · 2 – | 3 ✅ · 2 – | 9 ✅ | 5 ✅ · 4 – | 7 ✅ · 1 – |
| [Overlay](controls/Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](controls/Page.md) | 11 | 7 ✅ | 11 ✅ | 8 ✅ · 1 – | 9 ✅ | 7 ✅ · 1 – | 9 ✅ |
| [Scene](controls/Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [SplitView](controls/SplitView.md) | 10 | 6 ✅ | 8 ✅ · 2 – | 3 ✅ · 2 ✓ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TabView](controls/TabView.md) | 10 | 5 ✅ · 1 ✓ | 8 ✅ · 2 – | 3 ✅ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TextSpan](controls/TextSpan.md) | 12 |  |  |  | 9 ✅ | 9 ✅ | 9 ✅ |
| [TextSpans](controls/TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](controls/TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](controls/ToolbarItem.md) | 8 | 2 ✅ · 1 ✓ · 1 – | 6 ✅ · 1 – | 4 ✅ · 1 – | 8 ✅ | 7 ✅ · 1 – | 8 ✅ |
| [ToolbarItemGroup](controls/ToolbarItemGroup.md) | 2 | 2 ✅ | 2 ✅ | 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [Window](controls/Window.md) | 22 | 15 ✅ · 6 ✓ | 3 ✅ · 4 ✓ · 9 – | 2 ✅ · 4 ✓ | 22 ✅ | 8 ✅ · 6 ✓ · 8 – | 3 ✅ · 4 ✓ · 15 – |
| ✅ |  | 67 | 70 | 42 | 113 | 75 | 83 |
| ✓ |  | 20 | 17 | 15 | 2 | 7 | 9 |
| – |  | 1 | 18 | 13 | 0 | 27 | 20 |
| **Met** | 126 | **88** | **105** | **70** | **115** | **109** | **112** |
| 🧩 |  | 0 | 0 | 6 | 6 | 6 | 6 |
<!-- dictionary:end -->

## Contract members

A row per contract with properties or events - the tiers, then the elements -
naming them: a property by its modifier's name, an event with the `on…`
modifier it is heard through beside it. "Count" is how many members the row
names. An element's row counts them by mark on each host; a tier's carries no
mark, its members marked on the page of each element wearing it. A contract's
acts are under [Host acts](#host-acts); each member's own mark, its value and
its layer are on the element's page in [the control dictionary](controls/README.md).

<!-- members:begin -->
### Tiers

| Tier | Members | Count |
| --- | --- | --- |
| [PropertyContainer](controls/tiers/PropertyContainer.md) | `accessibilityIdentifier` | 1 |
| [VisualElement](controls/tiers/VisualElement.md) | `accessibilityHeading`, `accessibilityHint`, `accessibilityLabel`, `automationExcludedWithChildren`, `background`, `frame`, `height`, `ignoresInput`, `isAccessibilityHidden`, `isEnabled`, `isFocusedChanged`, `isVisible`, `layoutDirection`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `opacity`, `pivotX`, `pivotY`, `rotation`, `rotationX`, `rotationY`, `scale`, `scaleX`, `scaleY`, `style`, `translationX`, `translationY`, `width`, `zIndex` | 31 |
| [View](controls/tiers/View.md) | `allowsDrop`, `area`, `canDrag`, `onDragLeave` (`dragLeave`), `onDragOver` (`dragOver`), `dragStarting`, `dragText`, `onDrop` (`drop`), `onDragEnded` (`dragEnded`), `onFrameChanged` (`frameChanged`), `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`, `horizontalAlignment`, `margin`, `panTouchCount`, `onPanUpdated` (`panUpdated`), `panXChannel`, `panYChannel`, `onPinchUpdated` (`pinchUpdated`), `onPointerEntered` (`pointerEntered`), `onPointerExited` (`pointerExited`), `onPointerMoved` (`pointerMoved`), `onPointerPressed` (`pointerPressed`), `onPointerReleased` (`pointerReleased`), `swipeDirection`, `swipeThreshold`, `onSwiped` (`swiped`), `tapCount`, `onTapped` (`tapped`), `verticalAlignment` | 32 |
| [Layout](controls/tiers/Layout.md) | `avoidsSafeArea`, `clipsContent`, `letsInputThrough` | 3 |
| [Stack](controls/tiers/Stack.md) | `spacing` | 1 |
| [TextInput](controls/tiers/TextInput.md) | `cursorPosition`, `inputPurpose`, `isReadOnly`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `maximumLength`, `placeholder`, `placeholderColor`, `selectionLength`, `onTextChanged` (`textChanged`) | 10 |
| [Shape](controls/tiers/Shape.md) | `contentMode`, `fill`, `geometryTransform`, `stroke`, `dashPhase`, `dash`, `lineCap`, `lineJoin`, `miterLimit`, `lineWidth` | 10 |
| [TextualElement](controls/tiers/TextualElement.md) | `text`, `textCase` | 2 |
| [TextStyleElement](controls/tiers/TextStyleElement.md) | `tracking`, `textColor` | 2 |
| [FontElement](controls/tiers/FontElement.md) | `fontAttributes`, `isFontAutoScalingEnabled`, `fontFamily`, `fontSize` | 4 |
| [TextAlignmentElement](controls/tiers/TextAlignmentElement.md) | `horizontalTextAlignment`, `verticalTextAlignment` | 2 |
| [LineHeightElement](controls/tiers/LineHeightElement.md) | `lineHeight` | 1 |
| [DecorableTextElement](controls/tiers/DecorableTextElement.md) | `textDecorations` | 1 |
| [PaddingElement](controls/tiers/PaddingElement.md) | `padding` | 1 |
| [BorderElement](controls/tiers/BorderElement.md) | `shape`, `stroke`, `lineWidth` | 3 |
| [ImageElement](controls/tiers/ImageElement.md) | `contentMode` | 1 |
| [TintElement](controls/tiers/TintElement.md) | `tint` | 1 |
| [BarElement](controls/tiers/BarElement.md) | `barBackgroundColor`, `barForegroundColor`, `barIcon`, `barSubtitle`, `barTitle` | 5 |
| [MenuItemElement](controls/tiers/MenuItemElement.md) | `onClicked` (`clicked`), `icon`, `isDestructive`, `isEnabled`, `text` | 5 |
| [PageElement](controls/tiers/PageElement.md) | `icon`, `title` | 2 |

### Elements

| Element | Members | Count | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](controls/ActivityIndicator.md) | `isAnimating` | 1 | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Button](controls/Button.md) | `onClicked` (`clicked`), `icon`, `iconPosition`, `iconSpacing`, `lineBreak`, `onPressed` (`pressed`), `onReleased` (`released`) | 7 | 3 ✅ · 2 ✓ | 4 ✅ · 2 ✓ | 4 ✅ | 7 ✅ | 6 ✅ · 1 ✓ | 1 ✅ |
| [Canvas](controls/Canvas.md) | `onDragged` (`dragged`), `drawing`, `onPressed` (`pressed`), `onReleased` (`released`) | 4 | 1 ✅ · 3 ✓ | 1 ✅ · 3 ✓ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [CheckBox](controls/CheckBox.md) | `isOn`, `onToggled` (`toggled`) | 2 | 2 ✅ | 1 ✅ · 1 ✓ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ColorBox](controls/ColorBox.md) | `color`, `cornerRadius` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [DatePicker](controls/DatePicker.md) | `onClosed` (`closed`), `date`, `onDateChanged` (`dateChanged`), `format`, `isOpen`, `maximumDate`, `minimumDate`, `onOpened` (`opened`) | 8 | 3 ✅ · 1 ✓ | 4 ✅ | 5 ✅ · 3 ✓ | 7 ✅ · 1 ☑️ | 5 ✅ · 1 ☑️ · 2 ✓ | 4 ✅ |
| [Grid](controls/Grid.md) | `columnSpacing`, `columns`, `rowSpacing`, `rows` | 4 | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [Image](controls/Image.md) | `isAnimating`, `source` | 2 | 1 ✅ | 1 ✅ |  | 1 ✅ | 1 ✅ | 1 ✅ |
| [ItemsView](controls/ItemsView.md) | `items`, `itemsLayout`, `selectionMode`, `selectedItems`, `selectedItemsChanged`, `itemActivated`, `endReachedWithin`, `endReached`, `realizedChanged` | 9 | 5 ✅ · 4 ✓ | 5 ✅ · 4 ✓ | 8 ✅ · 1 ✓ | 9 ✅ | 9 ✅ | 8 ✅ · 1 ✓ |
| [Line](controls/Line.md) | `x1`, `x2`, `y1`, `y2` | 4 | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [Map](controls/Map.md) | `isScrollEnabled`, `showsTraffic`, `isZoomEnabled`, `onMapClicked` (`mapClicked`), `mapType`, `region`, `showsUserLocation` | 7 | 6 ✅ · 1 ✓ | 6 ✅ · 1 ✓ | 7 🧩 | 7 🧩 | 7 🧩 | 7 🧩 |
| [Marker](controls/Marker.md) | `onDetailsClicked` (`detailsClicked`), `label`, `location`, `onSelected` (`selected`), `subtitle`, `type` | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](controls/Menu.md) | `isEnabled`, `text` | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](controls/MenuBar.md) | `order` | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [ModalStack](controls/ModalStack.md) | `popped` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [NavigationStack](controls/NavigationStack.md) | `popped` | 1 | 1 ✓ | 1 ✅ |  | 1 ✅ | 1 ✅ | 1 ✅ |
| [Page](controls/Page.md) | `onAppearing` (`appearing`), `backButtonTitle`, `background`, `onDisappearing` (`disappearing`), `showsBackButton`, `showsNavigationBar`, `onNavigatedFrom` (`navigatedFrom`), `onNavigatedTo` (`navigatedTo`), `onNavigatingFrom` (`navigatingFrom`) | 9 | 7 ✅ | 9 ✅ | 8 ✅ · 1 – | 7 ✅ | 6 ✅ | 8 ✅ |
| [Path](controls/Path.md) | `data` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Picker](controls/Picker.md) | `onClosed` (`closed`), `isOpen`, `onOpened` (`opened`), `options`, `placeholder`, `selectedIndex`, `onSelectedIndexChanged` (`selectedIndexChanged`) | 7 | 3 ✅ · 1 ✓ | 1 ✅ · 3 ✓ | 3 ✅ · 1 ✓ | 7 ✅ | 3 ✅ · 4 – | 3 ✅ |
| [Polygon](controls/Polygon.md) | `fillRule`, `points` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Polyline](controls/Polyline.md) | `fillRule`, `points` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ProgressBar](controls/ProgressBar.md) | `progress` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [RadioButton](controls/RadioButton.md) | `groupName`, `isOn`, `onToggled` (`toggled`) | 3 | 3 ✅ | 2 ✅ · 1 ✓ | 3 ✅ | 3 ✅ | 3 ✅ |  |
| [Rectangle](controls/Rectangle.md) | `cornerRadius` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Scene](controls/Scene.md) | `activated`, `deactivated`, `stopped`, `windowClosed` | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [ScrollView](controls/ScrollView.md) | `horizontalScrollIndicator`, `orientation`, `scrollOffset`, `onScrollStopped` (`scrollStopped`), `scrollXChanged`, `scrollYChanged`, `verticalScrollIndicator` | 7 | 5 ✅ · 2 ✓ | 5 ✅ | 2 ✅ | 7 ✅ | 7 ✅ | 7 ✅ |
| [SearchField](controls/SearchField.md) | `submitLabel`, `onSubmitted` (`submitted`) | 2 | 1 ✅ · 1 – | 2 ✅ | 2 ✅ | 1 ✅ | 1 ✅ | 2 ✅ |
| [Slider](controls/Slider.md) | `onReleased` (`released`), `onPressed` (`pressed`), `maximum`, `minimum`, `value`, `onValueChanged` (`valueChanged`) | 6 | 4 ✅ | 4 ✅ · 2 ✓ | 4 ✅ | 4 ✅ | 4 ✅ · 2 – | 4 ✅ |
| [SplitView](controls/SplitView.md) | `showsSidebar`, `showsSidebarChanged` | 2 | 2 ✅ | 2 ✅ | 2 ✓ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Stepper](controls/Stepper.md) | `maximum`, `minimum`, `step`, `value`, `onValueChanged` (`valueChanged`) | 5 | 2 ✅ | 2 ✅ |  | 5 ✅ | 5 ✅ | 5 ✅ |
| [Switch](controls/Switch.md) | `isOn`, `onToggled` (`toggled`) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [TabView](controls/TabView.md) | `selectedTab`, `selectedTabChanged` | 2 | 1 ✅ · 1 ✓ | 2 ✅ |  | 2 ✅ | 2 ✅ | 2 ✅ |
| [Text](controls/Text.md) | `lineBreak`, `maximumLines` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [TextEditor](controls/TextEditor.md) | `growsWithText` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [TextField](controls/TextField.md) | `isPassword`, `submitLabel`, `showsClearButton`, `onSubmitted` (`submitted`) | 4 | 2 ✅ · 2 – | 4 ✅ | 3 ✅ · 1 – | 1 ☑️ | 2 ✅ | 3 ✅ |
| [TextSpan](controls/TextSpan.md) | `background` | 1 |  |  |  | 1 ✅ | 1 ✅ | 1 ✅ |
| [TimePicker](controls/TimePicker.md) | `onClosed` (`closed`), `format`, `isOpen`, `onOpened` (`opened`), `time`, `onTimeChanged` (`timeChanged`) | 6 | 1 ✅ · 1 ✓ | 2 ✅ | 5 ✅ · 1 ✓ | 2 ✅ | 4 ✅ · 1 ✓ | 2 ✅ |
| [ToolbarItem](controls/ToolbarItem.md) | `placement`, `showsText` | 2 | 1 – | 1 – |  | 2 ✅ | 2 ✅ | 2 ✅ |
| [ToolbarItemGroup](controls/ToolbarItemGroup.md) | `order`, `side` | 2 | 2 ✅ | 2 ✅ | 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [WebView](controls/WebView.md) | `canGoBackChanged`, `canGoForwardChanged`, `onNavigated` (`navigated`), `onNavigating` (`navigating`), `onProcessTerminated` (`processTerminated`), `source`, `userAgent` | 7 | 6 ✅ · 1 ✓ | 6 ✅ · 1 ✓ | 7 ✅ | 7 ✅ | 7 ✅ | 5 ✅ |
| [Window](controls/Window.md) | `activated`, `created`, `deactivated`, `destroying`, `floatsOnTop`, `height`, `hidesWhenInactive`, `isMaximizable`, `isMinimizable`, `isTranslucent`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `resumed`, `stopped`, `title`, `width`, `windowType`, `windowValue`, `x`, `y` | 22 | 15 ✅ · 6 ✓ | 3 ✅ · 4 ✓ · 9 – | 2 ✅ · 4 ✓ | 22 ✅ | 8 ✅ · 6 ✓ · 8 – | 3 ✅ · 4 ✓ · 15 – |
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

`ActivityIndicator`, `Application`, `Button`, `Canvas`, `CheckBox`, `ColorBox`,
`ContextMenu`, `DatePicker`, `Divider`, `Ellipse`, `Grid`, `HStack`, `Image`,
`ItemsView`, `Line`, `Map`, `Marker`, `Menu`, `MenuBar`, `MenuItem`,
`ModalStack`, `NavigationStack`, `Overlay`, `Page`, `Path`, `Picker`, `Polygon`,
`Polyline`, `ProgressBar`, `RadioButton`, `Rectangle`, `Scene`, `ScrollView`,
`SearchField`, `Slider`, `SplitView`, `Stepper`, `Switch`, `TabView`, `Text`,
`TextEditor`, `TextField`, `TextSpan`, `TextSpans`, `TimePicker`, `TitleView`,
`ToolbarItem`, `ToolbarItemGroup`, `VStack`, `WebView`, `Window`, `ZStack`.

### Properties

`accessibilityHeading`, `accessibilityHint`, `accessibilityIdentifier`,
`accessibilityLabel`, `allowsDrop`, `area`, `automationExcludedWithChildren`,
`avoidsSafeArea`, `backButtonTitle`, `background`, `barBackgroundColor`,
`barForegroundColor`, `barIcon`, `barSubtitle`, `barTitle`, `canDrag`,
`clipsContent`, `color`, `columns`, `columnSpacing`, `contentMode`,
`cornerRadius`, `cursorPosition`, `dash`, `dashPhase`, `data`, `date`,
`dragText`, `drawing`, `endReachedWithin`, `fill`, `fillRule`, `floatsOnTop`,
`fontAttributes`, `fontFamily`, `fontSize`, `format`, `frame`,
`geometryTransform`, `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`,
`groupName`, `growsWithText`, `height`, `hidesWhenInactive`,
`horizontalAlignment`, `horizontalScrollIndicator`, `horizontalTextAlignment`,
`icon`, `iconPosition`, `iconSpacing`, `ignoresInput`, `inputPurpose`,
`isAccessibilityHidden`, `isAnimating`, `isDestructive`, `isEnabled`,
`isFontAutoScalingEnabled`, `isMaximizable`, `isMinimizable`, `isOn`, `isOpen`,
`isPassword`, `isReadOnly`, `isScrollEnabled`, `isSpellCheckEnabled`,
`isTextPredictionEnabled`, `isTranslucent`, `isVisible`, `isZoomEnabled`,
`items`, `itemsLayout`, `label`, `layoutDirection`, `letsInputThrough`,
`lineBreak`, `lineCap`, `lineHeight`, `lineJoin`, `lineWidth`, `location`,
`mapType`, `margin`, `maximum`, `maximumDate`, `maximumHeight`, `maximumLength`,
`maximumLines`, `maximumWidth`, `minimum`, `minimumDate`, `minimumHeight`,
`minimumWidth`, `miterLimit`, `opacity`, `options`, `order`, `orientation`,
`padding`, `panTouchCount`, `panXChannel`, `panYChannel`, `pivotX`, `pivotY`,
`placeholder`, `placeholderColor`, `placement`, `points`, `progress`, `region`,
`rotation`, `rotationX`, `rotationY`, `rows`, `rowSpacing`, `scale`, `scaleX`,
`scaleY`, `scrollOffset`, `selectedIndex`, `selectedItems`, `selectedTab`,
`selectionLength`, `selectionMode`, `shape`, `showsBackButton`,
`showsClearButton`, `showsNavigationBar`, `showsSidebar`, `showsText`,
`showsTraffic`, `showsUserLocation`, `side`, `source`, `spacing`, `step`,
`stroke`, `style`, `submitLabel`, `subtitle`, `swipeDirection`,
`swipeThreshold`, `tapCount`, `text`, `textCase`, `textColor`,
`textDecorations`, `time`, `tint`, `title`, `tracking`, `translationX`,
`translationY`, `type`, `userAgent`, `value`, `verticalAlignment`,
`verticalScrollIndicator`, `verticalTextAlignment`, `width`, `windowType`,
`windowValue`, `x`, `x1`, `x2`, `y`, `y1`, `y2`, `zIndex`.

### Events

`activated`, `appearing`, `canGoBackChanged`, `canGoForwardChanged`, `clicked`,
`closed`, `created`, `dateChanged`, `deactivated`, `destroying`,
`detailsClicked`, `disappearing`, `dragEnded`, `dragged`, `dragLeave`,
`dragOver`, `dragStarting`, `drop`, `endReached`, `frameChanged`,
`isFocusedChanged`, `itemActivated`, `mapClicked`, `navigated`, `navigatedFrom`,
`navigatedTo`, `navigating`, `navigatingFrom`, `opened`, `panUpdated`,
`pinchUpdated`, `pointerEntered`, `pointerExited`, `pointerMoved`,
`pointerPressed`, `pointerReleased`, `popped`, `pressed`, `processTerminated`,
`realizedChanged`, `released`, `resumed`, `scrollStopped`, `scrollXChanged`,
`scrollYChanged`, `selected`, `selectedIndexChanged`, `selectedItemsChanged`,
`selectedTabChanged`, `showsSidebarChanged`, `stopped`, `submitted`, `swiped`,
`tapped`, `textChanged`, `timeChanged`, `toggled`, `valueChanged`,
`windowClosed`.

### Acts

`alert`, `announce`, `chooseAction`, `confirm`, `currentTime`,
`currentTimeZone`, `evaluateJavaScript`, `focus`, `goBack`, `goForward`,
`handlerFailed`, `hideOnScreenKeyboard`, `launchFile`, `launchLink`,
`moveToRegion`, `openFiles`, `persistSceneValue`, `persistValue`, `prompt`,
`readFile`, `reload`, `saveFile`, `scrollTo`, `unfocus`, `utcOffset`.
<!-- vocabulary:end -->
