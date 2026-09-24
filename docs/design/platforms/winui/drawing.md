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
