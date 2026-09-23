# Identity and diffing

The differ (`Differ`, Core/Diff.swift) walks the tree a render built against
the tree the host holds (`RenderedNode`, Core/Tree.swift) and packs only the
differences into a `HostPatch`. A `Node` is what an author wrote this render
and is thrown away after it; a `RenderedNode` is one element as it stands on
the host, and it persists.

```text
  Node (this render)          RenderedNode (what the host holds)
  type, id, key, props,  -->  id, type, props, handler ids, reads, views,
  events, children,           placeholder, watched values, engines,
  placeholders                driven states, children
                  \               /
                   Differ.element
                         |
                         v
                      HostPatch   (sparse: absence means unchanged)
```

## Keys

An element keeps its key, and with it its native control, focus, caret and
scroll position, for as long as it stays in the tree. `Differ.match` tries
three ways to be the same element, in order:

```text
  1  the author's .id()   a name, matched wherever the element moved to;
                          what a collection needs and what ForEach stamps
  2  the builder path     WHERE it was written: which statement, which branch
                          (Node.key); matched wherever it moved to as well
  3  the position         for a node put in by hand, counted among the
                          hand-written siblings only
```

The three never meet: a node identified one way is never matched to an element
identified another, so adding `.id()` to a view replaces its control rather
than quietly adopting the one the path had. The builder path exists because
position is not identity once a closure has an `if`: an `if` that produces one
child in one state and none in the other would otherwise hand the next view
the control, focus and caret of the one that left. Hand-written nodes, such as
a page's appended title view, are matched by position among themselves, so a
conditional beside them does not shift them.

`ElementId` has two cases that are two namespaces: `.auto` is a number the
differ assigns and `.manual` is the author's text. On the wire one is a number
and the other a string, so they can never collide.

## Ids are never reused

Element ids and handler ids come from counters that are never reset, not even
by a resync. A stale host control can never be mistaken for a new one that
lands on the same number, and an event arriving late never reaches the wrong
closure.

## Repeated ids

Two siblings written with the same `.id()` cannot both keep the bare id: the
host matches children by key and one control cannot stand in two places. A
fresh automatic id every render would rebuild the repeat's control, handlers
and state each time. The repeat takes a stable variant instead - the id, a NUL
and its occurrence number - which is the same key every render and can never
equal an id an author spelled.

## State survives a rebuild

A composed view is a value rebuilt on every render, so a `@State` on it comes
back as a fresh box holding the initial value. The view is not built when the
tree is written: it goes into the tree as a placeholder (`Node.Stateful`)
carrying the view's type, its state boxes and a closure that builds the real
subtree. The differ, on reaching the placeholder, knows the element's key and
whether the same kind of view stood there last render. If it did, the fresh
boxes adopt the old ones' storage (`State.adopt`), and only then is the body
built, so everything it reads sees the surviving values.

Same key, same view type, same state - the rule the differ applies to
controls, one level up. A different view type at the same place starts over,
as a different control type replaces the control.

## Paths pair state

`stateParts` walks the view's stored properties once per placeholder with
`Mirror`, and each box comes back under the path the walk reached it by: the
property's name at every level, the builder branch a keyed child came from,
and the type of any view stored along the way. Boxes are paired by path, not
by position. A stored slot that fills between two renders would otherwise
shift every later box by one and hand an untouched counter the count of
another; a path nobody answered last render is a box that starts at its
initial value. The view's type is part of the path because one property can
hold a different view each render, and naming only the property would hand the
newcomer its predecessor's state.

The walk stops at a `Binding` (the storage is its lender's), at an aim the view
was handed (its parent's), at a `Node` (built interface), at any `Equatable`
value (compared whole) and at any class (a reference keeps itself alive).

## Carrying a view

A composed view whose parent ran again is carried - not built, not compared,
not sent, its state and handlers untouched - when all of these hold:

```text
  same view type at the same key          nobody forced this build
  it read nothing that changed            the render is not a resync
  the styles did not move                 no provider above was replaced
  the parent wrote the same things on it  it was built with the same inputs
```

The decision is taken on the outermost view alone; a view made of another is
one element, and the inner view's inputs are the outer body's business.

## What a view was built with

`Input` is one stored property as far as the differ can see it, compared the
one way it can be:

```text
  value       by ==, opened on the first value's type
  borrowed    a @Binding by the storage it lends, never by the value in it
  box         a @State or declared @Aim by the storage/box held after adoption
  aim handed  by the box it aims through, never adopted
  slot        an @Environment by the object it resolved to
  reference   an object by identity
  parts       a container's count, so collections of different length differ
  opaque      a closure, a built node, anything else: always a change
```

It errs toward building: what it cannot see through it does not assume.

## What the parent wrote

`sameWriting` compares the placeholder as the parent wrote it: properties, the
motion plan, driven ties, the objects `.environment()` provided on it, the
watched values, and the names of the handlers. What runs as the view comes and
goes is compared by count, the closures being taken fresh by the carry. A slot
child, an engine or a reading written on the view makes it build as it always
did.

A carried view takes the handlers the parent wrote on it afresh, under the ids
it keeps: the parent's closure ran again, so what those handlers captured is
what the parent computed this time. The placeholder is kept fresh for the same
reason, so a later clean walk that builds the view from it runs the newest
inputs.

## What a carry cannot see

A view's inputs say nothing about the style sheet or about a provider above
replacing its object. The walk therefore suppresses every carry for the one
walk in which the sheet moved, and a composed element keeps a snapshot of the
nearest provided object per type (`RenderedNode.seen`) that a carry compares.

## The clean walk

`Differ.revisit` walks the tree the host holds with no fresh tree to compare
against, and builds again exactly the elements whose reads intersect the
changes. It runs the closure the element's placeholder captured last render,
which is correct precisely because the walk got there: the parent was left
alone, so nobody computed newer inputs. A parent that is rebuilt writes fresh
placeholders for its children, and those go through the full `element` path.
A clean walk moves nothing: a child's place among its siblings is its
parent's business.

An element keeps what the clean walk needs to build it without its parent:
a composed view keeps its placeholder, a container keeps its node with the
content still to run, the environment it provided, the scene it is in, and
whether its sizes arrive. A leaf keeps nothing: its properties were computed by
an ancestor's closure, and a change to them starts at that ancestor.

## Containers run their own content

A container's content is a deferred `producer` rather than built children. The
author's closure runs when the differ describes that element, not when the
author's line constructs the view. So a closure inside a carried view never
runs, an ancestor's `.environment()` is in scope when it does run, and its
reads land on the container's own element: the one built again when the state
moves. `materialize()` joins the produced content with the slot children a
modifier appended, produced content first.

The content runs inside a build frame, so `debugInfo()` in the container's
braces names the view whose braces they are.

## A resync keeps matching

`describeAll` changes what goes into the patch - every element in full - and
nothing about matching. Keys, state adoption and handler bookkeeping work
exactly as in an ordinary diff; otherwise a resync would reset every `@State`
and leak the whole registry. A complete description compares optional fields
against the host's own default rather than against this side's last render,
because the host receiving it may be a fresh one holding nothing.

## Handlers and their ids

A node carries closures, not ids: building a tree has no business writing to a
registry, and the id a host reports has to outlive the node. The differ
registers each event's closure under an id that belongs to the element and
stays put for as long as it handles that event, so an element the message does
not mention goes on resolving the ids the host already has. Ids are assigned
in event-name order, so two runs of one tree number alike. An event the
element stops handling takes its id with it.

The event map is sent when the set of handled events changed. An empty map is
sent for a continuing element whose last handler went, because there it means
"clear what you had"; for a new element or a resync an empty set is nothing to
say.

`addHandler` adds a handler beside any the event already has, never instead of
it: what a two-way binding leaves behind is a handler, and a modifier that
replaced it would silently break the binding.

## Properties no longer described

A property the element carried last render and no longer describes is named
in `clearedProperties`, and the host puts that one property back to the
control's default - a modifier that stops being written costs that property,
not the control, its handlers and the state of every view under it. A member
whose facts say it is not `cleared` has no host default to go back to, and
its loss replaces the element instead. A change of node type replaces the
element too.

## Transitions

A property that changed on a continuing element carries a `HostTransition`
beside its new value: the value is the destination and the host animates the
control to it. An element described for the first time - built, replaced,
resynced or adopted under a new key - has no before to animate from, so the
first frame anyone sees is always the value itself. Nothing is written for a
value with no half way (text, a flag, an enumeration member) or when the
motion resolves to none.

A size somebody measures is never animated. Where an element reports its own
frame, or the layout it stands in is measured, a size comes from a report, and
animating it would lay the page out at sizes nobody chose, growing from
nothing on the first report.

## Layout motion

Where children go and what visual states change are the host's own arithmetic
- a placement comes from a measurement, a visual state is applied by the
platform outside every message - so neither has a property for a transition to
ride beside. A layout that places children, an element with visual states, and
an element that answered `.motion(_:)` for itself say how their children
animate in `HostPatch.motion`.

`.inherited` is what a layout is until told otherwise, on both sides, so a
layout that animates the way the application does says nothing on any message.
What crosses is an override and its going away; the application always says
its own motion once. The lanes say which parts of a child's place animate: a
layout told `.motion(.none, .size)` moves children to new places but gives them
new sizes at once, and a measured layout's children take their sizes at once.

## Themes

A value with a half for each theme (`Color(light:dark:)`) stays whole in the
node and is resolved by the differ as the element is built. That read makes
the element the theme's reader, so a theme change builds it again. A leaf
wearing such a value keeps its authored node, the way a container keeps its
content, so the clean walk can resolve it again.

## Watching values

`.onChanged` compares a value with the one the same element carried last
render; nothing about it crosses to the host. Its rules:

```text
  the first render never fires       a view arriving is not a value changing
  values are kept in written order   one slot per modifier, so two watches
                                     never answer for each other
  a different count starts over      a watch under an `if` shifts every slot
  a slot of another type starts over it changed hands
  handlers run after the walk        a write mid-walk would be cleared
```

A handler that moves the very value it watches is fired again by the walk of
its own write; one that moves it every time is a loop, merged into the message
a few times and then a render per step.

## Created and destroying

`.onCreated` runs once for an element that was not there before - new, or
replacing what stood there - and `.onDestroying` once as it leaves, while its
state and environment still answer. Both run after the walk and before the
message leaves, so what they write is in that message. What leaves runs before
what arrives, innermost first, so what it saves is there for its replacement
to read. `forget` drops the handlers and disarms the engines of everything
under an element that left.

## Engines on an element

An element's engines are registered under numbers it keeps, so a render hands
the newest closure - this render's captures - to the engine that already has
a number. A different count is a different set of engines and starts over, as
with watches. The engines a conversion needs are armed beside the author's
own, ahead of them, in property order. A board that has forgotten an element's
engines, as after a session claimed afresh, gets them again under the numbers
the element already had.

## Driven properties

A property driven by a state (`.opacity($fade)`) writes no value into the
node; it registers the state instead. The state's number is issued the first
time anything asks, and properties are walked in name order, so numbers follow
the walk and two runs of one tree number alike. The registration set is sent
whenever it changed, an emptied set included: an element that stops tying a
property has to say so.

What `.inherited` means for a driven value can be answered only here: the host
knows what the application says, while an element's motion plan answers per
kind of value. The differ resolves it and leaves the answer on the state's
storage, which applies it at every crossing. Two elements resolving the same
state differently is a complaint; the one described last wins.

## Aims and readings on an element

An aim written on a view takes the key the element settled on; that is the
whole of how an act aims. The content a composed view unwraps to may carry an
aim of its own on its root, which is the same element and takes the same key.
A reading asked for with `.samples` is held by the element and keyed by its
target, so a view described again replaces its own reading.

## Recycling

A list scrolling by one row builds a row's controls and throws another row's
away, and building controls is what makes a scroll judder. The row leaving and
the row arriving usually have the same shape, so the leaving control could
stand in for the arriving one - if the host knew they were alike.

`Recycling.shape` is that knowledge: a number over the subtree's types,
property keys and event keys, values left out. Two rows share a shape exactly
when they name the same properties on the same controls in the same places, so
a control adopted under a matching shape is given a value for every property
it carries and has nothing left over to clear. A conditional property splits
the shape in two, which is correct: those two rows are not interchangeable.

```text
  shape = FNV-1a over   type name
                        property keys, sorted
                        ""              (a separator: props vs events)
                        event keys, sorted
                        children, recursively
                        ""              (so depth changes the number)
  every piece ends with 0xff, so "ab"+"c" never reads as "a"+"bc"
  0 means "may not be recycled"
```

The hash is written out rather than taken from Swift's hashing, which is
seeded per process: two runs must number a shape alike for a fixture, and two
instances in one run must, or nothing would be adopted. The keys are sorted
because a dictionary's order differs between two instances in one run.

`Recycling.poolable` is an inclusion list: a control whose whole state is in
the tree. Text inputs and pickers hold a caret, a selection or an open list;
a scroller its offset; a swipe view whether it is open; a refresh view its
spinner; a web view and a map a history and a region; a canvas its cached
surface. None of that is a property, so none of it is in the shape, and every
type added later is outside the list until someone puts it in.

## Merging patches

A render whose handlers wrote state before the message left sends its own
patch followed by the walk of what they wrote, merged into one: the later
patch was computed against the tree the earlier one left, so every element it
names is one the earlier one brought, changed or left standing. A later
`replace` wins whole; an element the message brings arrives at its values
with no transition and nothing cleared; an arranged child list is the whole
list in order, each child merged with what the earlier patch said about it.

A patch is empty - and its parent leaves it out - when it says nothing beyond
naming the element. A transition never counts on its own, since it names a
property in `properties`. A changed set of driven states counts, an emptied set
included, because it is the only field that says "untie".
