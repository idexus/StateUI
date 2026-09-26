# Host layer

A host - the platform backend that shows StateUI with one toolkit - is Swift in
the application's process, and most of what it does is the same on every
platform. That part is the host layer: the toolkit-neutral half of every
runtime, in `lib/StateUI.Host` - the module `StateUIHost`, a library of its own
beside the [`StateUI` core](core.md), which it reaches through `@_spi(Host)`.
It holds the mounted tree, the turn and the display frame, the animations, the
layout arithmetic, and the rules that turn what the user does into state.
Every host runs on it and adds only its toolkit's calls.
The [host contract](host-contract.md) specifies the typed patch the layer
takes.

## The rule

A host is a thin layer of its toolkit's calls. Everything two hosts would
decide alike - a rule, an order, arithmetic, a state machine - lives once in
the host layer, which serves every host and proves itself with its own pure
tests. Before anything new reaches a host, the part every host shares is
decided first and written in the host layer first; the host then adds only
the calls its toolkit alone can make. A rule found in one host belongs in the
layer: it is written there with its tests, and every host calls it.

```text
lib/StateUI.Host/Sources/
  Runtime/       the runtime's parts, the turn, the frame, the line to the core
  Tree/          the mounted tree, each element's native half, the windows
  Pages/         what an arrangement shows, a page's phases, the window's chrome
  Layout/        the layout arithmetic: stacks, grids, layers, scrolling, shapes
  Drawing/       boxes, brushes, pictures, a control's pressed fill
  Text/          words in their case, their look, their lines
  Input/         the user's changes, gestures, scrolling, typed words, ranges
  Motion/        the animator, the state channels, described and layout motion
  Acts/          answering acts, questions for the user, the application's acts
  Environment/   the machine a host stands on, in the core's terms
```

The design notes give each part's reasons: [the runtime](design/host/runtime.md),
[the mounted tree](design/host/tree.md), [pages](design/host/pages.md),
[layout](design/host/layout.md), [motion](design/host/motion.md),
[patches](design/host/patches.md) and [conformance](design/host/conformance.md).
The [glossary](design/glossary.md) maps StateUI's words to the common ones.

## What a host provides

A host builds one `HostRuntime`, through
`HostRuntime(clock:reducesMotion:makeNative:log:)`, and gives the layer what
only its toolkit has:

| Seam | What the host gives |
| --- | --- |
| `FrameClock` | the toolkit's display link: `now` in milliseconds on one monotonic clock, frames only while `held`, each calling `onFrame` with its time |
| `makeNative` | a `NativeElement` for each `MountedElement`: its view and everything hung on it, and the tab the user chose or the sidebar shown on screen, where its toolkit knows them |
| `TurnPresenter` | set as `pump.presenter`: shows what a render changed around the tree - the windows, their pages, their chrome - and performs an act |
| `FramePresenter` | set as `displayCycle.presenter`: hands each step of a frame back to the layer - `frames.commit`, `tree.present`, `pump.turn` |
| the doorbell | a thread of its own in `CoreLink.ringForever`, posting one `pump.turn()` to the UI thread whenever the core has work |
| `reducesMotion` | whether the user asked the platform for less motion |
| `log` | where a message the intake refused is said, through `HostLog` |
| `LayoutChild` | each child a layout measures: its `LayoutValues`, whether it shows, its size for an offered width |
| `PlacedView` | each view a layout stands at a rectangle |
| `FramedScroller`, `FrameReporter` | a scroller the frames serve, and an element whose frame the tree reads |
| a `Registry` | one registration per element contract it realizes, handed to the core by `CoreLink.setRealization` |

Both presenters are held weakly; the host keeps them.
[The runtime's parts](design/host/runtime.md#the-runtimes-parts) and
[the host layer](design/host/runtime.md#the-host-layer) draw the seams.

The registry is the core's
([realizations](design/core/contracts.md#realizations)): each registration
makes an element's view, puts the members the view takes, and raises its
events through `Reports`. What every element realizes by the layer's rules -
its place, its drawing, what assistive technology meets, the user's input - a
host names in one line each: `everyElementTakesItsPlace`,
`everyElementIsDrawnOverItsPlace`, `everyElementMeetsAssistiveTechnology` and
`everyElementHearsTheUser`
([what every element realizes](design/host/tree.md#what-every-element-realizes)).

Where the toolkit speaks another language, a relay stands beneath the host -
Java through JNI, C++ behind a C ABI. It receives native pointers, never
ownership; the layer hands it a colour as one ARGB number (`PropValue.argb`)
and a view by its number (`LiveViews`).

### Starting

Before the first render, a host hands the core its realization
(`CoreLink.setRealization`), what it reads of the machine
([environment and kept values](#environment-and-kept-values)) and the kept
values its store holds (`persistentKeys`, `restorePersistent`). It follows the
language's direction (`MountedTree.followTheLanguagesDirection`), connects its
scene (`CoreLink.connectScene`) and turns the pump once. The doorbell carries
every turn after.

### The roads in

What the toolkit tells a host enters the runtime by one road, the same on
every host:

| The toolkit says | The host calls |
| --- | --- |
| a control raised an event | `MountedElement.send` |
| the user changed a control's value | `MountedElement.reportUserChange` |
| the user moved a scroller | `ScrollMovement`; on the frame, `MountedElement.reportScrolled` |
| a view heard a tap, the pointer, a drag or a pinch | `MountedElement.hear` with a `HeardInput` |
| something was laid out or moved | `FrameFollowers.laidOut`; on the frame, `MountedElement.reportFrame` |
| a handler runs with its payload | `HostRuntime.dispatch` |
| several changes are one gesture | `HostRuntime.performUserTransaction` |
| the user chose a tab | `HostRuntime.tabChosen` |
| a split view's sidebar showed or hid | `HostRuntime.sidebarShown` |
| the user went back | `HostRuntime.goBack` with the window's `wayBack` |
| the theme, locale, power or network changed | `HostRuntime.environmentChanged` |
| a window was activated, deactivated or minimized | `HostRuntime.windowStateChanged` |
| the whole application was hidden or shown | `HostRuntime.applicationHidden` |
| the user closed a window | `HostRuntime.userClosed` |
| the application ends | `HostRuntime.ending` |

The element's roads call `HostRuntime.report`, `take` and `takeGestureValue` -
a value through a bound state, a journey the user took, a gesture's state - so
a host reaches them through the roads above.
[A user's change](design/host/runtime.md#a-users-change) draws the path.

### What a host never does

A host never:

- keeps a second description tree, diffs, infers identity from a native
  object, routes, or keeps an application's state;
- samples a timing law, advances an animation, runs the core's cycle, renders
  or takes the acts - `Animator`, `DisplayCycle` and `Pump` each do that
  alone - or calls the core except through `CoreLink`;
- keeps a write flag of its own: `ProgramWrite` is the one mark;
- times a scroller's rest on a clock of its own, or aims, shortens or corrects
  the toolkit's scrolling;
- groups radio buttons with the platform's own group: the tree names the peers;
- computes again what a type of the layer computes;
- strongly retains a control after its element leaves.

`RuntimeArchitectureTests` reads every host's sources and refuses each of
these that the text shows, and a type named for an engine or a channel
([names](design/host/runtime.md#names)).

## The runtime

`Runtime/` holds the runtime's parts and the order they work in.

- **`HostRuntime`** builds the parts every host holds alike and wires them
  once: the line to the core, the patch intake, the animator, the state
  channels, the described and layout motion, the display cycle on the host's
  clock, the mounted tree, the pump and the frame followers.
  ([The runtime's parts](design/host/runtime.md#the-runtimes-parts))
- **`CoreLink`** is the one line to the running core: a render, a cycle, an
  event, a user's report, an act's answer, the application's and the scene's
  reports, the kept values and the doorbell's wait (`ringForever`). The host
  calls it for what it tells the core; nothing else in a host calls the core.
  ([Core link](design/host/runtime.md#core-link))
- **`Pump`** is one turn, in one order: the jobs a resumed handler left, a
  pending cycle, a render when the core needs one, the handlers it raised,
  then the acts, so an act lands on the interface its handler changed. A turn
  asked for during another runs when that one ends. The host calls `turn()`
  and presents through its `TurnPresenter`.
  ([One turn](design/host/runtime.md#one-turn))
- **`PatchIntake`** takes the core's message whole, against the generation of
  the last message applied in full; a drift - a sparse message about a tree
  the host does not hold - is refused, and the whole tree is asked for once.
  The pump drives it; the host adds nothing.
  ([Patch intake](design/host/patches.md#patch-intake))
- **`HandlerDispatch`** raises the application's handlers in the order the
  user caused them: one raised while a patch applies, or inside the user's
  transaction, waits until that is over. A page's, a window's or a scene's
  phase is queued (`enqueuePhase`) and rendered before whatever follows it.
  ([The handlers' order](design/host/runtime.md#the-handlers-order))
- **`ProgramWrite`** is the one mark that the program, not the user, writes a
  native control; a native callback inside it reports nothing. The intake
  marks every patch and the tree every frame's walk; the host marks every
  other write it makes - a control it moves, a pop-up it opens - with
  `ProgramWrite.perform`.
  ([Program write](design/host/patches.md#program-write))
- **`DisplayCycle`** is one display frame, in one order: the user's reports,
  the animations, the core's cycle, one walk of the tree, a render, and the
  clock's hold, which lets go only when nothing moves. The host's
  `FrameClock` ticks it, and its `FramePresenter` hands each step back to the
  layer. ([One frame](design/host/runtime.md#one-frame))
- **`FrameFollowers`** keeps the frames coming while a scroller moves or a
  frame the tree reads may have moved, and on each frame lets the scrollers,
  then the elements, say where they stand, as one user's transaction. The
  host hands it each `FramedScroller` (`serve`) and `FrameReporter`
  (`follow`), and calls `laidOut()` after it lays anything out.
  ([Where a view stands](design/host/runtime.md#where-a-view-stands))
- **`ApplicationLifecycle`** settles what the toolkit tells of each window -
  minimized, activated - into the phases of the application, its scenes and
  its windows, a turn later, so one window deactivated as another is
  activated is one move. It keeps the scene in front, which hides the windows
  that hide while another scene is, and says whether a floating window floats
  now. The host tells `HostRuntime.windowStateChanged`.
  ([The application's phase](design/host/runtime.md#the-applications-phase))

## The tree and the native half

`Tree/` holds the host's live copy of the description: one mounted element
per described node, each with a native half its toolkit writes.

- **`MountedTree`** applies each message's root patch, with one start time for
  every animation the message begins, and owns what every element shares: the
  line to the core, the intake, the state channels and the two motions. It
  presents a frame's batch in one walk (`present`) and lays the tree out again
  where the language's direction turned (`followTheLanguagesDirection`).
  ([The mounted tree](design/host/tree.md#the-mounted-tree))
- **`MountedElement`** is one live element: its key, type, described
  properties, bound states, handlers and children in order. It applies a patch
  in one fixed order, refuses a drift, and leaves by every road out of the
  tree, letting go of its states and its animations. The host reads every
  value through it - `value`, `string`, `number`, `bool`, `handler`,
  `layoutValues`, `layoutDirection` - and keeps no copy.
  ([Leaving](design/host/tree.md#leaving))
- **`NativeElement`** is the native half's whole contract with the tree: it
  hears a patch about to apply and applied, presents a frame's changed
  properties and says what the frame asks around it (`FrameImpact`), arranges
  its children, says where a property stands natively (`standingValue`) and
  whether the toolkit animates it, says the tab the user chose (`chosenTab`)
  and whether a sidebar shows on screen (`showsSidebar`) where its toolkit
  knows them, and lets go of what it attached outside the tree as the element
  leaves. The element owns its half; the half refers back without owning, and
  whatever keeps an element beyond the tree - a window's page, a sheet - holds
  the element, never the half.
  ([The native half](design/host/tree.md#the-native-half),
  [standing values](design/host/tree.md#standing-values))

What a mounted element decides for every host, which the host turns into its
toolkit's calls:

| Member | What it decides | Reason |
| --- | --- | --- |
| `radioPeers` | the radio buttons a check takes away: those of its group in its window, else its siblings | [A radio group](design/host/tree.md#a-radio-group) |
| `drawingTransform`, `placement` | how a view is moved, turned and scaled over its place, and a placing run's places | [Drawn over its place](design/host/tree.md#drawn-over-its-place) |
| `accessibilityWords` | its identifier, label, hint and heading level, and whether assistive technology meets it | [What assistive technology meets](design/host/tree.md#what-assistive-technology-meets) |
| `arrangedProperties`, `unmeasuredProperties` | which change arranges the parent again, and which measures nothing | [Measured once](design/host/layout.md#measured-once) |
| `readsOwnFrame`, `reportFrame`, `frameNumbers` | whether the tree reads where the element stands, and the report it is told | [Where a view stands](design/host/runtime.md#where-a-view-stands) |
| `hearing`, `hear` | what input a view listens for, and the events each input raises | [What the user does with a finger](design/host/runtime.md#what-the-user-does-with-a-finger) |

- **`NodeType.pageTypes`**, **`viewlessTypes`** and **`slotTypes`** say which
  elements are the arrangements of pages a window shows, which have no view of
  their own, and which furnish a page's chrome rather than stand in its room.
- **`LiveViews`** holds a host's views weakly by the number each was made
  under: a callback crossing C names a view by its number and finds nothing
  once it has gone. ([Views by number](design/host/tree.md#views-by-number))
- **`ElementId.hostValue`** is a key as an event carries it: an author's name
  as its text, a counted key as its number.

## Windows

`Tree/` also holds how a window stands, the same on every host.

- **`WindowRoster`** keeps the window elements under the root in the tree's
  order, each with the host's controller of it: a window the tree keeps keeps
  its controller, a window it drops has its controller closed, a new one has
  one made, and the first window's coming is said. The host hands it `make`
  and `close`.
  ([The windows a tree holds](design/host/tree.md#the-windows-a-tree-holds))
- **`WindowPresentation`** says what a window shows, where it changed: its
  arrangement of pages, the pages its modal stack presents as sheets, what it
  lays over them, its frame, bounds and traits. The page the user sees hears
  that it is shown, and a new window that it was made, each in its turn,
  before the host first shows the window; `wayBack` is the way back the window
  offers. The host shows each in its toolkit's window.
  ([A window shown](design/host/tree.md#a-window-shown))
- **`WindowFrame`**, **`WindowBounds`** and **`WindowTraits`** read a window's
  place and size as four requests in DIPs, each alone; its least and greatest
  size; and whether the user may maximize and minimize it, whether the desktop
  shows through it, and whether it floats now. The host turns each into its
  toolkit's units and calls. ([A window's frame](design/host/tree.md#a-windows-frame),
  [a window's traits](design/host/tree.md#a-windows-traits))
- **`HostRuntime.userClosed`** tells what the user closing a window means: the
  window hears that it is going, then its scene hears what that means for it
  (`toldOnClosing`). A window the tree closes tells nothing.
  ([A window the user closes](design/host/runtime.md#a-window-the-user-closes))

## Pages

`Pages/` holds how an application's pages are read, the same on every host.

- **`visiblePage`**, **`shownChildren`**, **`selectedTab`**,
  **`sidebarIsVisible`**, **`visibleBackStack`** and **`tabsStandInWindow`**
  (on `MountedElement`) walk the page path: a stack's top page, the chosen
  tab, a split view's detail and its shown sidebar, and where a tabbed view's
  tabs stand. ([The page path](design/host/pages.md#the-page-path))
- **`setPagePresented`**, **`reconcilePresentation`** and
  **`PagePresentationReason`** give the phases a page hears as it is shown and
  hidden, each rendered before the next. The tree tells them after each patch
  of an arrangement shown, and `HostRuntime.tabChosen` and `sidebarShown`
  after the user's own choices.
  ([A page's phases](design/host/pages.md#a-pages-phases))
- **`TabChoice`** is which tab a tabbed view shows: a tab the tree asks for
  anew is chosen, and the user's choice stands.
  ([Tabs](design/host/pages.md#tabs))
- **`SidebarAdaptation`** decides once, on a split view's first room, whether
  its sidebar shows; the breakpoint is the platform's, which the host hands
  it.
  ([A sidebar on the first room](design/host/pages.md#a-sidebar-on-the-first-room))
- **`WayBack`** is the way back a window offers - a stack's top page going, or
  the top sheet - which `HostRuntime.goBack` takes.
  ([The way back](design/host/pages.md#the-way-back))
- **`slotContent`**, **`presentingElement`** and **`arrangedChildren`** say
  what stands in a slot, which element's view shows an element, and which
  children a layout places - a page's slots stand in none of its room.
  ([Slots](design/host/pages.md#slots))
- **`MenuEntry`** walks a menu - its items, separators and submenus in order,
  each with its caption, whether it can be chosen and its identifier - and a
  menu bar's menus. The host builds its toolkit's menu from the walk.
  ([Menus](design/host/pages.md#menus))
- **`WindowChrome`**, **`chromeActions`** and **`barColors`** compose a
  window's one chrome from what it shows: its title, the way back, the visible
  page's actions, the title's place and what stands beside it, the bars'
  colours, the menu bar and the sidebar's toggle. The host lays these out in
  its toolkit's chrome.
  ([The window's chrome](design/host/pages.md#the-windows-chrome))

## Layout

`Layout/` holds StateUI's layout arithmetic: pure functions, the same children
in and the same rectangles out. A host calls them from its own layout pass and
measures only its native views.

- **`LayoutValues`**, **`LayoutChild`** and **`LayoutSize`** are what a layout
  reads of a child (`MountedElement.layoutValues`) and the child as the
  arithmetic sees it; `offer` and `sized` measure a child at its stated width
  within its bounds. The host's child measures its own view at the width
  offered, its margin already taken out.
  ([The layout arithmetic](design/host/layout.md#the-layout-arithmetic),
  [a child measured](design/host/layout.md#a-child-measured))
- **`Extent`** is one axis of a child's slot: a stated size wins, a filling
  child takes the slot and any other its natural size, and the least size wins
  a contradiction.
  ([One axis of a slot](design/host/layout.md#one-axis-of-a-slot))
- **`MeasurementCache`** keeps the sizes one view measured, by the width
  offered, four at most. The host forgets them upward from a change to the
  nearest room, as `arrangedProperties` and `unmeasuredProperties` say.
  ([Measured once](design/host/layout.md#measured-once))
- **`StackArithmetic`**, **`GridArithmetic`**, **`ZStackArithmetic`** and
  **`SingleChildArithmetic`** give each layout's `size` for an offered width
  and the `places` of its children, nil for a hidden one.
  ([Stacks](design/host/layout.md#stacks), [grids](design/host/layout.md#grids),
  [tracks](design/host/layout.md#tracks), [layers](design/host/layout.md#layers),
  [one child](design/host/layout.md#one-child))
- **`ZStackArithmetic.drawingOrder`** and **`HostPlacement`**'s `place`,
  `drawnOpacity` and `drawnShade` say where a placing run stands a ZStack's
  children, how opaque it draws them, and in what order.
  ([A placing run](design/host/layout.md#a-placing-run))
- **`RowEdge`** stands an arrangement's own row - a tabbed view's tabs -
  across the top or the bottom of its room, the page taking the rest.
  ([A row beside a page](design/host/layout.md#a-row-beside-a-page))
- **`ScrollArithmetic`** gives a scroller's content size and the document the
  content stands in; `offsetWritten`, `kept` and `differs` say where an offset
  the tree writes moves it, and `WrittenScrollOffset` keeps one written before
  the scroller's first layout for it.
  ([Scrolling](design/host/layout.md#scrolling),
  [an offset the tree writes](design/host/layout.md#an-offset-the-tree-writes))
- **`ShapeArithmetic`** stands a line's, a path's, a polygon's or a polyline's
  geometry in its room (`placement`), and gives its points as flat commands,
  its stroke's width and its dashes.
  ([A shape's own geometry](design/host/layout.md#a-shapes-own-geometry))

Every call takes the element's `layoutDirection`: places are worked out left
to right and turned about the room's middle for a language written right to
left ([right to left](design/host/layout.md#right-to-left)). A grid's and a
ZStack's `children` stand in drawing order, by `zIndex`, so a host hands its
toolkit the children in that order
([drawing order](design/host/layout.md#drawing-order)).

## Drawing

`Drawing/` holds how a box, a fill and a picture are read, the same on every
host that draws them.

- **`BoxArithmetic`** gives a box's corners clockwise from the top left, each
  rounding no more than half its side; its outline's shape; and its outline's
  width - one where the tree gives a colour and no width, none without a
  colour. ([A box](design/host/layout.md#a-box))
- **`HostBrush`** reads a fill as the tree sends it: nothing, one colour, or a
  gradient's stops between 0 and 1 over its geometry; `firstColor` is what a
  line of one colour draws with. The host turns its colours into its
  toolkit's.
  ([As a host is handed it](design/types/brushes.md#as-a-host-is-handed-it))
- **`PressedFill`** keeps nine tenths of a control's own fill under the
  pointer and eight tenths pressed, where the host draws that fill itself.
  ([A box](design/host/layout.md#a-box))
- **`PictureArithmetic`** gives the files a picture's name stands for, in the
  order a host looks for them, and where the picture stands in its room by its
  aspect. ([A picture](design/host/layout.md#a-picture))
- **`PropValue.argb`** is a colour as one ARGB number, for a relay.

## Text

`Text/` holds how an element's words are read, the same on every host.

- **`TextMembers`** is what an element showing words takes of the text tiers:
  its words in their case, where the words or the case changed (`words`), and
  the look its font and colour give them, where one of those changed (`look`).
- **`TextLook`**, **`TextRun`** and **`MountedElement.textRuns`** give a look
  in the contract's terms and a label's spans as runs of words, each run's
  look standing over its label's. `letterSpacing(inEmsOf:)` hands a toolkit
  that spaces letters in ems its share of the font's size.
- **`LineBreak`** says whether words wrap (`wraps`) or are cut with an
  ellipsis (`truncates`), and on how many lines they stand
  (`lines(maximum:)`).
- **`TextCase.applied`** writes words in the case the tree asks for.

The host turns a finished look into its toolkit's attributes and nothing more.
([Runs of words](design/host/tree.md#runs-of-words))

## Input

`Input/` holds what the user does, carried into the runtime alike on every
host.

- **`MountedElement.send`**, **`reportUserChange`** and **`reportScrolled`**
  carry what the user does to a control: a value onto the state carrying it,
  then its event; a radio button checked turns its peers off first, in one
  user's transaction; what the program writes reports nothing. The host's
  native callback hands the value on, and turns a peer's control off in its
  toolkit's terms. ([A user's change](design/host/runtime.md#a-users-change))
- **`HeardInput`**, **`Hearing`** and **`PinchStep`** are the input a view
  heard, in the contract's terms: a tap in its run, the pointer, a press
  dragged, a pinch's step. The host listens for what
  `MountedElement.hearing` asks and hands each input to `hear`. ([What the
  user does with a finger](design/host/runtime.md#what-the-user-does-with-a-finger))
- **`SwipeDirection.swiped`** tells a swipe from a press and how far it moved:
  the way it moved most, far enough, where the view listens for that way.
  ([A swipe](design/host/runtime.md#a-swipe))
- **`ScrollMovement`** is one scroller's movement: where it went, frame by
  frame, and when it rests, timed on the frame clock. The host tells it the
  user's moves and holds; the scrolling itself is the toolkit's.
  ([A scroller's movement](design/host/runtime.md#a-scrollers-movement))
- **`InputWords`** cuts words to a field's bound in characters (`cut`) and
  gives a caret or a selection in the UTF-16 units a toolkit counts
  (`utf16Selection`). ([Typed words](design/host/runtime.md#typed-words))
- **`PickerChoices`** writes a picker's choices where they changed, and its
  choice only where the tree changed it or the choices.
  ([Typed words](design/host/runtime.md#typed-words))
- **`ValueArithmetic`** is a value inside a range: its ends in order, a step
  that moves, a share of work within 0 and 1, a slider's key and page steps,
  and a stepped number's decimals.
  ([A value in a range](design/host/runtime.md#a-value-in-a-range))

## Motion

`Motion/` animates every value a host shows. The timing laws are the core's
(`HostMotionLaw`), and only the animator samples one.

- **`Animator`**, **`Animation`**, **`AnimationTarget`** and
  **`AnimationStep`** are the one animator: every animation advanced together
  in target order - states, then described properties, then layout places -
  each pure in the time handed to it. With less motion every animation arrives
  at once. ([One animator](design/host/motion.md#one-animator))
- **`StateChannels`** holds one channel per host-carried state, shared by every
  control bound to it. It lives while any control wears it, and the user's hold
  stops its animation where the user holds the value.
  ([State channels](design/host/motion.md#state-channels))
- **`DescribedMotion`** is a property's transition a patch describes, keyed by
  element and property; a new one starts where the running one stands, at its
  speed. ([Described motion](design/host/motion.md#described-motion))
- **`LayoutMotion`**, **`TravellingPlaces`** and **`PlacedView`** move a
  layout's children to their places: what a patch changed travels, a room that
  moves is followed exactly, and the first arrangement arrives. A host's layout
  holds one `TravellingPlaces`, begins each arrangement with its width
  (`begin`) and stands each child through it (`place`).
  ([Layout motion](design/host/motion.md#layout-motion))

The display cycle drives all of it. The host says only whether its toolkit
animates a property (`NativeElement.animates`) and where the property stands
natively (`standingValue`).

## Acts

`Acts/` holds how an act the application calls is read and answered, the same
on every host.

- **`CoreLink.reply`**, **`CoreLink.fail`**, **`ActFailure`** and
  **`MountedTree.aimed`** answer an act with its values or fail it with a
  reason, so no caller waits on an act nobody performs; an act aimed at a view
  names it by its first argument. ([Acts](design/host/runtime.md#acts))
- **`HostActs`** lists the acts every host performs itself (`performed`): the
  focus, the questions for the user, a word to a screen reader, the time and
  the zones, the on-screen keyboard, a kept value and a handler's failure; and
  it reads and answers `currentTime` and `utcOffset`.
- **`HostQuestion`** and **`QuestionQueue`** read a question for the user
  from its act - an alert, a confirmation, a choice, a prompt - and its answer;
  questions show one at a time, each under a ticket of its own.
  ([Questions for the user](design/host/runtime.md#questions-for-the-user))
- **`InteropActs`** performs the acts an application registers on its host,
  each handed the values its contract declares, an aimed one also the control
  of the element it names.
  ([An application's own acts](design/host/runtime.md#an-applications-own-acts))

The host performs an act in its toolkit's terms in `TurnPresenter.perform`,
and nothing more.

## Environment and kept values

- **`HostLocaleInfo(words:)`**, **`HostDeviceInfo`**,
  **`HostConnectivityInfo`**, **`HostBatteryInfo`** and **`HostDisplayInfo`**
  (`Environment/`) turn what a host reads of its machine into what the core is
  told: the locale as eight words, the device as five, the network by its
  access and a set of bits, a desktop's power, and a screen that is landscape
  where it is at least as wide as it is tall. The host reports them through
  `CoreLink`'s setters. A change goes through `HostRuntime.environmentChanged`,
  which tells the core, follows the language's direction and renders in one
  turn. ([The environment](design/host/runtime.md#the-environment))
- **`KeptValuesText`** is the codec of the host's own file of kept values, for
  a platform with no store an application can use: a line a key, the keys in
  order, so the same values write the same file. Where the file stands and how
  it is read and written is the host's.
  ([Kept values](design/host/runtime.md#kept-values))
- **`KeptScenes`** and **`SceneKeeper`** keep the application's scenes for its
  next start, on a platform that restores no windows: each scene's kept
  values and the windows of a kind of its own it had open. At the start each
  scene comes back with its values and is offered its windows; the scenes are
  kept again as they change, but not once the last one ended. The host reads
  and writes the text, and performs `persistSceneValue` through `keep`.
  ([Kept scenes](design/host/runtime.md#kept-scenes))

## Diagnostics

- **`HostLog`** writes one line a message, begun by `StateUI` and the host's
  name, to standard error, which nothing buffers; a platform whose log is its
  own is handed the lines. ([The log](design/host/runtime.md#the-log))
- **`DiagnosticText`** and **`RenderTally`** write the running tally
  (`STATEUI_TALLY=1`) and every inspected pass (`STATEUI_INSPECT=1`) as text,
  and count what applying one message costs. The mounted tree keeps them; the
  host adds nothing.
  ([What a message costs](design/host/patches.md#what-a-message-costs),
  [what a runtime writes out](design/host/patches.md#what-a-runtime-writes-out))

## Testing

- The layer's own tests, in `lib/StateUI.Host/Tests`, prove its rules and
  arithmetic, pure, in its own package's suite on every platform the core
  builds on. They need no toolkit: a hand-wound clock reproduces every frame,
  and a native half of the test's own stands for a view.
- The conformance suite, in `lib/StateUI.Conformance`, proves the
  contract's effects on each real toolkit: a case is written once, and every
  host's suite runs it through the host's driver. It asserts effects - a
  state written, a handler heard, what is shown or let go - never a look, and
  its verdicts are the marks of the [platform contract](platform-contract.md)
  and the [control dictionary](controls/README.md).
  ([Conformance](design/host/conformance.md),
  [the driver](design/host/conformance.md#the-driver),
  [marks](design/contracts/dictionary.md#marks))
- A host's own tests prove its look, the native API behind a member and its
  toolkit's traps. They mark nothing.

## Adding to the layer

Something new reaches the hosts in one order:

1. Decide what of it every host shares - the rule, the order, the arithmetic,
   the state machine - and what only a toolkit can do.
2. Write the shared part in the host layer, in its part's folder, one element
   a file, under `@_spi(Host)`, with its `///` and a `Design:` line naming
   its section.
3. Prove it with pure tests in `lib/StateUI.Host/Tests`; a
   defect is proved red before it is fixed.
4. Give its reason a section in its design note under `docs/design/host/`,
   and the type a line in its part above.
5. Then each host calls it and adds its toolkit's calls. A copy of the rule
   that a host holds is removed, not kept beside the layer's.
6. Where executing the contract shows the effect, a conformance case proves
   it on every host.

One concept has one owner and one spelling. An element's name is its stem -
`Animator`, `StateChannels` - and a host prefixes its toolkit's name to what
only it has. [Names](design/host/runtime.md#names) gives the words the
runtime reserves.
