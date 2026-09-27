# StateUI core

The core is the `StateUI` library, in `lib/StateUI/Sources`: one dynamic
library, the same on every platform, which every application and every host
links, so a process holds one copy of StateUI's types. It imports no
Foundation and no platform framework, depends on no package and exports no C
function. It owns the UI tree, state, identity and diffing, the state side of
the display cycle, the timing laws of motion, acts, scenes and sessions, and
the element contracts every node type is declared by. It has two faces: the
public API an application writes with, and the typed boundary a host reads
through - `HostBoundary` and the values beside it, behind `@_spi(Host)`.
Between that boundary and every toolkit stands the [host layer](host-layer.md),
and the [host contract](host-contract.md) specifies the typed patch the
boundary hands over.

## The rule

The core decides once what is StateUI's to decide, and nothing after it
decides again; one concept has one owner, one spelling and one source:

- **One direction.** An application depends on the core, the host layer
  depends on it through `@_spi(Host)`, a host reaches it only through that
  boundary, and the core depends on nothing. A relay in a platform's own
  language never calls the core; it is handed pointers, never ownership.
  ([The packages](design/architecture.md#the-packages))
- **One declaration of state.** `@State` is the only one. Read in a body, a
  write rebuilds that body (reactive path 1); handed on as `$x`, the host
  carries it with no rebuild (reactive path 2). Its journey is part of it.
  ([Architecture](architecture.md), [state](design/core/state.md))
- **One contract per node type.** Every node type, tier and member exists
  through one contract, and everything writes and hears through its members;
  the public API has no road by token. ([Contracts](design/core/contracts.md))
- **The core alone keys and diffs.** An element is the same element by its
  `.id()`, then its builder path, then its position, and only the patch tells
  a host what changed. ([Keys](design/core/identity-and-diffing.md#keys))
- **The patch is deterministic.** The same session gives the same patch and
  exports on every run: tokens compare by name, whatever a dictionary or a set
  yields is sorted, and the core numbers the scenes.
  ([Tokens](design/core/contracts.md#tokens))
- **The UI thread is `MainActor`.** The core has no thread, run loop or timer
  of its own; everything happens inside a call the host makes on its UI
  thread, and handlers run on `@MainActor`. Nothing uses `Timer`, `RunLoop` or
  `DispatchQueue.main` but `UIThread.swift`'s one drain, and the core never
  calls a host back.
  ([MainActor on every platform](design/core/concurrency.md#mainactor-on-every-platform))
- **One process, one renderer.** `Renderer.shared` holds the one tree of every
  scene and window, with one generation, one board and one act queue.
  ([One process, one host](host-contract.md#one-process-one-host))

```text
lib/StateUI/Sources/
  Views/         what an application writes
    Structure/ Navigation/ Menus/   the application, its pages, their furniture
    Tiers/ Mixins/ Bindings/        tier protocols, modifiers, carried twins
    Composition/                    composed views, builders, ForEach
    Controls/ Text/ Layouts/        the library's views
    Shapes/ Collections/
    Styles/ Inspector/              styles and visual states, the inspector
  Types/         the values an application passes, and how each crosses
    Geometry/ Layout/ Colour/ Drawing/ Text/ Time/
    Motion/ Gestures/ Environment/ Sessions/ Controls/
  Contracts/     the library's contracts, and LibraryContracts
    Elements/    one contract per node type, in its view's topic folder
    Tiers/ Mixins/                  members several elements share
  Core/          the machinery
    State/ Carried/ Journey/        @State, carried values, journeys, laws
    Cycle/ Render/ Diff/            the board, the renderer, the differ
    Acts/ Scenes/                   acts and aims, the open scenes
    Contract/ Realization/          what a contract is, what a host realizes
    Threads/ Diagnostics/           the UI thread, the lock, the inspection
    Boundary/                       HostBoundary and the values a host reads
```

The parts meet along the two reactive paths, and everything a host reads
leaves through one boundary:

```text
  Views/  Types/  Contracts/      views as nodes written through their
        |                         contracts, values that cross, members
        v
  Core/State ---------------------+     a write asks for a render or a cycle
        | read in a body          | handed on as $x
        v                         v
  Core/Render -> Core/Diff        Core/Carried, Core/Journey -> Core/Cycle
  reactive path 1: HostRender     reactive path 2: HostCycle
        |                         |
        +------------+------------+
                     v
  Core/Boundary  <-- Core/Acts, Scenes, Realization, Threads, Diagnostics
        |  @_spi(Host)
        v
  the host layer's CoreLink
```

The design notes give each part's reasons - [views](design/views/README.md),
[values](design/types/README.md),
[element contracts](design/contracts/README.md) and
[the core](design/core/README.md), whose
[state write from start to finish](design/core/README.md#a-state-write-from-start-to-finish)
follows one change through - and the [glossary](design/glossary.md) maps
StateUI's words to the common ones.

## Who reaches what

Each part below says who reaches it:

- *Application* - the public API, what an application's module spells, each
  declaration with its `///`.
- *Host* - `@_spi(Host) public`, what the host layer and a host read after
  `@_spi(Host) import StateUI`. An application never sees it.
- *Internal* - nobody outside the module; the core's tests reach it through
  `@testable import`.

## Views

`Views/` holds what an application writes. Each view is a value that
describes itself as a `Node`, read afresh on every render, and the differ
turns the nodes into the patch.
([What a view is](design/views/README.md#what-a-view-is))

- **`Application`**, **`Scene`**, **`Window`** and **`Page`** (`Structure/`)
  are the application's structure, one composition getter each; `Windows`,
  `WindowGroup`, `WindowType` and `WindowError` are a scene's windows;
  `TitleBar` is an authored title area. `stateUIUseApp` names the application
  to the host from the application's own registration function.
  *Application.* ([Pages and windows](design/views/pages.md);
  [applications and sessions](application-and-sessions.md))
- **`NavigationStack`**, **`TabbedView`**, **`SplitView`** and
  **`ModalStack`** (`Navigation/`) are arrangements: pages that key the pages
  they hold, whose stack, chosen tab and modal stack are state. `Menu`,
  `MenuItem`, `MenuSeparator` and `ToolbarItem` (`Menus/`) are a menu's
  entries and a page's actions, collected without keys. *Application.*
  ([Arrangements are pages](design/views/pages.md#arrangements-are-pages),
  [menus](design/views/builders.md#menus-collect-without-keys);
  [navigation and presentation](navigation-and-presentation.md))
- **The tier protocols** (`Tiers/`) - `PropertyContainer`,
  `ModifiableElement`, `VisualElement`, `View`, `Layout`, `StackBase`, `Shape`
  and `InputView`, each with the `…Properties` half a style wears - and **the
  mixin tiers** (`Mixins/`), `TextElement`, `FontElement`, `TintElement` and
  their kin, offer the modifiers; a protocol's modifiers write the members of
  the tier contract of its name. *Application.*
  ([Two halves](design/views/tiers.md#two-halves),
  [modifiers](design/views/modifiers.md))
- **The binding twins** (`Bindings/`) are the `Binding` form of each value
  modifier, the driven words of a label, and the feeds the platform reports
  into a state; `setValue(_:on:mode:kind:)` carries an application's own
  property. *Application.* ([Bindings](design/views/bindings.md);
  [described and carried values](controls-and-input.md#described-and-carried-values))
- **`ContentView`**, **`ModifiedContent`**, **`ViewBuilder`** and
  **`ForEach`** (`Composition/`) compose: a composed view is a placeholder
  the differ builds or carries whole, a builder records the path of every
  statement, and `ForEach` keys each view by its item. *Application.*
  ([Composition](design/views/composition.md), [builders](design/views/builders.md);
  [composition and identity](composition-and-identity.md))
- **The library's views** - `Controls/` (`Button`, `Slider`, `Picker`, `Map`,
  `WebView` and the rest), `Text/` (`Label`, `TextSpan`, `TextField`,
  `TextEditor`, `SearchField`), `Layouts/` (`VStack`, `HStack`, `Grid`,
  `ZStack`, `ScrollView`) and `Shapes/` (`Rectangle`, `Path`, `Canvas` and
  their kin) - are each a node written through its contract, with a
  `…Properties` protocol of its own. *Application.*
  ([Controls](design/views/controls.md);
  [controls and input](controls-and-input.md), [layout](layout.md))
- **The composed layouts** - `FrameReader`, `ScrollReader` and `PlacedLayout`
  (`Layouts/`), `GalleryView` and `PositionIndicator` (`Collections/`) - are
  StateUI's composition over measurement, placement and scrolling, which no
  host builds again. *Application.*
  ([Measured layouts](design/views/measured-layouts.md);
  [StateUI-authored layouts](layout.md#stateui-authored-layouts))
- **`Style`**, **`StyleSheet`**, **`StyleTarget`** and **`VisualState`**
  (`Styles/`) are resolved before the patch: a node reaches the host already
  styled. *Application*; the merge (`styled`, `DeclaredState`) is internal.
  ([Styles](design/views/styles.md); [styles and drawing](styles-and-drawing.md))
- **`Inspector`**, **`InspectorButton`** and **`DebugInspector`**
  (`Inspector/`) show what each render costs and builds, inside the
  application, as a tree whose own views are muted. *Application*; its views
  and model are internal. ([Inspector](design/views/inspector.md);
  [build diagnostics](composition-and-identity.md#build-diagnostics))

## Types

`Types/` holds the values an application passes, and the providers and
sessions whose properties are `@State`. A value that crosses is
`HostRepresentable` - how it becomes a `PropValue` and comes back - or a
`StateValue`, how it lies on a carried state's image, so no host parses or
guesses anything. A closed vocabulary crosses as a number StateUI owns, an
author's open vocabulary as a `Name`, and absence as `.nothing`.
*Application*; a host is handed them as values.
([From a value to a host](design/types/README.md#from-a-value-to-a-host),
[the kinds of PropValue](design/types/README.md#the-kinds-of-propvalue))

| Folder | What it holds | Reasons |
| --- | --- | --- |
| `Geometry/` | `Point`, `Rect`, `Insets`, `CornerRadius`, `ViewTransform` | [runs of numbers](design/types/values.md#runs-of-numbers), [transforms](design/types/transforms.md) |
| `Layout/` | `Alignment`, `Area`, `GridLength`, `LayoutDirection`, `SafeArea`, `SafeAreaEdges`, `Placement`, `PlacedRun` | [placement](design/types/placement.md) |
| `Colour/` | `Color`, `GradientStop`, `Brush`, `Background` | [colour and theme](design/types/colour-and-theme.md), [brushes](design/types/brushes.md); [styles and drawing](styles-and-drawing.md) |
| `Drawing/` | `ImageSource`, `ContainerShape`, `Aspect`, the strokes, `Draw`, `DrawCommand`, `DrawingBuilder` | [drawing on a canvas](design/types/drawing.md) |
| `Text/` | `Name`, `FontAttributes`, `LineBreak`, `TextAlignment`, `TextCase`, `TextDecorations`, `InputPurpose`, `ReturnKey`, `HeadingLevel` | [text and names](design/types/values.md#text-and-names), [closed vocabularies](design/types/vocabularies.md) |
| `Time/` | `CalendarDate`, `ClockTime`, `TimeZoneInfo`, `Weekday` | [dates and time](design/types/dates-and-time.md) |
| `Motion/` | `Motion`, `Easing`, `MotionValues`, `MotionLanes`; a view's `MotionPlan`, internal | [motion](design/types/motion.md); [motion and journeys](motion-and-journeys.md) |
| `Gestures/` | `GesturePhase`, `PanUpdate`, `PinchUpdate`, `SwipeDirection` | [gestures](design/types/gestures.md) |
| `Environment/` | the standard providers - `Battery`, `Connectivity`, `DeviceDisplay`, `DeviceInfo`, `LocaleInfo`, `AppInfo` - their vocabularies and `Theme`; `StandardEnvironment`, internal | [the standard environment](design/types/environment.md); [environment](environment.md) |
| `Sessions/` | `ApplicationSession`, `SceneSession`, `WindowSession`, `PageSession`, their phases, `WindowOverlays` | [sessions](design/types/sessions.md); [applications and sessions](application-and-sessions.md) |
| `Controls/` | the vocabularies one control takes: `ScrollOrientation`, `ToolbarItemPlacement`, `PinType` and their kin | [closed vocabularies](design/types/vocabularies.md) |

## Contracts

`Contracts/` holds the library's declarations; what a contract is stands in
[`Core/Contract/`](#contract).

- **The element contracts** (`Contracts/Elements/`, in the topic folders of
  their views: `Controls`, `Text`, `Layouts`, `Shapes`, `Collections`,
  `Structure`, `Slots`, `Navigation`, `Menus`) are one enum per node type:
  its node type, its layer, the tiers it wears and each member with its
  value's type. An application writes and hears through them, as in
  `setValue(LabelContract.maximumLines, 3)`, and a host registers them.
  *Application* and *host.*
  ([One declaration per node type](design/contracts/README.md#one-declaration-per-node-type),
  [structure elements](design/contracts/structure.md))
- **The tier contracts** (`Contracts/Tiers/`) and **the mixin tiers**
  (`Contracts/Mixins/`) declare once the members several elements share, each
  naming the same set as the Swift tier protocol of its name in `Views/`.
  *Application* and *host.* ([Tiers](design/contracts/tiers.md),
  [layers](design/contracts/layers.md))
- **`LibraryContracts`** lists every contract the library declares, the tiers
  first; the differ reads its member facts by name from it, and the guards and
  the dictionary read it whole. *Host.*
  ([The contracts of the library](design/contracts/README.md#the-contracts-of-the-library))

The [control dictionary](controls/README.md) and the tables of the
[platform contract](platform-contract.md) are rendered from these
declarations and each host's verdicts ([marks](design/contracts/dictionary.md#marks)).

## Core

`Core/` holds the machinery: one folder a topic, one element to a file, a
type's extensions in its folder as `Type+Responsibility.swift`
([where things live](design/core/README.md#where-things-live)).

### State

- **`State`** is the one declaration of mutable state: a box made again with
  its view on every render, which adopts its predecessor's storage
  (`State.Storage`, internal), the one object that means this state across
  renders. A class declares its properties with it too.
  *Application.* ([Storage and box](design/core/state.md#storage-and-box);
  [state and reactivity](state-and-reactivity.md))
- **`Binding`** is a state borrowed as `$x` - no second value, no second
  owner - and a part of one through dynamic member lookup. *Application.*
  ([Bindings](design/core/state.md#bindings))
- **`Environment`** resolves the nearest provided object by its type; the
  standard providers and the four sessions are there with nothing provided.
  *Application.* ([The environment](design/core/state.md#the-environment);
  [environment](environment.md))
- **`PersistentKey`**, **`PersistentValue`** and **`PersistentKind`** are kept
  state, hydrated by the host before the first render (`PersistentStore`,
  internal). *Application.* ([Kept state](design/core/state.md#kept-state);
  [persistent state](state-and-reactivity.md#persistent-state))
- **`ElementSession`** is an object an element keeps for its life - how a
  page holds its `PageSession`. *Internal.* An `@Observable` model held in a
  `@State` is deprecated, since nothing arms its tracking.
  ([Element sessions](design/core/state.md#element-sessions),
  [an observable model](design/core/state.md#an-observable-model))

### Carried values

- **`StateValue`**, **`Walked`** and **`StateChoice`** say how a value rides a
  state and lies on its image, which values a journey is made of lane by
  lane, and how a closed vocabulary rides as its member's number.
  *Application* conforms its own values.
  ([Carried state](design/core/state.md#carried-state),
  [a state has one shape](design/core/state.md#a-state-has-one-shape))
- **`HostStorage`** is a carried state's value as the bytes both sides
  rewrite, in three copies: the image, the published copy and a pending
  write. Its type is public and its members internal.
  ([Three copies of a value](design/core/cycle.md#three-copies-of-a-value))
- **`StateCarried`**, **`StateMode`** and **`StateKind`** are a value as the
  image holds it, the way it crosses at an attachment, and the door it goes
  through; a host reads them as `HostStateValue`, `HostStateMode` and
  `HostStateKind`. `StateRegistration` and `StateImage` are internal.
  ([A state the host carries](design/types/README.md#a-state-the-host-carries))

### Journeys

- **`Journey`** is `$x.journey`: the value shown this frame, the destination,
  the velocity and the law, with `move(to:_:)`, `stop()` and `snap(to:)`.
  *Application.* ([The journey lanes](design/core/journeys.md#the-journey-lanes);
  [journey is part of state](motion-and-journeys.md#journey-is-part-of-state))
- **Conversions and readings** - `convert`, `.multi` (`MultiBinding`) and
  `.samples(_:into:_:)` at the pace `Asks` gives - run as engines the differ
  writes (`Conversion`, `Sampling`, internal). *Application.*
  ([Conversions](design/core/journeys.md#conversions),
  [readings](design/core/journeys.md#readings))
- **`HostMotionLaw`** and **`HostMotionSample`** evaluate the two timing laws
  from the time since an animation began; the host layer's animator alone
  samples one. *Host.* `JourneyLanes` and `StateLaw`, how a journey and its
  law lie on the image, are internal.
  ([Motion laws](design/core/journeys.md#motion-laws),
  [the law on the image](design/core/journeys.md#the-law-on-the-image))

### The cycle

- **`CycleBoard`** is one clock's images, engines and cycle: latch the
  pending writes, run the engines with a reason, publish what moved.
  *Internal*; the host runs it through `HostBoundary.cycle`.
  ([The board](design/core/cycle.md#the-board),
  [where a write lands](design/core/cycle.md#where-a-write-lands))
- **`.engine(following:)`**, **`EngineCycle`**, **`EngineAnswer`**,
  **`Sync`** and **`Followable`** make an engine: application frame code that
  runs while it has a reason - armed by a render, stirred by a write to a
  state it follows, awake after `.again`. Its own write never wakes it.
  *Application.* ([What wakes an engine](design/core/cycle.md#what-wakes-an-engine);
  [custom engines](state-and-reactivity.md#custom-engines))
- **`Ticker`** is a repeating timer on `Task.sleep`, sleeping to a deadline.
  *Application.* ([The ticker](design/core/cycle.md#the-ticker);
  [work on each tick](concurrency.md#work-on-each-tick))

### The render

- **`Renderer`** is the one renderer, `Renderer.shared`: it holds the
  application, the states written since the last render and their live
  readers, the generation, the act queue and the completions, and takes one
  of three roads - the clean walk, a build, or the complete tree. An
  application reaches `setApplication` through `stateUIUseApp`, and
  `setNeedsRender` to bridge a model it observes itself; a host reaches the
  rest through `HostBoundary`.
  ([Three roads](design/core/render.md#three-roads),
  [generations and baseline](design/core/render.md#generations-and-baseline))
- **`ReadScope`** and **`BuildScope`** record what a build reads and which
  view is being described; `debugInfo()`, public, explains a build in the
  author's names. *Internal.* ([Invalidation](design/core/invalidation.md))
- **The dispatch** (`Renderer+Dispatch.swift`) starts a handler: its payload
  read at once, then `Task.immediate` on `MainActor`. The handlers a render
  finds run in settle passes, and what they write joins the same message.
  *Internal.* ([Starting a handler](design/core/render.md#starting-a-handler),
  [handlers in the message](design/core/render.md#handlers-in-the-message))

### Diffing and identity

- **`Node`**, **`Element`**, **`PropValue`** and **`ElementId`** are one
  element as written this render, anything that describes itself as one, a
  value in the tree and at the boundary, and an element's key. *Application*;
  a host reads `PropValue` as `HostValue` and `ElementId` in every patch.
  ([Keys](design/core/identity-and-diffing.md#keys),
  [how a value crosses](design/types/values.md))
- **`Differ`** and **`RenderedNode`** walk the tree a render built against the
  tree the host holds and pack only the differences into a `HostPatch`: keys,
  adopted state, carried views, handler ids, driven states, transitions and
  layout motion. *Internal.*
  ([Identity and diffing](design/core/identity-and-diffing.md))
- **`StateBox`**, **`Input`** and **`stateParts`** (`Stateful.swift`) are what
  the differ reads of a composed view: its state boxes, its environment slots
  and the inputs it compares to carry the view. *Internal.*
  ([Carrying a view](design/core/identity-and-diffing.md#carrying-a-view))
- **`.onChanged`**, **`.onCreated`** and **`.onDestroying`** (`Changes.swift`,
  `Lifetime.swift`) are about the tree, not the platform: they run after the
  walk, and what they write is in the same message. *Application.*
  ([Created and destroying](design/core/identity-and-diffing.md#created-and-destroying);
  [element lifetime](composition-and-identity.md#element-lifetime))
- **`VisualStateRules`**, **`VisualInput`** and **`VisualStateListener`**
  decide once which visual state a control is in, from what the user does to
  it. *Internal.*
  ([Which state a control is in](design/views/styles.md#which-state-a-control-is-in))

### Acts

- **`stateUICall`**, **`stateUISend`** and **`StateUIError`** call an act of
  the application's - one with no control behind it - awaited or sent, and
  throw what a host could not do. *Application.*
  ([An act is a member](design/core/acts.md#an-act-is-a-member);
  [host-extension actions](interaction-and-actions.md#host-extension-actions))
- **`Aim`** is which control an act is aimed at: neither state nor a key.
  *Application.* ([Aims](design/core/acts.md#aims);
  [aims and control methods](interaction-and-actions.md#aims-and-control-methods))
- **`Dialogs`**, **`ScreenReader`**, **`OnScreenKeyboard`** and focus through
  an aim are the library's own acts. *Application.*
  ([Dialogs](design/core/acts.md#dialogs),
  [focus and the keyboard](design/core/acts.md#focus-and-the-keyboard))
- **`HostEvents`** and **`HostEventSubscription`** hear the events of the
  application's tier that a host raises. *Application.*
  ([Host events](design/core/acts.md#host-events);
  [host-extension events](interaction-and-actions.md#host-extension-events))
- **`ActCall`** and **`Reply`** are an act queued under its completion id and
  the answer it gets. *Internal*; a host takes each as a `HostActCall`.
  ([The act queue](design/core/acts.md#the-act-queue),
  [completion ids](design/core/acts.md#completion-ids))

### Contract

- **`Contract`**, **`ElementContract`** and **`ApplicationTier`** are a named
  set of members, a node type's contract, and a tier the application element
  wears. *Application* declares its own; `Contract.worn` is the host's.
  ([Tiers](design/core/contracts.md#tiers))
- **`ElementProperty`**, **`ElementEvent`** and **`ElementAct`** are the three
  kinds of `ContractMember`, each carrying its value's types. *Application*;
  each member's `token` is the host's.
  ([Members are written with their contract](design/core/contracts.md#members-are-written-with-their-contract))
- **`ElementLayer`** says who realizes an element or a member. *Application.*
  ([Layers](design/contracts/layers.md))
- **`HostRepresentable`** is a member's value and how it crosses and comes
  back; **`MemberValues`** encodes a member's positional values and refuses a
  payload of another shape whole. *Application*; `MemberValues` is the host's.
  ([Values that cross](design/core/contracts.md#values-that-cross))
- **`MemberFacts`** is what a member says of itself - whether it travels, is
  cleared, which group it moves with - read by name. *Internal.*
  ([Member facts](design/core/contracts.md#member-facts))
- **`NodeType`**, **`Prop`**, **`Event`** and **`Act`** are tokens: a name and
  only a name. The types are public, since a contract spells its node type as
  one; the library's entries (`Tokens.swift`), made from its members, are the
  host's. ([Tokens](design/core/contracts.md#tokens))

### Realization

- **`Registry`**, **`Registration`**, **`ElementValues`** and **`Reports`**
  are a host's realization of each element contract, member by member: how
  its view is made, which members the view takes, which events it raises -
  generic over the platform's view type. *Host.*
  ([Realizations](design/core/contracts.md#realizations))
- **`HostRealization`** and **`HostDeclaration`** are what a host realizes,
  handed over before the first render, and what it declares, read off its
  runtime with each owner named against the contracts. *Host.*
  `HostRealizations`, what the core was told, is internal.
  ([Declarations](design/core/contracts.md#declarations))
- **`HostRegister`**, **`HostRecord`** and **`HostVerdict`** are a host's
  register - its records by hand and its runtime's export - which decides
  whether a conformance case runs and what its verdict says. *Host.*
  ([Marks](design/contracts/dictionary.md#marks))

### Scenes

- **`Scenes`**, **`SceneRecord`** and **`SceneElement`** keep the open scenes
  as state the root reads, numbered by the core, each with its windows and
  their sessions. *Internal*; an application opens a scene through its
  `ApplicationSession`, and a host connects one through `HostBoundary`.
  ([The scene tree](design/core/scenes.md#the-scene-tree),
  [connecting and ending](design/core/scenes.md#connecting-and-ending))
- **`SceneKey`** names a value a scene keeps for the platform to restore
  (`@State(sceneKey:)`). *Application.*
  ([Scene keys](design/core/scenes.md#scene-keys);
  [state kept with a scene](state-and-reactivity.md#state-kept-with-a-scene))
- **`ValueText`** writes a `Codable` value as text and reads it back, by hand,
  in the order the value encoded it. *Internal.*
  ([What the platform keeps](design/core/scenes.md#what-the-platform-keeps))

### Threads

- **`UIThreadExecutor`** (`UIThread.swift`) is `MainActor`'s executor where
  nothing drains the platform's main queue, and the doorbell a host parks a
  thread on; `stateUIRunJobs` drains it on the calling thread, bounded.
  *Internal*; a host drains it through `HostBoundary.runJobs`.
  ([The doorbell](design/core/concurrency.md#the-doorbell),
  [draining jobs](design/core/concurrency.md#draining-jobs))
- **`Lock`** is the lock that state several threads touch stands behind,
  taken in one order. *Internal.* ([The lock](design/core/concurrency.md#the-lock))

### Diagnostics

- **`Inspection`** is the record an inspector reads: a pass for each render,
  an entry for each composed view it reached, and the host's half matched by
  generation. *Internal.* ([The inspector](design/core/diagnostics.md#the-inspector))
- **`complain`** says, once per process, that a value an application handed
  the library was not one it could use. *Internal.*
  ([Complaints](design/core/diagnostics.md#complaints))
- **The tally** - renders, empty ones, refused writes, live elements - is the
  renderer's, and a host reads it as `HostTally`.
  ([The tally](design/core/diagnostics.md#the-tally))

## The boundary

`Core/Boundary/` is the core's face to a host: `HostBoundary`, an enum of
static calls, and the typed values it hands over and takes back, all behind
`@_spi(Host)` and never serialized. In a runtime the host layer's `CoreLink`
alone calls it, and the lane codecs are called where the layer holds the
values ([core link](design/host/runtime.md#core-link)). The
[host contract](host-contract.md) says what each value means.

- **Render and patch.** `needsRender` and `render(baseline:)` answer a
  `HostRender` - its generation, whether it is complete, the root
  `HostPatch` - with `HostChildrenUpdate`, `HostDrivenUpdate`,
  `HostEventUpdate`, `HostTransition` and `HostLayoutMotion` inside and each
  value a `HostValue`. ([Sparse patches](host-contract.md#sparse-patches),
  [generations and recovery](host-contract.md#generations-and-recovery))
- **The display cycle.** `cycle(_:now:reducesMotion:)` advances one clock and
  answers a `HostCycle` of `HostStateChange`s in ascending state numbers;
  `cyclesPending` says whether anything waits for one, and `cycleTrace` gives
  the last as a line. ([State cycles](host-contract.md#state-cycles))
- **Carried states and journeys.** `value(for:)` reads the image a
  `HostStateBinding` carries out; `report(_:through:)` and
  `report(_:updating:through:)` bring a value or a journey's parts back;
  `complete(_:succeeded:)` answers an awaited journey; `gestureValue(state:)`
  and `moveGestureValue(_:state:)` follow a pan. The codecs `journey(from:)`,
  `value(of:)` and `placements(from:)` turn an image into a `HostJourney` or
  a `HostPlacementRun` and back, so no host knows a lane.
  ([What the host reports](design/core/cycle.md#what-the-host-reports))
- **Handlers and the application's events.** `dispatch(_:payload:)` runs the
  handler an event names, and `raise(_:_:)` an event of the application's
  tier, typed by its member.
  ([Handler identity and lifetime](host-contract.md#handler-identity-and-lifetime))
- **Acts.** `takeActCalls()` hands over the `HostActCall`s in the order the
  application made them; `reply(_:with:)` answers one and `fail(_:reason:)`
  fails it, so no caller waits on an act nobody performs.
  ([Acts](design/core/acts.md))
- **The UI thread.** `runJobs()` drains `MainActor`'s queued jobs on the
  calling thread, and `waitForWork()` parks the doorbell until work arrives.
  ([The doorbell](design/core/concurrency.md#the-doorbell))
- **What the host knows.** `setTheme`, `setDeviceInfo`, `setDisplayInfo`,
  `setApplicationInfo`, `setBatteryInfo`, `setConnectivityInfo`,
  `setLocaleInfo` and `setApplicationPhase` each write one standard provider,
  only where a field differs; `languageDirection` reads back the way the
  user's language is written.
  ([How the host writes it](design/types/environment.md#how-the-host-writes-it))
- **Scenes and kept values.** `connectScene(restoring:)` hands the core a
  scene the platform made, with what it kept; `persistentKeys` and
  `restorePersistent(_:)` hydrate kept state before the first render.
  ([Kept state](design/core/state.md#kept-state))
- **Realization.** `setRealization(_:)` says what the host realizes, which
  `realizes(_:)` answers; the registrations stand in
  [`Core/Realization/`](#realization).
- **Drawing.** `HostDrawing` is a canvas drawing as three flat lists,
  `HostPath` a path's SVG text parsed once for every host - with
  `HostCurveCommand` for a toolkit with no arc - `HostDrawingTransform` and
  `HostMatrix` how a view is drawn over its place, and `PropValue.argb` a
  colour as one number for a relay.
  ([Three lists for a relay](design/types/drawing.md#three-lists-for-a-relay),
  [canvas and path](design/views/controls.md#canvas-and-path))
- **Diagnostics.** `tally` is a `HostTally`; `inspecting`,
  `takeInspectionLog()` and `inspected(generation:scenes:apply:nodes:made:)`
  exchange the inspector's record.
  ([What a message costs](design/host/patches.md#what-a-message-costs))

Beside the facade, a host reads the other `@_spi(Host)` parts named above:
the tokens and `Contract.worn`, `MemberValues`, `LibraryContracts`,
`HostMotionLaw` and the realization types. No closure and no object of the
application's crosses: a handler crosses as its id, a drawing as records, a
carried state as its number and image, and a themed value as the half in
force ([values a host is handed](host-contract.md#values-a-host-is-handed)).

## Testing

The core's suite, `lib/StateUI/Tests`, is `swift test` at the repository
root. It needs no toolkit, runs on every platform the core builds on, and
asserts on the typed patch a host is handed, by the rule each case keeps,
never against a stored copy
([what the tests hold](development.md#what-the-tests-hold)).

| Folder | What it proves |
| --- | --- |
| `Rendering/` | builders and paths, builds and carried views, the diff, an element's release, determinism, the patch's shape, the typed render, drawings and SVG paths, the inspector |
| `State/` | `@State`, readers and invalidation, carried state and its cost, conversions, journeys and motion, the cycle and engines, the ticker, kept and model state, the environment, `.onChanged` and lifetime handlers, placed runs, driven patches |
| `Contracts/` | the contracts and the library's list, closed vocabularies, payloads, the whole contract against every name the library uses, the registry, declarations, realizations, the register and its verdicts, and the rendered dictionary (`ControlDictionaryTests`) |
| `Pages/` | scenes, windows, pages and their bars, the navigation stack, tabs, the split view, the modal stack, the environment a host writes |
| `Acts/` | act calls and their shape, aims, host events |
| `Views/` | controls, styles and visual states, colours and brushes, gestures, the frame reader, the gallery view, context menus, drawing transforms |
| `Threading/` | the UI thread's executor and the doorbell, acts sent from many threads, the lock, every async function on its caller's executor, and the library's four rules: no Foundation, no `DispatchQueue.main` but the one drain, no `Timer` or `RunLoop`, no `strdup` |
| `Project/` | the guards below |
| `Support/` | what the tests share: a differ to talk to, a patch printed readably, the dictionary's rendering, the applications' sources as files |

- **The project guards** read the repository as files: `DesignNotesTests`
  resolves every `Design:` reference and holds the golden rule of comments;
  `DocumentationTests` refuses an undocumented public declaration;
  `LicenceTests` holds the SPDX lines; `NativeProjectTests` keeps each host a
  sibling package named only under its condition, and a library that exports
  no C function; `RuntimeArchitectureTests` reads every host's sources
  ([what a host never does](host-layer.md#what-a-host-never-does));
  `ToolchainTests`, `ReleaseTests`, `AppsTests` and `VsCodeTests` keep one
  Swift release, one version, the applications and the editor.
- **The host layer's suite**, `swift test --package-path lib/StateUI.Host`,
  proves its rules with no toolkit, the core's `HostMotionLaw` among them
  (`MotionLawTests`). ([Testing](host-layer.md#testing))
- **The conformance suite**, `lib/StateUI.Conformance`, proves the contract's
  effects through every host's driver; its own tests prove the runner and that
  every member has its case (`ContractCompletenessTests`).
  ([Conformance](design/host/conformance.md))
- **The Gallery's suite** compiles every `swift` block of the handbook
  (`DocumentationExamplesTests`) and refuses each removed spelling at compile
  time (`ContractRoadsTests`).

## Changing the core

A change to what StateUI promises is one vertical change, in one order:

1. Decide its cross-platform name, its owner and its layer: what the core
   decides, what the host layer computes for every host, and what only a
   toolkit can do.
2. Declare it in its contract: a member with its value's type and layer, on
   the contract's `members` list; a node type through one `ElementContract`,
   listed in `LibraryContracts`. The member makes its token.
3. Write the public Swift in its topic folder, one element a file, with its
   `///`. A reason, a trap or a rule goes to its design note; the code keeps
   two or three lines and a `Design:` line naming the section.
4. Prove it in the core suite, in its topic's folder, on the typed patch; a
   defect is proved red before it is fixed.
5. Where a host needs something new, add it to `Core/Boundary/` behind
   `@_spi(Host)`, typed and deterministic, and let `CoreLink` carry it.
6. Write the host layer's part first where hosts share it, then every host's
   toolkit calls, and a conformance case where executing the contract shows
   the effect ([adding to the layer](host-layer.md#adding-to-the-layer)).
7. Give it a Gallery example and a handbook section, and render the
   dictionary again after each host's run.

A removal takes the same road, and a guard refuses the removed spelling. The
core never gains Foundation, a platform framework, a thread of its own, or
output whose order a hash decides
([changing the public contract](development.md#changing-the-public-contract),
[contributing](../CONTRIBUTING.md)).
