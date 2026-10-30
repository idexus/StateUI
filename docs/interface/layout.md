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

Down a row, `.firstBaseline` rests a view's first line of words on one line
with the row's other views aligned so - a label and a value of other sizes
read as one line; a view with no words rests its foot there, and a stack its
first child's line. Anywhere else it is the near edge:

```swift
HStack {
    Text("Total")
        .fontSize(13)
        .verticalAlignment(.firstBaseline)
    Text("€120")
        .fontSize(34)
        .verticalAlignment(.firstBaseline)
}
.spacing(8)
```

`layoutDirection` lays a view and everything under it out right to left or
left to right: a row fills from the right, a view aligned to `.start` stands
at the right, a grid's first column is the rightmost, a `GalleryView`'s cards
stand in the mirror, and padding and margins swap sides. A view left at
`.inherited`, the default, takes its parent's direction, and the top of the
tree the direction the user's language is written in. A transform, a drawing
and a `MotionLayout` keep the shape they are written in, unless the layout
says `.mirrorsRightToLeft(true)` ([a motion layout](#a-motion-layout)). `zIndex` orders the overlapping children of a `Grid` or a
`ZStack` without changing their places: a higher one is drawn over a lower
one, and children of the same `zIndex` in the order they are written.

## Visual transforms

`ViewTransform` is one ordered value for planar movement, turning, and sizing.
It is applied about the view's pivot - its center unless `pivotX`/`pivotY`
say otherwise - after layout has assigned the view's rectangle, so it changes
the drawing without changing measurement or arrangement:

```swift
Rectangle()
    .fill(.cornflowerBlue)
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

`VStack` and `HStack` are the two stack layouts:

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

A row with less room than its children need takes it from its words: a
button, a toggle or a picture keeps its width, and the labels share what the
others leave in proportion to their natural widths - wrapping to it, or
ending where the room does when kept to `.maximumLines(1)`. A label that
states its own width keeps it.

A row told `.wraps(true)` goes on onto a further line instead: each line
holds as many children as its room takes at their natural widths, at least
one, and the lines stand `.rowSpacing` apart, the spacing between children
on a line staying `.spacing`:

```swift
struct Tags: View {
    let tags = ["Swift", "Layout", "State", "Motion", "Journey", "Native"]

    var body: some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .padding(horizontal: 10, vertical: 4)
                    .background(.lightGray)
            }
        }
        .wraps(true)
        .spacing(8)
        .rowSpacing(8)
    }
}
```

Each line is a row of its own: a space takes what its line leaves, and
children aligned `.firstBaseline` rest on their line's baseline. Only a row
wraps; a column grows as tall as its children need.

The content closure is retained and described when the differ asks for the
container's children. A state read inside that closure belongs to the
container's description scope, which can keep invalidation narrower than a
read in an outer composed view.

### Space, Fill and Separator

A `Space` pushes: it takes the room its stack's other children leave along
the stack's axis, shared alike when there are several. A `Separator` is the
platform's own separator line, drawn across its stack:

```swift
VStack {
    HStack {
        Text("Draft")
        Space()
        Button("Send")
    }

    Separator()

    Text("Sent a minute ago")
}
.spacing(8)
.padding(16)
```

A space asks for no room of its own, so a stack only as long as its children
leaves it none; a space given a length along the axis - `.width(12)` in an
`HStack` - is a gap of exactly that length, and `.minimumWidth` or
`.maximumWidth` bound one that grows. A line between a menu's entries is a
`MenuSeparator`.

A `Fill` takes the room it is offered: in a `ZStack`, a grid's cell or a page
the whole room, across a stack its breadth - and along a stack only the length
it states. It is made of what its initializer gives it - a color, a gradient,
a blur or glass (*Materials*, in *Styles and drawing*) - in its box's shape,
outlined where it says so. A space is room too, and is drawn alike:

```swift
VStack {
    Text("Inbox")
    Fill(.gray)
        .height(1)
    Space()
        .background(.cornflowerBlue)
    Text("Archive")
}
.height(200)

ZStack {
    Text("Behind the glass")
    Fill(.glass(.clear))
        .shape(.capsule)
        .stroke(.white)
    Text("Over it")
}
.height(120)
```

`Fill(.gray).height(1)` is a rule; a fill stating no length along a stack
stands none long there, while the blue space takes the rest. What a fill is
made of is its background, so a later `.background` replaces it. `Fill()` is
clear and still takes the user's touch, a region for a gesture. A figure - its
line dashed or joined, its corners rounded one by one - is a shape: a
`Rectangle`, a `Capsule`, a `Path`.

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
every child fits its cell - a child spanning several tracks asks its room of
all of them - with each proportional track at its share: shares stand as
written, and words that fit in their cell stand on one line.

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
    Rectangle()
        .fill(.cornflowerBlue)

    Text("Bottom right")
        .horizontalAlignment(.end)
        .verticalAlignment(.end)

    Rectangle()
        .fill(.orange)
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
[motion layout](#a-motion-layout) whose axis the hand scrolls:
`.axis(_:input:range:snaps:)` with `.scroll(_:)`.

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
newer rectangle does while it runs: `.onFrameChanged(.cancelPrevious) { frame
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
.background(Color(hex: 0xF4F4F4))
.shape(.roundedRectangle(8))
.stroke(Color(hex: 0xD0D0D0))
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

Every room a page stands in - a window, a sheet, a popover - has a safe area:
the part of it clear of what stands over the page there. That is a phone's
status bar, notch and home indicator, the keyboard, a popover's arrow, and the
page's own bars - a stack's, the tabs', a split view column's part of the bar,
its bottom bar.
A page's own layout stands clear of all of it by default; `ignoresSafeArea`
names the edges it runs under instead - `.all` edge to edge, `.top`,
`[.start, .top]` - so its background colors the status bar's strip and its
rows scroll under a translucent bar, the first and the last stopping clear
of it. The start and the end are the layout's own: right to left, the start
is the right edge.

```swift
import StateUI

struct Header: View {
    var body: some View {
        VStack {
            Text("StateUI")
        }
        .padding(start: 20, top: 60, end: 20, bottom: 20)
        .background(.steelBlue)
        .ignoresSafeArea(.all)
    }
}
```

Words under the bars are hidden by them, so a layout that runs under them
pads its words clear. A bar a platform stands beside the page rather than
over it has nothing to run under, and a desktop window with nothing over its
content has its whole room safe. `clipsContent` controls whether descendants may draw
outside the assigned rectangle, cut to the layout's shape where it names one.
The [platform contract](../platform-contract.md) says where each is realized.

## StateUI-authored layouts

`MotionLayout` and `GalleryView` are StateUI's own layouts: the core
implements them once - a `GalleryView` is a `MotionLayout` with the
arithmetic of four shapes written - and the Gallery exercises both on every
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
            .onItemActivated { title in opened = title }
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
way it faces is the arrangement's - `.default` (a wheel), `.fan`, `.row` or
`.deck`, a pile swiped a card at a time, the card in front going out the way
the hand goes and under the next - and changing it animates every card to the
new shape. `.position($shown)` is
the card in the middle, counted from 0 and two-way: a swipe writes the card it
settled on, and a write moves the run. `.onItemActivated` hears the card in
front opened - a tap on it - with its identity, as a list's item is, and
`.onPositionChanged` another card coming to
the middle; a swipe carries the card in front with it, however big the room
draws the cards, and `.throwing(_:)` says how one let go with speed goes on, as a
[motion layout's](#a-motion-layout) input does, and `.itemSize(width:height:)`,
`.isSwipeEnabled`, `.emptyView`, `.shade` and `.fade` say the rest. Give it a
bounded size - a `.height`, or a `.fill` row of a `Grid`.
No view is built again while the run moves. Laid out right to left, the cards
stand in reading order, as a row's views do: the next one on the left, a
swipe to the right moving the run on.

### A motion layout

`MotionLayout` places its views by arithmetic of the application's own,
worked out from the room and parameters - a state of the application's, lent
with `parameters:`. The arithmetic answers one `Placement`
per view, in the items' order - its bounds from the layout's top left, and a
transform, an opacity, a shade and a `zIndex` - and runs on the host's frames
whenever the room or the parameters move, with no view built again. The layout
has no size of its own: it takes the room its own layout gives it, whatever
its views need, so give it one - a `.height`, or a `.fill` row of a `Grid`:

```swift
struct Shelf: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge"]

    var body: some View {
        MotionLayout(names, parameters: $turn) { name in
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

The parameters are where the run rests or is going: the program moves the run by
writing it; declare its axis
with `.axis(_:input:range:snaps:)` and the hand moves it too - a finger or a
pointer dragged, a trackpad's two fingers, a wheel - on its own, with no
scroller under it, carrying the view in front with it across its range and
coming to rest on the nearest of its snaps:

```swift
struct Carousel: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom"]

    var body: some View {
        VStack {
            MotionLayout(names, parameters: $turn) { name in
                Text(name)
            } placements: { room, turn in
                names.indices.map { index in
                    let step = Double(index) - turn

                    return Placement(
                        Rect(room.width / 2 - 60 + step * 140, 0, 120, room.height),
                        transform: .scale(1 - min(abs(step), 1) * 0.2),
                        zIndex: -Int(abs(step) * 10))
                }
            }
            .axis(\.self, input: .scroll(.horizontal), range: 0...Double(names.count - 1), snaps: .every(1))
            .motion(.spring(response: .milliseconds(240)))
            .height(200)

            Button("Next").onClicked { turn = min(turn + 1, Double(names.count - 1)) }
        }
    }
}
```

The arithmetic is handed the parameters as they stand each frame, and each
placement lands as written: what moves smoothly are the parameters, so every view
keeps to the path the arithmetic draws - an arc, a fan opening - rather than
cutting across it. `turn` is the snap the run rests on: written by the
program, the run travels there under `.motion(_:)` - with a hand or none -
and `try await $turn.journey.move(to: 2).arrived()` waits until it has; under
the hand it is the snap the run passes and the one it comes to rest on, and
a hand taking the run on its way stops the journey. A tap reaches the view
drawn on top through `.onItemTapped`, and `.shade(_:)` darkens a far view by
the `shade` its placement answers.

Laid out right to left, a motion layout keeps the shape its arithmetic writes:
a dial, a clock or a table of photos reads alike in every language. A layout
in reading order says `.mirrorsRightToLeft(true)`: each view's place turns
about the middle of the room, with its move along and its turn, and the hand
over it turns with it, so the arithmetic stays written left to right - the
carousel above, so marked, brings the next name in from the left in Arabic.

An axis's range is how far the hand moves it: past an end, less and less,
and let go there, it comes back onto the end. Its snaps are where it may rest
beside the range's ends, which it always may: `[1, 2]` lists them,
`.every(1)` puts one every unit from the lower end, `.at(stops)` takes a list
worked out, and `.endpoints` leaves the ends alone - a drawer is open or closed,
nothing between. Given no snaps, the axis rests wherever the hand leaves it
or its throw ends, inside the range, and is named only once it rests:

```swift
struct Drawer: View {
    @State private var open = 0.0

    var body: some View {
        MotionLayout(["Notes"], parameters: $open) { name in
            Text(name)
        } placements: { room, open in
            [Placement(Rect(0, room.height - 60 - open * 200, room.width, 260))]
        }
        // Pulled up, it opens; let go, it is open or closed.
        .axis(\.self, input: .scroll(.vertical, pointsPerUnit: 200), range: 0...1, snaps: .endpoints)
        .height(300)
    }
}
```

The hand carries the view in front: it travels as far for one unit of the
parameters as the front view of those the parameters move goes for it, so a carousel
that grows with its window turns as far under the finger as on a phone.
`pointsPerUnit:` gives the distance instead, for a run whose front view
hardly moves - a pile of cards fanned out by another axis.

A hand let go with speed throws the run: it goes on to the snap nearest
where the throw would end, and `turn` names that snap at once. How it goes
on is the input's `throwing:` motion - eased, its length says how far it
carries, a shorter length stopping it sooner, and it slows onto the snap from
the hand's speed; a spring carries it as far as its response and settles as
springs do. A throw sets out at the hand's speed, and goes on as the parameters'
journey does: `$turn.journey` says where the run is and how fast it goes while
it does, as for any journey. The landing on the next snap is never slower
than `.motion(_:)` moves a unit: a hand let go still, thrown back, or too slow
to get there sooner, brings the run onto it under that motion over as much of
its length as the way left is of a unit - the last tenth of a card takes a
tenth of the motion. A mouse's wheel turned notch by notch steps
the run a snap a notch, under `.motion(_:)`, however far apart the snaps
stand - an axis with none, a hundred points' worth of the hand.

A change of the layout where its parameters stand travels too. A view
joining fades in where the arithmetic puts it; one leaving goes at once and
the others close up; a new order slides; and a value read in the body - a
switch between a fan and a pile - takes every view from where it was to its
new place as a body of the layout's world, while the parameters go on as they
go. `.physicsWorld(_:)` says how: each view on a spring to its place,
`.standard` - 300 milliseconds, never past it - unless said, `.none` for
views standing at their places at once; `.motion(_:)` is the parameters' law
alone:

```swift
struct Hand: View {
    @State private var names = ["Mural", "Nebula", "Ridge"]
    @State private var fanned = true
    @State private var turn = 0.0

    var body: some View {
        let gap = fanned ? 140.0 : 12.0

        VStack {
            MotionLayout(names, parameters: $turn) { name in
                Text(name)
            } placements: { room, _ in
                names.indices.map { index in
                    Placement(Rect(room.width / 2 - 60 + Double(index) * gap, 0, 120, room.height))
                }
            }
            .physicsWorld(.spring(response: .milliseconds(300), damping: 0.8))
            .height(160)

            Button("Add").onClicked { names.append("Bloom") }
            Button("Fan").onClicked { fanned.toggle() }
        }
    }
}
```

Removing the card at the front brings the one behind it there, as the
others close up. Where the front card was the last, the parameters themselves have to
go: `$turn.journey.move(to:)` in the same handler sends the run to the card
before it, under `.motion(_:)`.

A view can be a body of its own: `.physicsBody(.followsLayout(_:))` on it
makes it follow its place on the spring it names - carried by the run, it
lags behind its place while the run turns, swings past where a throw stops
and settles back onto it. The world is worked out at a fixed step, so every
host and frame rate shows the same motion; under less motion every view
stands at its place. `.onSettled { parameters in … }` is told once the run comes to
rest - no hand holding it, the parameters at its destination and every view at its
place - with the parameters it rests at, whatever moved it: the one place to save
where the user left a run:

```swift
struct Swaying: View {
    @State private var turn = 0.0

    var body: some View {
        MotionLayout(["Mural", "Nebula", "Ridge", "Bloom"], parameters: $turn) { name in
            Text(name)
                .physicsBody(.followsLayout(.spring(response: .milliseconds(420), damping: 0.55)))
        } placements: { room, turn in
            (0..<4).map { index in
                Placement(Rect(room.width / 2 - 60 + (Double(index) - turn) * 140, 0, 120, room.height))
            }
        }
        .axis(\.self, input: .scroll(.horizontal), range: 0...3, snaps: .every(1))
        .onSettled { turn in print("at rest on \(turn)") }
        .height(160)
    }
}
```

The arithmetic can also be handed where the run's motion set out: the parameters
it stood at when the hand, a throw or a journey took it away, then each
snap the run passes. The parameters' side of it is the way the run goes, so a pile can
send the card that stood in front out that way - left as the hand moves the
run on, right as it takes it back - and under the others, while the next
comes up from beneath:

```swift
import StateUIFoundation
import StateUI

struct Pile: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom"]

    var body: some View {
        MotionLayout(names, parameters: $turn) { name in
            Text(name)
        } placements: { room, turn, from in
            names.indices.map { index in
                let step = Double(index) - turn
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
        .axis(\.self, input: .swipe(.horizontal), range: 0...Double(names.count - 1), snaps: .every(1))
        .height(220)
    }
}
```

`.swipe(_:)` moves the run one card a hand, however far the hand goes - a
trackpad's flick speeds up to well past a card - and a throw goes on to the
next card that way, no farther - so its axis needs snaps; its unit is
measured as the hand takes the run, so the card in front moves under it. At the parameters it set out from,
every view stands where it stood, so a hand taking the run back past it
changes nothing drawn - the same card goes out
the other way. A hand catching the card on its way goes on with it; a long
hand or a throw across several cards sends each out in turn.

`.pages(_:)` is a swipe a room's length a unit: boards side by side a room
apart are turned a board a hand, and a wider window or a turned phone keeps a
board a screen. A row of dots can wear the same `$board` under them - one
state, so they go with the hand and with every throw:

```swift
struct Boards: View {
    @State private var board = 0.0

    let names = ["Mail", "Clock", "Notes", "Music", "Maps", "Books"]

    var body: some View {
        VStack {
            MotionLayout(names, parameters: $board) { name in
                Text(name)
            } placements: { room, board in
                names.indices.map { index in
                    // Three a board, the boards a room's width apart.
                    let (page, slot) = index.quotientAndRemainder(dividingBy: 3)
                    let width = room.width / 3

                    return Placement(
                        Rect((Double(page) - board) * room.width + Double(slot) * width, 0, width, room.height))
                }
            }
            .axis(\.self, input: .pages(.horizontal), range: 0...1, snaps: .every(1))
            .height(80)

            MotionLayout([0, 1], parameters: $board) { _ in
                Rectangle()
                    .fill(.gray)
                    .cornerRadius(4)
            } placements: { room, board in
                [0, 1].map { page in
                    Placement(
                        Rect(room.width / 2 - 12 + Double(page) * 16, 4, 8, 8),
                        opacity: 0.3 + 0.7 * max(1 - abs(board - Double(page)), 0))
                }
            }
            .height(16)
        }
    }
}
```

The hand can also take one view by itself. `.itemDrag(begins: .longPress)` gives
it the view under a press that stands still a long press's time - an icon
lifted off a board - and `.itemDrag(begins: .perpendicular)` the view under a press
whose first move runs across the layout's axis - a card pulled up out of a
deck that scrolls sideways; a hand that begins any other way moves the run
as before. The held view follows the hand over the others, and
`.onItemDragged` is told whether the hand takes it, moves it or lets it go,
the item, where the hand is in the room, how long it has stood still, how
fast the hand goes, and the item whose view it is over (`drag.over`) - each
time the hand moves it, and again each long press it stands. Lift the
view as the hand takes it - `.scale(lifted == item ? 1.18 : 1)` with a
`.motion(_:_:)` of its own on `.transform` - so the hand knows it has it. Changing the order there makes room: the others travel to
their new places while the held view stays under the hand. Let go, it
settles into its place as a body of the layout's world:

```swift
struct Board: View {
    @State private var names = ["Mail", "Clock", "Notes", "Music"]
    @State private var turn = 0.0

    var body: some View {
        MotionLayout(names, parameters: $turn) { name in
            Text(name)
        } placements: { room, _ in
            names.indices.map { index in
                Placement(Rect(Double(index) * room.width / 4, 0, room.width / 4, room.height))
            }
        }
        .itemDrag(begins: .longPress)
        .onItemDragged { drag in
            // Over another name, the held one takes its place, the others make room.
            guard let over = drag.over, let from = names.firstIndex(of: drag.item),
                  let to = names.firstIndex(of: over) else { return }
            names.remove(at: from)
            names.insert(drag.item, at: to)
        }
        .height(80)
    }
}
```

`.onItemDismissed(.up, beyond: 120) { card in … }` lets a view go for good:
let go past 120 points up - or thrown far enough that way - it flies on out
of the room, and the handler runs once it has left, where the application
removes the item. Short of it, the view goes back. A handler that awaits takes
a gate, as an event's does - `.onItemDismissed(.up, beyond: 120, policy:
.ignoreWhileRunning) { card in try await archive(card) }` - and what it runs
ends with the layout.

A run with no ends comes round: `periodic: true` makes one turn of the range
bring the layout back where it was - its upper end is its lower one a turn
on, its snaps repeated each turn - so the hand and the program both move it
on forever. The arithmetic folds the parameters themselves:

```swift
struct Ring: View {
    @State private var turn = 0.0

    let names = ["Mural", "Nebula", "Ridge", "Bloom", "Dune"]

    var body: some View {
        MotionLayout(names, parameters: $turn) { name in
            Text(name)
        } placements: { room, turn in
            names.indices.map { index in
                let step = (Double(index) - turn).remainder(dividingBy: Double(names.count))

                return Placement(
                    Rect(room.width / 2 - 60 + step * 140, 0, 120, room.height),
                    opacity: 1 - min(abs(step) / 3, 1))
            }
        }
        .axis(
            \.self, input: .scroll(.horizontal, throwing: .spring(response: .milliseconds(400), damping: 0.8)),
            range: 0...Double(names.count), snaps: .every(1), periodic: true)
        .height(200)
    }
}
```

Parameters of several axes are a `LayoutParameters` of your own: a struct of numbers
listing its axes. Each axis moves on its own - one under the hand, another
written by the program - and travels under the same `.motion(_:)`:

```swift
struct Orbit: LayoutParameters {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}

struct Planets: View {
    @State private var orbit = Orbit()

    let names = ["Mercury", "Venus", "Earth", "Mars"]

    var body: some View {
        VStack {
            MotionLayout(names, parameters: $orbit) { name in
                Text(name)
            } placements: { room, orbit in
                names.indices.map { index in
                    let size = 60 * orbit.zoom
                    let step = Double(index) - orbit.turn

                    return Placement(Rect(room.width / 2 - size / 2 + step * size * 1.5, 0, size, size))
                }
            }
            .axis(\.turn, input: .scroll(.horizontal), range: 0...Double(names.count - 1), snaps: .every(1))
            .motion(.spring(response: .milliseconds(240)))
            .height(160)

            Button("Nearer").onClicked { orbit.zoom = orbit.zoom == 1 ? 2 : 1 }
        }
    }
}
```

`.axis(_:input:range:keyframes:snaps:periodic:)` declares one axis whole - what
moves it, how far it runs, where its layout is worked out, where it rests,
whether it comes round - and the hand moves
that one alone, resting it on its own snaps whatever the others do. One input
may move several axes, each by its own unit and range, resting its own way:
a hand that turns the cards and, slower, the sky behind them. Declared again,
an axis takes the new declaration; an axis declared none goes on as the
program sends it. A `Double` is the parameters of one axis, `\.self`.

Two fingers are inputs of their own: `.magnification` multiplies an axis
by how far they spread - on a touch screen, or a trackpad's pinch - and
`.rotation(degreesPerUnit:)` moves one a unit every so many degrees they
turn, clockwise on. Both move their axes at once; let go with speed, each
goes on to where it would end - onto the snap nearest it, where it has
snaps. A hand along the layout may move a third axis - and it goes on with
the fingers' middle while they spread and turn:

```swift
import StateUIFoundation
import StateUI

struct Dial: LayoutParameters {
    var turn = 0.0
    var size = 1.0

    static var axes: [WritableKeyPath<Dial, Double>] { [\.turn, \.size] }
}

struct Compass: View {
    @State private var dial = Dial()

    let names = ["North", "East", "South", "West"]

    var body: some View {
        MotionLayout(names, parameters: $dial) { name in
            Text(name)
        } placements: { room, dial in
            names.indices.map { index in
                let angle = (Double(index) + dial.turn) / 4 * 2 * .pi - .pi / 2
                let radius = 80 * dial.size

                return Placement(Rect(
                    room.width / 2 + cos(angle) * radius - 30,
                    room.height / 2 + sin(angle) * radius - 12,
                    60,
                    24))
            }
        }
        .axis(\.turn, input: .rotation(degreesPerUnit: 90), range: 0...4, snaps: .every(1), periodic: true)
        .axis(\.size, input: .magnification, range: 0.5...2, snaps: [1])
        .height(240)
    }
}
```

A magnification's range stands above nought, and its axis is nearest a
snap by the logarithm - 1.5 is nearer 2 than 1 - so pinching in acts as
spreading does. With a mouse, a press dragged with ⌥/Alt is two fingers -
the press and its mirror about the layout's middle - which turn round the
middle and spread toward and away from it; Control and the wheel spread too.
Chrome and Firefox tell no trackpad's rotation; there ⌥/Alt and a drag turn
a layout, as fingers do on a touch screen.

Two axes scrolled, one across and one down, are a pan: the hand moves both
whichever way it goes, the across axis with the hand across and the down
axis with it down, and let go, they rest together. One finger or two carry
it; two fingers carry it by their middle while they spread and turn, so a
pan, a magnification and a rotation move at once - here the zoom resting
anywhere between half and whole:

```swift
struct Sheet: LayoutParameters {
    var x = 0.0
    var y = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Sheet, Double>] { [\.x, \.y, \.zoom] }
}

struct Contacts: View {
    @State private var sheet = Sheet()

    let names = ["Ada", "Ben", "Cy", "Di"]

    var body: some View {
        MotionLayout(names, parameters: $sheet) { name in
            Text(name)
        } placements: { room, sheet in
            names.indices.map { index in
                let (row, column) = index.quotientAndRemainder(dividingBy: 2)
                let size = 120 * sheet.zoom

                return Placement(Rect(
                    room.width / 2 + (Double(column) - sheet.x) * size - size / 2,
                    room.height / 2 + (Double(row) - sheet.y) * size - size / 2,
                    size,
                    size))
            }
        }
        .axis(\.x, input: .scroll(.horizontal), range: 0...1, snaps: .every(1))
        .axis(\.y, input: .scroll(.vertical), range: 0...1, snaps: .every(1))
        .axis(\.zoom, input: .magnification, range: 0.5...1)
        .height(300)
    }
}
```

Given keyframes, an axis has its arithmetic asked only there - at them, at
its range's ends and at its snaps - and every view goes from its pose at one
keyframe to its pose at the next along `.interpolation(_:)`: straight unless
said, `.catmullRom` a smooth curve through them, `.monotone` one that never
swings past them. So quite different layouts, one at each keyframe, are one
the hand moves through - here a row, a column and a pile:

```swift
struct Arrangements: View {
    @State private var arrangement = 0.0

    let names = ["Ada", "Ben", "Cy", "Di", "Eve"]

    var body: some View {
        MotionLayout(names, parameters: $arrangement) { name in
            Text(name)
        } placements: { room, arrangement in
            // Asked at 0, 1 and 2 alone: a row, a column, a pile.
            [row(in: room), column(in: room), pile(in: room)][Int(arrangement)]
        }
        .axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1), snaps: .every(1))
        .interpolation(.catmullRom)
        .height(300)
    }

    private func row(in room: Rect) -> [Placement] {
        names.indices.map { Placement(Rect(Double($0) * 64, room.height / 2 - 20, 60, 40)) }
    }

    private func column(in room: Rect) -> [Placement] {
        names.indices.map { Placement(Rect(room.width / 2 - 30, Double($0) * 48, 60, 40)) }
    }

    private func pile(in room: Rect) -> [Placement] {
        names.indices.map { index in
            Placement(
                Rect(room.width / 2 - 30 + Double(index) * 4, room.height / 2 - 20 - Double(index) * 4, 60, 40),
                transform: .rotate(Double(index) * 6 - 12),
                zIndex: index)
        }
    }
}
```

Every view keeps its identity from layout to layout, and where the run rests
- an end or a snap, which are always keyframes - it shows the arithmetic's
own answer, never a blend. Each keyframe's answer is asked once and kept
until the room, the description or a state named in `.following(_:)`
changes, so a layout costly to work out is worked out a few times rather
than every frame. Several axes with keyframes blend together, each between
its own. Between two keyframes a view goes the curve's way rather than the
arithmetic's: an arc becomes a chord unless keyframes stand close, and
arithmetic that jumps between two keyframes - a card coming round from the
far end - is drawn sweeping across; blend a scale rather than a size, which
lays the view's content out every frame. On one axis the layouts are a
sequence: from the row to the pile, the run passes the column.

A value read in the body is a change of the description: the layout is built
again and its arithmetic with it. A state the arithmetic reads that moves on
the host's frames - a drag of your own - is named in `.following(_:)` instead.
On an axis nothing bounds - inside a scroller - keep the answer bounded:
placements that grow with the room grow the room, and the layout never
settles.

`MotionLayout` has its own row in the
[Platform contract](../platform-contract.md); `GalleryView` behaves as far as
the rows it uses - the motion layout and frame reporting - are checked
there.
