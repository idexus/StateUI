# The mounted tree

How a runtime holds the description it shows: one mounted element per
described node, each with a native half that its toolkit writes. [The
runtime](runtime.md) draws where the tree sits in a turn and a frame.

## The mounted tree

```text
  MountedTree                         the root, the numbers, the patch's clock
    |
    MountedElement  (host layer)      key, type, children,
    |   |                             described properties, bound states,
    |   |                             event handlers, layout motion,
    |   |                             drift, leaving, the frame walk
    |   |
    |   native: NativeElement  ---->  AppKitElement (toolkit half)
    |                                  NSView, constraints, gestures,
    |                                  accessibility, menus, pages
    MountedElement ...
```

`MountedTree` applies the root patch of each message and owns what every
element shares: the line to the core, the patch intake it tells of a drift,
the state channels the elements wear, and the property and layout animations.
Every element of one message takes its animations' start from one time, the
message's, so a patch that animates many properties starts them together.

A `MountedElement` is one live instance of a described node. It keeps the
node's key and type, its properties, bound states and handlers, and its
children in order. It applies a patch in one fixed order: the standing values
of what changes are read first; then the properties, events and bindings;
then the children, by key; then each changed property's animation starts, from
where it stands; and last its native half presents it all. A child a sparse
patch names but the element does not hold, or holds as another type, is a
drift: it is refused, and nothing is mounted from it.

## The native half

A toolkit writes only what the toolkit has: an element's view and what hangs
off it. `NativeElement` is that half's whole contract with the tree - it hears
that a patch is about to apply and that it applied, presents a frame's changed
properties, arranges children, reports where a property stands natively and
whether the toolkit animates it, and lets go when the element leaves. The
element owns its native half; the half refers back without owning, so it can
never outlive the element. Anything that keeps an element beyond the tree -
a window's shown page, a sheet - holds the element, never the native half.

## Standing values

An animation starts where the value stands, never where the tree last said it
was. A running animation's value comes first; then what the toolkit reads off
the control - a window's live frame, a slider's position, a view's opacity;
then the bound or described value. Where none exists but the toolkit animates
the property, the property's resting value is the start: no margin, no turn,
a scale of one, a corner radius of the target's shape.

## Leaving

An element leaves by every road out of the tree - dropped from an arrangement,
replaced, a new root - and everything under it leaves with it. It lets go of the states it wears, so a channel's
last wearer takes the channel with it once it lands; its property and layout
animations end; and its native half detaches what it attached outside the
tree: observers, recognizers, a scroller's hold on the frame clock. Nothing
keeps a control alive after the tree drops it.

## A radio group

A radio button checked by the user unchecks the others of its choice, and
each of those reports that it is off. Which they are is the tree's to say,
the same on every host: the radio buttons of its `groupName` anywhere in its
window, or, where it names no group, the radio buttons beside it under the
same parent. A native group of the platform's is not used: it holds only its
own direct children, while StateUI's may stand anywhere in a window's
layouts.

## Drawn over its place

How an element's view is drawn over the place its layout gave it is put
together once (`MountedElement.drawingTransform`): moved, turned and scaled,
`scale` multiplying both axes on top of their own, turned about its middle
where the tree names no pivot. A layout a state places - a placing run - keeps
its measure: the run moves its children without the layout measuring again.

## What every element realizes

What the host layer's own rules realize on every element - a view's place in
its layout, its drawing over that place, where it stands as the tree reads it
and what the user does to it - is declared once, as groups a host's registry
names (`everyElementTakesItsPlace`, `everyElementIsDrawnOverItsPlace`,
`everyElementMeetsAssistiveTechnology`, `everyElementHearsTheUser`): a host
realizing them through those rules says so in one line each, and the control dictionary reads the members as every
host alike.

## Views by number

A host's views are numbered as they are made and held weakly by their number
(`LiveViews`): a toolkit's callback crossing C names a view by its number, as
it cannot hold an object, and finds nothing once the view is gone; a test
counts the numbers held to see every view let go.

## A window shown

A window shows the first arrangement of pages among its children - a page, a
stack of them, tabs, a split view - the pages its modal stack presents as
sheets, what it lays over them, and whether its scene hides it ([the
application's phase](runtime.md#the-applications-phase)), and says each to
its host only when it changed (`WindowPresentation`). It says too the window
it belongs to: a window of a kind of its own is its scene's main window's,
and a main window is nobody's (`MountedElement.ownerWindow`); a toolkit that
knows owned windows stands the one above the other, hides it with it and
leaves it out of the system's list of the application's windows. The page
the user sees hears it is shown
([a page's phases](pages.md#a-pages-phases)), then the window hears, once,
that it was made - in their turn, before the host first shows the window,
and so before it hears it came to the front. The host shows them in its
toolkit's window.

## A window's frame

A window's place and size are four requests in DIPs, each alone
(`WindowFrame`): one the tree changes is said, and one it keeps or takes away
says nothing, so the window stays where the user put it or sized it. A place
is counted from the corner of the work area of the screen the window stands
on; a size that is not a finite number of at least nothing asks for none.
Its bounds (`WindowBounds`) are said the first time and where they change:
nil leaves the toolkit's own, and a greatest size below the least is the
least. The host turns each into its toolkit's units and calls.

## A window's traits

What a window is - whether the user may maximize and minimize it, whether the
desktop shows through it, and whether it floats over the application's other
windows now, which it does only while the application is in front - is said
the first time and where it changes (`WindowTraits`). A button the element
says nothing of is the toolkit's own; the rest are false until said.

## The windows a tree holds

Every host keeps the windows alike (`WindowRoster`): each window element
under the root, in the tree's order - a window holds none - with the host's
controller of it. A window the tree keeps keeps its controller, one it no
longer holds has its controller closed - the last first, so a window of a
kind of its own closes before the main window it belongs to, which a
toolkit would otherwise take down with it - and one new has one made; the first
window's coming is said, since the screen is known only once there is one.
A window is told apart by the element itself, since two scenes each name
their main window alike.

## Runs of words

A label's spans are runs of its words, put together once
(`MountedElement.textRuns`): each span's words in its own case, else the
label's, and its own look - size, weight and slant, colour, what stands
behind it, its lines - in the contract's terms (`TextLook`). A run's look
stands over its label's: where the run says nothing, the label's says it.
A host turns the finished look into its toolkit's attributes and nothing
more.

An element showing words - a label, a button, a radio button - reads the
text tiers the same way on every host (`TextMembers`): its words in their
case where the words or the case changed, and the look its font and colour
give them where one of those did. A break keeps the words on one line unless
it wraps - word and character wrapping do - and wrapped words stand on as
many lines as the tree allows, none where it allows none or fewer than one
(`LineBreak.lines`); a truncating break cuts them with an ellipsis. A toolkit
spacing letters in ems is handed the space as a share of the font's size.

## What assistive technology meets

What an element says for assistive technology is put together once, the same
on every host: its identifier, its label, its hint, its level as a heading,
and whether it is met at all - left out with everything in it where it says
so, else left out itself where it is hidden, its children still met, else met
where it says it is not hidden, and as its view is of itself where it says
nothing. A host puts those words on its view in its platform's terms, and puts
them again whenever any of them changes.

