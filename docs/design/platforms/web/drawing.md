# Drawing on the Web

A shape is SVG; a box a view paints of its own - a layout's, a button's - is
CSS. Both take StateUI's brushes as the host layer reads them (`HostBrush`),
so a colour, a line's gradient and a point's gradient mean the same on every
host.

## A shape

A shape is a box with no size of its own, as on every host - it takes the
room its layout gives it, and none along a stack - and over that box an
`<svg>` holding one `<path>` and the `<defs>` of its brushes, drawn again
whenever its room changes size. The trap: an `<svg>` as the view itself,
sized `100%`, took the stack's whole height, and what stood after it in the
stack fell out of the window. A rectangle and an ellipse fill
the room, set in by half their outline so the outline stays inside it, a
rectangle's corners fitted as the host layer fits a box's
(`BoxArithmetic.fitted`). A geometry of the shape's own is written from the
host layer's flat commands and placed in the room by the host layer's
arithmetic (`ShapeArithmetic.placement`) from the bounds the browser measures
for its path, as its content mode says; a transform the shape carries is six
finite numbers or none (`ShapeArithmetic.transform`).

An outline keeps its width however the path is placed or scaled
(`vector-effect: non-scaling-stroke`), its dashes measured in its width as the
host layer measures them (`ShapeArithmetic.dashLengths`). A gradient is an
SVG gradient of the shape's own, in the page's units over the room and one
line width around it, so a fraction of the shape means the same in its fill
and its outline; a colour is the path's own `fill` or `stroke`.

The trap: a gradient in the units of the path's bounding box would follow a
placed or dashed path rather than the room, and stretch with its aspect; the
room is the one geometry every host draws a shape's brush over.

## A brush on a box

A box's fill is its CSS `background`, its outline its `border` inside its
edge, its shape its `border-radius`. A colour is the colour itself; a gradient
is a CSS gradient written for the box's size in pixels, so the box follows its
own size with a size observer and writes it again as it changes.

A line's gradient has its two points as fractions of the box, which CSS does
not take: the angle is the direction from the first point to the second in
the box's pixels, and each stop is moved onto CSS's gradient line - the line
through the box's middle long enough to reach its corners - where the stripe
square to the direction meets it. A point's gradient is a circle around its
centre, as far as the host layer's reach (`HostBrush.reach`).

An outline of a gradient is a transparent border with the box's background in
two layers: the fill cut to the inside (`padding-box`), the outline's gradient
to the whole box (`border-box`), which the border shows. A box with a look of
its own and no outline loses the browser's border, so a button drawn by the
application carries no frame of the browser's.

## A canvas

A Canvas is a `<div>` taking the room its layout gives it, with a `<canvas>`
laid over it whole: the surface's bitmap - the room at the screen's own
density - takes no room of its own, which a canvas standing in the layout
itself would, growing each time its bitmap followed its size. The drawing
is the host layer's instructions and pen (`CanvasInstruction`, `CanvasPen`),
its arcs the host layer's curves (`CanvasArithmetic.arc`), its rounded
rectangles' corners fitted as a box's are; Swift turns them into one list of
numbers and words (`WebCanvasStroke`) the relay replays on the 2D context in
one call, cut to the room, and again whenever the room changes size. Words
wrap at their room's width in the system's font, placed across and down it
as their alignments say. A press, its drag and its release are told where
they are on the canvas, the pointer captured until it lets go.

