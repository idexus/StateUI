# Changelog

What each release changes for an application and for a host, newest first. A breaking change says how to move
over. StateUI is before 1.0: a release may break what the one before it promised, and says so here.

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
  `Button().icon(_:)`, and `showsMenuArrow` is gone - a button's menu names its kind, `.menu(.split) { … }`.
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
  `ViewContract.layoutBody` is new. A registered control's `applies([a, b])` is `applies(a, b)`,
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
