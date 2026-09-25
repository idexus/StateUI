# The GTK runtime

The GTK host is the runtime every host shares
([the runtime](../../host/runtime.md)), over GTK 4 and libadwaita: the core's
host layer supplies the mounted tree, the patch intake, the pump, the
animator, the state channels and the display cycle, and the GTK half supplies
what only the toolkit can - the frame signal, the doorbell's post, the
widgets, their layout, and the window around them. It is Swift alone: GTK's
API is C, and Swift calls it as it stands ([the C API](c-api.md)).

## The GTK runtime

`GTKRenderer` owns the runtime's elements, as every runtime does: the core
link, the intake, the mounted tree whose native halves are `GTKElement`s, the
pump, the animator and what follows it, the display cycle, and the frame
clock. It is the pump's `TurnPresenter` - after a render it shows the window -
and the display cycle's `FramePresenter`.

A view is let go of in the turn after its element left: its `deinit` is
`MainActor`'s, and a release outside a task's context puts it in the UI
executor's queue, which rings the doorbell. The view takes its widget out of
its panel and drops the reference it held.

## Starting

The head's `main` names the application and hands the thread to
`StateUIGTK.run(applicationID:)`, which makes an `AdwApplication` under that
name and runs GLib's main loop on the thread until the last window closes.
The application's first activation calls the host, whose first act is to drain
StateUI's UI executor on that thread: the drain is what makes the thread
`MainActor`'s. The name is the one the desktop knows the application by, and
GTK keeps one instance of it: a second launch activates the first, which
brings its window forward.

A test process runs no main loop: it starts libadwaita, registers an
application of its own so windows have one to belong to, and turns GLib's
loop itself. A window a test opens may stand behind another, and the desktop
draws such a window no frames, so a test lays a window out by raising its
surface's `layout` signal at the surface's size - the call a frame's layout
makes - rather than by waiting for a frame.

## The doorbell

A handler that awaits resumes on `MainActor`, whose jobs wait in StateUI's UI
executor until the host drains them. A GLib thread of the host's own parks
until the core has work, and posts one turn to the main loop with
`g_idle_add_full` at `G_PRIORITY_DEFAULT` - input's priority, above GTK's
redraw - so a turn's render lands before the next frame is drawn.

The thread is started from a nonisolated function: a closure written inside a
`MainActor` function is `MainActor`'s, and the runtime reports it as a data
race the moment another thread runs it.

## One frame

The frame clock adds a tick callback to the window while something holds it,
and removes it when nothing moves. GTK calls it once for every frame it draws
the window in, at the display's rate, before the frame's layout, so what the
frame moves is drawn in that same frame. The runtime's time is GLib's
monotonic clock, in milliseconds.

## The window

The first window element's arrangement of pages is the content of an
`AdwApplicationWindow`: a page shown by itself in a frame whose header bar is
the window's title bar, an arrangement as it stands, its pages carrying their
own ([pages](pages.md)). The window is presented the first time it shows
something, and told it was made once, in its turn. It opens at 560 by 440, as
a desktop host's window does, or at the size the window element says, which a
window already open takes too; the user may make it no smaller than the
element's smallest size, or GNOME's own - 360 by 294 - where it says none.
GTK 4 gives a window no largest size.

## The environment

As the host starts it tells the core what it stands on: a desktop, Linux, the
machine's model and maker as the kernel reads them, the host's name, the
system's version, whether the machine is virtual; the application's name and
its identifier. It tells the core the desktop's style - dark or light, as
libadwaita's style manager reads it from the desktop's settings - and again
whenever it turns, and once the window stands, the screen it stands on: its
size in pixels, its scale and its refresh rate.

## Acts

The acts the application calls are performed after each turn's render and
answered, a reply or a failure with its reason, so no caller waits on an act
nobody performs. The time of day is GLib's local time; the zone is GLib's
local zone, an IANA name; a zone's distance from UTC on a day is GLib's,
taken at the day's noon, so the day decides summer time, and a zone GLib
does not know fails the act. The screen reader is told through the window,
GTK's own announcement. The focus is put on the view the act names, or the
first control in it that takes it, and taken off by leaving it nowhere,
which GTK allows. A desktop's keyboard is its own, so taking the on-screen
keyboard down answers that no field had brought one up.

## Questions for the user

A question - an alert, a confirmation, a choice of actions, a prompt - is
libadwaita's `AdwAlertDialog` over the window, and its call waits under a
ticket the dialog's answer comes back with; a ticket is one number across
the process, so an answer that arrives after its renderer has gone answers
nothing of another's. A window shows one question at a time, as a desktop's
sheets are, so a question asked while one shows waits for it to close. A
choice of actions is a button a choice, the dangerous one first, and the
pressed caption is the answer - the cancelling one too; a dialog dismissed
any other way, Escape among them, answers that nothing was chosen. A
prompt's field takes the placeholder, the most characters and the keyboard
its purpose asks for, holds the keyboard as the dialog shows, and Enter in
it accepts.

## Kept values

The desktop keeps no store an application can use without a schema
installed, so the host keeps one of its own: `kept values.txt` in the user's
state folder, in a folder named by the application's ID, in the host
layer's text ([kept values](../../host/runtime.md#kept-values)). Every key
the application lists is read before the first scene connects and handed to
the core ahead of the first view; a key's new value writes the whole file
again, beside the old one and then in its place, so a failed write leaves
the old.

