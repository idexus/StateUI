# Controls

A control is a node of its contract's type and the modifiers written on it.
Each control file holds the control, its own properties protocol, the events
and acts it declares, and the binding twins of its values.

## A control is a node and its modifiers

```text
  public struct Slider: View, TintElement, SliderProperties {
      public var node: Node                      Node(contract: SliderContract.self)
      init()                                     nothing set: what a Style<Slider> uses
      init(_ value: Double)                      the purpose value, one-way
      init(_ value: Binding<Double>)             the purpose value, two-way
      func value(_:) / minimum(_:) / …           properties, from SliderProperties
      func onValueChanged(_:)                    events, through onEvent(member)
  }
  extension Aim where Target == Slider { … }    acts, through call(member)
```

What gives a control its purpose - a label's text, a picker's options, a
path's outline, an image's source - goes in the initializer; everything else is
a modifier (composition.md, what goes in the initializer). A two-way control
takes its binding both ways - in the initializer and in a modifier of the same
name (bindings.md, both spellings).

## Closed vocabularies are numbered here

A closed vocabulary a control uses - `IconPosition`, `MapType`, `SwipeSide`,
`WebNavigationEvent`, `WebNavigationResult` - crosses as an `.enumeration`
whose numbers are the library's own, in declaration order, the rule of
[closed vocabularies](../types/vocabularies.md#written-out-and-appended). A
host translates its toolkit's value onto the member
that means the same. A toolkit's own numbers stay out of it: a toolkit release
free to renumber its enumeration would otherwise make every report read as a
different member, silently. A member a host has no case for arrives as
`.unknown` where the vocabulary has one.

`SwipeSide` is not `SwipeDirection`'s bits, however alike they look: the left
items are what a swipe to the right reveals, so the two vocabularies would
agree on every name and disagree on every meaning.

## A colour stroke is a solid brush

`Border.stroke(_ value: Color)` is written over the brush form, so a border's
stroke and a shape's put the same bytes on the wire for the same colour. A bare
colour written out instead would make one property arrive in two shapes and
leave the host carrying a branch to tell them apart.

## A colour box fills with its colour

A `ColorBox` carries both `color` and `background`, and draws `color`. The
background is a second surface behind the box, which the corner radius does
not round and which need not share the box's transform: a rotated box carrying
both shows the background standing still underneath. A box is given its
colour through `color`, in a style as much as on the control.

## Opening a picker

A picker's, a date picker's and a time picker's `isOpen` asks the host to show
or dismiss the list, calendar or clock face; it is a presentation request, not
another selection state. `onOpened` answers the user opening it and not an
`isOpen(true)` write: the tree opening it opens the platform's own and raises
nothing, since an application that opened it from a button of its own already
knows. The user can still close it by choosing, tapping away or pressing
Escape, which `onClosed` reports.

A date picker and a time picker take `textColor` and letter spacing through
`TextStyleElement` but have no `text`: the field shows the formatted value. The
host does the formatting, where the calendar and the user's locale are, so
month names and a 12- or 24-hour clock come out in the user's own terms. There
is no `today` to hand, since the host's clock answers a time of day with no
date beside it, so a page whose limit is the current day holds that day in
state.

## Where a map opens

Where a map opens belongs in its initializer rather than in an act from
`.onCreated`: a region given there is kept by the host and applied once the
platform's map is ready, while the act lands an instant after the native map
exists and the platform's own opening region overwrites it. Moving a map that
is already up is the act `moveToRegion`.

A pin, a map, a web page and a navigation report what happened; handlers on
them observe. A handler runs a boundary away, after the platform has already
decided: a pin's tap handler cannot keep the callout shut, and a web view's
`onNavigating` cannot cancel the navigation - a page that must not be left is a
page not navigated to.

## Web view

What a web view is told to do is an act - `goBack()`, `reload()`,
`evaluateJavaScript(_:)` - because a description has no control to call a
method on; what it reports travels the other way, into a binding
(`.canGoBack($hasBack)`). Its source crosses as its kind and then what it is
made of: an address as the kind and the address, a document as the kind, the
document and its base address or nothing - three values whether or not there
is a base address, so the host reads the same places every time and never tells
the two apart by shape. A navigation's first report on Windows carries no
reason, the source having been given before the browser existed, so
`.unknown` there is an ordinary answer rather than a fault.

## Canvas and path

A canvas drawing travels as data - its canvas calls, in order - because an
object with a draw method is the one thing the boundary cannot carry; the host
replays the calls on the platform's own canvas. A drawing reading a state is
described again when the state changes, and so redrawn.

A path's outline crosses as SVG path text, and a parser shared by the hosts
normalizes it to absolute moves, lines, curves, arcs and closes before each
toolkit draws that closed set, so the grammar accepted is not any one
platform's.

## Text runs

A `TextSpan` is one run of text inside a Label, with its own colour, size and
weight; text in two colours is two runs. It is named `TextSpan` rather than
`Span` because the standard library's `Span<Element>` is in scope in every file
without an import: an application writing `Span("…")` would get "no exact
matches in call to initializer", and a plain `[Span]` "reference to generic
type 'Span' requires arguments". The node on the wire is `Span` all the same,
the vocabulary's name for a run.

## Images

An image's source is a file among the application's resources, never an
address: a name that looks like a url is looked for among the resources like
any other and is not found. Artwork kept as an SVG is asked for by its PNG
name. A source with a half for each theme carries both halves to the differ,
which picks the one the theme asks for as it builds the view, so a theme change
builds again only the views wearing a pair. An `Image` has no padding: a
modifier that compiles into nothing is worse than no modifier. Whether an
animated picture runs is a property rather than an act, so a paused animation
is a state the tree describes and a rebuild cannot lose.

## Items that are not views

A menu, a menu entry, a separator, a toolbar item, a swipe action and a map pin
are elements but not views: each has a caption, a picture or a point and
something to run, and no layout of its own. They take none of the modifiers a
view has, belong in one place - a page's session, a menu, a swipe view's
collections, a map - and are matched by their `.id()` or their position there.
The mode and the behaviour after invoking belong to a swipe view's collection
rather than to an item, so they are parameters of the collection, as a
gesture's settings are parameters of its handler; each collection is a child
node that says which side it is, since a node cannot live inside a property.

## Radio groups

A radio button's group is a name - every button in the set writes the same one
- and the host resolves it within one window without relying on how native
views are nested. Picking one unchecks the others and reports both changes
together, which is why a handler acts on `checked` alone. One state for the
whole group, rather than one flag per button, holds what is chosen.

## Refresh view

A refresh view's spinner shows while its state is true, and nothing clears it
on its own: the pull sets it, and the handler clears it when the work is done.
That binding is written from both sides, so its two-way form is the
initializer rather than a modifier. It goes around the scroller rather than
inside one, holding a single scrollable view, because a pull is a gesture that
scroller would otherwise claim.
