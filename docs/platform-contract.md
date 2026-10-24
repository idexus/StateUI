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
| – | The member will never be met by that host's family - a phone with no menu bar, a desktop whose keyboard captions no return key, a view that takes no keyboard focus - and meets the contract there: the host's register, or the case that proved it absent, says why. |
| 🧩 | Left to the application: the platform ships no control for it - a map on Android Views, WinUI 3, GTK 4 and the Web, where each provider needs the application's own key - so the host makes none, and the application registers its own control with the host, as each host's page shows ([Android Views](hosts/android.md#controls-acts-and-events-registered-in-swift)). Shown in each total, it is not counted as met: what the user gets there is the application's. |
| ❌ | A test of the member failed on that host's last run; the note gives the first failure. |
| ◐ | Some of its tests proved it and another could not run or read; the note says which. |
| · | The driver cannot do or read what the test needs - not yet, or because the platform holds nothing the test reads; the note says which. |
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
also once a family's revision is raised in `revisions.txt` and its verdicts
turn ⌛. The
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
| [Anchor](controls/Anchor.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](controls/Application.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Button](controls/Button.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ButtonMenu](controls/ButtonMenu.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Canvas](controls/Canvas.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Capsule](controls/Capsule.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [CheckBox](controls/CheckBox.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](controls/ContextMenu.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [DatePicker](controls/DatePicker.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Ellipse](controls/Ellipse.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Fill](controls/Fill.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Grid](controls/Grid.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [HStack](controls/HStack.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Image](controls/Image.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ItemsView](controls/ItemsView.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [LayoutEngine](controls/LayoutEngine.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Line](controls/Line.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Map](controls/Map.md) | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 | 🧩 |
| [Marker](controls/Marker.md) | provider | ✅ | ✅ | 🧩 | 🧩 | 🧩 | 🧩 |
| [Menu](controls/Menu.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuBar](controls/MenuBar.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuItem](controls/MenuItem.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuSeparator](controls/MenuSeparator.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [NavigationStack](controls/NavigationStack.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Overlay](controls/Overlay.md) | structure | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](controls/Page.md) | adaptive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Path](controls/Path.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Picker](controls/Picker.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Polygon](controls/Polygon.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Polyline](controls/Polyline.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Popover](controls/Popover.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ProgressBar](controls/ProgressBar.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Rectangle](controls/Rectangle.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Scene](controls/Scene.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ScrollView](controls/ScrollView.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [SearchField](controls/SearchField.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Separator](controls/Separator.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Sheet](controls/Sheet.md) | adaptive | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Slider](controls/Slider.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Space](controls/Space.md) | stateUI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Spinner](controls/Spinner.md) | native | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
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
| [ToolbarButton](controls/ToolbarButton.md) | structure | ✓ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarGroup](controls/ToolbarGroup.md) | structure | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
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
around the split view. On AppKit and WinUI 3 a tab selector keeps the
toolkit's selected and unselected appearance; GTK 4 stands its switcher on a
bar painted as its header bar is, and UIKit, Android Views and Web paint
their tabs in the bar's colors. An unwritten background retains the native
material; StateUI does not ask a host to rasterize an arbitrary brush into
page chrome.

On AppKit a written bar color paints the bars alone: the band the title bar
and toolbar cover, the window's under a floating sidebar's glass and the
visible content's - a split view's detail. The window's background is the one
written for the window; on a translucent window it tints the window's
material, which shows around the sidebar and under the page. Text on a painted
band - the page's title, and the application's name and line at the trailing
edge - is in the declared `barForegroundColor`, else white or black by the
band's lightness.
On the system's material both keep the system's colors.

`ItemsView` is the native virtualized collection. It presents identified
items as a list, a row or a grid, and StateUI builds an item as the
platform's collection comes near it. Its host adapters map to `NSCollectionView`,
`UICollectionView`, `RecyclerView`, WinUI `ItemsView`, `GtkListView` or
`GtkGridView`, and a semantic DOM list/grid; each member's mark is its case's
verdict on that host, as for every element.

`ForEach`, `GeometryReader` and `GalleryView` are StateUI compositions or
readers rather than additional platform controls. The core implements them
once; their platform behavior depends only on the rows they use.
`LayoutEngine` is an element of StateUI's own - its arithmetic, its phase and
the hand that moves it are the core's - which every host stands on its ZStack,
and its row below says how far each host carries it.

## Native control mapping

The table names the native class or API that each host adapts for a StateUI
surface. It records no implementation status; the ✅ tables keep that. Each
column names the class its host creates. `custom` marks the host's own view
built on the class it names, `structure` a node that creates no native object
of its own, `the application's own, registered` an element the application
registers with that host, and `—` a toolkit without an honest native
counterpart. A host may still choose another class that preserves the same
contract.

| StateUI surface | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | --- | --- | --- | --- | --- | --- |
| `Application` / `Scene` | `NSApplication` / structure | `UIApplication` / structure, a `UIWindowScene` per window | structure / structure | `Application` / structure | `AdwApplication` / structure | `document` / structure |
| `Window` | `NSWindow` | `UIWindow` | `Activity` | `Window` | `AdwApplicationWindow` | fixed `<div>` over the browser window |
| `Page` | custom `NSView` | `UIViewController` | custom `ViewGroup` | custom `Panel` | custom `GtkWidget` in an `AdwToolbarView` | `<section>` |
| `NavigationStack` | custom `NSView` stack; title, back and actions in the window's `NSToolbar` | `UINavigationController` | custom `ViewGroup` stack + `Toolbar` | custom `Panel` stack; title, back and actions in the window's `TitleBar` | `AdwNavigationView` of `AdwNavigationPage`s | `<div>` stack; one History API entry to go back |
| `TabView` | `NSTabView`: tabless under a full-width select-one `NSSegmentedControl` beneath the toolbar - the split view detail's `NSSplitViewItemAccessoryViewController` where the tabbed view stands in a split view's detail, else the title bar's bottom accessory - with top tabs where no window serves it | `UITabBarController` | custom `ViewGroup` + `LinearLayout` tab row | custom `Panel` under a `SelectorBar` | `GtkStack` + `GtkStackSwitcher` | ARIA `tablist` of `<button>` tabs |
| `SplitView` | `NSSplitViewController` | `UISplitViewController` | custom `ViewGroup`: a drawer where narrow, beside where wide | `SplitView`, the sidebar in its pane: beside the detail from 1008 DIPs, over it where narrower | `AdwOverlaySplitView` | `<aside>` in a CSS grid: beside the detail from 900px wide, a drawer over it where narrower |
| `Sheet` | sheet `NSWindow` | `present(_:animated:)` | `FrameLayout` sheet over the activity | sheets of `ContentDialog`'s look in a `Grid` layer over the window | `AdwDialog` | `<dialog>` with `showModal()` |
| `Anchor` | structure | structure | structure | structure | structure | structure |
| `Overlay` | pass-through `NSView` above the page | pass-through `UIView` above the page | top child of a `FrameLayout` | top layer of a root `Grid` | custom `GtkWidget` in the window's `GtkOverlay` | `<div>` layered over the page |
| `Popover` | `NSPopover` | `UIPopoverPresentationController`, a popover on a phone too | `PopupWindow` | `Flyout` | `GtkPopover` | `<div popover>` |
| `ContextMenu`, `MenuBar`, `Menu`, `MenuItem` | `NSMenu` / `NSMenuItem` | `UIMenu` / `UIAction`; `UIContextMenuInteraction`; `UIMenuBuilder` menu bar | `ContextMenu` / `SubMenu` / `MenuItem`; a menu bar's menus in the `Toolbar` overflow | `MenuFlyout` / `MenuBar` | `GMenu` in a `GtkPopoverMenu`; a menu bar as a `GtkMenuButton` main menu | ARIA `menu` in a `popover`; a menu bar's menus under the bar's More button |
| `ButtonMenu` | `NSComboButton`, unified or split | `UIButton.menu`, opened by a tap or held | `PopupMenu` at the button, opened by a click or held | `DropDownButton`, `SplitButton` | `GtkMenuButton`, `AdwSplitButton` | `aria-haspopup` button opening an ARIA `menu`, or held for it |
| `Separator` | an `NSBox` separator | a hairline `UIView` in the separator color | a `View` in the theme's list divider | a line in `DividerStrokeColorDefaultBrush` | a `GtkSeparator` | `<hr>` |
| `MenuSeparator` | a separator `NSMenuItem` | a group break in a `UIMenu` | a group divider in a menu | `MenuFlyoutSeparator` | a section break in a `GMenu` | `role=separator` in an ARIA `menu` |
| `ToolbarGroup` / `ToolbarButton` | `NSToolbarItem`; `NSMenuToolbarItem` overflow | `UIBarButtonItemGroup` / `UIBarButtonItem` | `Toolbar` `MenuItem` | `CommandBar` `AppBarButton` in the `TitleBar` | `GtkButton` in an `AdwHeaderBar` | `<button>` in an ARIA `toolbar` |
| `ZStack` / `LayoutEngine` / `Fill` / `Space` | custom `NSView` | custom `UIView` | custom `ViewGroup` | custom `Panel` | custom `GtkWidget` | CSS grid, one shared cell |
| `VStack` / `HStack` | custom `NSView` | custom `UIView` | custom `ViewGroup` | custom `Panel` | custom `GtkWidget` | flexbox |
| `Grid` | custom `NSView` | custom `UIView` | custom `ViewGroup` | custom `Panel` | custom `GtkWidget` | CSS grid |
| `ScrollView` | `NSScrollView` | `UIScrollView` | `ScrollView` / `HorizontalScrollView` | `ScrollViewer` | `GtkScrolledWindow` | `overflow: auto` |
| `Text` / `TextSpans` / `TextSpan` | `NSTextField` label; `NSAttributedString` runs | `UILabel`; `NSAttributedString` runs | `TextView`; `SpannableStringBuilder` spans | `TextBlock`; `Run` inlines | `GtkLabel`; `PangoAttrList` runs | `<span>`; `<span>` runs |
| `Button` | `NSButton` | `UIButton` | `Button` | `Button` | `GtkButton` | `<button>` |
| `Image` | `NSImageView` | `UIImageView` | `ImageView` | `Image` | custom `GtkWidget` drawing a `GdkTexture` | `<img>` |
| `TextField` | `NSTextField` / `NSSecureTextField` | `UITextField` | `EditText` | `TextBox` / `PasswordBox` | `GtkEntry` | `<input type=text>` / `<input type=password>` |
| `TextEditor` | `NSTextView` in an `NSScrollView` | `UITextView` | multi-line `EditText` | multi-line `TextBox` | `GtkTextView` in a `GtkScrolledWindow` | `<textarea>` |
| `SearchField` | `NSSearchField` | `UISearchTextField` | one-line `EditText` with a search key | `AutoSuggestBox` | `GtkSearchEntry` | `<input type=search>` |
| `Picker` | `NSPopUpButton` | pop-up `UIButton` menu | `android.widget.Spinner` | `ComboBox` | `GtkDropDown` | `<select>` |
| `DatePicker` | `NSDatePicker` | `UIDatePicker` | `TextView` opening a `DatePickerDialog` | `CalendarDatePicker` | `GtkCalendar` in a `GtkMenuButton`'s `GtkPopover` | `<input type=date>` |
| `TimePicker` | `NSDatePicker` showing hour and minute | `UIDatePicker` in time mode | `TextView` opening a `TimePickerDialog` | `TimePicker` | an hour's and a minute's `GtkSpinButton` in a `GtkMenuButton`'s `GtkPopover` | `<input type=time>` |
| `Switch` | `NSSwitch` beside an `NSTextField` | `UISwitch` beside a `UILabel` | `Switch` | `ToggleSwitch` | `GtkSwitch` beside a `GtkLabel` | checkbox `<input>` with `role=switch` in a `<label>` |
| `CheckBox` | `NSButton` checkbox | `UIButton` with a box symbol | `CheckBox` | `CheckBox` | `GtkCheckButton` | `<input type=checkbox>` in a `<label>` |
| `Slider` | `NSSlider` | `UISlider` | `SeekBar` | `Slider` | `GtkScale` | `<input type=range>` |
| `Stepper` | `NSStepper` | `UIStepper` | custom `LinearLayout` of two `Button`s | `NumberBox` | `GtkSpinButton` | `<input role=spinbutton>` between two `<button>`s |
| `ProgressBar` | `NSProgressIndicator` bar | `UIProgressView` | horizontal `ProgressBar` | `ProgressBar` | `GtkProgressBar` | `<progress>` |
| `Spinner` | spinning `NSProgressIndicator` | `UIActivityIndicatorView` | indeterminate `ProgressBar` | `ProgressRing` | `GtkSpinner` | CSS ring with `role=progressbar` |
| `Canvas` | custom `NSView` drawing | custom `UIView` `draw(_:)` | custom `View` `onDraw(Canvas)` | custom `Panel` painting a Direct2D `SurfaceImageSource` | custom `GtkWidget` snapshot | `<canvas>` |
| `Rectangle` / `Capsule` / `Ellipse` | custom `NSView` drawing `NSBezierPath` | custom `UIView` masked by a `CAShapeLayer` | custom `View` drawing `Path` | `Shapes.Path` in a custom `Grid` | `GskPath` in a snapshot | inline SVG `<path>` |
| `Line` / `Path` / `Polygon` / `Polyline` | custom `NSView` drawing `NSBezierPath` | custom `UIView` masked by a `CAShapeLayer` | custom `View` drawing `Path` | `Shapes.Path` in a custom `Grid` | `GskPath` in a snapshot | inline SVG `<path>` |
| `Map` / `Marker` | `MKMapView` / `MKAnnotation` | `MKMapView` / `MKAnnotation` | the application's own, registered | the application's own, registered | the application's own, registered | the application's own, registered |
| `WebView` | `WKWebView` | `WKWebView` | `WebView` | `WebView2`, a backend | WebKitGTK `WebKitWebView`, a backend | `<iframe>` |
| `ItemsView` | `NSCollectionView` | `UICollectionView` | AndroidX `RecyclerView` | `ItemsView` | `GtkListView` / `GtkGridView` | ARIA `list` or `listbox` |
| `TitleView` | structure | structure | structure | structure | structure | structure |

### Completeness

Every element contract appears exactly once in the first column; each
element's page in the control dictionary takes its native counterparts from
here, and `ControlDictionaryTests` holds the table to that.

These surfaces lack an honest native counterpart on at least one target:

- `NavigationStack`: Android Views has no page-stack control; GTK 4 has one only in libadwaita, which its host requires.
- `TabView`: Android Views has no framework tab bar; Web has no tab element.
- `SplitView`: Android Views has no framework drawer or split pane, so its host lays out its own; Web has no native pane.
- `Sheet`: Android Views has no modal page presentation, so its host slides a sheet over the activity; WinUI 3 shows one `ContentDialog` at a time, so its host stacks sheets of a dialog's look over the window.
- The application's name and mark in the bar (`barTitle`, `barIcon`): UIKit, Android Views and GTK 4 give each page a bar of its own that names that page; Web shows no mark in its bar - the browser's tab shows the site's icon.
- Menus: Android Views has no menu bar, so a menu bar's menus join the bar's overflow; Web has no native menu element.
- `Grid`: AppKit, UIKit, and GTK 4 have no container with star and auto tracks.
- `CheckBox`: UIKit has no check box.
- `Stepper`: Android Views has no stepper - `NumberPicker` is an integer wheel - so its host sets two buttons side by side.
- `DatePicker`: GTK 4 has `GtkCalendar` but no date field.
- `TimePicker`: GTK 4 has no time picker; its host sets a time as GNOME's applications do, with spin buttons.
- `Switch`: Web has no switch element; AppKit's, UIKit's and GTK 4's switch says no words, so their hosts set its words beside it.
- `Spinner`: Web has no spinner - an indeterminate `<progress>` draws a bar - so its host draws a ring.
- `Map` / `Marker`: Android Views, WinUI 3, GTK 4 and Web have no map of the platform's own - Google Play services, Azure Maps and libshumate each need a provider and its key, and the DOM has no map element - so the application registers its own with the host, the pins as the map's children.
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

- `device.accessibility`: `reducesMotion`, `prefersHigherContrast`, `isScreenReaderOn`, `textScale`
- `device.battery`: `chargeLevel`, `state`, `powerSource`, `energySaverStatus`
- `device.connectivity`: `networkAccess`, `connectionProfiles`
- `device.display`: `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate`
- `device.info`: `formFactor`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `isVirtual`
- `locale`: `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric`, `layoutDirection`
- `application.info`: `name`, `packageName`, `versionString`, `buildString`, `colorScheme`, `accentColor`
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
| `focus` | [FocusElement](controls/tiers/FocusElement.md) |
| `unfocus` | [FocusElement](controls/tiers/FocusElement.md) |
| `alert` | [Application](controls/Application.md) |
| `announce` | [Application](controls/Application.md) |
| `cancelCall` | [Application](controls/Application.md) |
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
| `readClipboard` | [Application](controls/Application.md) |
| `readFile` | [Application](controls/Application.md) |
| `saveFile` | [Application](controls/Application.md) |
| `sendRequest` | [Application](controls/Application.md) |
| `share` | [Application](controls/Application.md) |
| `useAccentColor` | [Application](controls/Application.md) |
| `useColorScheme` | [Application](controls/Application.md) |
| `utcOffset` | [Application](controls/Application.md) |
| `writeClipboard` | [Application](controls/Application.md) |
| `scrollTo` | [ItemsView](controls/ItemsView.md) |
| `moveToRegion` | [Map](controls/Map.md) |
| `evaluateJavaScript` | [WebView](controls/WebView.md) |
| `goBack` | [WebView](controls/WebView.md) |
| `goForward` | [WebView](controls/WebView.md) |
| `reload` | [WebView](controls/WebView.md) |
<!-- acts:end -->

## Shared view members

A property or event of the three tiers every view wears -
[AutomationElement](controls/tiers/AutomationElement.md),
[VisualElement](controls/tiers/VisualElement.md) and
[View](controls/tiers/View.md) - is named here and marked on the page of each
view: every view realizes it apart, and one may have what another lacks. The
core view members are StateUI's own API, which a host serves without a member
of its own; no case gives them a verdict of their own, so no page marks them:

- identity: `id`
- aimed control methods: `aim`
- core reactions: `onCreated`, `onDestroying`, `onChanged`, `samples`, `engine`
- motion selection: `motion`, `MotionValues`
- focus feed: `isFocused`

<!-- shared:begin -->
| Member | Tier | Kind |
| --- | --- | --- |
| `accessibilityIdentifier` | [AutomationElement](controls/tiers/AutomationElement.md) | property |
| `accessibilityActionPerformed` | [VisualElement](controls/tiers/VisualElement.md) | event |
| `accessibilityActions` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `onAccessibilityAdjusted` (`accessibilityAdjusted`) | [VisualElement](controls/tiers/VisualElement.md) | event |
| `accessibilityHeading` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityHint` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityLabel` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityRole` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `accessibilityValue` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `background` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `frame` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `height` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `hidesChildrenFromAccessibility` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `ignoresInput` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `isAccessibilityHidden` | [VisualElement](controls/tiers/VisualElement.md) | property |
| `isEnabled` | [VisualElement](controls/tiers/VisualElement.md) | property |
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
| `tooltip` | [VisualElement](controls/tiers/VisualElement.md) | property |
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
| `droppedFileTypes` | [View](controls/tiers/View.md) | property |
| `onDragEnded` (`dragEnded`) | [View](controls/tiers/View.md) | event |
| `onDrop` (`filesDropped`) | [View](controls/tiers/View.md) | event |
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
| [Button](controls/Button.md) | 102 | 58 ✅ · 2 ☑️ · 37 ✓ · 3 – | 56 ✅ · 1 ☑️ · 39 ✓ · 5 – | 73 ✅ · 5 ☑️ · 14 ✓ · 4 – | 83 ✅ · 1 ☑️ · 13 ✓ · 5 – | 68 ✅ · 2 ☑️ · 26 ✓ · 6 – | 78 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Canvas](controls/Canvas.md) | 75 | 35 ✅ · 2 ☑️ · 38 ✓ | 34 ✅ · 2 ☑️ · 38 ✓ · 1 – | 59 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 15 ✓ · 5 – | 46 ✅ · 1 ☑️ · 22 ✓ · 6 – | 51 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Capsule](controls/Capsule.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ | 59 ✅ · 14 ✓ · 6 – | 50 ✅ · 1 ☑️ · 22 ✓ · 6 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [CheckBox](controls/CheckBox.md) | 82 | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 37 ✅ · 2 ☑️ · 38 ✓ · 5 – | 61 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 25 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [DatePicker](controls/DatePicker.md) | 91 | 46 ✅ · 2 ☑️ · 36 ✓ · 7 – | 36 ✅ · 1 ☑️ · 37 ✓ · 13 – | 66 ✅ · 5 ☑️ · 15 ✓ · 3 – | 70 ✅ · 3 ☑️ · 13 ✓ · 5 – | 57 ✅ · 2 ☑️ · 26 ✓ · 6 – | 62 ✅ · 1 ☑️ · 20 ✓ · 7 – |
| [Ellipse](controls/Ellipse.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ | 59 ✅ · 14 ✓ · 6 – | 50 ✅ · 1 ☑️ · 22 ✓ · 6 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Fill](controls/Fill.md) | 74 | 38 ✅ · 1 ☑️ · 35 ✓ | 37 ✅ · 1 ☑️ · 35 ✓ · 1 – | 58 ✅ · 5 ☑️ · 10 ✓ | 56 ✅ · 1 ☑️ · 14 ✓ · 3 – | 46 ✅ · 1 ☑️ · 21 ✓ · 6 – | 50 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Grid](controls/Grid.md) | 84 | 46 ✅ · 1 ☑️ · 35 ✓ | 43 ✅ · 1 ☑️ · 37 ✓ · 1 – | 64 ✅ · 5 ☑️ · 12 ✓ | 65 ✅ · 1 ☑️ · 13 ✓ · 4 – | 53 ✅ · 1 ☑️ · 23 ✓ · 7 – | 59 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [HStack](controls/HStack.md) | 81 | 43 ✅ · 1 ☑️ · 35 ✓ | 40 ✅ · 1 ☑️ · 37 ✓ · 1 – | 61 ✅ · 5 ☑️ · 12 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 4 – | 50 ✅ · 1 ☑️ · 23 ✓ · 7 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Image](controls/Image.md) | 74 | 36 ✅ · 2 ☑️ · 35 ✓ | 35 ✅ · 2 ☑️ · 35 ✓ · 1 – | 56 ✅ · 5 ☑️ · 10 ✓ | 53 ✅ · 14 ✓ · 6 – | 44 ✅ · 1 ☑️ · 22 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ItemsView](controls/ItemsView.md) | 89 | 43 ✅ · 2 ☑️ · 39 ✓ · 4 – | 40 ✅ · 2 ☑️ · 41 ✓ · 5 – | 69 ✅ · 5 ☑️ · 13 ✓ | 66 ✅ · 1 ☑️ · 13 ✓ · 8 – | 54 ✅ · 1 ☑️ · 23 ✓ · 9 – | 60 ✅ · 1 ☑️ · 21 ✓ · 6 – |
| [LayoutEngine](controls/LayoutEngine.md) | 90 | 38 ✅ · 1 ☑️ · 44 ✓ · 1 – | 37 ✅ · 1 ☑️ · 46 ✓ · 2 – | 61 ✅ · 5 ☑️ · 16 ✓ · 1 – | 53 ✅ · 1 ☑️ · 26 ✓ · 8 – | 46 ✅ · 1 ☑️ · 30 ✓ · 8 – | 58 ✅ · 2 ☑️ · 24 ✓ · 4 – |
| [Line](controls/Line.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 66 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 6 – | 53 ✅ · 1 ☑️ · 22 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Map](controls/Map.md) | 79 | 40 ✅ · 2 ☑️ · 36 ✓ · 1 – | 39 ✅ · 2 ☑️ · 36 ✓ · 2 – | 79 🧩 | 79 🧩 | 79 🧩 | 79 🧩 |
| [Path](controls/Path.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 66 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 6 – | 53 ✅ · 1 ☑️ · 22 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Picker](controls/Picker.md) | 93 | 50 ✅ · 2 ☑️ · 36 ✓ · 2 – | 42 ✅ · 3 ☑️ · 40 ✓ · 5 – | 66 ✅ · 6 ☑️ · 13 ✓ · 3 – | 74 ✅ · 1 ☑️ · 13 ✓ · 5 – | 56 ✅ · 1 ☑️ · 24 ✓ · 12 – | 64 ✅ · 1 ☑️ · 20 ✓ · 6 – |
| [Polygon](controls/Polygon.md) | 83 | 46 ✅ · 2 ☑️ · 35 ✓ | 45 ✅ · 2 ☑️ · 35 ✓ · 1 – | 67 ✅ · 5 ☑️ · 10 ✓ | 63 ✅ · 14 ✓ · 6 – | 54 ✅ · 1 ☑️ · 22 ✓ · 6 – | 59 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Polyline](controls/Polyline.md) | 83 | 46 ✅ · 2 ☑️ · 35 ✓ | 45 ✅ · 2 ☑️ · 35 ✓ · 1 – | 67 ✅ · 5 ☑️ · 10 ✓ | 63 ✅ · 14 ✓ · 6 – | 54 ✅ · 1 ☑️ · 22 ✓ · 6 – | 59 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ProgressBar](controls/ProgressBar.md) | 73 | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 57 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 13 ✓ · 6 – | 43 ✅ · 1 ☑️ · 23 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Rectangle](controls/Rectangle.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 66 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 6 – | 53 ✅ · 1 ☑️ · 22 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ScrollView](controls/ScrollView.md) | 88 | 42 ✅ · 3 ☑️ · 36 ✓ · 7 – | 44 ✅ · 1 ☑️ · 37 ✓ · 4 – | 66 ✅ · 5 ☑️ · 13 ✓ · 3 – | 66 ✅ · 1 ☑️ · 13 ✓ · 8 – | 55 ✅ · 1 ☑️ · 23 ✓ · 9 – | 58 ✅ · 1 ☑️ · 20 ✓ · 9 – |
| [SearchField](controls/SearchField.md) | 98 | 54 ✅ · 4 ☑️ · 35 ✓ · 2 – | 57 ✅ · 2 ☑️ · 37 ✓ · 2 – | 78 ✅ · 5 ☑️ · 12 ✓ · 1 – | 73 ✅ · 5 ☑️ · 13 ✓ · 7 – | 64 ✅ · 3 ☑️ · 25 ✓ · 6 – | 74 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Separator](controls/Separator.md) | 71 | 33 ✅ · 2 ☑️ · 35 ✓ · 1 – | 32 ✅ · 2 ☑️ · 35 ✓ · 2 – | 55 ✅ · 5 ☑️ · 10 ✓ | 50 ✅ · 1 ☑️ · 14 ✓ · 5 – | 42 ✅ · 1 ☑️ · 22 ✓ · 6 – | 47 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Slider](controls/Slider.md) | 83 | 42 ✅ · 2 ☑️ · 35 ✓ · 2 – | 37 ✅ · 2 ☑️ · 39 ✓ · 5 – | 62 ✅ · 5 ☑️ · 12 ✓ · 3 – | 62 ✅ · 1 ☑️ · 13 ✓ · 5 – | 49 ✅ · 1 ☑️ · 25 ✓ · 8 – | 59 ✅ · 20 ✓ · 4 – |
| [Space](controls/Space.md) | 74 | 38 ✅ · 1 ☑️ · 35 ✓ | 37 ✅ · 1 ☑️ · 35 ✓ · 1 – | 58 ✅ · 5 ☑️ · 10 ✓ | 56 ✅ · 1 ☑️ · 14 ✓ · 3 – | 46 ✅ · 1 ☑️ · 21 ✓ · 6 – | 50 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Spinner](controls/Spinner.md) | 73 | 33 ✅ · 2 ☑️ · 36 ✓ · 2 – | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 57 ✅ · 5 ☑️ · 10 ✓ | 51 ✅ · 1 ☑️ · 14 ✓ · 6 – | 44 ✅ · 1 ☑️ · 22 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Stepper](controls/Stepper.md) | 81 | 43 ✅ · 2 ☑️ · 35 ✓ · 1 – | 37 ✅ · 2 ☑️ · 37 ✓ · 5 – | 60 ✅ · 5 ☑️ · 12 ✓ · 3 – | 61 ✅ · 2 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 24 ✓ · 6 – | 57 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Switch](controls/Switch.md) | 82 | 43 ✅ · 2 ☑️ · 35 ✓ · 2 – | 38 ✅ · 2 ☑️ · 37 ✓ · 5 – | 60 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 24 ✓ · 7 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Text](controls/Text.md) | 89 | 50 ✅ · 2 ☑️ · 35 ✓ · 1 – | 51 ✅ · 1 ☑️ · 35 ✓ · 1 – | 72 ✅ · 5 ☑️ · 10 ✓ | 70 ✅ · 1 ☑️ · 13 ✓ · 5 – | 59 ✅ · 1 ☑️ · 23 ✓ · 6 – | 65 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TextEditor](controls/TextEditor.md) | 97 | 57 ✅ · 3 ☑️ · 35 ✓ · 2 – | 56 ✅ · 2 ☑️ · 37 ✓ · 2 – | 77 ✅ · 5 ☑️ · 12 ✓ · 1 – | 77 ✅ · 2 ☑️ · 13 ✓ · 5 – | 63 ✅ · 3 ☑️ · 25 ✓ · 6 – | 73 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TextField](controls/TextField.md) | 100 | 55 ✅ · 4 ☑️ · 35 ✓ · 3 – | 59 ✅ · 2 ☑️ · 37 ✓ · 2 – | 79 ✅ · 5 ☑️ · 12 ✓ · 2 – | 77 ✅ · 4 ☑️ · 13 ✓ · 5 – | 65 ✅ · 3 ☑️ · 25 ✓ · 7 – | 75 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TimePicker](controls/TimePicker.md) | 89 | 44 ✅ · 2 ☑️ · 36 ✓ · 7 – | 37 ✅ · 1 ☑️ · 37 ✓ · 10 – | 66 ✅ · 5 ☑️ · 13 ✓ · 3 – | 65 ✅ · 2 ☑️ · 13 ✓ · 5 – | 56 ✅ · 1 ☑️ · 25 ✓ · 6 – | 60 ✅ · 1 ☑️ · 20 ✓ · 7 – |
| [VStack](controls/VStack.md) | 81 | 43 ✅ · 1 ☑️ · 35 ✓ | 41 ✅ · 1 ☑️ · 36 ✓ · 1 – | 62 ✅ · 5 ☑️ · 11 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 4 – | 51 ✅ · 1 ☑️ · 22 ✓ · 7 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [WebView](controls/WebView.md) | 87 | 48 ✅ · 2 ☑️ · 36 ✓ · 1 – | 45 ✅ · 2 ☑️ · 38 ✓ · 2 – | 66 ✅ · 5 ☑️ · 12 ✓ · 3 – | 49 ✅ · 13 ✓ · 24 – | 56 ✅ · 1 ☑️ · 24 ✓ · 6 – | 57 ✅ · 1 ☑️ · 20 ✓ · 6 – |
| [ZStack](controls/ZStack.md) | 80 | 42 ✅ · 1 ☑️ · 35 ✓ | 39 ✅ · 1 ☑️ · 37 ✓ · 1 – | 60 ✅ · 5 ☑️ · 12 ✓ | 61 ✅ · 1 ☑️ · 13 ✓ · 4 – | 49 ✅ · 1 ☑️ · 23 ✓ · 7 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| ✅ |  | 1529 | 1458 | 2187 | 2126 | 1779 | 1989 |
| ✓ |  | 1250 | 1288 | 390 | 469 | 795 | 685 |
| – |  | 52 | 96 | 36 | 202 | 226 | 127 |
| **Met** | 2930 | **2831** | **2842** | **2613** | **2797** | **2800** | **2801** |
| 🧩 |  | 0 | 0 | 79 | 79 | 79 | 79 |

### Application structure

| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Anchor](controls/Anchor.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](controls/Application.md) | 24 | 12 ✅ · 11 ✓ · 1 – | 14 ✅ · 10 ✓ | 11 ✅ · 1 ☑️ · 11 ✓ · 1 – | 19 ✅ · 4 ✓ · 1 – | 16 ✅ · 6 ✓ · 1 – | 18 ✅ · 6 ✓ |
| [ButtonMenu](controls/ButtonMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](controls/ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](controls/Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](controls/Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](controls/MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](controls/MenuItem.md) | 9 | 8 ✅ · 1 ☑️ | 8 ✅ · 1 ☑️ | 7 ✅ · 2 – | 9 ✅ | 6 ✅ · 3 – | 9 ✅ |
| [MenuSeparator](controls/MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [NavigationStack](controls/NavigationStack.md) | 11 | 6 ✅ · 1 ☑️ · 1 ✓ · 2 – | 7 ✅ · 4 – | 6 ✅ · 1 ☑️ · 4 – | 9 ✅ · 2 – | 5 ✅ · 6 – | 10 ✅ · 1 – |
| [Overlay](controls/Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](controls/Page.md) | 13 | 10 ✅ | 13 ✅ | 12 ✅ · 1 – | 12 ✅ · 1 – | 10 ✅ · 2 – | 12 ✅ |
| [Popover](controls/Popover.md) | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [Scene](controls/Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [Sheet](controls/Sheet.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [SplitView](controls/SplitView.md) | 15 | 10 ✅ · 1 ☑️ · 3 – | 10 ✅ · 1 ✓ · 4 – | 5 ✅ · 2 ☑️ · 4 ✓ · 4 – | 11 ✅ · 2 ☑️ · 2 – | 7 ✅ · 2 ✓ · 6 – | 12 ✅ · 2 ☑️ · 1 – |
| [TabView](controls/TabView.md) | 12 | 7 ✅ · 1 ☑️ · 1 ✓ · 2 – | 8 ✅ · 4 – | 7 ✅ · 1 ☑️ · 4 – | 10 ✅ · 2 – | 6 ✅ · 6 – | 11 ✅ · 1 – |
| [TextSpan](controls/TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](controls/TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](controls/TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](controls/ToolbarButton.md) | 8 | 4 ✅ · 1 ✓ · 1 – | 6 ✅ · 1 ✓ · 1 – | 5 ✅ · 1 – | 8 ✅ | 6 ✅ · 1 ✓ · 1 – | 8 ✅ |
| [ToolbarGroup](controls/ToolbarGroup.md) | 5 | 3 ✅ | 3 ✅ | 2 ✅ · 1 ☑️ | 3 ✅ | 3 ✅ | 3 ✅ |
| [Window](controls/Window.md) | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 100 | 95 | 77 | 123 | 89 | 108 |
| ✓ |  | 22 | 20 | 20 | 5 | 17 | 10 |
| – |  | 10 | 21 | 30 | 9 | 32 | 18 |
| **Met** | 148 | **132** | **136** | **127** | **137** | **138** | **136** |
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
| [AutomationElement](controls/tiers/AutomationElement.md) | `accessibilityIdentifier` | 1 |
| [VisualElement](controls/tiers/VisualElement.md) | `accessibilityActionPerformed`, `accessibilityActions`, `onAccessibilityAdjusted` (`accessibilityAdjusted`), `accessibilityHeading`, `accessibilityHint`, `accessibilityLabel`, `accessibilityRole`, `accessibilityValue`, `background`, `frame`, `height`, `hidesChildrenFromAccessibility`, `ignoresInput`, `isAccessibilityHidden`, `isEnabled`, `isVisible`, `layoutDirection`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `opacity`, `pivotX`, `pivotY`, `rotation`, `rotationX`, `rotationY`, `scale`, `scaleX`, `scaleY`, `style`, `tooltip`, `translationX`, `translationY`, `width`, `zIndex` | 36 |
| [View](controls/tiers/View.md) | `allowsDrop`, `area`, `canDrag`, `onDragLeave` (`dragLeave`), `onDragOver` (`dragOver`), `dragStarting`, `dragText`, `onDrop` (`drop`), `droppedFileTypes`, `onDragEnded` (`dragEnded`), `onDrop` (`filesDropped`), `onFrameChanged` (`frameChanged`), `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`, `horizontalAlignment`, `margin`, `panTouchCount`, `onPanUpdated` (`panUpdated`), `panXChannel`, `panYChannel`, `onPinchUpdated` (`pinchUpdated`), `onPointerEntered` (`pointerEntered`), `onPointerExited` (`pointerExited`), `onPointerMoved` (`pointerMoved`), `onPointerPressed` (`pointerPressed`), `onPointerReleased` (`pointerReleased`), `swipeDirection`, `swipeThreshold`, `onSwiped` (`swiped`), `tapCount`, `onTapped` (`tapped`), `verticalAlignment` | 34 |
| [Layout](controls/tiers/Layout.md) | `ignoresSafeArea`, `clipsContent`, `letsInputThrough` | 3 |
| [Stack](controls/tiers/Stack.md) | `spacing` | 1 |
| [TextInput](controls/tiers/TextInput.md) | `cursorPosition`, `inputPurpose`, `isReadOnly`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `maximumLength`, `placeholder`, `placeholderColor`, `selectionLength`, `onTextChanged` (`textChanged`) | 10 |
| [Shape](controls/tiers/Shape.md) | `contentMode`, `geometryTransform`, `stroke`, `dashPhase`, `dash`, `lineCap`, `lineWidth` | 7 |
| [FilledShape](controls/tiers/FilledShape.md) | `fill` | 1 |
| [CorneredShape](controls/tiers/CorneredShape.md) | `lineJoin`, `miterLimit` | 2 |
| [TextualElement](controls/tiers/TextualElement.md) | `text`, `textCase` | 2 |
| [TextColorElement](controls/tiers/TextColorElement.md) | `textColor` | 1 |
| [FontElement](controls/tiers/FontElement.md) | `fontAttributes`, `fontWeight`, `textStyle`, `isFontAutoScalingEnabled`, `fontFamily`, `fontSize` | 6 |
| [TextAlignmentElement](controls/tiers/TextAlignmentElement.md) | `horizontalTextAlignment` | 1 |
| [LineHeightElement](controls/tiers/LineHeightElement.md) | `lineHeight` | 1 |
| [TrackingElement](controls/tiers/TrackingElement.md) | `tracking` | 1 |
| [DecorableTextElement](controls/tiers/DecorableTextElement.md) | `textDecorations` | 1 |
| [PaddingElement](controls/tiers/PaddingElement.md) | `padding` | 1 |
| [BorderElement](controls/tiers/BorderElement.md) | `shape`, `stroke`, `lineWidth` | 3 |
| [ImageElement](controls/tiers/ImageElement.md) | `contentMode` | 1 |
| [TintElement](controls/tiers/TintElement.md) | `tint` | 1 |
| [KeyboardElement](controls/tiers/KeyboardElement.md) | `keyPressed`, `keysTaken` | 2 |
| [FocusElement](controls/tiers/FocusElement.md) | `isFocusedChanged` | 1 |
| [RefreshElement](controls/tiers/RefreshElement.md) | `isRefreshEnabled`, `isRefreshing`, `onRefreshRequested` (`refreshRequested`) | 3 |
| [BarElement](controls/tiers/BarElement.md) | `barBackgroundColor`, `barButtonBackgroundColor`, `barForegroundColor`, `barIcon`, `barSubtitle`, `barTitle`, `toolbarStyle` | 7 |
| [MenuItemElement](controls/tiers/MenuItemElement.md) | `onClicked` (`clicked`), `icon`, `isEnabled`, `keyboardShortcut`, `role`, `text` | 6 |
| [PageElement](controls/tiers/PageElement.md) | `icon`, `title` | 2 |

### Elements

| Element | Members | Count | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: |
| [Button](controls/Button.md) | `onClicked` (`clicked`), `icon`, `iconPosition`, `iconSpacing`, `keyboardShortcut`, `lineBreak`, `menuKind`, `onPressed` (`pressed`), `onReleased` (`released`), `role`, `showsMenuArrow` | 11 | 8 ✅ · 2 ✓ · 1 – | 9 ✅ · 2 ✓ | 6 ✅ · 2 ✓ | 11 ✅ | 10 ✅ · 1 ✓ | 11 ✅ |
| [Canvas](controls/Canvas.md) | `onDragged` (`dragged`), `drawing`, `onPressed` (`pressed`), `onReleased` (`released`) | 4 | 1 ✅ · 3 ✓ | 1 ✅ · 3 ✓ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [CheckBox](controls/CheckBox.md) | `isOn`, `onToggled` (`toggled`) | 2 | 2 ✅ | 1 ✅ · 1 ✓ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [DatePicker](controls/DatePicker.md) | `onClosed` (`closed`), `date`, `onDateChanged` (`dateChanged`), `format`, `isOpen`, `maximumDate`, `minimumDate`, `onOpened` (`opened`) | 8 | 3 ✅ · 1 ✓ · 4 – | 4 ✅ | 5 ✅ · 3 ✓ | 7 ✅ · 1 ☑️ | 5 ✅ · 1 ☑️ · 2 ✓ | 4 ✅ · 3 – |
| [Grid](controls/Grid.md) | `columnSpacing`, `columns`, `rowSpacing`, `rows` | 4 | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [Image](controls/Image.md) | `isAnimating`, `source` | 2 | 1 ✅ | 1 ✅ |  | 1 ✅ | 1 ✅ | 1 ✅ |
| [ItemsView](controls/ItemsView.md) | `items`, `itemsLayout`, `selectionMode`, `selectedItems`, `selectedItemsChanged`, `itemActivated`, `endReachedWithin`, `endReached`, `realizedChanged` | 9 | 5 ✅ · 4 ✓ | 5 ✅ · 4 ✓ | 9 ✅ | 9 ✅ | 9 ✅ | 8 ✅ · 1 ✓ |
| [LayoutEngine](controls/LayoutEngine.md) | `handAxis`, `handMoved`, `handStepped`, `itemDrag`, `itemMoved`, `magnifies`, `pans`, `phase`, `pinchMoved`, `rotates` | 10 | 1 ✅ · 9 ✓ | 1 ✅ · 9 ✓ | 6 ✅ · 4 ✓ | 1 ✅ · 8 ✓ · 1 – | 3 ✅ · 7 ✓ | 5 ✅ · 1 ☑️ · 4 ✓ |
| [Line](controls/Line.md) | `x1`, `x2`, `y1`, `y2` | 4 | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [Map](controls/Map.md) | `isScrollEnabled`, `showsTraffic`, `isZoomEnabled`, `onMapClicked` (`mapClicked`), `mapType`, `region`, `showsUserLocation` | 7 | 6 ✅ · 1 ✓ | 6 ✅ · 1 ✓ | 7 🧩 | 7 🧩 | 7 🧩 | 7 🧩 |
| [Marker](controls/Marker.md) | `onDetailsClicked` (`detailsClicked`), `label`, `location`, `onSelected` (`selected`), `subtitle`, `type` | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](controls/Menu.md) | `isEnabled`, `text` | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](controls/MenuBar.md) | `order` | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](controls/MenuItem.md) | `isOn`, `onToggled` (`toggled`) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [NavigationStack](controls/NavigationStack.md) | `popped` | 1 | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Page](controls/Page.md) | `onAppearing` (`appearing`), `backButtonTitle`, `background`, `onDisappearing` (`disappearing`), `showsBackButton`, `showsCloseButton`, `showsNavigationBar`, `showsTitle`, `onNavigatedFrom` (`navigatedFrom`), `onNavigatedTo` (`navigatedTo`), `onNavigatingFrom` (`navigatingFrom`) | 11 | 9 ✅ | 11 ✅ | 10 ✅ · 1 – | 10 ✅ · 1 – | 9 ✅ · 1 – | 10 ✅ |
| [Path](controls/Path.md) | `data` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Picker](controls/Picker.md) | `onClosed` (`closed`), `isOpen`, `onOpened` (`opened`), `options`, `placeholder`, `presentation`, `selectedIndex`, `selectedIndexChanged` | 8 | 4 ✅ · 1 ✓ | 1 ✅ · 1 ☑️ · 3 ✓ | 3 ✅ · 1 ☑️ · 1 ✓ | 8 ✅ | 4 ✅ · 4 – | 5 ✅ · 3 – |
| [Polygon](controls/Polygon.md) | `fillRule`, `points` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Polyline](controls/Polyline.md) | `fillRule`, `points` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Popover](controls/Popover.md) | `isPresented`, `isPresentedChanged` | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [ProgressBar](controls/ProgressBar.md) | `progress` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Rectangle](controls/Rectangle.md) | `cornerRadius` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [Scene](controls/Scene.md) | `activated`, `deactivated`, `stopped`, `windowClosed` | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [ScrollView](controls/ScrollView.md) | `horizontalScrollIndicator`, `orientation`, `scrollOffset`, `onScrollStopped` (`scrollStopped`), `verticalScrollIndicator` | 5 | 4 ✅ · 1 ✓ | 3 ✅ | 5 ✅ | 5 ✅ | 5 ✅ | 5 ✅ |
| [SearchField](controls/SearchField.md) | `submitLabel`, `onSubmitted` (`submitted`) | 2 | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 1 ✅ · 1 ☑️ | 1 ✅ · 1 ☑️ | 2 ✅ |
| [Sheet](controls/Sheet.md) | `isPresented`, `isPresentedChanged` | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Slider](controls/Slider.md) | `onReleased` (`released`), `onPressed` (`pressed`), `maximum`, `minimum`, `value`, `onValueChanged` (`valueChanged`) | 6 | 4 ✅ | 4 ✅ · 2 ✓ | 6 ✅ | 4 ✅ | 4 ✅ · 2 – | 6 ✅ |
| [Spinner](controls/Spinner.md) | `isAnimating` | 1 | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [SplitView](controls/SplitView.md) | `showsSidebar`, `showsSidebarChanged`, `sidebarBackground`, `flyoutBackground`, `sidebarOverlays` | 5 | 4 ✅ · 1 – | 4 ✅ · 1 ✓ | 1 ☑️ · 4 ✓ | 3 ✅ · 2 ☑️ | 3 ✅ · 2 ✓ | 3 ✅ · 2 ☑️ |
| [Stepper](controls/Stepper.md) | `maximum`, `minimum`, `step`, `value`, `onValueChanged` (`valueChanged`) | 5 | 5 ✅ | 5 ✅ | 5 ✅ | 5 ✅ | 5 ✅ | 5 ✅ |
| [Switch](controls/Switch.md) | `isOn`, `onToggled` (`toggled`) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [TabView](controls/TabView.md) | `selectedTab`, `selectedTabChanged` | 2 | 1 ✅ · 1 ✓ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [Text](controls/Text.md) | `lineBreak`, `maximumLines`, `verticalTextAlignment`, `isSelectable` | 4 | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 4 ✅ | 4 ✅ |
| [TextEditor](controls/TextEditor.md) | `growsWithText` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [TextField](controls/TextField.md) | `isPassword`, `submitLabel`, `showsClearButton`, `onSubmitted` (`submitted`) | 4 | 2 ✅ · 1 ☑️ · 1 – | 4 ✅ | 3 ✅ · 1 – | 1 ✅ · 2 ☑️ | 2 ✅ · 1 ☑️ · 1 – | 3 ✅ |
| [TextSpan](controls/TextSpan.md) | `background` | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [TimePicker](controls/TimePicker.md) | `onClosed` (`closed`), `format`, `isOpen`, `onOpened` (`opened`), `time`, `onTimeChanged` (`timeChanged`) | 6 | 1 ✅ · 1 ✓ · 4 – | 2 ✅ | 5 ✅ · 1 ✓ | 2 ✅ | 4 ✅ · 1 ✓ | 2 ✅ · 3 – |
| [ToolbarButton](controls/ToolbarButton.md) | `showsText` | 1 | 1 – | 1 – |  | 1 ✅ | 1 ✅ | 1 ✅ |
| [ToolbarGroup](controls/ToolbarGroup.md) | `hidesWithSidebar`, `isEnabled`, `order`, `part`, `position` | 5 | 3 ✅ | 3 ✅ | 2 ✅ · 1 ☑️ | 3 ✅ | 3 ✅ | 3 ✅ |
| [WebView](controls/WebView.md) | `canGoBackChanged`, `canGoForwardChanged`, `onNavigated` (`navigated`), `onNavigating` (`navigating`), `onProcessTerminated` (`processTerminated`), `source`, `userAgent` | 7 | 6 ✅ · 1 ✓ | 6 ✅ · 1 ✓ | 7 ✅ | 7 ✅ | 7 ✅ | 5 ✅ |
| [Window](controls/Window.md) | `activated`, `background`, `created`, `deactivated`, `destroying`, `floatsOnTop`, `height`, `hidesWhenInactive`, `isMaximizable`, `isMinimizable`, `maximumHeight`, `maximumWidth`, `minimumHeight`, `minimumWidth`, `resumed`, `stopped`, `title`, `width`, `windowType`, `windowValue`, `x`, `y` | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
<!-- members:end -->

A one-axis `ScrollView` owns input along its enabled axis. When it is nested,
a dominant input on its disabled axis passes to the nearest enclosing scroller.
This behavior is part of the shared contract; no conformance case proves the
hand-off yet, so the `ScrollView` marks do not cover it.

## Complete host vocabulary

The inventory is rendered from the contracts: every node type an element
contract declares, and every name a member is declared under, so a review
sees a name enter or leave the contract. Each contract's `layer` says who
realizes the element and each of its members.

<!-- vocabulary:begin -->
### Controls and structural nodes

`Anchor`, `Application`, `Button`, `ButtonMenu`, `Canvas`, `Capsule`,
`CheckBox`, `ContextMenu`, `DatePicker`, `Ellipse`, `Fill`, `Grid`, `HStack`,
`Image`, `ItemsView`, `LayoutEngine`, `Line`, `Map`, `Marker`, `Menu`,
`MenuBar`, `MenuItem`, `MenuSeparator`, `NavigationStack`, `Overlay`, `Page`,
`Path`, `Picker`, `Polygon`, `Polyline`, `Popover`, `ProgressBar`, `Rectangle`,
`Scene`, `ScrollView`, `SearchField`, `Separator`, `Sheet`, `Slider`, `Space`,
`Spinner`, `SplitView`, `Stepper`, `Switch`, `TabView`, `Text`, `TextEditor`,
`TextField`, `TextSpan`, `TextSpans`, `TimePicker`, `TitleView`,
`ToolbarButton`, `ToolbarGroup`, `VStack`, `WebView`, `Window`, `ZStack`.

### Properties

`accessibilityActions`, `accessibilityHeading`, `accessibilityHint`,
`accessibilityIdentifier`, `accessibilityLabel`, `accessibilityRole`,
`accessibilityValue`, `allowsDrop`, `area`, `backButtonTitle`, `background`,
`barBackgroundColor`, `barButtonBackgroundColor`, `barForegroundColor`,
`barIcon`, `barSubtitle`, `barTitle`, `canDrag`, `clipsContent`, `columns`,
`columnSpacing`, `contentMode`, `cornerRadius`, `cursorPosition`, `dash`,
`dashPhase`, `data`, `date`, `dragText`, `drawing`, `droppedFileTypes`,
`endReachedWithin`, `fill`, `fillRule`, `floatsOnTop`, `flyoutBackground`,
`fontAttributes`, `fontFamily`, `fontSize`, `fontWeight`, `format`, `frame`,
`geometryTransform`, `gridColumn`, `gridColumnSpan`, `gridRow`, `gridRowSpan`,
`growsWithText`, `handAxis`, `height`, `hidesChildrenFromAccessibility`,
`hidesWhenInactive`, `hidesWithSidebar`, `horizontalAlignment`,
`horizontalScrollIndicator`, `horizontalTextAlignment`, `icon`, `iconPosition`,
`iconSpacing`, `ignoresInput`, `ignoresSafeArea`, `inputPurpose`,
`isAccessibilityHidden`, `isAnimating`, `isEnabled`, `isFontAutoScalingEnabled`,
`isMaximizable`, `isMinimizable`, `isOn`, `isOpen`, `isPassword`, `isPresented`,
`isReadOnly`, `isRefreshEnabled`, `isRefreshing`, `isScrollEnabled`,
`isSelectable`, `isSpellCheckEnabled`, `isTextPredictionEnabled`, `isVisible`,
`isZoomEnabled`, `itemDrag`, `items`, `itemsLayout`, `keyboardShortcut`,
`keysTaken`, `label`, `layoutDirection`, `letsInputThrough`, `lineBreak`,
`lineCap`, `lineHeight`, `lineJoin`, `lineWidth`, `location`, `magnifies`,
`mapType`, `margin`, `maximum`, `maximumDate`, `maximumHeight`, `maximumLength`,
`maximumLines`, `maximumWidth`, `menuKind`, `minimum`, `minimumDate`,
`minimumHeight`, `minimumWidth`, `miterLimit`, `opacity`, `options`, `order`,
`orientation`, `padding`, `pans`, `panTouchCount`, `panXChannel`, `panYChannel`,
`part`, `phase`, `pivotX`, `pivotY`, `placeholder`, `placeholderColor`,
`points`, `position`, `presentation`, `progress`, `region`, `role`, `rotates`,
`rotation`, `rotationX`, `rotationY`, `rows`, `rowSpacing`, `scale`, `scaleX`,
`scaleY`, `scrollOffset`, `selectedIndex`, `selectedItems`, `selectedTab`,
`selectionLength`, `selectionMode`, `shape`, `showsBackButton`,
`showsClearButton`, `showsCloseButton`, `showsMenuArrow`, `showsNavigationBar`,
`showsSidebar`, `showsText`, `showsTitle`, `showsTraffic`, `showsUserLocation`,
`sidebarBackground`, `sidebarOverlays`, `source`, `spacing`, `step`, `stroke`,
`style`, `submitLabel`, `subtitle`, `swipeDirection`, `swipeThreshold`,
`tapCount`, `text`, `textCase`, `textColor`, `textDecorations`, `textStyle`,
`time`, `tint`, `title`, `toolbarStyle`, `tooltip`, `tracking`, `translationX`,
`translationY`, `type`, `userAgent`, `value`, `verticalAlignment`,
`verticalScrollIndicator`, `verticalTextAlignment`, `width`, `windowType`,
`windowValue`, `x`, `x1`, `x2`, `y`, `y1`, `y2`, `zIndex`.

### Events

`accessibilityActionPerformed`, `accessibilityAdjusted`, `activated`,
`appearing`, `canGoBackChanged`, `canGoForwardChanged`, `clicked`, `closed`,
`created`, `dateChanged`, `deactivated`, `destroying`, `detailsClicked`,
`disappearing`, `dragEnded`, `dragged`, `dragLeave`, `dragOver`, `dragStarting`,
`drop`, `endReached`, `filesDropped`, `frameChanged`, `handMoved`,
`handStepped`, `isFocusedChanged`, `isPresentedChanged`, `itemActivated`,
`itemMoved`, `keyPressed`, `mapClicked`, `navigated`, `navigatedFrom`,
`navigatedTo`, `navigating`, `navigatingFrom`, `opened`, `panUpdated`,
`pinchMoved`, `pinchUpdated`, `pointerEntered`, `pointerExited`, `pointerMoved`,
`pointerPressed`, `pointerReleased`, `popped`, `pressed`, `processTerminated`,
`realizedChanged`, `refreshRequested`, `released`, `resumed`, `scrollStopped`,
`selected`, `selectedIndexChanged`, `selectedItemsChanged`,
`selectedTabChanged`, `showsSidebarChanged`, `stopped`, `submitted`, `swiped`,
`tapped`, `textChanged`, `timeChanged`, `toggled`, `valueChanged`,
`windowClosed`.

### Acts

`alert`, `announce`, `cancelCall`, `chooseAction`, `confirm`, `currentTime`,
`currentTimeZone`, `evaluateJavaScript`, `focus`, `goBack`, `goForward`,
`handlerFailed`, `hideOnScreenKeyboard`, `launchFile`, `launchLink`,
`moveToRegion`, `openFiles`, `persistSceneValue`, `persistValue`, `prompt`,
`readClipboard`, `readFile`, `reload`, `saveFile`, `scrollTo`, `sendRequest`,
`share`, `unfocus`, `useAccentColor`, `useColorScheme`, `utcOffset`,
`writeClipboard`.
<!-- vocabulary:end -->
