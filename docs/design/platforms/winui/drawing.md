# Drawing on WinUI

How the WinUI host paints what StateUI draws of its own: a layout's box and
the brushes it is painted with, and a child a placing layout stands and draws
([layout](layout.md)).

## A box and its brush

A layout's box - its background, outline, shape and cut - is a WinUI shape
behind its children: a `Rectangle`, its corners rounded by one radius, or an
`Ellipse`, filled with the background and outlined by the stroke. The host
holds the shape as a view of its own, the first child of the layout's panel;
the panel measures it in every pass, so no pass is left unsettled, and places
it over the layout's whole size in each arrangement. A box that paints nothing
is let go of, and one whose outline turns from a rectangle into an ellipse is
made again, the two being different elements.

A brush crosses as its parts ([brushes](../../types/brushes.md)) and becomes
WinUI's own: a `SolidColorBrush`, or a `LinearGradientBrush` or
`RadialGradientBrush` whose points are fractions of the painted box, as
StateUI's are.

The cut is a clip on the panel's composition visual, a rounded rectangle or an
ellipse of the layout's size, written in the arrangement that gives the size
and only where it differs from the last. `UIElement.Clip` takes only a plain
rectangle, and a panel's own corner radius cuts none of its children.

A ColorBox is a `Border` of one colour, its four corners rounded each as the
element says; a `Rectangle` rounds all four alike.

## A placed child

A ZStack whose places a state drives stands each child where the run says, and
draws it as the run says - moved, turned, scaled about its centre, and as
opaque as the run makes it - over the child's own transform and opacity. The
run's order is the drawing order: `Canvas.ZIndex`, which every panel honours,
ranks the children without moving them in the panel, so nothing is laid out
again and a click reaches the one drawn in front. A placed grid's second child
is its shade, drawn as opaque as the run says.

A test reads what is drawn: the relay renders the element through
`RenderTargetBitmap` and samples it at the root's rasterization scale. The
bitmap holds only what is drawn, from the first thing drawn, so a panel with
no background is painted clear while it is rendered, and the bitmap then
begins at its corner.

## The shapes

Each of the six shapes is one WinUI `Path` in a figure of the relay's (see
[what assistive technology meets](controls.md#what-assistive-technology-meets)),
whose geometry the host hands over for the room its layout gives it, again
whenever that room changes. A
rectangle and an ellipse fill the room, drawn half their outline in from its
edges so the outline stays inside, as WinUI's own `Rectangle` does, then
moved by their transform; a rectangle's corners are its own arcs, each
corner its radius. A line, a
path, a polygon and a polyline draw a geometry of their own - a path's data
read by the core's parser, its arcs as curves - placed in the room by their
aspect: fitted, covering, stretched or at their own size, centred, then
moved by their transform, as every host places them
([a shape's own geometry](../../host/layout.md#a-shapes-own-geometry)). WinUI
measures the geometry's bounds, once for each geometry, and the host hands
the relay the place the arithmetic gives for the room; a geometry left where
it stands takes no transform, since WinUI draws nothing of one given the
identity. A shape has
no size of its own and asks its layout for none: it is drawn in the place its
layout gives it. WinUI cuts an element to the place it is put in where it
measured larger, so a figure a lean or a cap takes past its room would be
cut there: the figure measures its `Path` with no bound, which tells how far
it reaches, and puts it in a place from the room's corner as far as that -
the frame StateUI reports stays the room. Dashes, gaps and their offset are outline widths in WinUI
as in StateUI; a mitred corner's limit WinUI measures against half the
outline's width and StateUI against the whole, so it is doubled.


## A canvas

A Canvas replays its drawing with Direct2D, the drawing API WinUI itself
draws with. The canvas is a panel of the relay's with no size of its own,
painted with a `SurfaceImageSource` that Direct2D draws into: the drawing
crosses in one call as StateUI's three lists
([three lists for a relay](../../types/drawing.md#three-lists-for-a-relay)),
the relay keeps it, and on the next display frame replays it on a surface of
the canvas's size in pixels at the window's rasterization scale, cleared
first, so everything is cut at the canvas's edge. The canvas draws again when
it is given another drawing, another size or another scale, and when WinUI's
surfaces lose what they held; a device Windows takes away is made again, and
the drawing with it. One Direct2D device, and one DirectWrite factory, serve
every canvas.

The canvas hears its loading, which asks for a drawing, and never its
unloading. WinUI tells an element taken out and put back before it loaded -
a tabbed view holding its page again as the window takes its tabs - that it
unloaded after it has loaded again, and a canvas stopping there would lose
the drawing waiting for the next frame and stand empty until something else
asked for one. What the canvas listens to beyond
itself - its root's scale, the surfaces' loss - it hears for as long as it
lives, through references that do not hold it.

The replay keeps the colours, the widths, the text size, the opacity and the
transform as the instructions set them, a saved set on a stack. A wedge and
an arc of an oval are Direct2D arcs of a quarter turn at most; a path is the
core's curves, filled by the nonzero rule. Text is DirectWrite's, in the
system's family - Segoe UI Variable where Windows has it - at 14 until the
drawing says otherwise, wrapped in its box, set in it by the two alignments,
and cut at its edges by a layer, which cuts a turned box exactly where a clip
takes its bounds.

A press on the canvas is its own: the pointer's primary button, a finger or a
pen tip going down holds the pointer, and the relay tells where it went down,
each move while it is held, and where it was lifted - or where it last was
when the pointer is taken away - in DIPs of the canvas. The canvas's
background is never empty, so the whole canvas is hit, drawn on or not.
