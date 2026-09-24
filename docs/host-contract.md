# Host contract

Every host is Swift in the application's process and consumes a typed sparse
render through `StateUIHost`, behind `@_spi(Host)`. Code in a platform's own
language - Java through JNI, C++ behind a C ABI - is a relay beneath the host.

## One process, one host

One process owns one `Renderer.shared` and one host adapter. Every scene and
window belongs to the renderer's single application tree and shares its render
generation, state board, handler registry, act queue, and display cycle.
Multi-window support creates more native windows inside
that tree; it never starts another renderer or host.

Start the chosen platform host once, after registering the application. A
second host in the same process would consume the same singleton state without
an independent generation or identity namespace and is therefore unsupported.

## Sparse patches

```swift quote
struct HostRender {
    let generation: Int32
    let complete: Bool
    let root: HostPatch
}

struct HostPatch {
    let id: ElementId
    let type: NodeType

    var replace = false
    var properties: [Prop: HostValue] = [:]
    var clearedProperties: [Prop] = []
    var transitions: [Prop: HostTransition] = [:]
    var driven: HostDrivenUpdate?
    var events: HostEventUpdate?
    var motion: HostLayoutMotion?
    var children: HostChildrenUpdate = .unchanged
}

enum HostChildrenUpdate {
    case unchanged
    case changed([HostPatch])
    case arranged([HostPatch])
}

enum HostDrivenUpdate {
    case replace([Prop: HostStateBinding])
}

enum HostEventUpdate {
    case replace([Event: Int32])
}

struct HostStateBinding {
    let state: Int32
    let mode: HostStateMode
    let kind: HostStateKind
}

struct HostTransition {
    let motion: Motion
}

struct HostLayoutMotion {
    let motion: Motion
    let lanes: MotionLanes
}
```

Absence is meaningful:

- `nil` and `.unchanged` mean no update;
- `.replace([:])` clears a complete binding or event map;
- `.arranged([])` removes every child;
- `replace` rebuilds the native element from a complete patch for that
  identity.

Explicit `.id()` wins, then a `ForEach` item identity, then builder path, then
position. Swift owns matching and diffing; a host does not infer identity from
native objects.

## Apply order

A host applies one generation as one transaction:

1. validate the generation before changing the mounted tree;
2. find the mounted element by `ElementId`, or create the native object for
   a new complete patch;
3. replace an element only when `replace` says so;
4. clear `clearedProperties`, then apply changed `properties` and their
   `transitions`;
5. replace driven bindings and event subscriptions only when their optional
   update is present;
6. apply the changed layout-motion rule;
7. reconcile children according to `changed` or `arranged`;
8. detach every external subscription, recognizer, menu, timer, and native
   object belonging to an element that left;
9. retain the generation only after the transaction is complete.

`HostChildrenUpdate.changed` is a sparse path to descendants. It never changes
the sibling arrangement. `arranged` is the complete ordered list and is the
only case from which a host may infer insertion, removal, or movement.

## Handler identity and lifetime

`HostEventUpdate.replace` is the complete event-to-handler map for one element.
When the set of handled events is unchanged, the handler ids stay stable and no
event-map patch is needed. A rebuilt description replaces the Swift closure
registered under that id, so a native subscription invokes the current
captures without being detached and added again. A composed subtree that is
carried keeps the closure it already registered because that description was
not rebuilt.

A complete resynchronization sends the complete event map with those same
stable ids. When an event is removed, an explicit map replacement makes the
host detach its native callback and StateUI retires the handler. When an
element leaves, all handler ids owned by it stop answering. A late native
callback for a removed element is ignored; it must never reach a closure now
owned by another identity.

## Generations and recovery

The host calls `StateUIHost.render(baseline:)` with the last generation it
applied successfully. The renderer returns a sparse patch only when that
baseline is its current generation. On the first render, for baseline zero, or
for any mismatched baseline, `complete` is true and the root patch describes
the complete current tree.

Zero is reserved for “start over” and is never issued as a generation. The
renderer increments with wrapping arithmetic and skips zero. A host that loses
its mounted tree, rejects a transaction, or cannot prove its baseline requests
a complete render instead of applying a later sparse patch to uncertain state.

A complete render changes how much the message carries, not Swift identity.
The renderer still reconciles against its retained tree, so element ids,
`@State` storage, handlers, and unchanged composed descriptions keep their
identity. The host reconciles the complete hierarchy from that result; it does
not ask the application to construct a separate recovery tree.

## State cycles

The host resolves every `HostStateBinding` against the state board owned by
StateUI. `HostStateMode` states which direction may write. `HostStateKind`
states whether the channel carries a discrete value, journey lanes, text, a
feed, or another declared host shape.

On a native display frame the host:

1. applies pending program writes;
2. advances active property transitions, layout motion, and journey channels;
3. runs StateUI engines in deterministic priority order;
4. publishes the complete value and changed-lane mask for every changed state;
5. requests another display frame only while motion or an engine continues.

All journey values emitted by one clock tick are applied in one post-order tree
walk, so a shared ancestor is rearranged once for that frame. A native host
updates ordinary content views in place; it reconciles scene and window chrome
only when the changed property is presented by that outer shell.

Native input is committed to the matching channel before its event handler is
dispatched. Program writes never dispatch user events. Motion completion lands
on the exact destination once, and an interrupted awaited journey answers that
it did not reach its target.

Each lifecycle phase a host reports - a scene's, a window's or a page's - is
rendered before its next report, so the application sees every phase: a push
that raises a page's `appearing` and `navigatedTo` in one native move reports
them one render apart. A host may batch a user's change with the reports it
causes, never two phases into one render.

## Vocabulary ownership

Every element's contract declares the layer that realizes it, and so does each
of its members - an `ElementLayer`:

- `native` — every base host is required to map the semantic capability to its
  toolkit;
- `adaptive` — each host follows its platform convention while preserving the
  StateUI state contract;
- `stateUI` — the core derives the behavior from smaller primitives;
- `structure` — it carries tree or protocol structure;
- `provider` — an optional package owns the capability.

`NodeType`, `Prop`, `Event`, and `Act` remain open at the value level. An
extension or provider that introduces one must also supply the host adapter,
tests, Gallery coverage, and documentation that give it meaning. The base
AppKit host has no process-wide application control registry: an unknown node
is made visible as unsupported and an unknown property has no effect. A token
alone is not an implementation.

The human-readable inventory and implementation matrix for AppKit, UIKit,
GTK 4, Android Views, WinUI 3, and Web are maintained in
[Platform contract](platform-contract.md), and member by member in the
[control dictionary](controls/README.md). A check mark is evidence about a
host implementation, not merely the existence of a Swift declaration.

A public control belongs in the base library only when the target host families
support one honest semantic contract. A control decision is vertical: its Swift
API, vocabulary, every applicable host, tests, Gallery example, and
documentation change together.

## Thin native hosts

A host is an adapter. It owns:

- creation and lifetime of native objects;
- property and child-patch application;
- native input and lifecycle reports;
- layout integration with the toolkit;
- display-frame property and layout motion.

The host does not own a second description tree, diffing model, router, or
state system. Anything an element attaches outside its native subtree is
detached when that element leaves. No host object may strongly retain a control
after its element is dropped.

Platform-native classes are implementation choices behind semantic StateUI
tokens. They never enter application source, `HostPatch`, event payloads, or
state values.

The active host package is `lib/StateUI.AppKit`. Later hosts are sibling
packages, so platform dependencies never enter the core. `PlacedLayout` and
`GalleryView` remain StateUI-owned composition mechanisms and do not justify a
larger renderer surface.

## Collections

`ItemsView` is the public name for the shared collection surface. It presents
identified items without constraining their arrangement to a list or grid.
StateUI owns logical item order, stable identities, changes, and the subtree
for an identity. The toolkit owns the viewport, cell reuse, input, keyboard
navigation, and accessibility.

The native adapters are expected to use `NSCollectionView` or `NSTableView`,
`UICollectionView`, Android `RecyclerView`, WinUI `ItemsView`, and GTK 4
`GtkListView` or `GtkGridView`. The collection payload enters `HostPatch` only
when those hosts can consume the same complete contract.

Until that payload and its layout, selection, activation, reuse, accessibility,
and programmatic-scroll semantics are settled, the base contract exposes no
native collection control. Richer arrangements remain StateUI compositions
over the smallest accepted primitives.

## Values a host is handed

Every carried value is one case of `HostValue`:

| Value | Meaning |
| --- | --- |
| `.bool` | true or false |
| `.number` | a `Double` |
| `.string` | authored text |
| `.numbers`, `.strings` | homogeneous lists |
| `.color` | four RGBA channels |
| `.values` | a list of values of different kinds |
| `.enumeration` | an `Int32` member of a closed StateUI vocabulary |
| `.name` | an open, author-named vocabulary |
| `.nothing` | semantic absence |

`.string`, `.enumeration`, `.name`, and `.nothing` are not interchangeable.
Authored text remains text; closed library vocabulary has stable StateUI
numbers; open names stay names; absence never borrows an empty string,
sentinel number, or empty list.

The patch is deterministic. Every dictionary- or set-derived collection is
sorted by its stable StateUI name, and subtree shapes use a stable hash rather
than Swift's randomized `Hashable`, so the same session renders the same
patches in every run.
