# Gestures

A gesture reaches a handler already typed: a swipe as a direction, a pan as
a `PanUpdate`, a pinch as a `PinchUpdate`, a pointer as a `Point`. Every host
maps its native input onto this vocabulary before reporting it.

## One typed value per part

A gesture's payload carries one typed value per part of its contract, and
nothing is formatted or parsed: a number crosses as its own bits, and a
member of a closed vocabulary as StateUI's number for it.

```text
  swiped          the direction, as the one number its bits are
  panUpdated      phase, totalX, totalY
  pinchUpdated    phase, scale, then the origin as one pair
  pointerMoved    the position as one pair, or nothing where the platform does not say
```

## Phases

`GesturePhase` numbers its cases by StateUI's declaration order, so a
platform release cannot reinterpret a stored or transported report. A
platform that reports no distinct beginning starts a gesture at `.running`,
so a handler reads the values each report carries rather than relying on
catching `.started`.

## Swipe directions

`SwipeDirection` is a flag set, one bit per direction: a view listens for a
set of directions, and a swipe reports one. Every host reports the one
dominant direction bit, so a report carrying several bits, or none, is no
answer to "which way did it go?" and is not read as a swipe.

## Points

A `Point`'s units belong to the property that reads it: device units for a
pointer's position or a polygon's corner, fractions of the view for a
gradient's start and end or a pinch's origin. A list of points crosses as one
flat run of numbers, x then y for each point, so a long outline is neither
formatted nor parsed.

## A pan is measured from its start

A pan's totals are measured from where the pan began, on every platform,
which is what makes moving a view a matter of assigning them to its
translation. Android measures a pan against a frame that moves with the
view, so a handler answering by translating the view would feed its own
answer back into the next report; the host takes that movement back out
before reporting.

## A pinch is relative

A pinch's scale is how much the fingers moved since the last report, not
since the pinch began, so a handler multiplies what it holds rather than
assigning. The origin is where the pinch is centred, as a fraction of the
view.
