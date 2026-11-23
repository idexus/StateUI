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
  .outside(_:)           wholly out of sight, one way
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

## A shared presentation

Two views may be one thing to the user - a thumbnail and its picture. A
transition of each says how each comes and goes; a shared presentation says
that as one goes and the other comes, in the same change, what the user sees
is one view, the one coming setting out from where the other is drawn. Their
presentation is shared by the transition id written on each:

```text
  .transition(id: value)                 on a view: what its presentation is shared by on its page
  .transition(id: value, scope: where)   the same, met only by the views naming the scope
                                         both write ViewContract.sharedPresentation, a number
```

A transition id is what a view is drawn as, not who it is: `.id(_:)` keeps
an element the same element among its siblings and brings back a view still
leaving ([above](#a-transition)), and shares nothing. So the identities a
loop gives and the ids written to keep a control in a list never meet, and a
view takes part in a shared presentation only where its author says so. The
views stay two views - nothing of the leaving one's state is the coming one's -
and their kinds may differ: what is shared is where the view is drawn, its
size and its corner.

The page is where views of one transition id meet: a page that comes over
another is the navigation's to bring, and two views of one id on two pages are
each their own. A scope says where they meet within it: only the views naming
the same scope, so the parts of a component - its title, its picture - written
once meet the parts of the same card, and a page holding several numbered
examples keeps them apart. A scope is any `Hashable`, a card's own id or a
word.

One view goes and one comes: a transition id that stands on more than one view
of the page as the change runs - two leaving, two coming, or one staying beside
the two - makes nothing one. Which of two would the one coming set out from?
Each coming view enters by its own transition, a change waiting on it hears
`.unsupported`, and the library says once which id it was
(`Complaints.sayRepeatedTransitionID`, [complaints](../core/diagnostics.md#complaints)).

An id and a scope are any `Hashable`, and a host compares none. The modifier
asks the core for the number the pair crosses as (`SharedIdentities`, a
`SharedKey`): the same number while an element wears it - so the view a walk
drops and the view the same walk makes, of equal ids in equal scopes, cross
under one number - and forgotten once a walk ends with nobody wearing it, so a
pair written again later gets another. No number is given twice.

```text
  a view is made or said    the differ notes it wears the number
  a view is forgotten       it wears it no more
  a walk ends               the numbers nobody wears are let go
```

What a host does with the numbers is
[the host layer's](../host/motion.md#a-shared-presentation): where one view
dropped and one view made meet under a number on one page, the made one takes
over from the dropped one, and the dropped one, kept where its holder keeps a
view that leaves, goes along onto where the made one lands, the two drawn as
one; anywhere else each goes by its own transition. One change carries as many
ids as it holds - a row of tiles becoming a grid, each tile its own id, each
going its own way. What travels is the view wearing the id, with what it
holds: what else left with it - a caption under a picture - stands where it is
drawn and fades out there, so a view meant to travel whole wears the id itself.

The trap is one `.id()` among the same siblings. A thumbnail and its picture
written in one stack, of one kind, under one `.id()` are one element continued:
its size changes and its layout moves it, and nothing is shared, whatever
transition id they wear. Without it, or in two holders, or of two kinds, they
are two views, drawn as one.

