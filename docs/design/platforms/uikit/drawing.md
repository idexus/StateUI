# Drawing on UIKit

How the UIKit host draws what the tree describes: a view over its place, a
layout's box, a colour box, and a child a ZStack's run places.

## Drawn over its place

A view is placed by its bounds and its centre, which hold under any
transform, never by its frame. How it is drawn over its place is one matrix
on its layer: the element's own move, turn and scale, then a placing
layout's (`UIKitViewDrawing`), both as the host layer computes them about the
view's top left, carried to the layer's middle, about which a layer turns;
its opacity is its own times the one it is placed with.

## A layout's box

A layout paints its own box behind its children: the fill - a colour, or a
linear or radial gradient over the box in fractions of its size - inside the
outline, then the outline's stroke inside its edge, so the stroke never
spills over the place the layout was given. Each is a layer of its own, made
only while there is something to paint and kept behind the children by its
depth, whatever order the children's layers stand in. The outline is a
rectangle, a rectangle with rounded corners, or an ellipse; a stroke is drawn
in one colour, a gradient's first stop.

A layout that clips cuts what it holds to its outline - its bounds for a
rectangle, a mask for any other - and a touch outside the cut reaches none of
it. A layout that lets a touch through lets one beside every child reach what
stands under it.

A colour box is a view of one colour, its corners rounded each by its own
radius as a quarter of an ellipse; it takes the room its layout gives it and
asks for none.

## A placed child

A ZStack whose places a state drives stands each child where the run says, and
draws it as the run says - moved, turned, tipped in depth and scaled, and as
opaque as the run makes it - over the child's own transform and opacity. The
run's order is the drawing order: the ZStack holds its children back to front
in that order, and the one drawn in front takes the touch. A placed grid's
second child is its shade, drawn as opaque as the run says.
