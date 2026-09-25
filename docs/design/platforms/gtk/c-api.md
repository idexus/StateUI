# GTK's C API from Swift

GTK 4 and libadwaita are C libraries, and the host calls them from Swift as
they stand: its C module is the system's headers, found by pkg-config, and
nothing of its own. What C spells with macros, Swift spells with the
functions the macros stand for.

## Casts

A GTK class Swift imports as a struct where other classes derive from it -
`GtkWidget`, `GtkButton`, `GtkWindow`, `AdwApplicationWindow` - and as an
opaque pointer where the class is final - `GtkLabel`, `AdwToolbarView`. The
casts GTK's macros make are a pointer reinterpreted as another class:
`widget.of(GtkWindow.self)`, or `widget.opaque`.

## Signals

`g_signal_connect` is a macro; the host calls `g_signal_connect_data`, the
handler a C function handed the view's number as its data. A C function can
capture nothing, and a widget's pointer is not `Sendable`: the number is, so
the handler finds its view by the number, on the main actor, and does
nothing once the view has gone.

A handler's type is the C shape GTK calls it with - the instance, what the
signal hands, the number - one for each shape the host hears: nothing, one
argument by address, a press (its run and point), a point, a scale. A
property's change notice has a road of its own, `connectNotify`, which names
the property alone.

## A view and its number

Every view takes a number when it is made and holds its widget with a
reference of its own, sunk from the floating one GTK makes it with. The
number is what a signal and a panel hand back; the live views stand in a
table by number, weakly, so a signal arriving after its view left finds
nothing.

## A subclass from Swift

A layout's panel is a `GtkWidget` subclass registered from Swift:
`g_type_register_static_simple` with a class initializer that writes the
class's measure, allocate and request-mode functions and its dispose. Each is
a C function that reads the panel's view number from the widget's data and
asks that view; the dispose lets the panel's children go before the widget's
own dispose runs.
