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
