# Interop on GTK

How an application extends the GTK host from its own head: a control of its
own, an act it performs, an event it raises. The application's half is the
same for every host - a contract and a `View`; this is the other half.

## A control of the application's own

A control is an object of the application's that makes and holds the GTK
widget it shows (`GTKControl`). The host stands it in the tree as a view of
its own that wraps the control: the widget is placed, sized, shown and
listened to like any widget the host makes, its own measure is what the host
measures, and the control is held for as long as its element lives. The
registration's appliers are handed the application's own class, so a
property of the wrong type, or an event of a contract the element does not
wear, does not compile. A registered control is a leaf: this host arranges
children only in the layouts it makes itself.

## Acts and events

An act the application registers is performed where no act of the library's
answers the call: an act of its own is handed the values its contract
declares, and an act aimed at one of its elements is handed that element's
control, the aim's identity turned back into what is on screen. A performer
may await - GTK's clipboard answers only asynchronously - so it runs as a task
on the main actor and the call is answered once it returns. What a performer
throws fails the call with its reason; an act nobody registered is
refused by name. An event of the application's is raised through the core,
from any thread, and heard by every subscription; declaring it tells a
handler listening for one no source raises that it will not hear it.
