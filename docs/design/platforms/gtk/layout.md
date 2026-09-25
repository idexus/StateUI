# Layout on GTK

StateUI's layouts place their children by the core's arithmetic
([layout](../../host/layout.md)); GTK measures and draws each widget.

## A layout is a panel

Every StateUI layout is a `StateUIPanel`, a widget subclass whose measure and
allocate call the host, which answers with the core's arithmetic and measures
and places each child. GTK lays out by asking: a child is allocated only
inside its parent's allocation, so a layout never places a child outside the
pass GTK runs. A child's size is whole logical pixels, and never less than the
least GTK measured it at; its position is a translation, which may fall
between pixels, so a travelling child moves smoothly.

## A place between passes

A child is allocated only inside its parent's allocation, so a view keeps the
place it was last given and writes it according to when it comes. Inside an
allocation - the host counts the allocations under way - the place is
allocated at once. Between allocations, as a display frame moves a travelling
child, the view asks the layout that placed it for a new allocation
(`gtk_widget_queue_allocate`); GTK runs it in the same frame, after the tick
that moved the child and before it draws, and the layout's arrangement gives
the child the place it keeps.

## Measured per axis

GTK asks a widget for its size one axis at a time: its width, then its height
for a width. A panel says it wants its height for its width, and answers the
width with the arithmetic's natural width and the height with the
arithmetic's height at the width GTK gives. Its least is nothing: what fits
where is the arithmetic's decision, and a panel whose least were its natural
size would hold the window at the size of its content. Each measure GTK asks
for measures the children again; GTK keeps each child's own answer until
something about it changes, so asking again costs little.

## Measuring a widget

A widget's size counts its CSS margin, border and padding: a button measured
34 high draws its caption in the 24 inside that box. `gtk_widget_measure` and
`gtk_widget_allocate` both speak of the whole box, and where a widget stands
is read back with `gtk_widget_compute_bounds`, which does too;
`gtk_widget_get_width` and `gtk_widget_compute_point` are the box's inside.
A widget is measured at its natural width, no wider than offered and no
narrower than its least, and then at its natural height for that width - a
label wraps to the width it is given.

## Where a view stands

A view whose frame the tree reads - a state its frame drives, or a handler
for its changes - says where it stands on the display's next frame after a
layout or a scroll: its frame in its parent, its place in the window, and
that place from the top left of its page's content, beneath the page's own
header bar, all in logical pixels. The host hears every StateUI panel GTK
allocates and every scroller's movement, and asks only the views that are
read, in the order they were made; a view that did not move says nothing. It
speaks on a frame rather than inside GTK's allocation, so what a handler
renders is laid out in a pass of its own.

## Scrolling

A ScrollView is a StateUI layout holding GTK's `GtkScrolledWindow`, which
holds the document the core's scroll arithmetic lays out - never smaller than
the viewport, and several children stacked down. GTK puts the document in a
`GtkViewport`, which the host tells to give it its natural size along the ways
the view scrolls and the viewport's own size across them; the document's
least is nothing, so a viewport giving it its least would scroll nothing. A
way the view does not scroll holds the document to the viewport; a bar asked
never to show still scrolls.

The scroller says where its view stands through its adjustments'
`value-changed`, and that the user holds it - a touchpad's fingers down -
through a scroll controller's `scroll-begin` and `scroll-end`. The user's
movement is joined up to the display's next frame, which reports it to its
state and its handlers, and rests once it has stood still, as on every host
([a scroller's movement](../../host/runtime.md#a-scrollers-movement)). The
program moves the view by setting the adjustments, which GTK tells inside the
program's write: `ProgramWrite` drops that echo, and nothing else is kept.

A viewport owns its child: a view whose parent is not a StateUI panel is not
taken out by the view as it goes, and the scroller takes its document out of
the viewport before it goes itself.
