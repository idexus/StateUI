# Motion in the runtime

How a runtime animates: one animator advances every animation, one channel per
bound state feeds every control tied to it, and the animations a patch
describes are keyed by element and property. The timing laws are the core's,
`HostMotionLaw`; [the runtime](runtime.md) draws where these elements sit in a
frame.

## One animator

A value is animated by `Animator` alone. Every running animation is an
`Animation`: where each lane began, where it is going, its starting speed, its
timing and when it began. An animation is pure: its position is
`HostMotionLaw` at the time handed in, so a hand-wound clock reproduces every
frame. One advance moves every animation in `AnimationTarget` order - states
by number, then described properties by element and property, then layout
places by element - so two runs of the same frame write in the same order. An
animation that arrives leaves the animator, and where the user asks for less
motion every animation arrives at once, at its destination.

## State channels

A host-carried `@State` has one channel, whatever number of controls are bound
to it. No control keeps its own copy of the animated value, so every bound
control stands at the same value and turns toward a new destination with the
same speed on the same frame. A control that joins mid-animation joins at the
value where the channel stands.

The channel is not a control's to end. It counts the controls wearing it; when
the last one lets go it goes too, but only once its animation has landed where
it was sent, so a control described again a moment later joins it where it
is. When the user takes the value on a control that reports it, the
animation stops where the user holds it and its waiter hears that it was cut
short.

## A channel lane by lane

A channel travels in runs: the lanes one change sent on together, each run an
animation of its own in the animator (`AnimationTarget.state(_:run:)`) with
the waiter that change brought. A change names its lanes by their dirty bits,
so a write of some lanes - a new destination, a value written, a speed -
takes those lanes out of the runs they travel in, where they stand, and
leaves the rest of each run going on its own clock: a phase of two axes
turned by the hand while the program moves its zoom keeps both journeys
whole. A run cut short answers its waiter false once and travels on with the
lanes it keeps, its animation narrowed to them; the laws work lane by lane,
so narrowing changes no frame. A stop and a user's take end every run. A
write of every lane is one run, as a whole value's write is, and the channel
says itself once a frame however many runs moved.

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

## What travels

A host moves frame by frame only what its views present and whose values
travel: `TransitionSurface` names them, element type by element type - a
view's opacity, background, size and transform; a rectangle's corners; a
label's size and colour of type; a layout's padding and spacing;
a shape's fill and stroke; a window's place. A host's element answers
`animates(_:)` from it, and the host layer then walks the value and hands
it each frame's. Every other pair arrives at once, rather than
keeping a motion alive that nothing shows: a host that answers no pair
animates nothing, however the tree asks.

What a moved value asks of the elements around it is the host layer's too
([one frame](runtime.md#one-frame)): a window's frame and the bar colours
its visible path declares are the window's chrome, which the host composes
again on the frames that move them (`WindowChrome.follows`).

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

`TravellingPlaces` decides it once for every child as an arrangement begins;
a width that moved by more than half a point is a new width.

A size a child states for itself arrives while its place animates: a stated
size is either still or already animating on its own. Where a frame under the
layout is read, every child arrives, because each frame of an animation would
hand the reader of that frame a room nobody chose. The same place asked for
again keeps its running animation, and a new place bends a running one from
where it has reached, at its speed. Layout motion holds each child's view
weakly: a view the tree dropped is not kept alive for its place.

## A sidebar sliding

A host whose toolkit moves a split view's pane by itself - the detail beside it
laid out once at its end width - slides the sidebar on the runtime's frames
instead (`SidebarSlide`): how far it has come, 0 hidden and 1 shown, over
320 milliseconds - the Web's columns' time - slowing as it arrives either
way, the pane that wide each frame and the detail
taking every width between, as a sidebar beside its detail slides where the
toolkit lays out as it goes. The sidebar's page stands at its whole width, its
trailing edge at the pane's. A slide turned back bends from where it stands,
and with less motion it arrives at once. One frame moves a slide at most 50
milliseconds' way: a frame coming later - the first ones of a page measured
at new widths - slows the slide rather than skipping it. A split not placed
yet stands at once: a window opens with its sidebar where it is.

Where the toolkit slides the sidebar itself but gives the detail its end
width at once, the slide follows the toolkit's own motion and keeps its
time - never slowed, as the toolkit's sidebar is not - and the detail's
page stands as far from its edge as the sidebar has come. One split's slide
is a `SplitSlide`: the width its column last stood at, where it is going,
and three steps a host fills in with its toolkit's calls - as it begins, at
each frame the pane's width and the page's, and where it rests. A toggle
asked while it slides turns it back from where it is going, not from where
the toolkit last stood. A split leaving the tree takes its slide with it:
the tree tells the runtime the element left, and the slide stops where it
stands, telling nothing more, whatever host showed it.

## Words at their destination

A child whose place travels is told where it is bound as it sets out
(`PlacedView.travels(to:)`), and that it is bound nowhere once it lands or
arrives. A view that lays out words lays them out at the size it is bound
for, its place travelling around them: at the widths the place passes
through, words that fit the destination on one line would break onto two
for as long as the place travels. Every other view stands at each size it
passes through.

## Showing and hiding

An element's showing moves by one rule on every host (`MountedElement`'s
`fadeIn`, `crossVisibility`); the host hands it the view (`FadingView`) and
what closes the layout over it. A child that joins a standing layout fades
in from nothing under the layout's motion, where its view presents opacity
and no state owns it; an opacity already on its way keeps its motion. A
change of visibility on an element already shown crosses under the
element's own motion or the application's: hidden, it fades out - standing
shown the while (`standsShown`) - and only as the fade ends, landed or cut
short, does it hide and its layout close over it; shown again mid-fade, it
comes back from the opacity it stands at; shown from nothing, it fades in.
Where nothing moves - no motion, or the user asked for less - nothing
crosses, and the view simply shows or hides.
