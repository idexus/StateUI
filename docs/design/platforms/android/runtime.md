# The Android runtime

The Android Views host is the runtime every host shares
([the runtime](../../host/runtime.md)), over Android views: the host layer
supplies the mounted tree, the patch intake, the animator, the state
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
first thing the start does is take that thread as the UI thread:
`takeTheUIThread()` makes StateUI's UI executor `MainActor`'s and drains it
there, and every native call after it asserts that isolation rather than
assuming a thread.

## A later activity

The process outlives its activity. Android makes an activity again - for a
new configuration - while the scene stands, and every connection makes
another independent scene, so a later activity takes over the scene the one
before showed, with its state: the previous tree leaves, letting go of the
old activity's views, and a renderer of the new activity's own, whose intake
holds no message yet, asks for the whole tree, and the scenes kept pass to
it. Back finishes the activity: the user closed its window, which hears it is
going, and its scene that the window closed, and the scene ends with it. The
launcher's next activity finds none standing: the scenes kept come back, as
for the first activity.

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
facts in one call: the model, the maker, the device's name and Android's
version - the name its user gave it in Settings, which tells one terminal of
a model from another, else the model's code name; the display's
size in pixels, its density, rotation and refresh rate; the application's
name, package and version. A device whose smallest width is 600
density-independent pixels or more is a tablet, any other a phone - the host
layer's rule for every touch screen, the Web's too. The relay hands the
device, the locale and the network as the words and numbers the host layer
reads for every relay ([The environment](../../host/runtime.md#the-environment)). The
system's dark or light theme is read with them, and the activity is made in
the matching one: a change of theme makes Android create the activity again,
and the new one takes the scene over, its controls drawn in the new theme.

The user's locale, the battery and the network are read with them and again
whenever one changes: the activity watches the zone, the clock, the battery,
its saver and the default network from its creation to its destruction, each
change read whole in one call per group. A change of language creates the
activity again, so the locale - its direction with it - is read as the new one
starts. The network needs `ACCESS_NETWORK_STATE`, which every head's manifest
asks for; without it the network is reported unknown.

## The activity's lifecycle

The activity's resume, pause and stop are its one window's state - activated
in front of the user, neither, off the screen - which settles into the phases
of the application, its scene and its window by the host layer's rule ([the
application's phase](../../host/runtime.md#the-applications-phase)): each
rendered before the next is heard, and a window shown again after it stopped
resumed on its way to active. The window hears it was made as the host layer
shows it, once; and it is going, and its scene that it closed, only when the
activity finishes, not when Android makes the activity again for a new
configuration. The window's title - the visible page's that names it, else
the window's own, as the host layer's chrome says it - is the activity's, and
the label its task shows among the recent ones.

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

## Files

A file dialog is the system's document picker, started for its result over
the activity and waiting its turn among the questions
([files](../../host/runtime.md#files)); the activity hands its result to the
relay by the request's code, and the picker answers under its ticket. One
that opens asks for the MIME types of every kind's extensions - any document
where none is known - and several only where asked; one that saves suggests
the act's name and the type of its extension, and the contents are written
to the document the user made, beside the UI thread, before it is answered.
A document's address is its `content:` URI and its name the one its provider
shows; the leave to read it lasts while the application runs. A document is
read beside the UI thread; every answer comes back on it.

A document is launched by a view intent with leave to read it, an address by
a view intent of its own; each answers whether an application took it. A
test holds the picker and the launches back in the relay, which records
them.

## The application's own acts

An act no control of the library's stands behind - one the application's
contract declares - is performed by what the application registered for it
(`StateUIActs`, the host layer's `InteropActs`), handed the values its
contract declares and answered with those it returns, once the performer
returns; an act nothing registered is refused by its name. An event the
application raises (`StateUIEvents`) reaches every listener to it. Both are
said as the library loads: `JNI_OnLoad` runs on the UI thread and says them
before `StateUIAndroid.load(_:)`, which registers the host's natives; the
activity starts the host after it.

## The application's own controls

An element of the application's own is realized by a control the
application registered (`StateUIControls`): an object holding an Android view
of the application's own Java, made from Swift through the host's JNI - the
same `Java` calls the host makes, published for this - with the activity.
The host wraps the view as one of its own (`AndroidHostedView`) and places,
measures and shows it as it does every view; the control's registration puts
each member on it. The view tells its Swift half what the user did through
the application's own native methods, by a number the control gave it, so
nothing of the host's numbering or listeners reaches the application.

## Kept values

A kept state's key is in the platform's preferences, as the words its kind
reads back. Every key the application lists is read before the first scene
connects, in one call, and handed to the core ahead of the first view; a
key's new value is written as its save arrives.

Android restores no windows, so the application's scenes are kept beside the
values, under a key of the host's own, by the host layer's rule ([kept
scenes](../../host/runtime.md#kept-scenes)), and come back at the next
start.
