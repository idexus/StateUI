# Transitions

A `Transition` says how a view comes as the tree gains it, and goes as the
tree drops it. It is a value
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
how it stands. An entry runs from the effect to the view as it stands, an
exit from the view as it is drawn to the effect. It is made of steps,
combined in the order written:

```text
  .identity              the view as it stands
  .opacity               faded out wholly
  .translation(x:y:)     moved from its place, in points
  .scale(_:)             drawn so many times as large about its middle
  .outside(_:)           wholly out of the room that holds it, one way
```

The order matters between a move and a scale, as it does in any drawing: a
move written after a scale is the move as written, and a scale written
after a move scales the move with the view. The core folds the steps into
what a host draws (`TransitionEffect.host`, a `HostTransitionEffect`):

```text
  opacity       what the view's opacity is multiplied by: 0 where a step fades it, else 1
  translation   each move added as written; each scale multiplies the moves before it
  scale         the factors multiplied
  outside       the last way out written; none where no step says one
```

The way out is no number of the effect's own: how far takes a view wholly
out depends on where it stands and how large its room is, which only the
layout that placed it knows. The host layer works the move out as the view
enters or leaves (`HostTransitionEffect.move(of:in:)`): to the left and up
by the view's far edge, to the right and down by what is left of the room.

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
crosses in the patch as eleven numbers - the entry's fold, the exit's, and
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
layouts drop what they are not handed; a host says in its realization that
it draws no exit, and the matrix shows it.

A view that comes back under the same `.id(_:)` while it is still leaving
goes on from how the leaving one is drawn
([the same view coming back](../host/tree.md#the-same-view-coming-back)):
its entry's effect is not played over a view still on the page.

Hiding a view with `isVisible(_:)` keeps the view and its state, and is no
leaving: it crosses by the rule of
[showing and hiding](../host/motion.md#showing-and-hiding), whatever
transition the view declares.

The trap is a transition read as the view's state. It is the last one a
patch said: nothing follows it, and writing another to a standing view
starts no motion.

## A shared transition

Two views may be one thing to the user - a thumbnail and its picture. A
transition of each says how each comes and goes; a shared transition says
that as one goes and the other comes, in the same change, what the user sees
is one view growing from where the first was.

```text
  .transitionScope(id)     on a layout: the views in it are matched in it          LayoutContract.transitionScope
  .sharedTransition(id)    on a view: the one of this id in its scope is its partner   ViewContract.sharedTransition
```

The views stay two views. Nothing of the leaving one's state is the entering
one's, and the key is no `.id(_:)`: it ties what is drawn, not who a view is.

A scope is a layout - the type refuses the modifier anywhere else - as it is
what holds the views that come and go: a scope written on a view that holds
none would promise nothing. A view's scope is the nearest layout above it
that says one; a view under none is tied to nothing.

Both identities are any `Hashable`, and a host compares none of them. The
modifier asks the core for the number an identity crosses as
(`SharedIdentities`): the same number while an element wears it - so the view
a walk drops and the view the same walk makes, written with equal
identities, cross under one number - and forgotten once a walk ends with
nobody wearing it, so an identity written again later gets another. No
number is given twice.

```text
  a view is made or said    the differ notes it wears the number
  a view is forgotten       it wears it no more
  a walk ends               the numbers nobody wears are let go
```

What a host does with the two numbers is
[the host layer's](../host/motion.md#a-shared-transition): where one view
dropped and one view made meet under a key, the made one enters from where
the dropped one was drawn; anywhere else each goes by its own transition.

The trap is a key read as an identity. Two views of one `.id(_:)` are one
element continued; two views of one shared key are two elements, each with
its own life, tied for the length of one entry.

