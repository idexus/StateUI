# Drawing on Android

How the Android Views host paints what a view is drawn with rather than what
it holds: a shape and the brush that fills it, a border around its child, a
child an engine places, and the application's pictures.

## A shape and its brush

A Border, a ColorBox and any background that is not one plain colour are
drawn by one drawable of the host's, `StateUIShapeDrawable`: a rectangle, a
rectangle with rounded corners, or an ellipse, filled with a brush and
outlined in one colour. The Swift host tells it every part - the shape's kind
and its corners' radii in pixels, the brush's kind, its stops' colours and
offsets and its geometry - and it builds the gradient for the bounds it is
drawn at, so the geometry stays in fractions of the thing painted, as
[brushes](../../types/brushes.md#geometry-in-fractions) says. A plain colour
stays the view's own colour background; a background cleared gives back the
one the view was made with.

Radii that two corners on one side would overlap with are shrunk together,
so a radius larger than the shape never draws a shape inside out.

## A border

A Border is a layout of one child within its padding, on a shape it fills
and outlines. It cuts what it holds to that shape: the drawable gives the
view its outline, and the view clips to it, so a picture in a rounded card
has rounded corners. The outline is drawn inside the view's bounds, half its
width on either side of the shape's edge being inside, and never pushes the
child in - that is the padding's work.

## A placed child

An engine's placement run stands each child of an absolute layout at a
rectangle of its own and draws it moved, turned, scaled and faded about its
centre, over whatever the child's own properties say. Android keeps one
translation, rotation and scale per view, so the host composes the two:
rotations add, scales multiply, and the view's own translation is turned and
scaled by the placement's before the placement's is added. That is exact
while the scales are the same on both axes, which is what a placement draws.
The opacities multiply, and the view's own opacity is still what its
animations start from.

A higher rank is drawn over a lower one because the layout draws its
children in that order, back to front, which is also the order a touch
reaches them in; nothing is moved in the group, so nothing is laid out again
for it. The order is set when a run or the children change, never while
Android lays the layout out. A run that follows another stands its children
at once, without laying out anything around the layout: its places need no
room. The shade a placed layout lays over a card is the holder's
second child, drawn at the run's shade.

## Pictures

A picture crosses as a file name, and the files are the application's
`Resources/Images`. Android draws no SVG, so the build draws each SVG three
times over, in sRGB, as `<name>@3x.png`, and copies every other picture as it
is, into the APK's `images` assets; only what changed is drawn again. At run
time a name finds its drawing three times over first, then a file of its
own name, which is kept at one pixel a point.

An image is measured at its picture's own size in points, read from the
file's header alone: the size is at the display's density, and Android's own
measure would scale it a second time. The four aspects are Android's four
scale types, and an image cuts what it draws to its bounds, since a StateUI
layout does not.

A picture's pixels are read when its view is placed, at the fewest the view
needs: one pixel in two, four, up to sixteen across and down, while that
still covers the view, scaled to the display's density as it is read. A card
showing a picture three times smaller than it was drawn holds a quarter of
its pixels, in memory and on the GPU alike. A StateUI layout measures a
height it has not settled yet, so the size a view is placed at is the one
that decides; a size given whole by a parent of Android's decides as well.
The bitmap says the density a whole one would have, so Android draws it at
the picture's own size. It is read again only for more pixels, never for
fewer, so a size in motion does not read it every frame, and a picture
shown centred, at its own size, is read whole. Views showing the same
picture at the same thinning share one bitmap, and the last to leave lets it
go; only a bar's and a tab's icons are kept for as long as the host runs.

A colour box has nothing to show but its colour: it takes the room its layout
gives it and asks for none of its own.
