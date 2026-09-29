# The AppKit runtime

What the AppKit runtime holds, and what it reads of the Mac it runs on and
tells the core, beside what [the host layer](../../host/runtime.md) shares with
every runtime.

## The AppKit runtime

`AppKitRenderer` holds the host layer's runtime (`HostRuntime`) and adds what
is AppKit's: the windows, native window restoration, the page menus in the
application's menu bar, the pictures, the doorbell on the main queue. It presents what a turn rendered through the `Pump`
(`TurnPresenter`): the windows kept in step with the tree, the restored
windows offered to their scenes - a restored window no scene claims by the
presentation after its offer is declined - and it performs the acts the
application calls. A window's or a scene's phase, and what the user settled
on a native control after the phases it moved, wait in the pump's queue and
are rendered in their turn.

## The window

Each window element the tree holds is shown in an `NSWindow` of its own, kept
by a window controller in the tree's order (`WindowRoster`); a window the
tree no longer holds closes, the last first, telling nothing. What a window
shows comes from the host layer (`WindowPresentation`): its arrangement of
pages is the window's content under one unified toolbar ([the window's
chrome](../../host/pages.md#the-windows-chrome)), the pages its modal stack
presents are sheets, and the page the user sees and the window made are told
before the window first comes to the front. A new window with no place asked
stands centred, each after the first a step down and to the right.

## A window's frame

A window stands where the host layer says its element asks ([a window's
frame](../../host/tree.md#a-windows-frame)), each request alone. A size is the
content area the title bar and toolbar leave, the window keeping its top
edge; a place is counted from the top left of the screen's work area. The
bounds are the content area's too, the chrome's height added, as AppKit
bounds the whole content view, and are applied again on every presentation,
since the chrome grows with a row of tabs; what the tree leaves unsaid is the
window's own. The traits ([a window's traits](../../host/tree.md#a-windows-traits))
are the zoom and minimize buttons, a window the desktop shows through, and
the floating level while the application is in front. A window of a kind of
its own stands apart from its scene's main window, as a Mac's auxiliary
windows do, and out of the Windows menu.

## The application's phase

What AppKit tells a window's delegate - the keyboard coming and going,
minimizing and coming back - and the application's being hidden settle into
the phases of the application, its scenes and its windows by the host
layer's rule ([the application's
phase](../../host/runtime.md#the-applications-phase)): each tells whether the
window stands minimized and whether it holds the keyboard. Another
application in front takes the keyboard from every window, which is all
AppKit tells of it. A window its scene hides is ordered out, and ordered in
again without the keyboard. A window the user closes is heard by it and its
scene; the application ending tells each scene's windows, then the scene.

## Restored windows

The system restores a Mac's windows itself: each window encodes its
restoration record - its scene's identifier, its kind, its value, the scene's
kept values - and the system hands it back to the restoration class before
the application finishes launching. A restored main window connects its
scene with the values it kept (`AppKitSceneSession`); a restored window of a
kind of its own is offered to the scene that owns it, and taken by the window
the scene opens for its kind and value. One no scene claims by the
presentation after its offer is declined, and one whose scene never comes is
let go after three seconds. The system keeps a restored window's frame too, so
a window keeps nothing in the application's preferences: a frame autosave
name, one a window, would leave a key there for every window ever opened,
and every move would write the growing file again.

## The menu bar

Every application stands with the menu bar a Mac application has: its own
menu with Quit, File with a new window, Edit and Window. Edit holds the text
commands - undo, redo, cut, copy, paste, delete, select all - each sent down
the responder chain, where the field holding the keyboard answers it: AppKit
routes ⌘C, ⌘V and ⌘Z through the menu bar's key equivalents, so a field in an
application with no Edit menu copies and pastes nothing. A page's menus join
the bar as the page shows, into the menu of the same name where there is one.

## The toolbar

A window's toolbar holds the chrome its arrangement composes. A layout the
tree stands in it - a title bar's leading or trailing content, a page's
title view - is held in a slot at the size StateUI measures it at: AppKit
measures a toolbar item's view by its constraints and warns of any it
measures at nothing, so a layout holding nothing stands out of the toolbar,
and in it again once it holds something.

## Acts

The acts every host performs (`HostActs`) are AppKit's own calls: the time
of day and the zone from the system's calendar, a zone's distance from UTC
on the day asked - a zone the system does not know fails the act - a word to
the screen reader as an announcement over whatever it was saying, and the
focus through the window's first responder. An act of the application's own
is its registered performer's (`InteropActs`), handed the view an aimed act
names; a performer may await.

## Questions for the user

A question is AppKit's own alert, a sheet on the window the user is looking
at, one at a time (`QuestionQueue`): a confirmation's and a prompt's accepting
button first, a choice's actions, its dangerous one marked, then its cancel.
A choice answers the caption pressed, its cancel's included; a prompt its
field's words, cut to their bound. A host that shows no window holds the
alert unshown, answered as a press answers it.

## The environment

The device, the main display, the application and the system's appearance are
told as the runtime starts. The user's locale, the battery and the network are
told as the application starts and again whenever one changes, for as long as
it runs, each change through the runtime's one step for it: the system's
appearance when it turns, the locale when the user or the time zone changes it, the battery when
macOS reports its power source or Low Power Mode turns, the network when its
path moves. The locale's language decides the root's layout direction. It is
the locale macOS resolves for the application - its bundle's localization
nearest the user's languages - so an application localized in no language
written right to left lays out left to right, as AppKit's own controls do. A Mac
with no battery reports none - full, on mains - and Low Power Mode as the
battery saver. The network is reachable when its path is satisfied, local when
interfaces stand but no route leads out; each interface in use - Wi-Fi, wired,
cellular - is a connection profile.
