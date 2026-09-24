# Layout

StateUI describes layout intent and keeps the resulting tree identities. A
native host measures and arranges native controls. Swift owns the semantic
rules that must stay identical across hosts; the host owns integration with its
toolkit's measurement and display cycle.

The declared primitive vocabulary is deliberately small: vertical and
horizontal stacks, `Grid`, `AbsoluteLayout`, `ScrollView`, `Border`, and
ordinary view sizing and alignment. More specialized arrangements are composed
from these or implemented once as StateUI-authored layout. A primitive is
usable on a platform only when its row and required members are checked in the
platform matrix.

## Size, margin, padding, and alignment

Every eligible view can state requested, minimum, and maximum dimensions:

```swift
Label("Summary")
    .width(240)
    .minimumHeight(44)
    .horizontalAlignment(.center)
    .verticalAlignment(.start)
    .margin(16, 8)
```

A request is input to measurement, not a promise that the platform has that
much room. Minimum and maximum values bound the request. The enclosing layout
still decides the final rectangle.

`margin` is outside a view. `padding` is inside controls and containers that
own content padding. `Insets` can be supplied as one value, horizontal and
vertical values, or four edges. `horizontalAlignment` and `verticalAlignment`
express start, center, end, or fill behavior in the slot assigned by the
parent.

An explicit size wins over `.fill`: a view with a `width` keeps that
width, bounded only by its own minimum and maximum, even in a slot that would
stretch it. A filling view that stops short of its slot, because of an
explicit size or a maximum, stands in the middle of the slot. Without either,
`.fill` takes the whole slot.

`layoutDirection` lays a view and everything under it out right to left or
left to right: a row fills from the right, a view aligned to `.start` stands
at the right, a grid's first column is the rightmost, and padding and margins
swap sides. A view left at `.inherited`, the default, takes its parent's
direction, and the top of the tree the direction the user's language is
written in. `zIndex` orders overlapping siblings without changing their layout
positions.

## Visual transforms

`ViewTransform` is one ordered value for planar movement, turning, and sizing.
It is applied about the view's center after layout has assigned the view's
rectangle, so it changes the drawing without changing measurement or
arrangement:

```swift
ColorBox(.cornflowerBlue)
    .width(80)
    .height(80)
    .transform(.rotate(15).scale(1.1).translate(20, 0))
```

Read a chain from left to right. Every operation acts after everything written
before it. Consequently, `.rotate(45).translate(100, 0)` turns the view and
then moves it right in parent coordinates, while
`.translate(100, 0).rotate(45)` also rotates the earlier displacement.

| Operation | Meaning |
| --- | --- |
| `translate(x, y)` | moves in device-independent units |
| `rotate(degrees)` | turns clockwise in the screen plane |
| `scale(factor)` | scales both axes about the center |
| `scaleX(factor)`, `scaleY(factor)` | scales one axis |
| `turn(degrees)`, `tilt(degrees)` | draws a deterministic flat view of a vertical or horizontal turn |
| `skew(x, y)` | adds an ordered shear to the transform matrix |

The core composes the matrix before it reaches a host. A native view surface is
represented by translation, planar rotation, and two scales. That preserves
all such chains, but an ordered chain that genuinely contains shear—such as a
one-axis scale after an earlier rotation—keeps its move, rotation, and sizes
while omitting the slant. `turn` and `tilt` are flat projections rather than
platform camera transforms, and stop shrinking at a right angle.

Shapes accept the same value through `renderTransform`. A shape is redrawn
from the full matrix in its own coordinate system, so `skew` is preserved
there. This is distinct from `transform`, which moves the already drawn view
about its center.

Transforms are visual, not layout. They do not produce frame reports; changing
an animated layout property such as `width` does because it changes the
settled rectangle. Host support for transform member groups remains explicit
in the [platform matrix](platform-contract.md#shared-view-members).

## Stacks

`VStack` and `HStack` are the two non-wrapping stack layouts:

```swift
VStack {
    Label("Account")

    HStack {
        Button("Cancel")
        Button("Save")
    }
    .spacing(8)
}
.spacing(16)
.padding(24)
```

The content closure is retained and described when the differ asks for the
container's children. A state read inside that closure belongs to the
container's description scope, which can keep invalidation narrower than a
read in an outer composed view.

## Grid

A grid owns row and column definitions; each child states its cell and spans:

```swift
@State var name = ""

Grid {
    Label("Name")

    TextField($name)
        .gridColumn(1)

    Button("Save")
        .gridRow(1)
        .gridColumnSpan(2)
}
.rows(.auto, .fill)
.columns(.auto, .fill)
.rowSpacing(8)
.columnSpacing(12)
```

`GridLength` has four useful spellings:

| Value | Meaning |
| --- | --- |
| `.fixed(100)` | 100 device-independent units |
| `.auto` | enough room for measured content |
| `.fill` | one share of remaining room |
| `.proportional(2)` | two shares of remaining room |

An omitted row or column is zero. An omitted span is one. Several children may
occupy the same cell; they overlap and `zIndex` decides drawing order.

Grid definitions are data. Changing a definition keeps child identities and
rearranges the existing controls, and each child rectangle travels to its new
place under the grid's layout motion rather than being described frame by
frame - see [Motion and journeys](motion-and-journeys.md).

## Absolute placement

`AbsoluteLayout` reads a `Rect` from each child:

```swift
AbsoluteLayout {
    ColorBox(.cornflowerBlue)
        .absoluteLayoutBounds(Rect(0.5, 0.5, 120, 60))
        .absoluteLayoutProportions(.position)
}
.height(240)
```

`AbsoluteLayoutProportions` says which coordinates and dimensions are proportional
to the layout. Unflagged values are device-independent units.
`AbsoluteLayout.autoSize` leaves that dimension to the child's measurement.
Attached placement lives on the child because any view can become an absolute
layout child.

Absolute placement is useful for semantic overlays and externally calculated
positions. It is not a reason to reproduce ordinary stack or grid behavior in
application code.

## Scrolling

`ScrollView` owns one viewport and describes all descendants it contains:

```swift
@State var offset = Point.zero

ScrollView {
    VStack {
        ForEach(1...100) { row in
            Label("Row \(row)")
        }
    }
}
.scrollOffset($offset)
.verticalScrollBarVisibility(.default)
```

The `Point` binding is two-way. A program write moves the viewport; native
scrolling reports the standing offset into the same state. The state is a
`Journey`, so `offset` is its destination and `$offset.journey.value` is its
current host-frame position.

Where a scroller comes to rest is the platform's, with the platform's own
deceleration. `onScrollStopped` runs once a movement has ended, and a write to
the offset from there carries the viewport on to a resting place of the
author's own:

```swift quote
ScrollView { cards }
    .orientation(.horizontal)
    .scrollOffset($offset)
    .onScrollStopped {
        let card = ($offset.journey.value.x / 320).rounded()
        offset = Point(card * 320, 0)
    }
```

The write is a destination, so the host carries the viewport there from where
it stands. `GalleryView` comes to rest on its cards the same way.

A scroller must own a bounded viewport. Putting it in a parent that measures
it to the full content length leaves nothing to scroll. Avoid nesting two
scrollers in the same direction unless the inner viewport independently owns
that gesture and size.

Orthogonal nesting has one deterministic gesture rule: a one-axis scroller
handles movement along its enabled axis and passes a dominant movement on its
disabled axis to the nearest enclosing scroller. A horizontally overflowing
code listing inside a vertical page therefore keeps horizontal input while the
page continues moving under vertical input.

`ScrollView` is eager. It is not a virtualized data collection.

### ScrollReader

`ScrollReader` gives authored placement arithmetic native scroll input without
moving the content subtree itself. It lays a transparent native scroller over
the held views and reports that scroller's offset into one driven `Point`
state. An engine can read `$offset.journey.value` and move already mounted
children on host frames, without rebuilding a view for every wheel, trackpad,
or touch update.

```swift quote
@State private var offset = Point.zero
@State private var places = PlacedRun()

ScrollReader(across: Double(cards.count - 1) * 90) {
    PlacedLayout(cards, id: \.id) { Card($0) }
        .placement($places)
        .engine(following: $offset) { _ in
            places = placements(at: $offset.journey.value.x / 90)
        }
}
.scrollOffset($offset)
```

`across` and `down` are the distances the run may travel beyond the measured
room, not total content dimensions. Use the single-axis initializers or provide
both for two-dimensional input.

The rest of the contract follows from that ownership:

- `.scrollOffset($offset)` is the two-way offset. A program write moves the native
  scroller; input reports into the same state. `Journey.snap(to:)` lands now
  and `Journey.move(to:)` requests a host-driven animation.
- `onScrollStopped` is the scroller's own: it runs once a movement has ended,
  and a write to the offset from there is how a run comes to rest on an item.
- The held subtree is input-transparent because the scroller owns the room's
  native input. Attach `onTapped`, `onPanUpdated`, or `onTapped(within:_:)` to
  the reader rather than to a held card.
- `onTapped(within:_:)` receives the measured room and returns the active
  rectangle in that room. With a scroll binding, StateUI keeps the native hit
  target over that viewport rectangle as the content offset moves. Without a
  binding it falls back to the whole run.
- `aim(_:)` exposes the underlying scroller for other aimed acts. Offset
  movement itself remains state, not an act.

`ScrollReader` is a StateUI composition, so its availability is the combined
availability of frame reporting, scrolling, driven state, and any authored
layout used by its content. It is not an additional native control row.

## Repeated content and collections

`ForEach` expands application data into identified children:

```swift quote
ForEach(items, id: \.id) { item in
    Row(item: item)
}
```

Use it for finite content in stacks, grids, menus, and drawing structures. A
plain `for` is intentionally not accepted by `ViewBuilder`, because the
builder must know stable identity rather than receiving only positions.

The shared native virtualized-collection API is not admitted yet. Its contract
must cover stable item identity, viewport ownership, reuse, selection,
activation, accessibility, and programmatic scrolling across all target
toolkits before it enters the base library. This keeps virtualization in the
native host without growing a second UI framework there.

## Frame readings

Frame observation is opt-in. A view without a frame modifier creates no frame
subscription. Any view can report its rectangle when that rectangle changes:

```swift quote
.onFrameChanged { rect = $0 }
.onFrameChanged(in: .global) { windowRect = $0 }
.onFrameChanged(in: .safeArea) { safeRect = $0 }
```

There are three readings of the same native measurement:

| Surface | Use |
| --- | --- |
| `.frame($room)` | a one-way host feed of the parent-space rectangle into state |
| `.onFrameChanged(in:)` | an asynchronous handler for one selected coordinate space |
| `FrameReader` | local content rebuilt from its last measured rectangle |

The frame feed is useful when an engine or authored layout needs the native
rectangle without making a body read it:

```swift quote
@State private var room = Rect(0, 0, 0, 0)

PlacedLayout(items, id: \.id) { ItemView($0) }
    .placement($places)
    .frame($room)
```

Handing over `$room` is not a state read and therefore causes no body rebuild
by itself. The host writes the standing parent-space rectangle into the state;
an application write to that input feed does not set a native frame. A body
that separately reads `room` still follows ordinary state invalidation, and an
engine listing the state in `following:` wakes on the host write.

The coordinate spaces are:

| Space | Origin |
| --- | --- |
| `.parent` | the enclosing layout's content area |
| `.global` | the current window |
| `.safeArea` | window coordinates measured from the origin where this branch can safely place content |

One host report carries the parent rectangle plus the same origin converted to
global and safe-area coordinates. Each modifier selects its own space and
deduplicates independently. Thus an ancestor scroll can notify a `.global`
listener while a `.parent` listener on the same view remains quiet.

A subscribed view reports after its first layout and whenever any fact needed
for the selected answer changes:

- its own measured or arranged rectangle;
- an ancestor's position;
- an ancestor scroll that moves it relative to the window or safe area.

The host coalesces a settled layout update, and StateUI suppresses an equal
rectangle for each handler. A handler recreated by a body rebuild starts with
no remembered rectangle and can therefore receive the standing value once
again. A malformed frame payload is rejected rather than delivered as a
partial rectangle.

The handler runs as an ordinary asynchronous StateUI event after layout. It may
await and may write state; such a write requests a later description. The
report never changes layout by itself. A visual transform never reports,
because it does not alter the layout rectangle; an animated layout property
reports the rectangles that the host actually settles.

`FrameReader` owns the measured rectangle as its own state and rebuilds only
its content from that value. Its closure first receives a zero rectangle; the first
native frame report supplies the measured rectangle:

```swift
FrameReader { frame in
    Label("\(Int(frame.width)) x \(Int(frame.height))")
}
```

Use a reader when layout-derived content belongs locally. Use
`onFrameChanged` when another owner genuinely needs the measurement. Avoid
feedback where a measurement directly changes the dimension being measured
without a stable stopping condition. A size derived from measurement normally
uses `.motion(.none)`: letting the measured size travel can feed intermediate
measurements back into the same calculation.

## Safe areas and clipping

`avoidsSafeArea` states which edges participate in the host's safe-area
integration. `clipsContent` controls whether descendants may draw outside
the assigned rectangle. Both are semantic requests and only count as available
on a platform after the matrix records host tests for them.

## StateUI-authored layouts

`PlacedLayout` and `GalleryView` are StateUI composition mechanisms, not new
native controls. Their declarations and core tests preserve the intended
authored-placement vocabulary, but they are deliberately outside the initial
native-host acceptance milestone. That milestone first completes the primitive
contract, sparse property motion, and layout motion.

Do not mark either composition supported merely because its Swift declaration
compiles. A host must first have checks for every primitive it depends on, and
the Gallery must exercise the visible behavior on that platform. Until then,
use [Platform contract](platform-contract.md) as the support authority and
treat `PlacedLayout` and `GalleryView` as deferred surfaces.
