# Motion

A change animates by default: assign a state and the control animates to its
new value. `Motion` is the whole of what an author says about how, and the
same vocabulary answers everywhere it is said.

## One vocabulary in four places

```text
  application.motion = ...                  what every value uses by default
  .motion(.none)                            what this element does instead
  @State(motion: .none) var x               what this state does instead, wherever it is shown
  $fade.journey.move(to: 0.1, .spring())    what this one write does instead
```

The tree describes where the interface is going; the host is how the screen
catches up. The renderer resolves these choices into a `HostTransition`
beside each changed property, or a `HostLayoutMotion` for a layout's
children, and a native host animates the presentation on its display frames
while the tree keeps the destination.

## Two laws

A motion has one of two shapes. An eased motion takes as long as it is told,
whatever the distance: the right law for something whose distance the author
knows, such as a fade, a page sliding in, or a card turning over. A spring
has no duration: it answers as quickly as its response says and settles when
it is done, so one whose destination changes carries on from the speed it
had rather than starting again. That is the right law for anything the user
can interrupt, such as a card being dragged or a value still being chosen.

## Every law arrives

Both laws arrive at what the tree said, and that is why there are only two.
A law with no destination - a throw, bled off, coming to rest wherever its
speed runs out - would leave the screen showing a value nothing described,
and because an absent field means unchanged, nothing could ever put it
right. The physics of a throw lives where a throw is: in the scroller.

## Custom animates in an engine

`.custom` is not a third law but a third animator. The host animates nothing,
and an engine of the application writes where the value is and how fast it
is going, frame by frame, toward a destination the state still holds. It is
said where the value is declared, `@State(motion: .custom)`, because which
side animates a state is fixed when the state is first registered with the
host. The host never sees `.custom`: what crosses is `.none` over the value
the engine wrote, so the host wears each frame as it comes.

## Inherited and none

`.inherited` is what a write means when it says nothing about motion: the
element's own motion, else the application's, else the standard one. It is
what makes `move(to:)` without a motion and a plain assignment agree, so the
two differ only in being awaited. `.none` applies a change at once, and an
ordinary property that snaps carries no `HostTransition` beside its value.

Both are made of an eased motion of no duration on this side. On a carried
state they cross as themselves, the first of a law's three lanes naming
which, and an inherited law is resolved against the element's motion on its
way out.

## The standard motion

`Motion.standard` is one 200-millisecond eased motion on `.cubicOut`, used
for ordinary changes and for a scroller's landing unless the application
says otherwise.

## Spring numbers

A spring's response is at least 1 millisecond and its damping at least 0.05.
A damping of 1 comes to rest without overshooting. Below 1 a spring
overshoots and oscillates, which is a deliberate choice and never a default:
half a card's worth of wobble is what a user reads as a mistake.

## Easing curves

An easing is a curve from 0 to 1: given how far through its time an
animation is, it says how far through the change it should be. `.linear` is
the straight line, and every other curve is worth having only because it is
not. `In` curves start slowly, `Out` curves end slowly and `InOut` curves do
both, which is why `.cubicOut` suits something arriving on screen and
`.cubicIn` something leaving. The curves and the two laws are
[closed vocabularies](vocabularies.md#the-numbers-belong-to-stateui).

## Groups of values

`MotionValues` names groups rather than single properties, because that is
how a user thinks about what they are watching: where a view sits, how big
it is, its colours. A motion written on a view applies to all of them unless
it names some. A panel whose content changes shape says
`.motion(.none, .size)`: its children move to their new places and take
their new size at once, since a view growing out of nothing is the one
movement a user reads as a fault.

A colour's group is read off the value rather than from a list of property
names, so a colour property added later is in the group the day it arrives.
Every other property says its group through its member's `moves`; see
[moves](../contracts/member-facts.md#moves).

A selective rule steers the properties the tree describes. What a host
decides with no property of its own - where a layout puts its children, what
a visual state changes, showing and hiding - follows the plain
`.motion(_:)`. A child's placement is also split into `.place`, `.width` and
`.height`, so a rule can snap those parts alone.

## A plan per view

`.motion(_:)` and `.motion(_:_:)` build a `MotionPlan`: one base answer and
the exceptions to it, in writing order. The last rule that names a value
answers for it, as a modifier written later does everywhere else. A plan
written on a view goes over the plan the view is made of: its base replaces
the view's own, and its rules come after, being the later word. The plan
stays in the core, and only its resolved `Motion` answers reach a host.

## Layout lanes

A host works out where a child sits from native measurement, so a placement
is not an ordinary property and cannot carry a property transition. A layout
sends `HostLayoutMotion` instead: its motion, and which lanes of a place
animate (`MotionLanes`: x, y, width and height). A measured layout's children
take their sizes at once and animate only their place.

A layout that animates the way the application does says nothing at all:
`.inherited` is what it is until told otherwise, on both sides, so the
common case never reaches the wire. What is said is an override, and its
going away.
