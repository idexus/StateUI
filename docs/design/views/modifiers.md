# Modifiers

A modifier is how everything but a view's purpose is said: a property, a
handler, a key, an animation rule, a child slot. Every modifier returns a
modified copy, so a view stays a value all the way down.

## A modifier returns a modified copy

Every modifier goes through one operation, `modified(_:)`: copy the node,
change one thing, return the copy. There is a single place where a change is
stored, and only that place knows where it goes, which keeps every modifier
working for controls, styles and composed views alike - a composed view's
`modified` answers a `ModifiedContent` (composition.md).

```text
  Label("Total")           Node(Label, props: [text: "Total"])
    .fontSize(20)          copy, props[fontSize] = 20
    .onTapped { … }        copy, events[tapped] += handler
    .id("total")           copy, id = "total"
    .contextMenu { … }     copy, children += ContextMenu(...)
```

## Setting a property

A value modifier writes one property through its contract member:
`setValue(LabelContract.maximumLines, 3)`. The member carries the property's
token and its value's type, so a modifier cannot write the wrong type, and the
token is what the patch names. A modifier that writes several things at once -
`onTapped(count:)`, `onSwiped`, `transform` - does it inside one `modified`
closure with `write` and `describe` on the node, because chaining two
modifiers would return `Modified.Modified`, which nothing can promise is
`Modified`.

## A handler runs beside the one before

`addHandler` adds a handler to an event beside any already there, never in its
place. What a described two-way binding leaves behind is itself a handler - it
writes the new text back on every edit - and an `.onTextChanged` written after
it has to run beside it, or the binding would go quietly dead. Every typed
event modifier comes through here with its member's token. It lives on
`ModifiableElement`, so nothing reachable from a `Style` can put a handler
into a bag of values.

## An event payload that does not read

What arrives is what the contract says or nothing. A payload with a value
missing, one too many, or one of another kind is reported once and does not
reach the handler. Gestures follow the same rule: a swipe handler run with an
empty direction set would say a swipe happened with no direction, which no
test of the direction could tell from a real one.

## Slot children

Some modifiers write a child rather than a property: `.contextMenu` appends a
context menu, `.visualState` appends states, `Map.pins` writes pins, a
`TitleBar` fills its content slots and a `SwipeView` its item collections.
They sit after whatever the view lays out, so the view's own children keep the
positions the differ gave them, and the host finds each by type and leaves it
out of the arrangement. The slot a `.contextMenu` appended stays last: a
modifier that writes other children - pins, title bar slots - puts them in
front of it.

## Motion is per view

`.motion(_:)` says how this view's values animate, and it applies to this view
and not to what is inside it. Nothing in the library reaches down a tree: a
value animating because something four levels up said so is a surprise slow to
find. A whole application is set once, with `application.motion` in its
session.

`.motion(_:_:)` answers for some values only, and the last rule naming a value
answers for it, which is what a modifier written later means everywhere. Its
usual use is a view whose shape changes: it takes its new size at once while
its place still animates, since a panel growing out of nothing reads as a
fault and a panel that slides does not. The plan stays in the renderer: its
answers become transitions for changed properties and layout motion for the
children a host arranges.

## Keys are described text

`.id(_:)` takes any `Hashable` and stores `String(describing:)` of it, as a
`ForEach` item, a navigation route, a tab and a modal sheet do, so one value
means one thing wherever a key is given (builders.md, ForEach keys are text).
A key is not a property and does not go through `setValue`: it travels as the
element's identity, and the host finds and keeps the native control by it.

## An aim is not a key

An aim (`@Aim`, `.aim(_:)`) is who a view is to an act; `.id(_:)` is who it is
to the differ. The differ fills the aim with the element's own identity as it
walks, so there is nothing to spell and nothing to collide. A view carrying
only an aim is still matched by where it was written, so a collection's rows
keep wanting `.id()`, and the two compose. The aim is typed, `Aim<Self>`, so
the declaration and the view agree at compile time and the aim offers exactly
the acts the control has.

## Showing and hiding cross fades

`isVisible` animates rather than blinking a view in and out: a view being
hidden fades to nothing first and goes when it gets there, and one being shown
appears at nothing and fades in. Two views in one place - a tab chosen, a
panel swapped - therefore cross-fade. The view stays in the tree the whole
time and is hidden once the fade lands; a view on its way out answers no touch,
so a tap during the change reaches what is arriving. A view described for the
first time is simply shown or not, since nothing anybody saw is changing, and
`.motion(.none)` makes the property a plain flag again.

## One transform about the centre

`.transform(_:)` writes `translationX`, `translationY`, `rotation`, `scaleX` and
`scaleY` from one `ViewTransform`, about the view's own centre, so those five
are its to say. The parts apply in the order written, each to what the parts
before it made: a move written before a turn is swung round by it, one written
after is not. `renderTransform` on a shape is the other transform: it
transforms the geometry, in the shape's own units, before it is drawn.

## Turning out of the screen plane

A turn out of the screen's plane - `rotationX`, `rotationY` - is projected
through a camera each platform chooses for itself, so the same angle is not
the same picture everywhere: one run of cards at one angle is turned away on
one platform, and drawn tilted in the plane and moved on another. A turn that
must look alike everywhere is written as what a turned rectangle looks like: a
scale of `cos(angle)` across the axis it turns about. `ViewTransform.turn`
draws a turn about the vertical axis that way.

## Accessibility and automation

Four modifiers say what a view is to somebody not looking at it, and they are
two jobs that do not stand in for one another.

`accessibilityIdentifier` is a handle nothing reads out: a UI test, a script or
an agent driving the application asks the platform's automation for it, where
the alternative is a coordinate read off a picture. It is on
`PropertyContainer` because a toolbar item and a menu entry carry one as much
as a view does, so the button in a page's bar can be named. It stays stable
across renders and unique on the page: an id that moves with the state is one
nothing can wait for, and two things sharing one leave the driver to guess.

The label, the hint and the heading level are read out by a screen reader and
are no use to a driver, a description being prose that changes with the
user's language. They are a view's alone, on `VisualElementProperties`. A
label on a control that shows its own words replaces them rather than adding to
them, so the ones worth writing are on controls with no words of their own.
Left unsaid, whether a screen reader skips a view is the platform's decision,
which is nearly always right: a view with words is reachable and a plain
container is not.

## Gestures

Gestures belong to every view, so a Border holding a whole row, an Image or a
Label can answer one; a list row can be a view with a tap recognizer rather
than a button disguised as a container. Tap, swipe, pan, pinch, pointer, drag
and drop are described.

A recognizer is added to the native view when the tree first carries a handler
for it and kept for as long as it does, as a control's own events are
subscribed once, so a render can change what a gesture does without anything
being rebuilt. A recognizer's settings ride with its handler rather than
becoming modifiers of their own: `.onSwiped(direction: .left)` says what it
listens for in the same breath as what it does, and there is no
half-configured recognizer to leave lying about.

A drag carries text, the portable payload. A native drag session needs its
payload at once, so the handler that runs as the drag starts cannot decide it.

## Placement is written on the child

Where a view sits in a Grid or an AbsoluteLayout is written on the child: the
layout asks and the child answers. The modifiers live on `ViewProperties`,
where any view that may find itself in such a layout can reach them - and a
style too, a view's place in a grid being as styleable as its margin.

They carry the layout's name - `.gridRow()`, never `.row()` - which says which
layout is asking. The absolute layout is the one place the prefix gives
ground: its name followed by the property's would be
`absoluteLayoutLayoutBounds`, and the doubled word says nothing more, so the
modifiers are `.absoluteLayoutBounds` and `.absoluteLayoutProportions`. The
wire uses the same names, so there is one name from the modifier to the host's
table. A view that says nothing sits at row 0, column 0, spanning one of each.

## Safe area edges

`avoidsSafeArea` takes one value for all four edges, two for the horizontal
and the vertical edges, or four. The two-value form is written out to four
edges before it travels, so the wire carries one shape of the property and the
host reads one thing rather than three spellings of it. The four regions
travel as members, in order, each a value of its own rather than a run of
numbers - a member and a quantity are different things on the wire - and the
one-value form sends a single `.enumeration`.

## Environment

`.environment(_:)` provides an object to a view and everything under it,
resolved by type; a nearer one of the same type overrides it for its own
branch. Providing reads no property of the object, so a change in the object
rebuilds the readers below and not the provider, and replacing the object -
writing the `@State` that holds it - rebuilds the branch. Nothing about it
crosses to a host.
