# Motion in the runtime

How a runtime animates: one walker steps every animation, one channel per
bound state feeds every control tied to it, and the animations a patch
describes are keyed by element and property. The timing laws are the core's,
`HostMotionLaw`; [the runtime](runtime.md) draws where these elements sit in a
frame.

## One walker

A value is animated by `Walker` alone. Every running animation is a `Trip`:
where each lane began, where it is going, its starting speed, its timing and
when it began. A trip is pure: its position is `HostMotionLaw` at the time
handed in, so a hand-wound clock reproduces every frame. One step walks every
trip in `TripTarget` order - states by number, then described properties by
element and property, then layout places by element - so two runs of the same
frame write in the same order. A trip that arrives leaves the walker, and with
Reduce Motion every trip arrives at once, at its destination.

## State channels

A host-carried `@State` has one channel, whatever number of controls are bound
to it. No control keeps its own copy of the animated value, so every bound
control stands at the same value and turns toward a new destination with the
same speed on the same frame. A control that joins mid-animation joins at the
value where the channel stands.

The channel is not a control's to end. It counts the controls wearing it; when
the last one lets go it goes too, but only once its animation has landed where
it was sent, so a control described again a moment later joins it where it
is. When the user takes the value on a two-way control, the animation stops
where the user holds it and its waiter hears that it was cut short.

## Described motion

A patch can describe how a property of an element moves to its new value.
`HostPatch.properties` stays the committed value; `DescribedMotion` owns only
the value drawn on the current frame, keyed by element and property. A new
animation of a property starts from where the running one stands, with its
speed.

A value moves as numeric lanes and only within one shape: a number, a list of
numbers of one length, a colour, or a structure whose kind and parts stay the
same - a gradient moves its geometry, stops and colours, never its kind or
stop count. A brush property moves only between two colours or two well-formed
brushes of one shape; anything else snaps. A themed value never moves.

## Layout motion

A layout works out where each child goes; `LayoutMotion` decides where the
child stands on the way. Why an arrangement happens decides everything:

- A patch reached the layout since its last arrangement: it holds something
  different - a row inserted, a card grown - and its children animate to their
  new places, under the layout's own motion or else the application's. A child
  that joins fades in.
- No patch: the room itself is moving - a window resized, a sidebar dragged -
  and every child follows exactly, because a child that glides after the
  user's own hand is late on every frame. A layout whose own width changed is
  this case even with a patch: its width is its parent's to say.
- The first arrangement arrives: the first thing anyone sees is the thing itself.

A size a child states for itself arrives while its place animates: a stated
size is either still or already animating on its own. Where a frame under the
layout is read, every child arrives, because each step of an animation would
hand the reader of that frame a room nobody chose. The same place asked for
again keeps its running animation, and a new place bends a running one from
where it has reached, at its speed. A layout's children hold no strong
reference: a view the tree dropped is not kept alive for its place.
