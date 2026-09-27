# The UIKit runtime

The UIKit host is the runtime every host shares
([the runtime](../../host/runtime.md)), over UIKit on iOS and iPadOS: the
host layer supplies the mounted tree, the patch intake, the animator, the
state channels, the display cycle, the windows' roster and presentation and
every layout's arithmetic, and the UIKit half supplies what only the toolkit
can - the display link, the main queue the core is woken on, the views, and
the scenes around them.

## The UIKit runtime

`UIKitRenderer` owns the runtime's elements as every runtime does: the
runtime (`HostRuntime`), its frame clock - a `CADisplayLink` running only
while something holds it - and the roster of the windows it shows. The core
is woken as on every Apple host: a thread of the host's parks until the core
has work, and each ring puts a turn of the pump on the main queue. The
application's delegate starts the runtime as the application launches, and
tells it what the device, the display and the application are.

## Scenes

A StateUI scene is a window scene of UIKit's own. Each scene iOS connects -
the one it opens at launch, and each window the user opens on an iPad - tells
the core to connect a scene, and the StateUI window that scene's render holds
stands in it: a window of the scene's, its root view showing the window's
arrangement of pages within the safe area, the title of the page the user
sees the scene's title. A window the tree lets go of lets its scene go with
it. The application's `Info.plist` says it supports many scenes, so an iPad
opens as many as the user asks for; a window the tree holds with no scene
standing for it asks iOS for one, and stands in the next scene iOS connects.

A window's lifecycle is its scene's: in front of the user and active, behind
once in the background, and neither between - each told to the host layer,
which settles what it means for the window, its scene and the application. A
window that comes to stand in a scene already in front, or behind, is told
where it stands. The user closing a window - swiping its scene away - is the
scene's session discarded, which the window hears as closed by the user; a
scene iOS only disconnects to save memory closes nothing.

A window the tree closes in front of the user first brings back the window
activated last of those staying: iPadOS shows the home screen once the scene
in front is destroyed, the application's other windows behind it.

The trap: the scene of a window the tree lets go of is destroyed, and iPadOS
ends the process once an application's last scene is destroyed. A host whose
windows share one scene - the tests' host stands every window in the one
scene the runner has - does not own that scene, so its windows only leave
it.

## Acts

The acts every host performs are the host layer's performer's; UIKit's part
is its toolkit's. The clock and the zones are the device's. A word to the
screen reader is VoiceOver's announcement. On iOS only a field or an editor
takes the focus: an act focusing a view gives it to the view, or the first
view in it that takes it, and answers whether one did; taking the keyboard
down ends the editing in the window the user is looking at. Where the focus
is, each element following it hears as it moves - a field and an editor say
so as their editing begins and ends, and every focus act says so too, as not
every view taking the focus does. Kept values stand in the preferences, read
before the first render.

## Questions for the user

A question is UIKit's alert, presented over what the user's window shows -
its top sheet, else its pages: a confirmation and a prompt with their cancel
first, as iOS orders them, a prompt's field ready with its words, a choice as
an action sheet - on an iPad standing in the middle of the window - its
dangerous caption marked. Pressing a button takes the alert away and answers
the question, once; the next question in line then shows.

