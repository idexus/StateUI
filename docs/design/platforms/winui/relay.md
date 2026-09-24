# The relay

Swift does not call WinRT's own interfaces. Beneath the WinUI host stands a
C++/WinRT relay, the package's C++ target `CStateUIWinUI`, behind plain C
functions its header declares - one set per family of controls, so the host
and the relay are each held to the types by their own compiler. SwiftPM
compiles it as C++20 over the projection `tools.ps1` generates; it links into
the host's library.

The relay holds only what Swift cannot do: WinUI's subclasses - the
application and the panel every layout is - the events, the post onto the UI
thread's queue, the frame's event, and what a test reads of the screen. Measured on the first probe, a call
from Swift into C costs a nanosecond, and a setter through the relay a few
hundred more than the same setter in C++: the crossing is nothing next to the
work it asks for.

## The C surface

A handle is a WinRT object's default interface, `AddRef`'d, which the host
lets go of with `stateui_winui_release`. A handle is read back as the type it
was made as with no `QueryInterface`, or as any of its interfaces with one.
No C++ exception leaves a function of the relay: each says what failed on
standard error and leaves the object as it was.

## The callbacks

The host hands the relay one table of functions, which the relay calls on the
UI thread: WinUI stands, a turn landed, a frame, a panel's measure and
arrange, a click, a switch's turn, a slider's move, a field's words and its
Return. Every one is set - the relay calls them unchecked, and an
empty one is a jump to nothing.

## A view and its number

The relay knows a view by the number the host gave it when it made the
element, and calls back with that number; the host finds the live view by it,
and a view that has left answers nothing.
