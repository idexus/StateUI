# Motion in the runtime

How a runtime animates: one animator advances every animation, one channel per
bound state feeds every control tied to it, and the animations a patch
describes are keyed by element and property. The timing laws are the core's,
`HostMotionLaw`; [the runtime](runtime.md) draws where these elements sit in a
frame. Of a moving value's three owners
([architecture](../architecture.md#a-moving-value-has-three-owners)) this is
the second: where a value stands on a frame, its speed and its runs are owned
here and nowhere else.

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

The channel is its consumers' together: every control showing the state, and
every element following its journey with no property (`HostPatch.followed`).
A state with no consumer has no channel - a value read for it is the state's
own. When the last consumer lets go the channel goes at once, its runs with
it, and says nothing: the core counted the same consumers and answers whoever
awaited a movement `.detached`. The count is settled as a message is applied
whole (`StateChannels.settle`, at the outermost `MountedTree.apply`), so a
consumer that leaves one element for another in one message keeps the channel
where it stands.

A run's waiter is answered once, with how the run ended
(`HostMotionOutcome`): it traveled there; it was put there at once - there
already, under a motion that does not animate, with less motion asked for; a
newer destination, a written value or the user's hand took its lanes; a stop
ended it. When the user takes the value on a control that reports it, the
animation stops where the user holds it and its waiter hears `.superseded`.
Every report the channel makes says who moved it: the user's take, the
program's stop, the animation otherwise.

## A channel lane by lane

A channel travels in runs: the lanes one change sent on together, each run an
animation of its own in the animator (`AnimationTarget.state(_:run:)`) with
the waiter that change brought. A change names its lanes by their dirty bits,
so a write of some lanes - a new destination, a value written, a speed -
takes those lanes out of the runs they travel in, where they stand, and
leaves the rest of each run going on its own clock: a phase of two axes
turned by the hand while the program moves its zoom keeps both journeys
whole. A run cut short answers its waiter once and travels on with the
lanes it keeps, its animation narrowed to them; the laws work lane by lane,
so narrowing changes no frame. A stop and a user's take end every run. A
write of every lane is one run, as a whole value's write is, and the channel
says itself once a frame however many runs moved.

## A lane a hand holds

A hand over a value holds a lane of its state's channel
(`StateChannel.hold`, [the hand over a value](interaction.md)): the lane
leaves the run it traveled in - which goes on with the lanes it keeps - and
stands where the hand holds it, with no speed, bound for where it would rest.
The channel says it as the user's: a frame where only the value moved, the
whole position where the destination did, so the state is written a snap
at a time and never a frame at a time. Let go (`release`), the lanes set
out from where the hand left them, each at its speed, as one run under the
law the release gives, said as the user's too; a lane let go with no hold
before it - a wheel's notch - leaves its run there.

A write of the program naming a held lane asks whoever holds it to let go
first (`StateChannels.interrupts`), and then lands as on any lane, traveling
from under the hand. A lane whose hand waits is kept instead: the channel
holds where the program sent it (`deferred`) with that write's waiter, shows
it as the destination, and sends the lane there under the state's own law
once the hand lets go. A stop ends the runs of the lanes no hand holds.

## Described motion

A patch can describe how a property of an element moves to its new value.
`HostPatch.properties` stays the committed value; `DescribedMotion` owns only
the value drawn on the current frame, keyed by element and property. A new
animation of a property starts from where the running one stands, with its
speed.

A value moves as numeric lanes and only within one shape: a number, a list of
numbers of one length, a color, or a structure whose kind and parts stay the
same - a gradient moves its geometry, stops and colors, never its kind or
stop count. A brush property moves only between two colors or two well-formed
brushes of one shape; anything else snaps. A themed value never moves.

## A change and what it started

A render may carry presentation changes
([the core's half](../core/journeys.md#a-change-and-what-it-started)). The
host layer keeps one group for each (`PresentationChanges`, the tree's
`changes`), and no host adds to it:

```text
  before the patch    each change finds its view by its place, as it stands now
                      none, or one that left: both waiters answered `.notPresented`
                      else a group opens on that view's mount
                      and takes the runs born since the render before, of the states its writes
                      sent that are shown under the view
  the patch applied   a property set moving on that mount or under it joins every open group
                      each element under it the patch says something of is remembered
  after the patch     `applied` is answered; a group whose patch reached nothing settles at once
  the layout pass     a place that sets out, or the entry of a view given its first place, joins
                      the groups whose patch reached that element or the one holding it
  a frame ends        what arranged since the last is remembered no more
                      the second frame after the patch, nothing is
  a member ends       at rest: nothing said of it
                      another destination for the same property, place or state: `.superseded`
                      a state stopped where it stood: `.stopped`
                      its element released: `.detached` - or, released as its exit ended, as that
                      exit did: the same view come back `.superseded`, the budget `.limited`
  a view is dropped   declaring an exit nothing draws there: `.unsupported`, or `.limited` where the
                      budget takes none in - said to the open groups, born and ended in one step
  the last one ends   `settled` is answered: `.settled`, or `.interrupted` with the reasons gathered
```

A member is a described motion - a property the patch moved under the
view's motion, an entry's numbers and a kept exit's among them - or a place
on its way (`LayoutMotion`), a run of a state's channel, or the rest of a
layout whose program that state runs. Each tells its birth and its end
(`born`, `ended`), which is all a group hears. A kept exit's numbers are born as the
patch drops the view, so the view that left is waited for until its exit
lands ([a view kept as it leaves](tree.md#a-view-kept-as-it-leaves)); how
the exit ended is said before the element is released (`exitEnds`), so its
numbers end as it did and not as a view that merely left.

A place sets out in the toolkit's layout pass, after the patch is applied
and the group has answered `applied`. So a group keeps a layout window: the
elements its patch reached, each until the layout placing it has arranged.
What is born in a layout pass joins by that - the cause, not the time - so
an arrangement belongs to the patches that waited for it: a later patch's
pass moves nothing of an earlier change, and two patches one pass placed
both have its movements. The window is over once nothing is left to
arrange, or with the second display frame after the patch: a toolkit that
lays out after its frame's callback has done so by then
(`PresentationChanges.layoutWindow`). A group settles only once its window
is over, and holds the frame clock until then.

A state's write reaches its channel in the core's cycle, and a turn runs
the cycle before it renders: the run is born before the render that carries
the change. So the channels tell every run's birth and end
(`StateChannels.watching`), a group opening takes the runs of its states
born since the render before, and one born later - a channel the render
itself attached - is taken within the group's window. A state shown by no
view under the aimed one is no part of the change, whoever wrote it.

A state that runs a layout's program moves more than itself: the views the
program places may travel on after the state arrived
([bodies](layout.md#bodies)). So a group that takes a run of such a state
takes the rest of every such layout under its view too, and that member
ends as the layout comes to rest ([at rest](layout.md#at-rest)) - or with
the run, where the run did not arrive. The layout's own `settled` event is
told by the same rest and by nothing of a change: it is the layout's, heard
whether or not anybody made a change, and once however many did.

What is born as a later patch is applied joins that patch's groups alone:
the movement a later write starts in place of a member is that write's own,
so new animations never prolong an old wait. A movement running since
before a change opened is no member of it.

The trap is finding the view after the patch. A change may remove the very
view it aims at; the group holds its mount from before.

## What travels

A host moves frame by frame only what its views present and whose values
travel: `TransitionSurface` names them, element type by element type - a
view's opacity, background, size and transform; a rectangle's corners; a
label's size and color of type; a layout's padding and spacing;
a shape's fill and stroke; a window's place. A host's element answers
`animates(_:)` from it, and the host layer then walks the value and hands
it each frame's. Every other pair arrives at once, rather than
keeping a motion alive that nothing shows: a host that answers no pair
animates nothing, however the tree asks.

What a moved value asks of the elements around it is the host layer's too
([one frame](runtime.md#one-frame)): a window's frame and the bar colors
its visible path declares are the window's chrome, which the host composes
again on the frames that move them (`WindowChrome.follows`).

## Layout motion

A layout works out where each child goes; `LayoutMotion` decides where the
child stands on the way. Why an arrangement happens decides everything:

- A patch reached the layout since its last arrangement: it holds something
  different - a row inserted, a card grown - and its children animate to their
  new places, under the layout's own motion or else the application's. A child
  that joins enters ([a view that enters](#a-view-that-enters)).
- No patch: the room itself is moving - a window resized, a sidebar dragged -
  and every child follows exactly, because a child that glides after the
  user's own hand is late on every frame. A layout whose own width changed is
  this case even with a patch: its width is its parent's to say.
- The first arrangement arrives: the first thing anyone sees is the thing itself.

`TravelingPlaces` decides it once for every child as an arrangement begins;
a width that moved by more than half a point is a new width.

A size a child states for itself arrives while its place animates: a stated
size is either still or already animating on its own. What reads a frame
under the layout changes none of this: a reader of the layout's stage hears
where a child is going, once
([two rectangles](runtime.md#two-rectangles)). The same place asked for
again keeps its running animation, and a new place bends a running one from
where it has reached, at its speed. Layout motion holds each child's view
weakly: a view the tree dropped is not kept alive for its place.

## A child that is a body

A child comes onto its place as its body says where it has one - its own
(`ViewContract.layoutBody`), else what its layout says for every child
(`LayoutContract.layoutBodies`); the element resolves it into what a layout
reads of it (`LayoutValues.body`), so every host, placing through
`TravelingPlaces`, places a body with no code of its own. Where neither
says one, the arrangement above stands.

```text
                      a patch moved its place          its place moved otherwise
  no body said        the layout's motion              arrives
  .none               arrives                          arrives
  .onChange(s)        travels on the spring s          arrives
  .followsLayout(s)   travels on the spring s          travels on the spring s
```

`LayoutMotion.arrangement(of:said:resized:among:)` is the rule.
A body's spring is the child's law whatever the layout's own motion - a
layout told to move nothing still brings a body onto its place - and the
place travels by the one animation a place has (`AnimationTarget.placed`):
a new place bends it from where it has reached, at its speed, which is all
following a moving place is. A body answering a change arrives where its
layout's own width changed, as every child does; one following its place
travels then too. Less motion arrives.

An element running a layout program resolves a child's body the same way -
its own, its layout's, and a spring answering a change where the layout
says none ([bodies](layout.md#bodies)). Such a view is a body of that
layout alone: the holder the program places gives the view the holder's
own room, and reads no body of it - a body in both would spring twice.

The trap is two movers of one place: a body's spring beside the layout's
motion would each take the child part of the way. A child has one law for
its place, chosen once as it is placed.

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

## Words on the way

A child that lays out words - a label, a button (`NodeType.wordsTypes`,
`LayoutValues.laysOutWords`) - travels its size as any child does, but never
stands narrower than its words need where it is bound: their natural size,
measured with no width offered as its place sets out, or the destination's
size where they wrap there (`LayoutMotion.room`). A button a wider cell takes
grows the whole way; a caption made bold stands at its new width from the
start, so its words never break onto a second line; words that wrap where
they are bound stand at the destination's width and height until the place
is wider. The host stands the view at the frame the host layer gives it.

A button's words stand in a box of its own (`LaidOutWords.boxed`), and the
box is what the eye follows: where its new words need more than the box has
as its place sets out, it keeps showing the words it showed before while the
box grows, and shows the new ones once the box holds them - on the way where
it is bound wider, else as it lands (`PlacedView.heldWords`). Meanwhile it is
measured at its new words' size, so a layout asked again places it where the
new words take it; new words given while some are held back show at once.
Words that shrink show at once, and a place that merely arrives forgets the
former words.

The trap is a view laying out words held at its whole destination while its
place travels: a label shows nothing of it, but a button's box is what the
eye follows, and it jumps to its end while only its corner travels.

## A layout bound for a size

A child whose place travels is told where it is bound as it sets out
(`PlacedView.travels(to:)`), and that it is bound nowhere once it lands or
arrives. A layout bound for a size lays its children out at that size, its
own box traveling around them: a label filling it would otherwise break at
the widths the layout passes through.

## A view that enters

A layout tells every child it gives a first place how the child comes
(`LayoutMotion.place`, a `LayoutEntry`), and the element decides what that
means for it, once for every host (`MountedElement.enter(_:as:)`):

```text
                    joining a layout already standing    appearing with its layout
  a transition      enters from its entry's effect       enters where it says initialAppearance
  none              fades in under the layout's law      is simply there
```

A child joins where a patch reached its layout as it stood
(`Arrangement.joins`), and is told the law that layout's children animate
under - none where they arrive. One given its first place by any other
arrangement - its layout's first, a room that moved - appears with it. A
host asks `entersMoving(presentsOpacity:)` whether the element may come
moving at all, and hands the entry on with the view (`FadingView`).

An element of no transition fades in from nothing under the layout's law,
where that animates, its view presents opacity and no state owns it; an
opacity already on its way keeps its motion. One holding a view made with it
that sets out from its partner comes as it stands
([a shared transition](#a-shared-transition)).

An element declaring a transition
([a transition](../views/transitions.md#a-transition)) comes from its
entry's effect: each number the effect touches is stood where the effect
puts it and brought onto what the element declares.

```text
  opacity        what it declares, times the effect's
  translationX   what it declares, and the effect's move across
  translationY   what it declares, and the effect's move down
  scale          what it declares, times the effect's factor
```

Each goes by the road a property's own animation takes
(`receiveProperty`), so no host draws an entry by anything it did not draw
by already. The law is the element's own motion, else the application's
(`LayoutMotion.law(of:)`) - never the layout's, which says how its children
change places. An effect out of its room moves the element as far as takes
it wholly out of sight ([out of sight](#out-of-sight)); a view no layout
placed has no room to stand out of, and moves by nothing that way. A
number a state drives is the state's, and one already on its way keeps its
way. Where nothing moves - no motion, or the user asked for
less - the element stands as declared.

A message that makes again what the tree showed - a complete one after a
drift, another root in the standing one's place - makes elements the user
already saw: the tree marks them as it makes them (`MountedTree.remakes`,
`MountedElement.isRemade`), and none enters by a transition. The first
message's are not made again: a transition saying `initialAppearance` enters
with the window's first page.

The trap is the layout's law deciding whether a child enters. A view with a
motion of its own, in an application that says none, would then never
enter; so the layout says only that the child joined, and under what law
its own children move, and the element reads its transition.

An entry is drawn where it sets out from the frame that gives the view its
first place. Each number it starts is presented at once - the opacity on the
view it enters on, the move and the scales by the element's own
`presentFrame` - in the toolkit's layout pass, not at the display's next
frame: that one comes after the toolkit has drawn this one, and the view
would stand a frame whole at its place first. A fade hid it; a move, a
scale or a shared transition, which fades nothing, did not.

## Out of sight

A view going out of its room - by `.outside(_:)` as it comes or goes, or
thrown away - goes wholly out of what shows it: the nearest view at or above
the layout that placed it that draws nothing beyond its own rectangle - that
layout where it clips its content, else a scroller or a page above
(`MountedElement.placeInWhatShowsIt`, `standingInWhatShowsIt`). A layout says
its room as it begins an arrangement (`TravelingPlaces.begin(width:height:)`),
and layout motion keeps it with the child's place (`LayoutMotion.placed`);
the layout's corner in what shows it, and that view's size, are read off the
frames the toolkit reports. Where the toolkit says no rectangle, the room is
the layout's.

The trap is a layout that draws beyond its room. A stack does not clip: a
view taken just past its edge stands in the margin around it, still seen,
and vanishes as its exit ends. So the room is the view that cuts what it
shows, and the move takes the view past that.

## A shared transition

A view made wearing a key enters from where the one view its patch dropped
wearing that key was drawn ([the declaration](../views/transitions.md#a-shared-transition)).
The host layer keeps the notes of one patch (`SharedTransitions`, the tree's
`shared`), and no host adds to it:

```text
  a patch drops a child     every view wearing a key in it or under it is noted, with the
                            rectangle it is DRAWN in - its own transform in it - in its window
  a patch makes a view      wearing a key: noted
  its first place           one view dropped and one made under the key, in that patch, one window
                            and one page, and both rectangles known:
                              it is drawn moved by the difference of their middles and scaled by
                              the ratio of their sizes, each way apart, and brought onto what it
                              declares under its own motion, else the application's
                              the dropped one, still leaving by its own exit, ends at once
                            anything else: it enters as any view does, and a change that waits
                            for the patch hears `.unsupported`
  two frames later          the notes are let go
```

A key is the scope's element and the key's number: the scope is the nearest
layout above the view that says `transitionScope`, found by walking up, so
two scopes of one identity are two scopes. One commit is one patch - a view
made by an earlier patch is no partner of one a later patch drops.

Where the made view stands is worked out from what the tree knows as its
layout places it: the place its layout gave it, and each place a layout gave
what holds it, up to its scope or to the first view no layout's motion
placed, whose corner the toolkit says - and a view a layout program places
is one: its toolkit first stands it across the layout's room, by the
layout's motion, and the program moves it from there by itself. Where that is not known yet,
nothing is guessed - and a view a layout program places, made with the
patch - a motion layout's new item, in its holder - is not known yet.

The trap is the first place of a view made with its motion layout. The
toolkit lays the new layout out before its program is asked, in the
display's next frame, and stands each holder across the whole room
meanwhile: the view's first place - where its entry is decided - is that
room, not the item's. Read from the toolkit, the view would set out toward
the room and be drawn squashed into it until the program moved its holder.
So it is no partner: it enters by its own transition, and a waiting change
hears `.unsupported` - an item joining a layout that stands too. A view made
inside an item that stands - a swap in the item - stands where its toolkit
draws the item, and travels.

The entry is the road every entry takes
([a view that enters](#a-view-that-enters)) - numbers set out from and
brought onto what the view declares - so it needs no view kept as it leaves,
and no surface of its own: a host that draws a move and two scales draws
it. A return during the movement reads where the view now leaving is drawn,
and so goes on from there.

The trap is the leaving view's place. Its layout's rectangle is where it
would stand; a view half way through its own entry is drawn elsewhere, and
the partner must set out from what the user sees.

The trap is what holds the made view. A holder the same patch makes - the
row a thumbnail comes back in - joins a layout that stands, and would fade in
from nothing under the application's law: the view setting out inside it,
whole where its partner was drawn, would be drawn at none of its opacity,
the partner already gone. So a holder of a view that sets out from its
partner comes as it stands (`SharedTransitions.holdsAPartner`); a transition
it declares is its own still. A layout places a holder before what it holds,
so the holder is decided first, by what is known before the view is placed
- the one partner, drawn, in one window and page, no place unknown on the
way to the scope - the same rule that view's own entry asks first
(`partner(of:key:patch:)`). A view refused all the same - its place found
empty - leaves its holder unfaded, never faded over a view setting out.

## Showing and hiding

An element's showing moves by one rule on every host (`MountedElement`'s
`crossVisibility`); the host hands it the view (`FadingView`) and
what closes the layout over it. A
change of visibility on an element already shown crosses under the
element's own motion or the application's: hidden, it fades out - standing
shown the while (`standsShown`), deaf to input (`ignoresInput`, which the
element presents as true and hands its view by `setIgnoresInput`) - and only
as the fade ends, landed or cut short, does it hide, hear again and its
layout close over it; shown again mid-fade, it comes back from the opacity it
stands at and hears again; shown from nothing, it fades in.
Where nothing moves - no motion, or the user asked for less - nothing
crosses, and the view simply shows or hides.

Its layout closing over it is the change hiding it at once would be, though
no patch carries it: every layout from its own up to the page travels to its
new places (`configureLayoutMotion`) and measures again
(`invalidateMeasurements`). A layout that closed alone, its own size cached
by the layouts around it, left what stands below it where it stood - a gap
that stayed until another change, and then a jump.
