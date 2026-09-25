# Drawing on GTK

What the GTK host draws itself: a layout's box, a colour box, and a child
placed by an engine's run. Each is a `StateUIPanel` whose snapshot the host
answers ([the C API](c-api.md#a-subclass-from-swift)).

## A layout's box

A layout draws its own box in its snapshot, before its children: the fill -
a colour, or a linear or radial gradient over the box in fractions of its
size - inside the outline, then the outline's stroke inside its edge, so the
stroke never spills over the place the layout was given. The outline is a
rectangle, a rectangle with rounded corners, or an ellipse, each GSK's
rounded rectangle. A stroke is drawn in one colour: a gradient's first stop.

A layout that clips cuts what it holds to its outline as it draws it, and
takes `overflow: hidden`, so a child cut away also takes no click. A layout
that does not clip cuts nothing.

A colour box is a panel of one colour, its corners rounded each by its own
radius; it takes the room its layout gives it and asks for none.

## A widget's own box

GTK sizes and draws a widget's own box - the room between its edge and its
content - from CSS alone. The host keeps one style sheet for the whole
display, and a rule in it for each value asked for, a class named for what
it says - `stateui-padding-24-8-12-4`, a header bar's colours
`stateui-bar-b512BD4FF-fFFFFFFFF` - which a widget wears to take it and takes
off to give it up. The sheet stands above the theme, so its rule wins over
the theme's own for the same widget. A rule is written the first time its value is
asked for and stays, the sheet written again in the rules' order; a value
that moves every frame has its own road, never a rule a frame.

## The application's pictures

The application's pictures stand in an `Images` folder beside its
executable, which the run script fills from the application's
`Resources/Images`, and the tree names each by its file. Where the tree asks
for a PNG the folder holds as an SVG, the SVG is shown: the application's
pictures are written once, as SVGs, for every host.

A picture shown as an icon is a `GtkImage` of the file's icon, a given number
of logical pixels across: GTK reads the file - an SVG through gdk-pixbuf's
loader - at that size times the display's scale, and again when the scale
changes.

## A placed child

A ZStack whose places a state drives stands each child where the run says, and
draws it as the run says - moved, turned, tipped in depth and scaled, and as
opaque as the run makes it - over the child's own transform and opacity. The
run's order is the drawing order: the panel holds its children back to front
in that order, which is the order GTK draws them in and the reverse of the
order a click tries them in, so the one drawn in front takes the click. A
placed grid's second child is its shade, drawn as opaque as the run says.

A test reads what is drawn: the widget drawn afresh from its parent, as a
frame's paint draws it, rendered to a texture by its window's renderer and
read back as premultiplied colour, sampled at the points the test names. A
widget's own paintable shows only the drawing GTK last kept, which a layout
since has thrown away.
