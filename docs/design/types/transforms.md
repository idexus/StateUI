# Transforms

`ViewTransform` is the one transform in the library: a view wears it through
`.transform(_:)`, and a `Path`'s geometry takes the same value through
`.renderTransform(_:)`.

## One transform

A transform is a chain of parts - move, turn, size, turn away, lean - each
applied about the view's centre, after the layout has placed it, in the
order written. Each part applies to what the parts before it made, which is
why the order matters: `.rotate(45).translate(100, 0)` moves the turned view
to the right, while `.translate(100, 0).rotate(45)` swings the move round
with the turn. Each part is also offered as a starting point, so a chain
reads `.rotate(14).scale(0.9)` rather than `.identity.rotate(14).scale(0.9)`.

## The arithmetic is in the core

The parts compose as a matrix, worked out in the core rather than in a host:

```text
  x' = a·x + c·y + tx
  y' = b·x + d·y + ty
```

Each part multiplies onto the matrix of the parts written so far. The
trigonometry comes from the platform's C maths library rather than from
Foundation, which the library does not import: the C runtime is linked
everywhere already, and the maths libraries agree with each other to more
places than any screen can show. So a transform is the same picture on every
host.

## Five view properties

On a view the matrix comes to five ordinary properties about its centre:
`translationX`, `translationY`, `rotation`, `scaleX` and `scaleY`. A changed
transform therefore animates like any other value, every part of it at once.
The view's own `scale` is left alone, so a `.scale(_:)` written on the view
multiplies on top of the transform.

## The shear limit

Those five properties can say any move, any turn, and any sizing of the
turned view, but not a sizing along one axis of a view turned earlier:
`.rotate(45).scaleX(2)` slants a rectangle into a parallelogram, and no
platform has a view property that draws one. Such a chain is drawn as the
nearest thing the five can say: the turn, the move and both sizes are kept,
and the slant alone is left out. `skew` is exactly that slant, so on a view
it changes nothing. A geometry is redrawn rather than carried by view
properties, so `.renderTransform(_:)` on a `Path` draws the whole matrix,
lean included.

## Turned away drawn flat

`turn` and `tilt` turn a view away about its vertical or horizontal axis,
drawn flat: a rectangle turned by an angle is a rectangle `cos(angle)` as
wide, which is the same picture on every platform. A three-dimensional turn,
`rotationX` or `rotationY`, is projected through a camera each platform
chooses for itself, so a run of cards turned the same way does not look the
same everywhere. Past a right angle a view would show its back, which a flat
drawing cannot make, so the turn stops there. The sign of the angle is kept,
though both sides look the same drawn flat, so arithmetic either side of a
middle can be written as one line.

## Reading the five properties back

A host carries the five properties and nothing else, so a transform comes
back from them: the turn is the angle the across axis ended at, the width is
that axis's length, and the height is how far the down axis reaches from it.
A mirror survives as a negative height; a shear does not, there being no
property to give one to.

A chain that never turned is read back without the general arithmetic. The
square root and the division would hand a written 0.9 back with a last bit
of noise on it, and a value that is exactly what was written is what the
wire should carry.
