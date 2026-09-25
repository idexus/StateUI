# The WinUI runtime

The WinUI host is the runtime every host shares
([the runtime](../../host/runtime.md)), over WinUI 3: the core's host layer
supplies the mounted tree, the patch intake, the animator, the state channels
and the display cycle, and the WinUI half supplies what only the toolkit can -
the frame signal, the doorbell's post, the elements, their layout, and the
window around them. What WinUI asks of C++ stands in the relay beneath it
([the relay](relay.md)).

## The WinUI runtime

`WinUIRenderer` owns the runtime's elements, as every runtime does: the core
link, the intake, the mounted tree whose native halves are `WinUIElement`s,
the animator and what follows it, the display cycle, and the frame clock. Its
turn is the one every runtime keeps: the jobs a resumed handler left, a
pending display cycle, a render when the core needs one, the handlers the
render created, and then the acts - on the interface their handler has just
changed. A turn asked for inside a turn runs when it ends, and an event raised
while a patch applies waits for the patch.

A view is let go of in the turn after its element left: its `deinit` is
`MainActor`'s, and a release outside a task's context puts it in the UI
executor's queue, which rings the doorbell. The WinUI element goes with it.

## Starting

The head's `main` names the application and hands the thread to
`StateUIWinUI.run()`, which loads the Windows App SDK the application carries
and starts WinUI's `Application` there; WinUI's loop runs that thread until
the last window closes. Its `OnLaunched` calls the host, whose first act is to
drain StateUI's UI executor on that thread: the drain is what makes the thread
`MainActor`'s, and every native call after it asserts that isolation rather
than assuming a thread.

## An application with no XAML

WinUI's control resources, `XamlControlsResources`, name types such as the
acrylic brushes, and only an application that answers for the types
(`IXamlMetadataProvider`) lets the framework resolve them - an application the
XAML compiler would write, and the relay's `StateUIApplication` writes by
hand, handing `XamlControlsXamlMetaDataProvider`'s answers on. The provider is
made on the first question, as the compiler's own is.

A test process runs no loop of WinUI's: it makes the application first and
then `WindowsXamlManager.InitializeForCurrentThread()`, which calls that
application's `OnLaunched` - where nothing starts - and a control takes its
template only in a window of that thread once the thread's messages ran.

## The doorbell

A handler that awaits resumes on `MainActor`, whose jobs wait in StateUI's UI
executor until the host drains them. A thread of the host's own parks until
the core has work, and posts one turn to the UI thread's `DispatcherQueue`
through the relay; the turn runs on the UI thread among WinUI's own work.

The thread is started from a nonisolated function: a closure written inside a
`MainActor` function is `MainActor`'s, and the runtime reports it as a data
race the moment another thread runs it.

## One frame

The frame clock subscribes to `CompositionTarget.Rendering` while something
holds it and lets go of it when nothing moves. Subscribed, WinUI composes at
the display's rate and raises the event before each frame it composes, so what
the frame moves is drawn in that same frame. The runtime's time is the
performance counter's, in milliseconds.

## The window

The first window element's arrangement of pages is the content of a WinUI
`Window`, under the window's chrome, which names it after the visible page
([the window's chrome](pages.md#the-windows-chrome)); the window is activated
the first time it shows a page, and told it was made once, in its turn.

## The environment

The host tells the core what it stands on as it starts: a desktop running
Windows - the device's maker, model, name and version, and whether it is a
virtual machine - the application's name, the system's theme, the user's
locale, the battery and the network; and the screen once there is a window,
at the system's scale, which a window on a second screen may not share. The
theme is the one Windows paints its controls in, so a colour written for
light and dark reads as WinUI's own text beside it. Windows says when the
theme, the power or the network changes; the relay posts each change to the
UI thread, and the host tells the core again and renders what it changed.

## Acts

The acts the application calls are performed after each turn's render and
answered, a reply or a failure with its reason, so no caller waits on an act
nobody performs. The time of day is the system's local time; the zone is the
one the locale reports, an IANA name; a zone's distance from UTC on a day is
ICU's - the ICU Windows carries - taken at the day's noon, so the day decides
summer time, and a zone ICU does not know fails the act. The screen reader is
told through the window's content, cutting off what it was saying. The focus
is put on the view the act names, or the first control in it that takes it;
WinUI has no way to leave the focus nowhere, so taking it off lends it to the
window's content for a moment, as no control, and the on-screen keyboard goes
with a field that loses it.

## Kept values

Windows keeps no store for an application that is no package, so the host
keeps one of its own: a file in the user's local data, in a folder named
after the executable, a line a key - its name and its words apart by a tab,
the tabs, line ends and backslashes in either escaped. Every key the
application lists is read before the first scene connects and handed to the
core ahead of the first view; a key's new value writes the whole file again,
its keys in order, beside the old one first and then in its place, so a
failed write leaves the old.

## Self-contained

An application carries the Windows App SDK beside its executable, with no
package: the runtime of WinUI, Foundation and InteractiveExperiences, a
manifest registering every class each component declares - the registrations
the SDK's own build writes - and `resources.pri`, where WinUI's controls find
their resources. `.scripts/WinUI/tools.ps1` lays them out after each build,
the test runner's included, and owns the versions.
