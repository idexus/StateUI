# The AppKit runtime

What the AppKit runtime holds, and what it reads of the Mac it runs on and
tells the core, beside what [the host layer](../../host/runtime.md) shares with
every runtime.

## The AppKit runtime

`AppKitRenderer` holds the host layer's runtime (`HostRuntime`) and adds what
is AppKit's: the windows, native window restoration, the page menus in the
application's menu bar, the pictures, the turn after every pass of the main run loop. It presents what a turn rendered as the runtime's
`HostPresenter`: the windows kept in step with the tree, a window element
new to it taking the window the system restored for it where one waits - and
it performs the acts the application calls. A window's or a scene's phase,
and what the user settled on a native control after the phases it moved, wait
in the host layer's queue of handlers - a phase through
`HandlerDispatch.enqueuePhase` - and are rendered in their turn.

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
the floating level while the application is in front. Every window stands
in the Windows menu.

A window with a maximum takes no full screen: AppKit would stand it at its
maximum in the middle of the screen, the toolbar alone across the top in the
system's colour. Its zoom button grows it to the maximum instead, the way a
bounded window maximizes on every desktop; with the maximum cleared, the
window's own full-screen behaviour is back.

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
scene; the application ending tells every window. *File ▸ New Window*, and the
Dock with no window open, open one more window of the group with no name.

## Restored windows

The system restores a Mac's windows itself: each window encodes its record's
text (`WindowRecord`) as its restorable state, and the system hands it back
to the restoration class before the application finishes launching, which
gives it to the renderer (`AppKitRestorationBroker`). What happens to it then
is the host layer's, the same on every host whose platform restores windows
([restored windows](../../host/runtime.md#restored-windows)); AppKit makes
the window it comes in, and hands the system none for a window refused, which
then restores nothing. Where the system restored none by the time the
application finished launching, the host connects a new one: the window launch
opens.
The system keeps a restored window's frame too, so
a window keeps nothing in the application's preferences: a frame autosave
name, one a window, would leave a key there for every window ever opened,
and every move would write the growing file again.

## The menu bar

Every application stands with the menu bar a Mac application has: its own
menu with Quit, File with a new window, Edit and Window. Edit holds the text
commands - undo, redo, cut, copy, paste, delete, select all - each sent down
the responder chain, where the field holding the keyboard answers it: AppKit
routes ⌘C, ⌘V and ⌘Z through the menu bar's key equivalents, so a field in an
application with no Edit menu copies and pastes nothing. File, Edit and
Window carry their `StandardMenu` identity as their item's identifier.

The menus the key window's visible page composes (`chromeMenus`) join the bar
as it shows and leave it as it goes: one whose identity is a standard menu
the bar holds joins it as a section after its entries, parted by a line; a
standard one the bar holds none of stands where the platform puts it - View
after Edit, Help last - and any other before Window. Each entry is a copy of
the page's item in a menu that enables its items by asking, so the element
it tells answers whether it can be chosen (`validateMenuItem`), as the tree
says.

## The toolbar

A window's toolbar holds the chrome its arrangement composes: each group of
actions a run of items with a space between it and the next, so each keeps a
background of its own, the leading groups before the flexible space and the
trailing ones after it. A layout the
tree stands in it - a page's title view - is held in a slot at the size
StateUI measures it at: AppKit
measures a toolbar item's view by its constraints and warns of any it
measures at nothing, so a layout holding nothing stands out of the toolbar,
and in it again once it holds something. A search field standing in the
title's place is the toolbar's own search item's field
(`NSSearchToolbarItem.searchField`), which AppKit draws as its rounded
field: held as a plain item's view, a field in a macOS 26 toolbar is drawn
with no field at all.

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

## Files

A file dialog is AppKit's own panel, a sheet on the window the user is
looking at, waiting its turn among the questions
([files](../../host/runtime.md#files)). An open panel enables the files of
every kind's extensions and chooses several only where asked; a save panel
offers each kind once, by its first extension, under its caption in the
panel's menu of kinds where there are two or more, and suggests the act's
name - an empty name is the panel's own. A save's contents are written
beside the UI thread where the user said, in place, as a sandbox lets an
application write the file the user chose and not a neighbour swapped in;
the file is answered once they stand written, or the act fails with the
system's reason. A chosen file's address is its path; the sandbox keeps it
the application's while it runs. A file is read beside the UI thread too.

A file or an address is launched through `NSWorkspace`, which answers
whether an application took it; an address with no scheme is taken by none.
A host that shows no window holds the panel unshown, answered as the user's
choice answers it, and a test holds launches back, recording them.

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
