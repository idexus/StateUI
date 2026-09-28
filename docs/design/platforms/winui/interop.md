# Interop on WinUI

How an application extends the WinUI host from its own head: a control of its
own, an act it performs, an event it raises. The application's half is the
same for every host - a contract and a `View`; this is the other half.

## A control of the application's own

A control is an object of the application's that holds the WinUI element it
shows (`WinUIControl`). Swift calls no WinRT: the element is made by a relay
of the application's own, C++/WinRT behind C functions beside its head, which
hands it over as the host's own handles cross - a `UIElement`'s default
interface, `AddRef`'d. The host stands it in the tree as a view of its own
that wraps the control and holds a reference of its own to the element
(`stateui_winui_retain`), so each side lets go of its own: the element is
placed, sized, shown and listened to like any the host makes, its own measure
is what the host measures, and the control is held for as long as its
element lives. The registration's appliers are handed the application's own
class, so a property of the wrong type, or an event of a contract the element
does not wear, does not compile. A registered control is a leaf: this host
arranges children only in the layouts it makes itself.

The application's relay reaches back through callbacks of its own, naming the
control by a number its Swift half gave the element as it made it, held
weakly by that number. A relay no C++ exception leaves, as the host's.

## Acts and events

An act the application registers is performed where no act of the library's
answers the call, by the host layer's rule ([an application's own
acts](../../host/runtime.md#an-applications-own-acts)): an act of its own is
handed the values its contract declares, and an act aimed at one of its
elements is handed that element's control, the aim's identity turned back
into what is on screen. A performer may await, so it runs as a task on the
main actor and the call is answered once it returns. What a performer throws
fails the call with its reason; an act nobody registered is refused by name.
An event of the application's is raised through the core, from any thread,
and heard by every subscription; declaring it tells a handler listening for
one no source raises that it will not hear it.
