# The Android runtime

The Android Views host is the runtime every host shares
([the runtime](../../host/runtime.md)), over Android views: the core's host
layer supplies the mounted tree, the patch intake, the animator, the state
channels and the display cycle, and the Android half supplies what only the
toolkit can - the frame signal, the doorbell's post, the views, their layout,
and the activity around them.

## The Android Views runtime

`AndroidRenderer` owns the runtime's elements, as every runtime does: the core
link, the intake, the mounted tree whose native halves are `AndroidElement`s,
the animator and what follows it, the display cycle, and the frame clock. Its
turn is the one every runtime keeps: the jobs a resumed handler left, a
pending display cycle, a render when the core needs one, the handlers the
render created, and then the acts - on the interface their handler has just
changed. A turn asked for inside a turn runs when it ends, and an event raised
while a patch applies waits for the patch.

The window is the activity's. Its content is an empty root that keeps out of
the system bars; the host shows the first window's page in it.

## Starting

The activity loads the head's library - named by the manifest's
`stateui.library` - whose `JNI_OnLoad` names the application and registers
the host's natives. Its `onCreate` then starts the host on the UI thread. The
first thing the start does is drain StateUI's UI executor on that thread: the
drain is what makes the thread `MainActor`'s, and every native call after it
asserts that isolation rather than assuming a thread.

## A later activity

Back finishes the activity while the process lives on, and the launcher then
starts another. The application's scene is connected once, by the first
activity: every connection makes another independent scene. A later activity
therefore takes over the scene the one before showed, with its state: the
previous tree leaves, letting go of the old activity's views, and a renderer
of the new activity's own, whose intake holds no message yet, asks for the
whole tree.

## The doorbell

A handler that awaits resumes on `MainActor`, whose jobs wait in StateUI's UI
executor until the host drains them. A thread of the host's own parks until
the core has work, and writes an eventfd that the main looper watches; the
looper's callback runs a turn. Nothing on that path enters the JVM.

The thread is started from a nonisolated function: a closure written inside a
`MainActor` function is `MainActor`'s, and the runtime reports it as a data
race the moment another thread runs it.

## One frame

The frame clock asks the UI thread's `Choreographer` for one frame at a time
while something holds it, and none when nothing moves. Its callback runs in
the display's frame, among the frame's animations and before it lays out and
draws, so what the frame moves - a value, a place, a size - is drawn in that
same frame. A frame signal of its own beside the toolkit's would run its work
outside the toolkit's frame: the views it changes wait for the toolkit's next
frame, and every other frame of the display is lost.

The frame's time is `CLOCK_MONOTONIC` in milliseconds, the clock the
choreographer stamps its frames with, so a frame's time and a patch's time
are on one clock.

## Print reaches logcat

An Android application's standard output goes nowhere. The host points stdout
and stderr at a pipe whose reader writes each line to logcat under the tag
`StateUI`, so an application's `print` reaches the log the scripts follow.

## The environment

What the device, its display and the application are is read as the host
starts and whenever the activity's configuration changes, each group of
facts in one call: the model, the maker and Android's version; the display's
size in pixels, its density, rotation and refresh rate; the application's
name, package and version. A device whose smallest width is 600
density-independent pixels or more is a tablet, any other a phone. The
system's dark or light theme is read with them, and the activity is made in
the matching one: a change of theme makes Android create the activity again,
and the new one takes the scene over, its controls drawn in the new theme.

## The activity's lifecycle

The activity's resume, pause and stop move the application's phase, and
then the scene's and its window's: activated, deactivated and stopped, each
rendered before the next is heard. A window shown again after it stopped is
resumed on its way to active. The window hears it was made after the render
that first shows it, once; and it is going - then its scene - only when the
activity finishes, not when Android makes the activity again for a new
configuration. The window's title is the activity's, and the label its task
shows among the recent ones.

## Acts

The acts the application calls are performed after each turn's render and
answered, a reply or a failure with its reason, so no caller waits on an act
nobody performs. The time of day, the zone and a zone's distance from UTC are
the platform's, each one call; the screen reader is told through the window's
root; the focus is put on or taken off the view the act names, a text field
bringing up the keyboard. A question for the user - an alert, a confirmation,
a choice of actions, a prompt - is the platform's own dialog: its call waits
under a ticket the dialog hands back as the user answers, and a dialog
dismissed any other way answers that it was not accepted. A script run in a
web view waits the same way, until the page answers. A ticket is one number
across the process, so an answer that arrives after its renderer has gone
answers nothing of another's.

## Kept values

A kept state's key is in the platform's preferences, as the words its kind
reads back. Every key the application lists is read before the first scene
connects, in one call, and handed to the core ahead of the first view; a
key's new value is written as its save arrives.
