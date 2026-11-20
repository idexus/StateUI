# Transitions

A `Transition` says how a view comes as the tree gains it. It is a value
written with the view - `.transition(_:)`, on any view
(`ViewContract.transition`) - and read by the host layer where the view is
given its first place: making one moves nothing and starts no clock.

```text
  Transition ── enter   the effect the view comes from     TransitionEffect
                exit    the effect the view goes to        TransitionEffect
                initialAppearance   whether it enters as it appears with what holds it too
```

What a host does with one is [the host layer's](../host/motion.md#a-view-that-enters).

## An effect

A `TransitionEffect` says how a view is drawn while it is absent, against
how it stands. An entry runs from the effect to the view as it stands. It is
made of steps, combined in the order written:

```text
  .identity              the view as it stands
  .opacity               faded out wholly
  .translation(x:y:)     moved from its place, in points
  .scale(_:)             drawn so many times as large about its middle
```

The order matters between a move and a scale, as it does in any drawing: a
move written after a scale is the move as written, and a scale written
after a move scales the move with the view. The core folds the steps into
what a host draws (`TransitionEffect.host`, a `HostTransitionEffect`):

```text
  opacity       what the view's opacity is multiplied by: 0 where a step fades it, else 1
  translation   each move added as written; each scale multiplies the moves before it
  scale         the factors multiplied
```

So a host is handed three things it already draws by, and no list of steps:
the fold is the core's, once, and two hosts cannot order it differently.

A step given what is no number - a move that is not finite, a scale below
nought - is refused and said, and stands as no step.

The trap is an effect that names a host's own animation - a slide, a
curl. An effect is numbers every host draws by; how they move is the
view's motion, which is not the effect's to say.

## A transition

A transition holds two effects, as an entry and an exit need not mirror
each other; `symmetric(_:)` is the one effect both ways. It is a property
of the view (`ViewContract.transition`, of the layer StateUI composes): it
crosses in the patch as nine numbers - the entry's fold, the exit's, and
whether it enters as it first appears - and the host layer reads it back
from the element (`MountedElement.transition`).

The transition moves under the view's own motion - `.motion(_:)` - else the
application's; it says no law of its own, so a view has one motion, whatever
moves it.

A view enters as it joins what already stands. One that appears with what
holds it - a page shown, a window opened - is simply there, unless its
transition says `initialAppearance(true)`. A transition given to a view
already standing moves nothing: it is how the view comes, not something
that happens to it.

A view the tree drops goes by its exit where what holds it keeps a view
that left ([a view kept as it leaves](../host/tree.md#a-view-kept-as-it-leaves)):
it is the application's no more at once, and drawn until the exit lands.
Where nothing keeps it, it is released at once - as on every host whose
layouts drop what they are not handed.

Hiding a view with `isVisible(_:)` keeps the view and its state, and is no
leaving: it crosses by the rule of
[showing and hiding](../host/motion.md#showing-and-hiding), whatever
transition the view declares.

The trap is a transition read as the view's state. It is the last one a
patch said: nothing follows it, and writing another to a standing view
starts no motion.
