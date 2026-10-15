# Layout

StateUI describes layout intent and keeps the resulting tree identities. A
native host measures and arranges native controls. Swift owns the semantic
rules that must stay identical across hosts; the host owns integration with its
toolkit's measurement and display cycle.

The declared primitive vocabulary is deliberately small: vertical and
horizontal stacks, `Grid`, `ZStack`, `ScrollView`, and ordinary view
sizing and alignment. More specialized arrangements are composed
from these or implemented once as StateUI-authored layout. A primitive is
usable on a platform only when its row and required members are checked in the
platform matrix.

## Size, margin, padding, and alignment

Every eligible view can state requested, minimum, and maximum dimensions:

```swift
Text("Summary")
    .width(240)
    .minimumHeight(44)
    .horizontalAlignment(.center)
    .verticalAlignment(.start)
    .margin(horizontal: 16, vertical: 8)
```

A request is input to measurement, not a promise that the platform has that
much room. Minimum and maximum values bound the request. The enclosing layout
still decides the final rectangle.

`margin` is outside a view. `padding` is inside controls and containers that
own content padding. `Insets` can be supplied as one value, horizontal and
vertical values, or four edges. `horizontalAlignment` and `verticalAlignment`
express start, center, end, or fill behavior in the slot assigned by the
parent.

An explicit size wins over `.fill`: a view with a `width` keeps that width,
held within its own minimum and maximum and the room its slot has, even in a
slot that would stretch it. A filling view that stops short of its slot,
because of an explicit size or a maximum, stands in the middle of the slot.
Without either, `.fill` takes the whole slot.

`layoutDirection` lays a view and everything under it out right to left or
left to right: a row fills from the right, a view aligned to `.start` stands
at the right, a grid's first column is the rightmost, and padding and margins
swap sides. A view left at `.inherited`, the default, takes its parent's
direction, and the top of the tree the direction the user's language is
written in. `zIndex` orders the overlapping children of a `Grid` or a
`ZStack` without changing their places: a higher one is drawn over a lower
one, and children of the same `zIndex` in the order they are written.

## Visual transforms

`ViewTransform` is one ordered value for planar movement, turning, and sizing.
It is applied about the view's pivot - its center unless `pivotX`/`pivotY`
say otherwise - after layout has assigned the view's rectangle, so it changes
the drawing without changing measurement or arrangement:

```swift
Rectangle(.cornflowerBlue)
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

Shapes accept the same value through `geometryTransform`. A shape is redrawn
from the full matrix in its own coordinate system, so `skew` is preserved
there. This is distinct from `transform`, which moves the already drawn view
about its center.

Transforms are visual, not layout. They do not produce frame reports; changing
an animated layout property such as `width` does because it changes the
settled rectangle. Host support for transform member groups remains explicit
in the [platform matrix](../platform-contract.md#shared-view-members).

## Stacks

`VStack` and `HStack` are the two non-wrapping stack layouts:

```swift
VStack {
    Text("Account")

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

### Spacer and Divider

A `Spacer` takes the room its stack's other children leave along the stack's
axis, shared alike when there are several; a `Divider` is the platform's own
separator line, drawn across its stack:

```swift
VStack {
    HStack {
        Text("Draft")
        Spacer()
        Button("Send")
    }

    Divider()

    Text("Sent a minute ago")
}
.spacing(8)
.padding(16)
```

A spacer asks for no room of its own, so a stack only as long as its children
leaves it none; a spacer given a length along the axis - `.width(12)` in an
`HStack` - is a gap of exactly that length, and `.minimumWidth` or
`.maximumWidth` bound one that grows. A line between a menu's entries is a
`MenuSeparator`.

## Grid

A grid owns row and column definitions; each child states its cell and spans:

```swift
@State var name = ""

Grid {
    Text("Name")

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

Rows or columns alike are written once, with their count:
`.rows(.fill, .auto(count: 2), .fill(count: 5), .fixed(80))` is nine rows, and
`.columns(.fill(count: 4))` four equal columns. Each spelling takes `count:`.

A grid's own width, where its room does not decide it, is the least at which
each proportional track holds its content at its share: shares stand as
written, and words that fit in their column stand on one line.

An omitted row or column is zero. An omitted span is one. Several children may
occupy the same cell; they overlap and `zIndex` decides drawing order.

Grid definitions are data. Changing a definition keeps child identities and
rearranges the existing controls, and each child rectangle travels to its new
place under the grid's layout motion rather than being described frame by
frame - see [Motion and journeys](../concepts/motion-and-journeys.md).

## Layers

`ZStack` lays its children one over another. Each child stands in its area -
the whole room within the stack's padding, or the rectangle it names with
`.area` - by its own alignments, as in any layout:

```swift
ZStack {
    Rectangle(.cornflowerBlue)

    Text("Bottom right")
        .horizontalAlignment(.end)
        .verticalAlignment(.end)

    Rectangle(.orange)
        .area(.proportional(0.5, 0, 0.5, 1))
}
.height(240)
```

`.absolute(x, y, width, height)` names an area in device-independent units
from the top left of the room inside the stack's padding;
`.proportional(x, y, width, height)` names one in fractions of that room, so
`.proportional(0.5, 0, 0.5, 1)` is its right half whatever the stack's size
(left to right; a right-to-left stack mirrors the area, so there it is the
left half). A child fills its area unless its size or alignment says otherwise. A later
child is drawn over an earlier one, and `zIndex` reorders them without moving
anything. The stack needs the room its neediest child needs at its natural
size.

Layers are for overlays, badges and externally calculated positions. They are
not a reason to reproduce ordinary stack or grid behavior in application code.
A badge over a view is a ZStack of the view and the badge aligned to a
corner; a picture behind words is a ZStack with the picture first. Either
counts towards the stack's room, so a badge or a picture larger than the view
makes the stack larger - give it a size, or keep it smaller. What stays over
every page of a window is declared with `.overlays { }` on the window's page
([Over every page](navigation-and-presentation.md#over-every-page)).

## Scrolling

`ScrollView` owns one viewport and describes all descendants it contains:

```swift
@State var offset = Point.zero

ScrollView {
    VStack {
        ForEach(1...100) { row in
            Text("Row \(row)")
        }
    }
}
.scrollOffset($offset)
.verticalScrollIndicator(.automatic)
```

The `Point` binding is two-way. A program write moves the viewport; native
scrolling reports the standing offset into the same state. The state walks a
journey: `offset` is its destination and `$offset.journey.value` where the
viewport stands this frame.

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
it stands.

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

A layout whose views the hand moves without moving its content - a run of
cards turned by a finger, a wheel or a trackpad, endless if need be - is a
[layout engine](#a-layout-engine) with `.input(.scroll(_:))`.

## Repeated content and collections

`ForEach` expands application data into identified children:

```swift quote
ForEach(items, id: \.id) { item in
    Row(item: item)
}
```

Use it for finite content in stacks, grids and other view builders; a menu
takes an array of items, and a `Canvas` drawing repeats with a plain `for`. A
plain `for` is intentionally not accepted by `ViewBuilder`, because the
builder must know stable identity rather than receiving only positions.

Many items - more than a screen holds - belong in an `ItemsView`, which
builds only the items the platform's own collection shows
([Controls and input](controls-and-input.md#collections)).

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
| `.onFrameChanged(in:)` | a handler run after layout for one selected coordinate space |
| `GeometryReader` | local content rebuilt from its last measured rectangle |

The frame feed is useful when an engine or authored layout needs the native
rectangle without making a body read it:

```swift quote
@State private var room = Rect.zero
@State private var columns = 1.0

Grid { tiles }
    .frame($room)
    .engine(following: $room) { _ in columns = max((room.width / 240).rounded(.down), 1) }
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

The handler runs as an ordinary StateUI event after layout. It may write state;
such a write requests a later description. A handler that awaits names what a
newer rectangle does while it runs: `.onFrameChanged(gate: .cancelPrevious) { frame
in … }`. The
report never changes layout by itself. A visual transform never reports,
because it does not alter the layout rectangle; an animated layout property
reports the rectangles that the host actually settles.

`GeometryReader` owns the measured rectangle as its own state and rebuilds only
its content from that value. Its closure runs once the first native frame report
supplies the measured rectangle; until then the reader holds nothing:

```swift
GeometryReader { frame in
    Text("\(Int(frame.width)) x \(Int(frame.height))")
}
```

Use a reader when layout-derived content belongs locally. Use
`onFrameChanged` when another owner genuinely needs the measurement. Avoid
feedback where a measurement directly changes the dimension being measured
without a stable stopping condition. A size derived from measurement normally
uses `.motion(.none)`: letting the measured size travel can feed intermediate
measurements back into the same calculation.

## A layout's own box

A stack, a grid or a ZStack paints its own box: its background, filled to the
shape it names, and an outline on that shape. There is no separate view to
wrap content in for a card - the layout holding the content is the card.

```swift
VStack {
    Text("Cheese")
    Text("Aged twelve months")
}
.padding(14)
.background(Color("#F4F4F4"))
.shape(.roundedRectangle(8))
.stroke(Color("#D0D0D0"))
.lineWidth(1)
.clipsContent(true)
```

`shape` is `.rectangle`, `.roundedRectangle(radius)`, `.capsule` or `.ellipse`.
A corner rounds no more than half the shorter side, so a radius larger than
that rounds a wide box's ends whole; `.capsule` asks for exactly that at any
size - a pill-shaped button or tag keeps round ends as its words grow. The
outline is drawn inside the layout's bounds and never pushes its children in; that is
the padding's work. `clipsContent(true)` cuts what the layout holds to the
shape, so a picture in a rounded card has rounded corners; without it the shape
is drawn and nothing is cut. A dashed outline belongs to a shape: lay a
`Rectangle` with a dash pattern over the layout in a `ZStack`.

## Safe areas and clipping

`avoidsSafeArea` states, edge by edge, what a layout stands clear of on a
screen with bars and a notch. A page's content stands clear of them by
default (`.container`); the page's own layout says `.none` - edge to edge -
to run under them, so its background colours the status bar's strip:

```swift
import StateUI

struct Header: View {
    var body: some View {
        VStack {
            Text("StateUI")
        }
        .padding(left: 20, top: 60, right: 20, bottom: 20)
        .background(.steelBlue)
        .avoidsSafeArea(.none)
    }
}
```

Words under the bars are hidden by them, so a layout that runs under them
pads its words clear. `clipsContent` controls whether descendants may draw
outside the assigned rectangle, cut to the layout's shape where it names one.
The [platform contract](../platform-contract.md) says where each is realized.

## StateUI-authored layouts

`LayoutEngine` and `GalleryView` are StateUI's own layouts: the core
implements them once - a `GalleryView` is a `LayoutEngine` with the
arithmetic of three shapes written - and the Gallery exercises both on every
host.

`GalleryView` shows one card at a time, swiped through, in a shape one word
chooses:

```swift
struct Album {
    let title: String
}

struct AlbumsPage: View {
    @State private var shown = 0
    @State private var opened = "Tap the card in front"

    let albums: [Album]

    var body: some View {
        Grid {
            GalleryView(albums, id: \.title) { album in
                Text(album.title)
            }
            .arrangement(.fan)
            .position($shown)
            .onItemTapped { album in opened = album.title }
            .gridRow(0)

            Text("\(opened) · card \(shown + 1) of \(albums.count)")
                .gridRow(1)
        }
        .rows(.fill, .auto)
    }
}
```

The initializer builds a card's face, one card per item, identified by `id:`
or by the item itself where it is `Hashable`. Where a card stands and which
way it faces is the arrangement's - `.default` (a wheel), `.fan` or `.row` -
and changing it animates every card to the new shape. `.position($shown)` is
the card in the middle, counted from 0 and two-way: a swipe writes the card it
settled on, and a write moves the run. `.onItemTapped` hears a tap on the
card in front, with its item, and `.onPositionChanged` another card coming to
the middle; a swipe carries the card in front with it, however big the room
draws the cards, and `.throwing(_:)` says how one let go with speed goes on, as a
[layout engine's](#a-layout-engine) input does, and `.itemSize(width:height:)`,
`.isSwipeEnabled`, `.emptyView`, `.shade` and `.fade` say the rest. Give it a
bounded size - a `.height`, or a `.fill` row of a `Grid`.
No view is built again while the run moves.

### A layout engine

`LayoutEngine` places its views by arithmetic of the application's own,
worked out from the room and a phase. The arithmetic answers one `Placement`
per view, in the items' order - its bounds from the layout's top left, and a
transform, an opacity, a shade and a `zIndex` - and runs on the host's frames
whenever the room or the phase moves, with no view built again. The layout
has no size of its own: it takes the room its own layout gives it, whatever
its views need, so give it one - a `.height`, or a `.fill` row of a `Grid`:

```swift
struct Shelf: View {
    let names = ["Mural", "Nebula", "Ridge"]

    var body: some View {
        LayoutEngine(names) { name in
            Text(name)
        } placements: { room, _ in
            names.indices.map { index in
                let width = room.width / Double(names.count)

                return Placement(Rect(Double(index) * width, 0, width, room.height))
            }
        }
        .height(60)
    }
}
```

The phase is where the run rests or is going. Lend it a state with
`.phase(_:)` and the program moves the run by writing it; give it
`.input(.scroll(_:))` and the hand moves it too - a finger or a pointer
dragged, a trackpad's two fingers, a wheel - on its own, with no scroller
under it, carrying the view in front with it and coming to rest on the
nearest of its `.snapTargets(_:)`:

```swift
struct Carousel: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom"]

    var body: some View {
        VStack {
            LayoutEngine(names) { name in
                Text(name)
            } placements: { room, phase in
                names.indices.map { index in
                    let step = Double(index) - phase

                    return Placement(
                        Rect(room.width / 2 - 60 + step * 140, 0, 120, room.height),
                        transform: .scale(1 - min(abs(step), 1) * 0.2),
                        zIndex: -Int(abs(step) * 10))
                }
            }
            .phase($turn)
            .input(.scroll(.horizontal))
            .snapTargets(names.indices.map(Double.init))
            .motion(.spring(response: .milliseconds(240)))
            .height(200)

            Button("Next").onClicked { turn = min(turn + 1, Double(names.count - 1)) }
        }
    }
}
```

The arithmetic is handed the phase as it stands each frame, and each
placement lands as written: what moves smoothly is the phase, so every view
keeps to the path the arithmetic draws - an arc, a fan opening - rather than
cutting across it. `turn` is the snap target the run rests on: written by the
program, the run travels there under `.motion(_:)` - with a hand or none -
and `try await $turn.journey.move(to: 2).arrived()` waits until it has; under
the hand it is the target the run passes and the one it comes to rest on, and
a hand taking the run on its way stops the journey. A tap reaches the view
drawn on top through `.onItemTapped`, and `.shade(_:)` darkens a far view by
the `shade` its placement answers.

The hand carries the view in front: it travels as far for one unit of the
phase as the front view of those the phase moves goes for it, so a carousel
that grows with its window turns as far under the finger as on a phone.
`pointsPerUnit:` gives the distance instead, for a run whose front view
hardly moves - a pile of cards fanned out by another axis.

A hand let go with speed throws the run: it goes on to the target nearest
where the throw would end, and `turn` names that target at once. How it goes
on is the input's `throwing:` motion - eased, its length says how far it
carries and its curve how it slows, a shorter length stopping it sooner; a
spring carries it as far as its response and settles as springs do. A throw
sets out at the hand's speed and never speeds up after the lift. A hand let
go still, or too slowly to reach the next target, slides the run back to
the nearest under `.motion(_:)`. A mouse's wheel turned notch by notch steps
the run a target a notch, under `.motion(_:)`, however large the targets
stand.

A change of the layout at the phase it stands at travels too. A view
joining fades in where the arithmetic puts it; one leaving goes at once and
the others close up; a new order slides; and a value read in the body - a
switch between a fan and a pile - takes every view from where it was to its
new place, under `.motion(_:)`, while the phase goes on as it goes:

```swift
struct Hand: View {
    @State private var names = ["Mural", "Nebula", "Ridge"]
    @State private var fanned = true

    var body: some View {
        let gap = fanned ? 140.0 : 12.0

        VStack {
            LayoutEngine(names) { name in
                Text(name)
            } placements: { room, _ in
                names.indices.map { index in
                    Placement(Rect(room.width / 2 - 60 + Double(index) * gap, 0, 120, room.height))
                }
            }
            .motion(.spring(response: .milliseconds(300)))
            .height(160)

            Button("Add").onClicked { names.append("Bloom") }
            Button("Fan").onClicked { fanned.toggle() }
        }
    }
}
```

Removing the card at the front brings the one behind it there, as the
others close up. Where the front card was the last, the phase itself has to
go: `$turn.journey.move(to:)` in the same handler sends the run to the card
before it, under `.motion(_:)`.

The arithmetic can also be handed where the run's motion set out: the phase
it stood at when the hand, a throw or a journey took it away, then each
target the run passes. The phase's side of it is the way the run goes, so a pile can
send the card that stood in front out that way - left as the hand moves the
run on, right as it takes it back - and under the others, while the next
comes up from beneath:

```swift
import Foundation

struct Pile: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom"]

    var body: some View {
        LayoutEngine(names) { name in
            Text(name)
        } placements: { room, phase, from in
            names.indices.map { index in
                let step = Double(index) - phase
                let leaving = Double(index) == from && abs(step) < 1
                // Out the way the run goes and back, under the others past halfway.
                let out = leaving ? sin(abs(step) * .pi) * (step < 0 ? -1 : 1) : 0
                let behind = leaving ? 0 : abs(step)

                return Placement(
                    Rect(room.width / 2 - 70 + out * 160, 10 + behind * 6, 140, 180),
                    transform: .rotate(out * 12).scale(1 - min(behind, 3) * 0.04),
                    zIndex: leaving && abs(step) > 0.5 ? -100 : -Int(behind * 10))
            }
        }
        .phase($turn)
        .input(.swipe(.horizontal))
        .snapTargets(names.indices.map(Double.init))
        .height(220)
    }
}
```

`.swipe(_:)` moves the run one card a hand, however far the hand goes - a
trackpad's flick speeds up to well past a card - and a throw goes on to the
next card that way, no farther; its unit is measured as the hand takes the
run, so the card in front moves under it. At the phase it set out from,
every view stands where it stood, so a hand taking the run back past it
changes nothing drawn - the same card goes out
the other way. A hand catching the card on its way goes on with it; a long
hand or a throw across several cards sends each out in turn.

A run with no ends comes round: `.wraps(every:)` makes one turn of the phase
bring the layout back where it was, its targets repeated each turn, so the
hand and the program both move it on forever. The arithmetic folds the phase
itself:

```swift
struct Ring: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom", "Dune"]

    var body: some View {
        LayoutEngine(names) { name in
            Text(name)
        } placements: { room, phase in
            names.indices.map { index in
                let step = (Double(index) - phase).remainder(dividingBy: Double(names.count))

                return Placement(
                    Rect(room.width / 2 - 60 + step * 140, 0, 120, room.height),
                    opacity: 1 - min(abs(step) / 3, 1))
            }
        }
        .phase($turn)
        .input(.scroll(.horizontal, throwing: .spring(response: .milliseconds(400), damping: 0.8)))
        .snapTargets(names.indices.map(Double.init))
        .wraps(every: Double(names.count))
        .height(200)
    }
}
```

A phase of several axes is a `LayoutPhase` of your own: a struct of numbers
listing its axes. Each axis moves on its own - one under the hand, another
written by the program - and travels under the same `.motion(_:)`:

```swift
struct Orbit: LayoutPhase {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}

struct Planets: View {
    @State private var orbit = Orbit()

    let names = ["Mercury", "Venus", "Earth", "Mars"]

    var body: some View {
        VStack {
            LayoutEngine(names) { name in
                Text(name)
            } placements: { room, orbit in
                names.indices.map { index in
                    let size = 60 * orbit.zoom
                    let step = Double(index) - orbit.turn

                    return Placement(Rect(room.width / 2 - size / 2 + step * size * 1.5, 0, size, size))
                }
            }
            .phase($orbit)
            .input(.scroll(.horizontal), drives: \.turn)
            .snap(\.turn, to: names.indices.map(Double.init))
            .motion(.spring(response: .milliseconds(240)))
            .height(160)

            Button("Nearer").onClicked { orbit.zoom = orbit.zoom == 1 ? 2 : 1 }
        }
    }
}
```

`.input(_:drives:)` says which axis a hand moves, and it moves that one
alone. `.snap(_:to:)` gives an axis targets of its own, where it rests
whatever the others do; `.snapTargets(_:)` lists whole phases instead - the
combinations allowed - and letting go sends every axis without targets of
its own to the nearest of them. A `Double` is the phase of one axis.

A value read in the body is a change of the description: the layout is built
again and its arithmetic with it. A state the arithmetic reads that moves on
the host's frames - a drag of your own - is named in `.following(_:)` instead.
On an axis nothing bounds - inside a scroller - keep the answer bounded:
placements that grow with the room grow the room, and the layout never
settles.

`LayoutEngine` has its own row in the
[Platform contract](../platform-contract.md); `GalleryView` behaves as far as
the rows it uses - the layout engine and frame reporting - are checked
there.
