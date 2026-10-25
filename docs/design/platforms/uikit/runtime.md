# The UIKit runtime

The UIKit host is the runtime every host shares
([the runtime](../../host/runtime.md)), over UIKit on iOS and iPadOS: the
host layer supplies the mounted tree, the patch intake, the animator, the
state channels, the display cycle, the windows' roster and presentation and
every layout's arithmetic, and the UIKit half supplies what only the toolkit
can - the display link, the views, and the scenes around them.

## The UIKit runtime

`UIKitRenderer` owns the runtime's elements as every runtime does: the runtime
(`HostRuntime`), its frame clock - a `CADisplayLink` running only while
something holds it - and the roster of the windows it shows. The core is
turned as on every Apple host: after each pass of the main run loop where it
has work ([the turn on Apple](../../host/runtime.md#the-turn-on-apple)). The
application's delegate starts the runtime as the application launches, which
tells what the device and the application are; each scene iOS connects tells
what the display is.

## The frame clock

The display link asks the display's full rate, up to 120 frames a second
(`UIKitFrameClock.fullRate`), and only while something holds the clock - a
motion, a hand, an animation. A ProMotion iPad gives it; an iPhone gives it
only to an application whose `Info.plist` says
`CADisableMinimumFrameDurationOnPhone`, and otherwise draws a display link's
motion at sixty while its own scrolling runs at 120 - a layout moved by the
hand then moves half as often as the finger. The bundle every UIKit head is built into
says it (`.scripts/UIKit/tools.sh`), so no application has to.

## Scenes

Each StateUI window stands in a window scene of UIKit's own: a window of the
scene's, its root view showing the window's arrangement of pages over the
whole window, each page within the safe area its bars leave, the title of
the page the user sees the scene's title. A window the tree lets go of lets
its scene go with it. The application's `Info.plist`
says it supports many scenes, so an iPad opens as many as the user asks for.

A scene iOS connects is one of four (`UIKitRenderer.connect`):

- the session of a window standing, which iPadOS let go of in the background,
  brings that window back;
- a session keeping a window's record comes in as that window, by the host
  layer's rule ([restored windows](../../host/runtime.md#restored-windows));
- one a window the tree holds asked iOS for stands for it;
- any other is a new window: the first the window launch opens, another one
  more of the group with no name. A kept window of a kind no scene declares
  now is a new one too - iOS connected its scene, and the user is to see
  something in it.

Every window writes its record in its scene's session
(`UISceneSession.userInfo`) - its kind, its value and what its StateUI scene
keeps - which iOS keeps and hands back as it restores the scene. Nothing
renders before the first scene connects ([the platform's first
window](../../host/runtime.md#the-platforms-first-window)).

A window's lifecycle is its scene's: in front of the user and active, behind
once in the background, and neither between - each told to the host layer,
which settles what it means for the window, its scene and the application.
iPadOS keeps every window on screen active and dims those behind the one the
user works in; a scene's active appearance tells which, so a window dimmed
stands inactive, and is activated as the user comes back to it. A
window that comes to stand in a scene already in front, or behind, is told
where it stands. The user closing a window - swiping its scene away - is the
scene's session discarded, which the window hears as closed by the user; a
scene iOS only disconnects to save memory closes nothing: its window waits for
the session to come back.

A window the tree closes in front of the user first brings back the window
activated last of those staying, where that one stands off the screen under
it: iPadOS shows the home screen once the scene in front is destroyed, the
application's other windows behind it. One standing on the screen beside it
is left where and as big as it is - brought back, iPadOS would stand it in
the closing window's place, at its size.

The trap: the scene of a window the tree lets go of is destroyed, and iPadOS
ends the process once an application's last scene is destroyed. A host whose
windows do not own their scenes (`ownsScenes` off) - the tests' host, which
stands its window in the one scene the runner has - does not own that scene,
so its windows only leave it.

## A link opened

A scene's delegate hears the links it is asked to open: those it connects with
(`UIScene.ConnectionOptions.urlContexts`) and those a running scene is handed
(`scene(_:openURLContexts:)`), each named by the scene's window where it
stands. The application's delegate, `StateUIApplicationDelegate`, is open: an
application whose SDK asks for a delegate subclasses it, calling `super` where
it overrides, and hands it to `StateUIUIKit.run(delegate:)`.

## The environment

The device, the application and the main display are told as the runtime
starts and the first scene connects. The theme, the user's locale, the
battery and the network are told as the application starts - the theme once
its first scene connects - and again whenever one changes, each change
through the runtime's one step for it: the theme when the scene's traits
turn it, the locale when the user or the time zone changes it, the battery
when its level or state moves or Low Power Mode turns, the network when its
path moves. The theme is the whole application's: every scene stands in the
one the user chose, so one scene's traits say it - a scene iOS holds: one it
lets go of is followed no more, and another it holds, else the next to
connect, is followed in its place, since iOS makes a scene anew for a session
it brings back. A battery UIKit knows
nothing of - the simulator's - is none, full, on mains; Low Power Mode is the
battery saver. The network is reachable when its path is satisfied, local
when interfaces stand but no route leads out; each interface available to
the path - Wi-Fi, wired, cellular - is a connection profile. The accessibility
settings are UIKit's - Reduce Motion, darker colors for more contrast,
VoiceOver - and the scale of words the size the user chose draws the body's
17 points at; each is told again as UIKit announces its change.

The display is told again as UIKit sets out to give a window a new size
(`viewWillTransition(to:with:)` on its root): the scene stands turned
already, and the window is laid out at the turned size after it. A page
measured there - its frame reported in the same layout pass - is heard with
the display it is measured on, so an answer worked out from the two holds.
The scene's own report of its new geometry comes after that layout and finds
nothing new; told only there, a page turned back would answer from the last
turn and never be measured again.

## Acts

The acts every host performs are the host layer's performer's; UIKit's part
is its toolkit's. The clock and the zones are the device's. A word to the
screen reader is VoiceOver's announcement. On iOS only a field or an editor
takes the focus: an act focusing a view gives it to the view, or the first
view in it that takes it, and answers whether one did; taking the keyboard
down ends the editing in the window that asked. Where the focus
is, each element following it hears as it moves - a field and an editor say
so as their editing begins and ends, and every focus act says so too, as not
every view taking the focus does. Kept values stand in the preferences, read
before the first render.

## The clipboard

The clipboard is the general pasteboard: words are written as its string and
read back at once. iOS asks the user before an application reads what another
put there, and a refusal reads none. A conformance run writes to a pasteboard
of the driver's own name, as the simulator's general one is the Mac's too.

## Sharing

What the user shares is offered in UIKit's activity sheet over what the window
shows - from its middle on an iPad, a popover with no arrow: the words and the
link as its items, the answer whether the user completed an activity.

## Questions for the user

A question is UIKit's alert, presented over what the user's window shows -
its top sheet, else its pages: a confirmation and a prompt with their cancel
first, as iOS orders them, a prompt's field ready with its words, a choice as
an action sheet - on an iPad standing in the middle of the window - its
dangerous caption marked. Pressing a button takes the alert away and answers
the question, once; the next question in line then shows.


## Files

A file dialog is UIKit's document picker, presented over what the user's
window shows and waiting its turn among the questions
([files](../../host/runtime.md#files)). One that opens offers the files of
every kind's extensions - any file where none is asked - and several only
where asked. iOS exports a ready file rather than ask for a place, so a save
writes its contents first, beside the UI thread, to a file of the act's name
in a folder of its own - "Untitled" where the name is empty, as the picker
names none - and the picker exports it; the file the user saved is
answered, and the one written goes. A file the picker answers is the
application's while it runs: its access is taken as it is chosen and never
given back. A chosen file's address is its path; a file is read beside the
UI thread.

A file is launched as iOS's preview of it, over what the window shows,
answering whether it can be previewed; an address is opened by
`UIApplication`, which answers whether an application took it. A test holds
launches back, recording them.
