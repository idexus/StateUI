# What a member says about itself

Beside its name, its layer and its value's type, a property says three
things the differ acts on: whether a change animates (`travels`), whether a
value an element stops writing is put back to the control's default
(`cleared`), and which group of a view's values it belongs to (`moves`).
They are arguments of `ElementProperty`, written in the contract files, and
each defaults to the common case.

```text
  static let maximumLines = ElementProperty<Self, Int>("maximumLines", layer: .native, travels: false)
  static let region       = ElementProperty<Self, MapRegion>("region", layer: .provider, travels: false, cleared: false)
  static let fontSize     = ElementProperty<Self, Double>("fontSize", layer: .native, moves: .text)
```

## Travels

A change to a property animates to its new value unless its member says
`travels: false`, which the library says where there is no half way. A
host still snaps a transition it cannot interpolate; this keeps the ones
StateUI knows are meaningless out of the patch.

```text
  a place or a count       gridRow, gridColumn and their spans, tapCount, panTouchCount,
                           selectedIndex, currentPage, position, count, maximumVisible,
                           cursorPosition, selectionLength, maximumLength, maximumLines, zIndex
  a range or a region      a slider's and a stepper's minimum and maximum, a stepper's step,
                           a map's region, a pin's location
  a placement              absoluteLayoutBounds, absoluteLayoutProportions: the layout's own
                           motion carries a child from one place to the next
  a state's number         panXChannel, panYChannel, scrollOffset
  a list drawn whole       a polygon's or a polyline's points, a stroke's dash pattern
  a gesture's threshold    swipeThreshold
  where the host puts it   a toolbar item's placement and priority
```

`testAPlaceOrACountNeverTravels` holds that the differ honours every member
that says so; which members say it is the contracts' own word. A property
that should animate never says it.

## Cleared

A value an element stops writing is named to the host, which puts that one
property back to the control's default, so a modifier that stops being
written costs that property alone. Where no default answers for a value,
its member says `cleared: false`, and losing it builds the whole element
again instead:

```text
  a gesture's settings           allowDrop, canDrag, dragText, tapCount, panTouchCount,
                                 swipeDirection, swipeThreshold: they belong to the recognizer
  a list's items                 a picker's options, which are data
  where the host puts an item    a toolbar item's placement and priority, a swipe's side
  a choice                       selectedIndex, currentPage: clearing would move it
  what keeps a platform window   windowType, windowValue, floatsOnTop, hidesWhenInactive
  where a map opens              region
```

Every host agrees with the members that say so, or the difference is found
only on a screen.

## Moves

`moves` names the group of values a property is in, for `.motion(_:_:)`,
where its value alone cannot say: a size, a place, a transform, spacing or
text. A colour says its own group through its value, so no colour member
names one. A width or a height that a measured layout works out arrives at
once rather than animating: carried through a motion, it would lay the page
out at sizes nobody chose.

## One name one set of facts

The differ and the hosts hold a property as a token, which is a name, and
read what it says by that name: `Prop.facts` looks it up in
`LibraryContracts.facts`, where the first member met under a name answers
for every member of it. So every member of one name says the same of its
layer, travel, clearing and motion; two that disagreed would each be half
wrong. `LibraryContractTests` holds every member of one name to one set of
facts. A name no library contract declares, an application's own, travels,
is cleared, and says nothing of motion.
