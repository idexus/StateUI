# Drawing on UIKit

How the UIKit host draws what the tree describes: a view over its place, a
layout's box, a shape, and a child a ZStack's run places.

## Drawn over its place

A view is placed by its bounds and its center, which hold under any
transform, never by its frame. How it is drawn over its place is one matrix
on its layer: the element's own move, turn and scale, then a placing
layout's (`UIKitViewDrawing`), both as the host layer computes them about the
view's top left, carried to the layer's middle, about which a layer turns;
its opacity is its own times the one it is placed with.

## A placed opacity

The opacity a placing layout gives a view moves every frame of a turning
ring or a deck, and it stands on the view's layer (`layer.opacity`); the
element's own opacity goes through the view's `alpha`. The trap: a view's
`alpha` coming back from nothing tells UIKit's focus system that a view
appeared, and with a keyboard attached it asks for a focus update - which
it throttles to one a second and answers by mapping every focusable place
in the window. On an iPad Pro with a keyboard that is 40-50 ms on the main
thread, once a second while a hand drags the cards: a jump each time.
Shown by the layer, the view is drawn, read (`alpha` reads the layer) and
hit-tested alike - a view at nothing takes no touch - and the focus system
maps it when it next looks. An author's own appearing view still tells it.

## A layout's box

A layout paints its own box behind its children: the fill - a color, or a
linear or radial gradient over the box in fractions of its size - inside the
outline, then the outline's stroke inside its edge, so the stroke never
spills over the place the layout was given. Each is a layer of its own, made
only while there is something to paint and kept behind the children by its
depth, whatever order the children's layers stand in. The outline is a
rectangle, a rectangle with rounded corners, or an ellipse; a stroke is drawn
in one color, a gradient's first stop.

A layout that clips cuts what it holds to its outline - its bounds for a
rectangle, a mask for any other - and a touch outside the cut reaches none of
it. A layout that lets a touch through lets one beside every child reach what
stands under it.


## A layout's blur or glass

A layout's blur or glass is a `UIVisualEffectView` of its own, the first of its
subviews, beneath the children: `UIGlassEffect` - regular or clear, its tint,
interactive where asked - or `UIBlurEffect` of UIKit's own four materials
(`systemUltraThinMaterial` to `systemThickMaterial`, and `systemChromeMaterial` for the thickest). Over it a blur's tint
and the box's outline move into the effect's content, so the tint lies over
the blur, and the effect takes the box's shape as the next section says. It
takes no touch unless its glass is interactive.
UIKit reads no material's style back, so the driver reads the effect the host
gave (✓).

## Glass takes its corners

UIKit's glass keeps to no mask: an effect view of `UIGlassEffect` under a
`CAShapeLayer` mask, or a mask view, is glass across its whole frame, its rim
showing around the figure. It is shaped by its `cornerConfiguration` alone. So
a backdrop stands as a figure one of two ways. A rounded rectangle - a box's
outline, a rectangle, a capsule or a circle of glass, as the host layer reads
the corners (`BoxArithmetic.roundedCorners`) - takes its corners, a capsule's
ends round whole (`.capsule()`), any other corner as UIKit rounds it. Any
other figure - an oval of two lengths, a figure of its own, a turned one, and
a shape's blur, which a mask keeps to its drawn path exactly - is cut by a
mask and shows its blur, glass's the one standing in for it
(`HostMaterial.withoutGlass`), its tint painted over it as a blur's. The
register records the oval layout's and the figure's glass as partial.

## The shapes

A shape draws its geometry for the room its layout gives it: a rectangle -
its corners rounded, none past half its side - and an ellipse fill the room
half their outline in from its edges, so the stroke never spills over it; a
line, a path, a polygon and a polyline draw their own geometry, placed in the
room by the host layer's rule. Every one is then moved by its own transform.
The fill and the stroke are each a layer the shape's path cuts out of its
brush - a color, or a gradient over the room - the stroke with its dashes,
ends, joins and miter limit, its dashes and gaps in stroke widths. A shape
asks for no room of its own.

## A figure made of a material

A shape whose fill is a blur or glass stands a `UIKitBackdropView` - the same
effect view a layout's box shows - lowest in the shape's view, standing as the
figure as glass takes its corners: glass across the figure's room where the
figure is a rounded rectangle; a blur, and any other glass, across the view,
cut by the figure's path. A blur's tint is the fill layer's paint over it,
cut to the figure as any fill; a glass's tint is the glass's own. The
outline's layer stands over both.

## A canvas

A Canvas replays its drawing in order on Core Graphics within its own
bounds: the instructions and the pen the host layer reads, a saved state
saving the context's too, its arcs the host layer's curves, its text in its
box by the box's two alignments. It asks for no room of its own; a finger on
it is heard as it goes down, moves and lifts, where it is.

## A placed child

A ZStack whose places a state drives stands each child where the run says, and
draws it as the run says - moved, turned, tipped in depth and scaled, and as
opaque as the run makes it - over the child's own transform and opacity. The
run's order is the drawing order: the ZStack holds its children back to front
in that order, and the one drawn in front takes the touch. A placed grid's
second child is its shade, drawn as opaque as the run says.

## Interactive glass

Interactive glass (`Glass.isInteractive`) answers the touch on what stands
in it: UIKit's glass effect lights and swells under a finger on its own view
and its content view's, not on a sibling standing over it. So a layout whose
box is interactive glass stands its children in the glass's content view -
the same room, the backdrop's frame being the layout's bounds - and a touch
on a child, a field taking it, is the glass's too; every other layout stands
its children in itself, above the backdrop. A layout letting a touch beside
its children through counts the glass as beside them. The children move only
as the glass comes or goes, and then stand in the order the layout draws them
(`orderChildren`) - a motion layout's front view in front - never in the
tree's order on every pass of UIKit's layout.

UIKit keeps whether glass answers the touch as it was where one glass effect
gives way to another of the same style: turned interactive alone, the glass
stayed still under the finger until its clarity changed, and then answered
on both clarities. A change of interactivity alone takes the old effect away
before the new one stands.
