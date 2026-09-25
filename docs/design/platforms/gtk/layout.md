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
