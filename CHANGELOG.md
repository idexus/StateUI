# Changelog

What each release changes for an application and for a host, newest first. A breaking change says how to move
over. StateUI is before 1.0: a release may break what the one before it promised, and says so here.

## 0.8.3 - 2026-11-09

### Breaking changes

- **A page's title is `.pageTitle(_:)`.** `.title(_:)` written on the view a page shows is `.pageTitle(_:)`, as
  `.pageIcon(_:)` and `.pageBackground(_:)` are: `SettingsPage().pageTitle("Settings")`. A map marker keeps its
  `.title(_:)`.
- **A page says no subtitle.** The line under a page's title is no longer offered: `View.subtitle(_:)` and
  `PageContract.subtitle` are gone, and a page says what it needs in its title or in its content. A map marker keeps
  its `subtitle`.
- **A sheet stands over the window's overlays.** Overlays declared on a window's page stand over every page it shows
  and under its sheets, on every platform; overlays declared on a sheet's page stand over that sheet, which on iOS,
  GTK and the Web they did not. An overlay meant to cover a sheet is declared on the sheet's page.

### New

- **A branch is written in its localization's language.** A `Localization` given with `.environment(_:)` says the
  language it speaks on its branch: a screen reader reads the words there in it and the platform sets them by its
  rules - every view on iOS, Windows and the Web, a text's words on the Mac, Android and GTK. The Web page says the
  browser's language until the application says its own. A host reads it as `LanguageElementContract.language`.
- What a host writes for the user itself - a split button's arrow, a map pin's details button, a save named nothing -
  speaks the user's language.

### Fixed

- Numbers: a number that is none - NaN or infinite - is no value to a view, and a number past what a toolkit counts
  no longer ends the process: a range's ends, a line limit, a prompt's bound, a grid's tracks, a day outside the
  years 1 to 9999, a font weight, a wheel, a hand, a map region off the globe, a stepped number on the Web, and sizes
  and spacing on GTK and WinUI.
- Pages and sheets: a sheet stays as the window is arranged anew; a sheet shown again shows its page on GTK and WinUI;
  the way back is named by the page beneath it; a page saying no title stays named on GTK; each group behind a bar's
  More is a section of its menu; a page's scroller keeps clear of the system bars as its axes change.
- A view whose root may change: a key reaches what it holds, the chrome reads its bars and tabs, a list item offers
  its swipe actions, and a sheet shows the arrangement it holds.
- Input: on Android a view with no hold or menu takes no long press; the keypad's Enter presses Return on Android and
  GTK; on the Web and WinUI a field turns into its case what is typed however the words come - a paste, an input
  method; a button whose role is taken away wears plain words again.
- State and time: a scene value holding a map keyed by a key type comes back as it went; a ticker ticks no further
  than its limit; a state's move arrives even when the last control carrying it leaves before the move begins; a new
  application starts without the theme and accent of the one before; the Apple hosts read the time on the Gregorian
  calendar whatever calendar the user reads; reading the time throws, rather than ending the process, where a host
  answers no number.
- Drawing, web views and maps: an arc's flags written together are read; a web view keeps the user's page as its
  host is told the whole tree again; a script answering NaN or a date no longer ends the application.
- Hosts: a picture keeps its size as Android's display density changes, and a window made again at the new density
  stands alone in its root; GTK paints a journey's style where it lands rather than adding to its style sheet every
  frame.

### Tooling

- CONTRIBUTING says how comments and design notes are written: under a quarter of a file's lines, with a reason, a
  trap or a rule in `docs/design` behind a `Design:` reference.
- The Gallery's window overlay sample opens a sheet with a notice of its own.

## 0.8.2 - 2026-11-08

### Breaking changes

- **Apple's systems from 26.4.** StateUI runs on iOS, iPadOS, Mac Catalyst and macOS 26.4 or newer: an application's
  manifest says `.iOS("26.4")`, `.macCatalyst("26.4")` and `.macOS("26.4")`. The Swift runtime of 26.0 to 26.2 stops
  the process where one isolated deinit runs inside another.
- **A control takes its purpose value once, in its initializer.** A text's words, a toggle's words and state, a
  slider's or a stepper's value, a picker's date or time, a line's ends, a canvas's drawing and a web view's address
  are given where the control is made; the modifiers that set them again, and a style's setters of them, are no
  longer offered.
- **Every kind is named a kind.** `MapType` is `MapKind`, `MarkerType` is `MarkerKind`, `WindowType` is `WindowKind`
  and `WebNavigationType` is `WebNavigationKind`; `Map.type`, `Marker.type` and a web navigation's `type` are `kind`.
- **Dates and times are read by a format.** `DateStyle` is `DateFormat`, and a time picker's `.format(_:)` takes a
  `TimeFormat` - `.short` unless said. A date picker's `minimumDate` and `maximumDate` are `minimum` and `maximum`.
- **A page's icon is `pageIcon`.** `.icon(_:)` on a view that stands as a page is `.pageIcon(_:)`; a button's
  `icon` is its own picture.
- **A drop is heard as it happens.** `.onDragOver`, `.onDragLeave` and `.onDrop` are `.onDragEntered`,
  `.onDragExited` and `.onDropped`.
- **A view's presence to accessibility is one setting.** `.isAccessibilityHidden(_:)` and
  `.hidesChildrenFromAccessibility(_:)` are `.accessibilityPresence(_:)`: `.element`, `.hidden` or
  `.hiddenWithContents`.
- **The debug inspector says so.** `InspectorButton` is `DebugInspectorButton`, `Inspector.Place` is
  `DebugInspector.Place` and `ToolbarButton.inspector` is `.debugInspector`; a window's inspector is
  `window.debugInspector`, the place it shows in or nil, where `openInspector()`, `closeInspector()`,
  `toggleInspector()` and `isInspectorOpen` stood.
- **An event is written one way.** A policy is always `policy:`, after the event's own arguments, and every event is
  heard plainly, with a policy or through a gate. `Picker.onSelectedIndexChanged` is `.onSelectionChanged`. A swipe
  hears a `SwipeDirections` set and reports the one direction it took.
- **Motion says what moves.** A motion layout's `.motion(_:)` for its parameters is `.parameterMotion(_:)`;
  `.followsLayout(response:damping:)` is `.layoutBody(.followsLayout(response:damping:))`. `LayoutInput`'s
  `pointsPerUnit:` is `lengthPerUnit:`. `Motion.custom`, `LayoutInput.Travel` and `MotionLanes` are gone.
- **A clock reads in seconds.** `EngineCycle.now`, `.elapsed` and `.mostElapsed` are `nowSeconds`, `elapsedSeconds`
  and `mostElapsedSeconds`. `Ticker.isRepeating` is gone: a delay is a ticker with `limit: 1`, and `$ticker.interval`
  and `$ticker.limit` are bindings.
- **A fact says what is; a request may be nil.** `application.info.versionString` and `buildString` are `version`
  and `build`, `device.info.versionString` is `platformVersion`. `LocaleChoice` and `ColorScheme.system` are gone: a
  locale choice and `application.colorScheme` are nil to follow the system. `LocaleTag.direction` and
  `LocaleInfo.layoutDirection` are `writingDirection`, a `WritingDirection`.
- **The platform's own choice reads automatic.** `GridLength.auto`, `GridTracks.auto`, `InputPurpose.default`,
  `SubmitLabel.default` and `ToolbarStyle.system` are `.automatic`; `TextCase.default` is `.none`.
- **Drawing speaks a transform's words.** `Draw.saveState()`, `.restoreState()`, `.translateBy` and `.scaleBy` are
  `saveGraphics()`, `restoreGraphics()`, `translate` and `scale`, with `scaleX` and `scaleY`.
- **Aims say where.** `Aim.scrollTo` is `scroll(to:anchor:)` and `Aim.moveToRegion` is `show(_:)`.
- **A color is a background.** Every background takes a color or a brush; `Brush.solidColor` is gone.
- **The application's surface names no host value.** Values only a host reads - a selection's mode, a corner's
  radii, a web view's source, a kept value's kind - leave what an application writes; every view slot is a builder,
  and every carried property takes a state.
- **Host authors.** An element wears tiers - `RangeElement`, `PopupElement`, `PressElement`, `ToggleElement`,
  `SubmitElement` and the others - and a member's key names its contract (`Text.maximumLines`). A state crosses to a
  control by its `StatePassage`. A head imports StateUI by name and starts its host by the host's name; Android's
  `Java.call` is generic over the answer it reads. The host layer fills in a range's unsaid ends, and each host's
  module stands recorded in `lib/StateUI/exports/api/`.

### New

- `.accessibilityPresence(_:)`, `SwipeDirections`, `WritingDirection`, `Menu.joins(_:)` to place a menu in the
  platform's, `ButtonRole.normal`, and the window's and session's own settings as bindings (`window.$title`,
  `$width`, `$height`, `application.$colorScheme`, `localization.$language`).

### Fixed

- Identity: no key holds a NUL, a value stands in one place under one provider, a rebuilt element's key stands once
  on its walk, and a host's tokens stand apart from an author's ids.
- Lists: a list shows the header it was last given, an item's value stands once, the end is told again as items come
  or go, and a collection's handlers run in the order written.
- Handlers: each composed handler has a gate of its own, a handler no longer written ends its runs, a run superseded
  in its first step is cancelled, and an aimed act begins on the control standing then.
- Text and locale: a language tag is read as BCP 47 writes it, every host tells the user's languages in order, a
  year or a number of any size round-trips through its text, and typed words are counted as they stand.
- Input: what began on a view ends as it is disabled, a gesture taken away stays away to its end, and on the Mac
  input meets a view where it is drawn and a flattened view takes none.
- Hosts: the keyboard is found in a sheet over a stack, a hidden element says nothing of its own, a drawing's pixels
  keep no view that left, an arc of any angle is drawn at once, a web view reloads its current source, and on WinUI
  a list's rows and a popover draw no line along their top.

### Tooling

- The test window acts as its user can and waits for the work an act began; a closed test window leaves no work
  behind.
- The VS Code extension, the scripts and the manifests name one floor, which `ToolchainTests` holds.

## 0.8.1 - 2026-11-02

### Breaking changes

- **The clock is the application's.** `ClockTime.now()` is `application.clock.now()`, the day
  `application.clock.today()`, and `TimeZoneInfo.utcOffset(of:on:)` is `application.clock.utcOffset(of:on:)`, its zone
  a `TimeZoneName`. The user's zone is `locale.timeZone`, a `TimeZoneName?`, nil until the host has said;
  `TimeZoneInfo` is gone. Host authors: `ApplicationContract.currentTimeZone` is gone, and `currentTime` answers year,
  month, day, hour, minute, second and millisecond; `ActToolkit.localTime()` answers a `LocalTime`.
- **An application registers itself.** Each head names its application with `NotesApp.register()` - the type is
  public, with a `public init()` the protocol now asks for; `registerApplication()` is gone. An act of the
  application's is `application.call(_:_:)`, awaited, or `application.tell(_:_:)`, not awaited; `stateUICall` and
  `stateUISend` are gone. `stateUIVersion()` is `application.info.libraryVersion`, and `stateUIPlatform()` is
  `device.info.platform` with `device.info.architecture`.
- **Every session stands in one phase.** `SessionPhase` - `.active`, `.inactive`, `.background` - is the
  application's, a scene's and a window's; `ApplicationPhase`, `ScenePhase` and `WindowPhase` are gone. A window's
  `.created`, `.activated`, `.deactivated`, `.stopped`, `.resumed` and `.destroying` read as `.inactive`, `.active`,
  `.inactive` and `.background`: save on `.background`. Host authors: `WindowContract.resumed` is gone.
- **A tap is a tap.** `Map.onMapClicked { }` is `Map.onLocationTapped { location in }`;
  `MotionLayout.onItemTapped { item in }` is `onItemActivated { id in }`, and `onItemDragged` and `onItemDismissed`
  hand the item's identity as a list's and a gallery's events do - `ItemDrag<ID>`'s `id` and `over`, its `speed` now
  `velocity`. Host authors: `MapContract.mapClicked` is `locationTapped`.
- **A gesture tells points.** `PanUpdate`'s `totalX` and `totalY`, `velocityX` and `velocityY` are `total` and
  `velocity`, each a `Point`, and `at` says where the press is now; `PinchUpdate.scaleOrigin` is `pivot`. A canvas
  hears a press as every view does: `Canvas.onPressed`, `.onDragged` and `.onReleased` are gone - `.onPointerPressed`,
  `.onPanUpdated`'s `at` and `.onPointerReleased` tell it, in the canvas's own points. Host authors:
  `CanvasContract.pressed`, `.dragged` and `.released` are gone; `ViewContract.panUpdated` carries where the press
  is, and `HeardInput.drag` takes `from:`, where the press began.
- **A conversion is written with its way back, in the source's type.** `$x.convert { … }.convertBack { … }` is
  `$x.convert { … } back: { … }`, or `convert(_:back:)`; `back` is `(Out) -> Value`, so a way back answering another
  type no longer compiles, and a way back that comes and goes is one call, `back: editing ? { … } : nil`.
  `.multi($a, $b).convert { … }.convertBack { … }` is `.multi($a, $b).convert(_:back:)`.
- **A scroller names its axes as a set.** `.orientation(.horizontal)` is `.axes(.horizontal)`, `.both` is `.all`
  and `.neither` is `[]` (`ScrollAxes`); `LayoutInput.Orientation` is `Orientation`. Host authors:
  `ScrollViewContract.orientation` is `axes`, its value bits.
- **One word names an address.** `WebView(_ address:)`, `.source(_ address:)` and `.source(html:baseAddress:)`, a
  navigation's `address`, `Link(_:address:)`, `share(address:)` and `share(text:address:)`. Host authors:
  `LinkContract.destination` is `address`, `WebViewSource.url` is `.address`, and `ApplicationContract.launchLink` is
  `launchAddress`.
- **A library error names its reason as a case:** `StateUIError` is `.notPerformed(act:reason:)`,
  `.unreadableAnswer(act:answered:declared:)`, `.aimOnNoView`, `.aimOnTwoViews`, `.noItem` or
  `.writesWhileBuilding`, and its `description` says the words; `StateUIError.message` and `StateUIError(message:)`
  are gone.
- **What the host has not said is nil.** `device.battery.chargeLevel` - also where no battery stands - and
  `device.display.width`, `height`, `density` and `refreshRate` are optional: no `-1` or `0` stands for a fact.
- **The user's language is a tag.** `locale.language` is a `LocaleTag?` - `locale.language?.region` is the region,
  `.identifier` the whole tag; `LocaleInfo.region` and `LocaleInfo.name` are gone.
- A list's parts are sections: `ItemsView(groups:)` is `ItemsView(sections:)`, and `scrollTo(_:inGroup:)` is
  `scrollTo(_:inSection:)`.
- `.bottomBar(edge:)` is `.bottomBar(scrollEdge:)`. Host authors: `BottomBarContract.edge` is `scrollEdge`.
- An event's handler takes no label: `accessibilityAction("Clear") { }`, `.onKeyPressed([.escape]) { }` - a list of
  keys - and `.onVisualStateChanged([.pressed]) { }`, a list of states; none hears every state.
- `.eased(length, curve)` is `.eased(length, curve: curve)`; `.followsLayout(.spring(response:damping:))` is
  `.followsLayout(response:damping:)`, on a view and on `LayoutBody`; `clipboard.text()` and `write(text:)` are
  `read()` and `write(_:)`; `Asks` is `Cadence`; `GalleryArrangement.default` is `.wheel`; `confirm`'s `accept:` and
  every question's `message:` may be left out. `State.get()` is gone - read `wrappedValue`.
- A marker's `.label(_:)` is `.title(_:)`, and a map's `.mapType(_:)` is `.type(_:)`, as a marker's is. Host authors:
  `MarkerContract.label` is `title`, and `MapContract.mapType` is `type`.
- A line is drawn between two points, `Line(from: Point(0, 0), to: Point(240, 0))`: `.x1`, `.y1`, `.x2` and `.y2`
  are `.from(_:)` and `.to(_:)`, each a `Point` or its state. Host authors: `LineContract.x1` to `y2` are `from` and
  `to`.
- An area is a rectangle: `.area(.absolute(Rect(16, 16, 120, 40)))`, `.proportional(Rect(0.5, 0, 0.5, 1))`.
- `Color(red:green:blue:alpha:)` is `Color(red:green:blue:opacity:)`, its opacity from 0 to 1 as everywhere else.
- `ProgressBar($done)` and `Spinner($loading)` take a state, as `Slider($v)` does.
- `.draggable(text:canDrag:onDragStarting:)` is `.dragText(_:)`, `.isDraggable(_:)` and `.onDragStarting { }`. Host
  authors: `ViewContract.canDrag` is `isDraggable`.
- An initializer names what its builder builds - `Group(content:)`, `GeometryReader(content:)`,
  `Canvas(drawing:)`, `StyleSheet(styles:)`, `ToolbarGroup(items:)`; a trailing closure reads as before.
- On Android `clipboard.read()` throws where the window is not in focus - the platform hands it nothing - in place
  of answering nil.
- Extension authors: `StyleBag` is `Styling`, and `StyleBase` and `StyleState` are `StyleScope.Whole` and
  `StyleScope.VisualState` - `extension Styling: MyControlProperties where Target == MyControl {}`. `StyleTarget`
  requires `static var nodeType: NodeType` in place of `init()`: an application's own control writes
  `extension RatingBar: StyleTarget { public static var nodeType: NodeType { RatingBarContract.nodeType } }`.
  `PersistentValue.init?(persisted:)` is `init?(persistentValue:)` - a kept value converts as `carried` and
  `init?(carried:)`, `propValue` and `init?(propValue:)` do.

### New

- [Extending StateUI](docs/interface/extending.md) adds an element, a value and the application's own acts and
  events - the second public surface, which the library's own controls are written with; the handbook names every
  public type.
- `ItemsView` and `MotionLayout` are style targets: `Style<ItemsView<String>>()`.
- A question's own buttons and the Mac's menu bar speak the user's language where the application names no words.
- [StateUI for VS Code](docs/editors/VSCode/README.md) is the extension's handbook page, and the extension carries
  it as its readme.

### Fixed

- A chain of conversions follows its first source, a way back no longer written goes, and a conversion nobody read
  lets its source go.
- Two items of an `ItemsView` that describe alike are two items, each keeping its identity as the order changes;
  only the same value twice is said.
- An id stays with the view it is written on, a list's included, whether its lifetime is written before it or
  after.
- A `TextField` or `SearchField` nothing sizes is at least twenty digits wide, its placeholder too, on every host.
- GTK, WinUI and the Web read the time zone again as the application comes back to the front, and WinUI the
  languages.
- A cell no grid has - a row or a column before the first, a span of none, an index past the grid - stands in the
  nearest one there is, said once.
- A task cancelled while it waits for a movement's `arrived()` stops waiting alone; the others hear the end.
- A motion layout hands no host a number that is not finite; a read through a part of an element gone answers the
  element as it last stood.
- A window for a value never stands without one; a link stands at its words' size.
- Pictures cost less memory on Apple's platforms: macOS keeps no bitmap of every size an SVG or a PDF was drawn at
  (the Gallery's footprint after its heaviest samples: 475 MB -> 178 MB), pictures nothing shows are kept within one
  budget of forty million pixels on macOS and iOS, and a picture still shown on iOS is not decoded again after
  memory pressure.
- A WinUI picture opens drawn once, at the size it shows at; a Web page's bar at its foot leaves with its page, and
  the Web relay answers every request once.

### Tooling

- The VS Code extension stands in `editors/VSCode`, `editors/` holding each editor's extension: it is built from a
  checkout by `cd editors/VSCode`, `npm ci` and `npm run package`. An extension installed before this release looks
  for its sources in `lib/StateUI.VSCode`, so it is built and installed once by hand. It restarts the Swift language
  server once more where the Swift extension's restart is refused while the server loads its packages - the first
  activation in a fresh clone failed so.
- The public API stands recorded in two files, `lib/StateUI/exports/api/StateUI.txt` - what an application writes -
  and `StateUI.extending.txt`, what an extension writes.
- A conformance case that pans, pinches or turns two fingers reads the gesture's speed off a still clock, the same on
  every machine; CI runs every Web conformance family.
- CONTRIBUTING says where a feature's pull request is finished: on its own branch where it allows edits by
  maintainers, else on a `feature/<issue>-<short-name>` branch.

## 0.8.0 - 2026-10-31

### Breaking changes

- **A state is lent whole, or its value is handed with an event.** Every member that takes a state takes a
  `Binding<Value>` made from a `@State`: `$name`, or `contact.$name` where a class declares `@State var name`.
  `$state.member` and `$state[i]` are a `StatePart`, which reads, writes and posts but which no member takes, and
  `Binding(get:set:)` is gone. A value that crosses to the host as it is - words, a switch, a number, a date, a
  time, a color - may instead be given as a plain value, the user's change heard in its event:
  `TextField(chore.title).onTextChanged { … }`, `CheckBox(todo.done).onToggled { … }`. A choice the library
  translates - a picker's item, a list's selection, a tab, a stack's pages, a sheet - takes the state alone. Move
  over: make the field a control edits a `@State` of a class, or hand its value and write the change back in the
  event. `@Environment` has no projected value - a provided object's field is `model.$field` - and
  `ApplicationSession.colorScheme` and `.accentColor` are states (`Picker(themes, selection:
  application.$colorScheme)`).
- **A split view shows its sidebar by a modifier.** `SplitView($showsSidebar, sidebar: …, detail: …)` is
  `SplitView(sidebar: …, detail: …).showsSidebar($showsSidebar)`; `flyoutBackground` is
  `sidebarOverlayBackground`.
- **A tab view is typed by its tab** (`TabView<Tab>`), and its `.selection(_:)` takes a state of that type.
- **A window kind names the value it opens for.** `WindowType<Value>` is declared in an extension -
  `extension WindowType where Value == Note { static let note = WindowType("note") }` - and
  `WindowGroup(.note, for: Note.self) { $note in … }` is `WindowGroup(.note) { $note in … }`.
- **A handler's policy stands alone.** `.onClicked(gate: .ignoreWhileRunning) { … }` is
  `.onClicked(.ignoreWhileRunning) { … }`; after an event's own arguments it is `policy:`
  (`.onTapped(count: 2, policy: .waitForPrevious)`); `.none` is `.runConcurrently`; and `gate:` takes only a shared
  `Gate(.ignoreWhileRunning)`, what was `Gatekeeper`.
- **The layout worked out from parameters is `MotionLayout`.** Move over by renaming:

  | Before | Now |
  |---|---|
  | `LayoutEngine` | `MotionLayout` |
  | `LayoutPhase` | `LayoutParameters` |
  | the generic parameter `Phase` | `Parameters` |
  | `LayoutPlaces`, `LayoutPlaces.limits` | `AxisValues`, `AxisValues.endpoints` |
  | the axis's `wraps:` | `periodic:` |
  | `LayoutInput.Axis` | `LayoutInput.Orientation` |
  | `ItemDragStart.across`, `.held` | `.perpendicular`, `.longPress` |

  A throw goes on by one law for the whole layout: `.throwMotion(_:)` replaces the `throwing:` argument of every
  `LayoutInput` (`.magnification(throwing:)` is gone), and a `GalleryView`'s `.throwing(_:)` is `.throwMotion(_:)`.
  A gallery's `onItemTapped { item in }` is `onItemActivated { id in }`, handed the card's identity.
- **A motion is compared, never read apart.** `Motion.law`, `.curve`, `.factor`, `.isInherited`, `.isCustom`,
  `.length` and `Motion.Law` are gone (`motion == .none`). A law given to `move(to:_:)` is that move's alone: a plain
  assignment after it travels on the value's own law. `Sync`, the `sync:` of `engine(following:)` and
  `engine(tracking:)`, and `EngineCycle.sync` are gone - an engine runs on the display's frame.
- **Several sources convert through `multi` alone.** `$a.convert(with: $b) { … }` is `.multi($a, $b).convert { … }`,
  and journeys alike.
- **Controls named for what they show.** `Spacer` is `Space` - it alone grows along a stack - and `Fill` takes the
  room it is offered; `ActivityIndicator` is `Spinner`; `PositionIndicator` is `PositionDots`, with `.dotColor`,
  `.currentDotColor`, `.dotSize`, `.dotShape` and `DotShape`; `Divider` is `Separator`. `RadioButton` and
  `groupName` are gone: a choice among few is `Picker(...).presentation(.radio)`, and `CheckBox` and `Switch` say
  their words with `.text(_:)`.
- **A side follows the direction.** `Insets`, `.margin` and `.padding` take `start:` and `end:` where they took
  `left:` and `right:`; `IconPosition.leading` and `.trailing` are `.start` and `.end`.
- **A layout names the edges it runs under.** `.avoidsSafeArea(...)` and `SafeArea` are gone:
  `.ignoresSafeArea(.top)` (`SafeAreaEdges`) runs a layout under the bars and the system's edges it names, and
  keeps it clear of the rest.
- **A toolbar's items are typed.** `ToolbarItem` is what every bar item is: `ToolbarButton`, `ToolbarToggle`,
  `ToolbarLabel` and `ToolbarGroup`. `.toolbar(.trailing, order: 1) { ToolbarItem("Save") }` is
  `.toolbar { ToolbarButton("Save") }`; an item says where it stands with `.placement(.sidebar, at: .end, order: 1)`,
  and `ToolbarSide` and `ToolbarItemPlacement` are gone. A page's `barTitle`, `barSubtitle` and `barIcon` are gone -
  a page names itself with `.title(_:)` and `.subtitle(_:)` - and `barBackgroundColor` is `barBackground`, a color
  or a material.
- **A checked menu entry is a `MenuToggle`**: `MenuItem("Wrap").isOn($wraps)` is `MenuToggle("Wrap", isOn: $wraps)`.
  `.isDestructive(true)` on a menu item or a toolbar button is `.role(.destructive)`. `Button(icon:)` is
  `Button().icon(_:)`, and a button's menu names its kind, `.menu(.split) { … }`. A toolbar button holds a menu as
  a button does, `.showsMenuArrow(_:)` included.
- **A sheet is presented by a view.** `ModalStack` is gone: `.sheet(isPresented: $shown) { … }` and
  `.sheet(item: $item) { item in … }` present a page the state asks for, and the user's dismissal writes `false` or
  `nil`.
- **The window asks; the application acts.** `Dialogs.alert`, `.confirm`, `.chooseAction`, `.prompt`, `.openFile`,
  `.openFiles` and `.saveFile`, `OnScreenKeyboard.hide()` and `Inspector.open/close/toggle/isOpen(in:)` are the
  window's (`@Environment(\.window)`: `window.confirm(...)`, `window.hideOnScreenKeyboard()`,
  `window.openInspector()`) and stand over that window. `Links.launch` and `ScreenReader.announce` are
  `application.launch` and `application.announce`. A choice of actions answers the value chosen:
  `window.chooseAction("Share via", among: Share.allCases, caption: …, destructive: .delete) -> Share?`, `nil` for its
  cancel; `confirm`'s `cancel:` may be left out, and `alert`'s button is `accept:`.
- **A kept key is typed by its value.** `PersistentKey("name", of: T.self)` is `PersistentKey<T>("name")`, declared as
  a static of `extension PersistentKey where Value == T`, and a state of another type does not compile; `SceneKey`
  alike, its value any `Codable`, kept as JSON text - a value an earlier version kept reads as none once.
  `application.persistentKeys` is gone.
- **Names say what a thing is.** `AppInfo` is `ApplicationInfo`; `device.info.deviceType` is
  `device.info.isVirtual: Bool?`; `device.honours(_:)` is `device.honors(_:)`; a catalog's languages are an
  `enum AppLanguage: LocaleTag, CaseIterable`, its associated type `CatalogLanguage`;
  `.automationExcludedWithChildren(_:)` is `.hidesChildrenFromAccessibility(_:)`.
- **Values are typed.** `Color("#512BD4")` is `Color(hex: 0x512BD4)`, `Color("#80FF0000")` is
  `Color(hex: 0xFF0000, opacity: 0.5)`, and a color from data is `Color(parsing:)`, `nil` for what is no color.
  `Rectangle(.red)` is `Rectangle().fill(.red)`, `Ellipse` and `Capsule` alike; `Image(light:dark:)` is
  `Image(ImageSource(light:dark:))`. `Map(latitude:longitude:radiusMeters:)` is
  `Map(region: MapRegion(center: Location(...), radiusMeters:))`, `Marker("Name").location(latitude:longitude:)` is
  `Marker(at: Location(...)).label("Name")`, and an aim moves a map with `moveToRegion(_:)`.
  `DatePicker.format("D")` is `.format(.long)` (`DateStyle`).
- **One road for each thing.** A scroller's offset is read with `.scrollOffset($offset)`; its `scrollXChanged` and
  `scrollYChanged` events are gone. An array of views is no longer a container's content: write the statements, or a
  `ForEach`. `onKeyPressed`'s handler takes a `KeyPress` (`press.key`, `press.modifiers`). `currentThreadNumber()`
  is gone - ask `MainActor.preconditionIsolated`.
- **A head starts the application in Swift.** `@_cdecl("stateui_app_register") public func stateui_app_register()`
  is `public func registerApplication()`, and `exit(StateUIGTK.run(...))` and `exit(StateUIWinUI.run())` are
  `StateUIGTK.run(...)` and `StateUIWinUI.run()`, which never return.
- **For host and backend authors (`@_spi(Host)`):** `Renderer` is the host's alone - an application tells every
  change by writing a state. `Prop("…")`, `Event("…")` and `Act("…")` are the host's; a member is reached through
  its contract. The motion layout is `MotionLayoutContract`, node type `"MotionLayout"`, its members `parameters`,
  `translationOrientation`, `translationUpdated`, `wheelStepped`, `itemDragUpdated` and `pinchRotationUpdated`;
  `ViewContract.layoutBody` is new. `ButtonContract.showsMenuArrow` is `ButtonMenuElementContract.showsMenuArrow`,
  which a toolbar button wears too. A registered control's `applies([a, b])` is `applies(a, b)`,
  `children(_:members:)` is `children(_:properties:events:)`, and an element reads a state handed to it when it is
  described. `CoreLink.readsKept { name, kind in … }` replaces `persistentKeys` and `restorePersistent`. The tier
  `TextStyleElement` is `TextColorElement`; `HostDeviceInfo` takes `isVirtual:`. A host's motion laws take and give
  speeds per second.

### New

- A two-way control - a field, a switch, a check box, a slider, a stepper, a date or time picker, a color picker -
  takes its value with an event of the user's change: `onTextChanged`, `onToggled`, `onValueChanged`,
  `onDateChanged`, `onTimeChanged`, `onColorChanged`. A picker tells the index chosen (`onSelectedIndexChanged`), a list its selection
  (`onSelectionChanged`).
- `.popover(isPresented:)` and `.popover(item:)` show the platform's popover by a view, a sheet on a phone. A sheet
  stands as a card on a wide screen, as large as its page asks, and its stack offers a close button
  (`.showsCloseButton(_:)`).
- A page stands a bar at its foot (`.bottomBar { … }`) and a toolbar there (`.toolbar(.bottom) { … }`); a page runs
  under its bars where it says so (`.ignoresSafeArea`). A bar says how rows show at its edge (`.barScrollEdge`), how
  its buttons stand (`.toolbarStyle`, `.toolbarSpacing`) and the color of their words (`.barForegroundColor`); its
  background may be a material. A split view's bar stands in two parts, and `.showsSidebarToggle(false)` hides its
  toggle.
- `Link` opens its address; `.onLinkOpened` hears the links of a view's window, a link of the application's own
  scheme included. `.onHeld` hears a press held on any view. `ColorPicker` opens the platform's own picker.
  `ToolbarToggle` is a setting on the bar, a toolbar button holds a menu (`.menu(_:_:)`), and a button's words may
  stand out of sight and still name it (`.showsText(false)`).
- `application.clipboard` writes and reads text; `window.share(text:link:)` offers the platform's share sheet;
  `application.send(HTTPRequest(...))` sends an HTTP request on every host.
- A scroller or a list is pulled to refresh: `.isRefreshing($refreshing)`, `.onRefreshRequested`,
  `.isRefreshEnabled`. A list item's `.contextMenu` is also its swipe actions on UIKit.
- `.accessibilityRole` and `.accessibilityValue` say what a view made of parts is and holds;
  `.accessibilityAction(_:perform:)` and `.onAccessibilityAdjusted` take a screen reader's actions and steps;
  `device.accessibility` reads less motion, more contrast, a running screen reader and the scale of words.
- `InputPurpose.username`, `.newPassword` and `.oneTimeCode` let the platform fill a sign-in in. Tab, Space, Home,
  End, Page Up and Page Down are keys. On Windows, GNOME and the Web an Edit menu (`.id(StandardMenu.edit)`) holds
  the platform's undo, clipboard and selection entries, as on the Mac and the iPad.
- `StateUITesting` drives an application's own pages in its tests as a user does, on every host's toolkit; the
  starter's test clicks its button.
- `DispatchQueue.main.async` runs on the UI thread on Android, Windows and Linux too.
- `Space`, `Fill`, and a figure filled with a material (`.fill(_:)` takes a `Material`). `Group` and `AnyView` hold a view with no
  element of their own.
- Words of other sizes rest on one baseline (`Alignment.firstBaseline`), a row can wrap onto further lines
  (`HStack { … }.wraps(true)`, `.rowSpacing`, `.lineAlignment`), a row short of room takes it from its words, and
  `.monospacedDigits` draws every digit at one width.
- An application gives its own accent (`application.accentColor`).
- A motion layout may mirror right to left (`.mirrorsRightToLeft(true)`); its views move as bodies
  (`.dynamics(_:)`, `.layoutBody(_:)`, `.followsLayout(_:)`), it tells once it rests (`.onSettled`), and an axis of
  keyframes alone needs no input. A gallery's cards may follow their places (`.itemBody(_:)`).
- `Motion.glide(longest:)` is a public motion law, setting out at its value's speed; `journey.reach(_:)` says where a
  motion would bring a value. Every gesture tells how fast it goes (`PanUpdate.velocityX`, `.velocityY`,
  `PinchUpdate.velocity`, `.onRotationUpdated`), and a dragged item knows what it is over.
- `.onHostEvent(event) { … }` hears a host event while its view stands, and a field takes an outline of its own
  (`.stroke`, `.shape`, `.lineWidth`).
- An application's own control raises the events of the tiers it wears (`reports.raise`).

### Fixed

- A tapped view presses as a button on every host, and a single tap is pressed as a button is; a press that traveled
  is no tap, a touch catching a moving or springing list presses no row, and a held finger's menu stays as it lifts.
- A placed opacity no longer wakes UIKit's focus system: with a hardware keyboard, a motion layout and the Home
  screen no longer jump once a second on the iPad.
- A drawn picture under a moving transform stands as pixels of the size it is shown at on AppKit, so a thrown or
  zoomed picture no longer stutters, and a box that did not change draws nothing anew.
- A tabbed view's tabs come back after a tab that is a stack, stand in the middle of their bar, and its bar moves at
  once on GTK.
- A traveling layout lays out at its destination, a button's words stand where it travels to, and a field keeps the
  keyboard as its row moves.
- A closed window's views are let go on every host; a UIKit bar button no longer outlives its element.
- On Android pages no longer slide through each other on a push, a list cuts its cells at its edges and reports where
  it stands, a view is never a pixel short, the window draws edge to edge, and a theme holds before Android 12.
- A grid draws its children in their order, a grid child spanning tracks asks its room of them, and a child's new
  words arrange its layout again.
- A UIKit list chooses many with taps; a GTK sheet fits its window; a WinUI bar's buttons stand as a toolbar's.

### Faster

- A ticker's tick rebuilds only the views that read its values, and sheets taken together go in one render.
- A motion layout moving alone arranges no child.

### Tooling

- The public API stands recorded in `lib/StateUI/exports/api/StateUI.txt`, held by the suite; every interface
  example in the handbook compiles, and a Gallery sample's listed code is the code that runs.
- An element a host keeps after it left is counted, and a closed window's views are proven let go.

## 0.7.1 - 2026-10-20

### Breaking changes

- **An identity is compared as the value it is.** `.id(_:)` and `ForEach`'s `id:` match an element by its value,
  not by its description: two values that describe themselves alike - two instances of one class - are two
  elements, and a route or a tab need not describe itself apart from the others. `Node.id` can no longer be set;
  a view takes its identity with `.id(_:)`.
- **For host and backend authors (`@_spi(Host)`):** AppKit and UIKit share one web view, one map and the
  system's facts from `StateUIApple` (`lib/StateUI/StateUI.Apple`). What two hosts decided alike is the host
  layer's, and each host asks it: a scroller's echo, a navigation path change, a run of taps, a hand over a
  layout, a slider's and a stepper's step, a list's estimate and its scroll to an item, a window's dialogs, the
  focus, a frame reader's following (`FrameFollowers.follow(_:of:reads:)`). A collection that learns its cells'
  nearness once a frame tells the cells together (`ItemsCells.hold(_:endingShowing:)`).

### New

- A registered control takes properties together: `applies([...]) { view, values in ... }` hands a view every
  property it names whenever one of them changes, each as its contract's type and whether it changed
  (`ControlValues`) - a web view its agent before its page.
- A member the running host does not realize is said once in Debug, with the reason its register gives:
  "Switch.tint is never realized on this host: AppKit draws it in the accent color the user chooses".
- A host writes its lines, and every complaint the application routes nowhere, where its platform's developers
  read: Apple's system log, WinUI's debugger output, GLib's log, logcat, the browser's console.

### Fixed

- Words held to some lines end with an ellipsis on every host.
- A navigation path change moves alike on every host: a push brings its last page in however many came, a pop
  moves back once, a replacement and reduced motion move nothing. On UIKit two pages no longer slide in at once.
- A page hears it goes when the tree closes its window, and when the user pops it, on every host.
- A question or a file dialog over a window the tree closes is answered as dismissed, and the next one asks.
- A text field's bound counts characters on every host, a question's field included; WinUI, Android and the Web
  counted UTF-16 units.
- A slider's keyboard step and a stepper's step follow one arithmetic on every host, and a fractional step lands
  on its decimals: 0.2 and a step of 0.1 make 0.3. AppKit's arrow keys moved a twentieth and Page Up to the end;
  Android's slider stepped a twentieth; UIKit's progress view took a value that is not a number.
- A label's and a field's start follows the layout's direction on AppKit and UIKit, not the script of their words.
- A vector picture stretched to its room is drawn at the room's own pixels on GTK and WinUI - on GTK it was
  covered and squeezed.
- Android and WinUI count a run of taps with the platform's own interval and distance.
- A scroll to an item glides there unless the user asks for less motion, on every host.
- On Android and WinUI a layout the toolkit narrows is placed before it is drawn, not a frame behind its width.
- A chosen item's band is the accent at a fifth on every host, and a map's search result is purple on the Web
  too.

### Faster

- A body is built only for what it read: a page whose body ends on a view with its own state is no longer built
  for that state. In the host layer's benchmark, scrolling 1000 rows builds some 1200 bodies, against 5500.
- A render that makes no element spells no identity as text.
- On the Web a change inside a child arranges none of its ancestors, and a list takes the cells the browser saw
  coming and going in one frame together, with one render. A fling of 20 000 points a second in Chrome keeps every
  frame on time, where the rows in view stood empty until the list stopped; a list's page opens in some 1.9 s in
  WebKit with no JIT, against 3.8 s, and with the JIT in some 160 ms, against 530. Measured on an M1 Max MacBook
  Pro.

### Tooling

- The host layer's benchmarks gate four gestures' work by counts in every run; a walk opens every Gallery sample
  and checks nothing it made stays alive; the Web modules hold their size budgets.

## 0.7.0 - 2026-10-19

### Breaking changes

- **Motion lengths are durations.** `.eased(400, .cubicOut)` is `.eased(.milliseconds(400), .cubicOut)`, and
  `.spring(response: 320)` is `.spring(response: .milliseconds(320))`.
- **A gate stands only where a handler awaits.** A handler with no `await` takes no `gate:` -
  `.onClicked { count += 1 }`; one that awaits names what a second event does while it runs -
  `.onClicked(gate: .ignoreWhileRunning) { try await save() }`.
- **A layout engine's axis is one declaration.** `.input(_:)`, `.snapTargets(_:)` and `.wraps` are gone:
  `.axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))`, with `keyframes:` and `wraps:`
  where the axis has them.
- **`move(to:_:)` takes a law, never an optional one.** `$x.journey.move(to: 0)` moves under the value's own law
  and `$x.journey.move(to: 0, .none)` under no motion - which an optional law read as "none given", and animated.
- **`convertBack` hears the user's changes alone.** A value the application writes goes forward as written:
  `volume = 0.123` through a slider converting by hundredths stays 0.123 instead of coming back as 0.12.
- **A layout engine with no motion of its own moves under the application's** (`application.motion`), as every
  value a host carries does, rather than under `.standard`.
- **A GTK or a WinUI head exits with the status its host's run returns**: `exit(StateUIGTK.run(...))`, as the
  templates write it.
- **For host and backend authors (`@_spi(Host)`):** a host's register is written with the contracts' members -
  `.complete(SwitchContract.isOn)`, `.notPlanned(VisualElementContract.background, on: SliderContract.self,
  reason: ...)` - and names elements by their contracts (`byApplication: [MapContract.self]`), as does
  `HostRuntime.start(unrealized:)`; a misspelled name no longer compiles.

### New

- The layout engine: keyframes on an axis; a pan in every direction; two fingers move an axis by spreading and
  turning; a press dragged with ⌥ or Alt is two mirrored fingers; a wheel turned with Control is a pinch; the hand
  carries the view in front; a view can be taken by the hand. `GalleryView` stands its cards as a deck too.
- Every value modifier has its binding twin beside it.
- A split view tells whether its sidebar lies over the page.
- `StateUIFoundation`: the platform's C library behind one import (`exp`, `sin`), the same on every platform.
- `STATEUI_PROBE=1` times a runtime's stages, once a second; on the Web also what the page spends.

### Fixed

- Some 140 defects a module-by-module audit found, each with the test that would have caught it, in the core,
  the host layer, every host, the conformance runner and the tools. Among them: a carried view keeps its body's
  handlers; a state with no number no longer holds the frame clock awake; a replaced element keeps its engines;
  Android's acts outlive the activity they began in; GTK lets go of a page the stack takes away; the Web never
  runs a `javascript:` address; on UIKit a sheet and a question in one turn no longer lock the window.
- On an iPad a page beside a sliding sidebar narrows with it frame by frame, its layout placed in the frame that
  measured it; what a layout pass reports moves no animation on, on every host.
- On UIKit a scroller tied to `.scrollOffset($)` stretches past its edge as the user pulls it.
- On an iPhone a page turned to landscape and back hears its new room with the display already turned.
- A list scrolled to an item stands it where the anchor says once the rows around it are measured, on UIKit,
  AppKit, GTK and the Web - on an iPad it stood a point short; the user moving the list lets it go.
- A change that moves a list's rows - an item put first, one taken out - builds the items it brings into view in
  the same render, so the platform's collection measures them as it animates the change: on an iPhone the rows no
  longer jump above where they stood, and on AppKit they no longer settle a few points off once the animation
  ends. AppKit's list keeps its own header and footer through the animation.
- Rendering on the Web is several times cheaper. Measured in WebKit on an M1 Max MacBook Pro: with no JIT, as
  Safari runs WebAssembly on an iPad, a home screen's render at a new icon's place takes some 47 ms, against some
  213 ms, and a list of 1000 rows scrolls at some 41 frames a second, against 27. With the JIT both already kept 60
  frames a second; the same render takes some 4-5 ms, against 8-9, and the list's longest frame some 19 ms, against
  30-37.

### Conformance

- A wait that runs out fails its case, a case proves its own family's contract alone, and a case whose driver
  cannot read what it needs says so: some marks fell, to tell the truth.
- A wait - a session's, a driver's, a host test's - stops as what it waits for holds, rather than asking again to
  its bound.
