# Host contract

Same-process Swift hosts consume a typed sparse render. A foreign-language host
can consume the same model through the deterministic little-endian Wire
encoding.

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
    var recycles: Bool?
    var shape: UInt64?
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
- `replace` rebuilds the native subtree for that identity.

Explicit `.id()` wins over builder path, which wins over position. Swift owns
matching and diffing; a host does not infer identity from native objects.

## Apply order

A host applies one generation as one transaction:

1. find the mounted element by `ElementId`, or create the native object for a
   new complete patch;
2. replace an element only when `replace` says so;
3. clear `clearedProperties`, then apply changed `properties` and their
   `transitions`;
4. replace driven bindings and event subscriptions only when their optional
   update is present;
5. apply the changed layout-motion rule;
6. reconcile children according to `changed` or `arranged`;
7. detach every external subscription, recognizer, menu, timer, and native
   object belonging to an element that left;
8. retain the generation only after the transaction is complete.

`HostChildrenUpdate.changed` is a sparse path to descendants. It never changes
the sibling arrangement. `arranged` is the complete ordered list and is the
only case from which a host may infer insertion, removal, or movement.

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

Native input is committed to the matching channel before its event handler is
dispatched. Program writes never dispatch user events. Motion completion lands
on the exact destination once, and an interrupted awaited journey answers that
it did not reach its target.

## Vocabulary ownership

`HostContract` is the checked inventory for StateUI's built-in controls,
properties, and events. Every built-in token has one owner:

- `native` — every base host maps the semantic capability to its toolkit;
- `adaptive` — each host follows its platform convention while preserving the
  StateUI state contract;
- `stateUI` — the core derives the behavior from smaller primitives;
- `structure` — the token carries tree or protocol structure;
- `provider` — an optional package owns the capability.

Application-defined tokens remain open and are resolved through the
application's control registry.

The human-readable inventory and implementation matrix for AppKit, UIKit,
GTK 4, Android Views, WinUI 3, and Web are maintained in
[Platform contract](platform-contract.md). A check mark is evidence about a
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

The shared collection surface is semantic, not named after a platform class.
StateUI owns logical item order, stable identities, changes, and the subtree for
an identity. The toolkit owns the viewport, cell reuse, input, keyboard
navigation, and accessibility.

The native adapters are expected to use `NSCollectionView` or `NSTableView`,
`UICollectionView`, Android `RecyclerView`, WinUI `ItemsView`, and GTK 4
`GtkListView` or `GtkGridView`. The collection payload enters `HostPatch` only
when those hosts can consume the same complete contract.

Until that payload and its selection, activation, reuse, accessibility, and
programmatic-scroll semantics are settled, the base contract exposes no
partial collection control. Richer arrangements remain StateUI compositions
over the smallest accepted primitives.
