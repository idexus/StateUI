# The WinUI runtime

The WinUI host is the runtime every host shares
([the runtime](../../host/runtime.md)), over WinUI 3: the core's host layer
supplies the mounted tree, the patch intake, the animator, the state channels,
the display cycle and the turn, and the WinUI half supplies what only the
toolkit can - the frame signal, the doorbell's post, the elements, their
layout, and the window around them. What WinUI asks of C++ stands in the relay beneath it
([the relay](relay.md)).

## The WinUI runtime

`WinUIRenderer` holds the parts every runtime holds alike (`HostRuntime`): the
core link, the intake, the mounted tree whose native halves are
`WinUIElement`s, the animator and what follows it, the display cycle on
WinUI's frame clock, and the pump. Its turn is the one every runtime keeps
(`Pump`): the jobs a resumed handler left, a pending display cycle, a render
when the core needs one, the handlers the render created, and then the acts -
on the interface their handler has just changed. A turn asked for inside a
turn runs when it ends, and an event raised while a patch applies waits for
the patch. What the renderer adds is WinUI's: the window, its sheets and its
chrome shown after each render, and the acts performed.

A view is let go of in the turn after its element left: its `deinit` is
`MainActor`'s, and a release outside a task's context puts it in the UI
executor's queue, which posts a turn. The WinUI element goes with it.

## Starting

The head's `main` names the application and hands the thread to
`StateUIWinUI.run()`, which loads the Windows App SDK the application carries
and starts WinUI's `Application` there; WinUI's loop runs that thread until
the last window closes. Its `OnLaunched` calls the host, whose first act is to
claim that thread as the UI thread: `claimUIThread()` makes StateUI's UI
executor `MainActor`'s and drains it there, and every native call after it
asserts that isolation rather than assuming a thread.

## A windowed application

The head links as a windowed application (`/SUBSYSTEM:WINDOWS`, its entry
still the C runtime's `main`), so one started by itself - from Explorer, a
shortcut - opens no console beside its window. One started from a console - a
terminal - still writes there: where the process was handed no output of its
own, the relay attaches it to the console of the process that started it
before WinUI starts, and points the C runtime's streams, and its descriptors
1 and 2, at that console. Output a caller sent elsewhere - a file, or the
debugger F5 starts it under, which shows it in the editor's debug console -
stays where it was sent. A windowed application is not waited for by the
shell that starts it, so `run-app.ps1` waits for it itself.

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

A turn is posted to the UI thread's `DispatcherQueue` through the relay, and
runs on the UI thread among WinUI's own work. The host gives the core that
post at its start (`CoreLink.postTurns`), and the core makes it from any
thread: on the UI thread for work it made - a state written, an act sent - and
on the thread that queued a job, a handler's resume or a post among them. No
thread of the host's waits. What a layout pass decides - a split view's first
room - waits in the doorbell until the pass is over, and runs as the next turn
posted begins.

## One frame

The frame clock subscribes to `CompositionTarget.Rendering` while something
holds it and lets go of it when nothing moves. Subscribed, WinUI composes at
the display's rate and raises the event before each frame it composes, so what
the frame moves is drawn in that same frame. The runtime's time is the
performance counter's, in milliseconds.

## The window

Each window element the tree holds is shown in a WinUI `Window` of its own,
kept by a window controller in the tree's order; a window the tree no longer
holds is closed. The first is the one whose screen the environment reads. A window element's
arrangement of pages is its window's content, under the window's chrome, which
names it after the visible page, else after the element's title
([the window's chrome](pages.md#the-windows-chrome)); the window is activated
the first time it shows a page, and told it was made once, in its turn
(`WindowPresentation`); the pages the window's modal stack presents stand on
sheets over it.

## A window's frame

A window stands where the host layer says its element asks ([a window's
frame](../../host/tree.md#a-windows-frame)): the place, the size and the
bounds the tree changed, each alone. The size is the content's, the chrome's
included, as WinUI's content reaches under it. WinUI's `AppWindow` takes
pixels, so each DIP is the window's DPI over 96 of them - known before
anything is laid out, where the root's rasterization scale is not. The size
is set as the whole window's, the content's asked for plus the frame around
it as it stands: `ResizeClient` would add the title bar's height again, which
the content already covers.

The bounds are the presenter's preferred least and greatest size. The
traits ([a window's traits](../../host/tree.md#a-windows-traits)) are the
presenter's too - its maximize and minimize buttons, a button left unsaid
being WinUI's own, which lets the user press it, and its standing on top of
other windows for one that floats.

## A window's backdrop

A window made of a blur shows the desktop through it in the desktop acrylic;
any other window shows Mica, the desktop's tint. The acrylic is a system
backdrop of the relay's own over WinUI's `DesktopAcrylicController`, since
WinUI's ready one holds neither a kind nor an opacity: the two thinnest
blurs are the thin kind, the rest the base one, and its luminosity hides as
much of the desktop as the blur's thickness does
(`Blur.Thickness.opacity`, the share a stand-in colour lets through), and
its tint grows from none on the thinnest blur to nine tenths on the
thickest: the luminosity alone - from 0.45 to 0.95 - barely tells the five
apart, an ultra-thick window still showing the desktop through. Its colour - tint, and the fallback an inactive window
shows - is the blur's stand-in colour, the theme's: a controller given any
one value keeps none of the theme's own (an ultra-thick blur came out
white in the dark theme), so every colour is written, and the theme
turning gives the window its traits again. XAML's default configuration has
the acrylic follow the window's activation. The backdrop is made
again only where it turns. A tint colours the acrylic itself - its colour is
the tint laid over the theme's, which the acrylic's tint then carries as far
as the thickness says - and lies over it on the window's root as well, as
the colour a window is painted does. Glass is the acrylic at its fallback
thickness: WinUI has no glass.

A background the application writes shows behind the detail as it does
beside the sidebar and under the bars: the card a navigation view lays over
its detail - WinUI's layer fill, which turns a written colour grey - is
clear (`NavigationViewContentBackground`, written into the window root's
resources, which every navigation view in the window reads on its way up),
and its edge - the line under the bar and beside the sidebar - is the
theme's divider (`DividerStrokeColorDefault`), in a dictionary for each
theme so it follows the theme by itself. A window left to the platform keeps WinUI's card.

## The application's phase

Each window's activation and its minimizing settle into the phases of the
application, its scenes and its windows by the host layer's rule ([the
application's phase](../../host/runtime.md#the-applications-phase)): the
relay tells the window's state at each of WinUI's events - whether it stands
minimized, and whether it is activated - because a window being minimized is
also told it lost its activation, in either order; a change of its size or
presenter tells it only where it is minimized. A window its scene hides is
`AppWindow.Hide`, and shown again without being activated; one hidden before
it was ever shown is activated as it is first shown. A floating window is
`IsAlwaysOnTop` while the application is in front. Every window is one of
its own, in the taskbar and the switcher. A window its scene hides tells its
state as it hides and shows again
(`AppWindow.Changed`), off the screen while it is hidden. A window is told it was made before it is
first shown: WinUI tells it that it was activated inside `Activate`, before
the call returns.

## The environment

The host tells the core what it stands on as it starts: a desktop running
Windows - the device's maker, model, name and version, and whether it is a
virtual machine - the application's name, the system's theme, the user's
locale, the battery and the network; and the screen once there is a window,
at the system's scale, which a window on a second screen may not share, and
turned as Windows says (`dmDisplayOrientation`, quarters of the picture's
turn clockwise, the host layer's rotation). The theme is the one Windows
paints its controls in, so a colour written for light and dark reads as
WinUI's own text beside it. Windows says when the theme, the power, the
network or a screen's area changes - a tablet turned among them; the relay
posts each change to the UI thread, and the host tells the core again,
the screen with it, and renders what it changed.

## Acts

The acts the application calls are performed after each turn's render and
answered, a reply or a failure with its reason, so no caller waits on an act
nobody performs - by the host layer's performer, WinUI's part its toolkit's
(`WinUIActToolkit`, [acts](../../host/runtime.md#acts)). The time of day is the system's local time; the zone is the
one the locale reports, an IANA name; a zone's distance from UTC on a day is
ICU's - the ICU Windows carries - taken at the day's noon, so the day decides
summer time, and a zone ICU does not know fails the act. The screen reader is
told through the content of the window the user is in, cutting off what it
was saying. The focus
is put on the view the act names, or the first control in it that takes it;
WinUI has no way to leave the focus nowhere, so taking it off lends it to the
window's content for a moment, as no control, and the on-screen keyboard goes
with a field that loses it. A page asks for the focus as it appears, before
WinUI's next layout: a view a control presents through its template - a split
view's detail, just shown - stands in no window until that layout and refuses
the focus, which then falls to the window's first stop, its title bar, as the
field that held it leaves. So the window lays out what it was given before the
focus moves.

## Questions for the user

A question - an alert, a confirmation, a choice of actions, a prompt - is
WinUI's own dialog, over the window the user is in when its turn comes - the
one activated last, else the first - and its call waits under a ticket the
dialog hands back as the user answers; a ticket is one number across the
process, so an answer that arrives after its renderer has gone answers
nothing of another's. Questions are asked one at a time, in the order the
application asked them, by the host layer's queue ([questions for the
user](../../host/runtime.md#questions-for-the-user)): the next shows once the
one before is answered. A choice of actions is a
button a choice, the dangerous one first, and the pressed caption is the
answer - the cancelling one too; a dialog dismissed any other way, Escape
among them, answers that nothing was chosen. A prompt's field takes the
placeholder, the most characters and the keyboard its purpose asks for.

A dialog needs its window's `XamlRoot`, which a window opened a moment ago -
a page asking as it is made - does not have until WinUI has loaded it. The
question is made at once and shown on the content's `Loaded`; answering it
"not chosen" there would lose it without the user ever seeing it.

## Files

A file dialog is Windows' own, from the Windows App SDK's pickers
(`FileOpenPicker`, `FileSavePicker`), over the window the user is in, and it
waits its turn among the questions ([files](../../host/runtime.md#files)).
A dialog that opens filters by every kind's extensions, as one list; one that
saves offers each kind under its caption, the first as its default
extension. Windows shows the dialog on a thread of its own and hands back a
path: a save's contents are written to it beside the UI thread, and the file
is handed over only once they stand written - or the act fails with
Windows' reason. A file is read beside the UI thread too. A chosen file's
address is its path.

A file or an address is launched through `Launcher`, which answers whether
an application took it. Every answer reaches the host on the UI thread, by
the ticket the call was given.

## Kept values

Windows keeps no store for an application that is no package, so the host
keeps one of its own: a file in the user's local data, in a folder named
after the executable, holding the host layer's text ([kept
values](../../host/runtime.md#kept-values)). Every key the
application lists is read before the first scene connects and handed to the
core ahead of the first view; a key's new value writes the whole file again,
its keys in order, beside the old one first and then in its place, so a
failed write leaves the old. Windows restores no windows either, so the
scenes are kept the same way, in a second file beside it, by the host
layer's rule ([kept scenes](../../host/runtime.md#kept-scenes)): read as the
host starts, and written whenever the scenes it holds write another text.

## Self-contained

An application carries the Windows App SDK beside its executable, with no
package: the runtime of WinUI, Foundation and InteractiveExperiences, a
manifest registering every class each component declares - the registrations
the SDK's own build writes - and `resources.pri`, where WinUI's controls find
their resources. `.scripts/WinUI/tools.ps1` lays them out after each build,
the test runner's included, and owns the versions. What a backend's engine
needs beside an application the backend lays itself, and only beside one
linking it: each `lib/Backends/<Element>.WinUI/SelfContained.ps1` the script
runs looks for its own library there - the web view's lays WebView2's
component and loader.

The manifest stands beside the executable as `<name>.exe.manifest`, which
Windows reads for an executable carrying none of its own. It is not written
into the executable: the build records what it linked, and the next build
links an executable changed since again, even when nothing else has.

## Another architecture

A head is built for the toolchain's own architecture, whose Swift runtime
stands on the search path. An ARM64 machine builds an x64 head too, by
SwiftPM's `--arch x86_64` (its `--triple` builds the toolchain's own whatever
it names), in the same `.build\winui`, each architecture's head in a folder of
its own. Such a head carries the Swift runtime of its architecture beside it,
from the merge module the Swift installer keeps in `Redistributables` - its
`File` table and its cabinet read through `msi.dll`, unpacked by
`expand.exe` - and the Windows App SDK and every backend's engine of its
architecture. A deployed head carries the Swift runtime and Visual Studio's
app-local C++ runtime of its architecture whatever it is, so its folder runs
where neither is installed.
