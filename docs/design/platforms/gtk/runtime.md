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
a desktop host's window does.
