# Pages on UIKit

How the UIKit host shows pages and their arrangements: each held by a view
controller of UIKit's own, so a page stands under UIKit's bars, goes back by
UIKit's gestures and sits in UIKit's tab bar and split view, and the user's
choices on them are handed to the host layer, which tells the pages and the
states.

A page is a controller whose view holds the page's own view within the safe
area its bars leave. An arrangement of pages is the controller UIKit has for
it; the window's arrangement is a child of the window's root controller, over
the whole window.

## The safe area

A page's view stands in its controller's safe area, clear of the screen's
bars, the notch, a stack's bar, the tabs and an iPad window's own controls in
its corner (the safe area with its corner adapted), and out to the
controller's edge where its content lets itself under them ([the safe
area](../../host/layout.md#the-safe-area)) - under the glass of a stack's bar
too; a scroller let under keeps their depth as its content inset, its offset
counted from its first row clear. The controller's own view shows the page's
background, so it stands behind the bars either way. Only a page's own layout
reaches under them; one deeper in stands where its page puts it. A sidebar
beside the detail is no part of it: UIKit lays the detail's column under the
sidebar and counts the sidebar in its safe area, so a detail's page takes the
sidebar's inset off its whole room too, and runs under the bars but never under
the sidebar - as far from its leading edge as the sidebar has come while it
slides. A frame report's safe area is that same one -
the page's, under its stack's bar as well as the status bar - so a view at its
page's top corner reads nothing from it.

## The bar

A page's bar is its navigation item: its title and the line under it the page
says, its `subtitle` - a sidebar's page that says no title names the
application - or the view standing in for them, its actions as the host layer composes them along the page's path, each
group a `UIBarButtonItemGroup` of its own, so each keeps its own shared
background, the leading ones beside the way back, those beyond the bar in a
menu behind its last button - a picture on the bar, titled More, the word
UIKit's own menu of what a narrow bar has no room for and VoiceOver say of
it - whether it offers the way back, and its material and colors - a blur UIKit's
own effect in its thickness under its tint, glass the system's own bar
where the tree gives them, a gradient the picture UIKit takes for a bar's
background, drawn as large as the background stands - the bar's width, from
the top of its stack's view under the status bar to the bar's bottom edge,
a tab bar's whole size - and drawn again as the bar takes another width. The view standing in for the title is fitted to
what it holds as it comes, and a layout again at every render; a control -
a search field - keeps the width the bar gives it, since a fit to its words
at every render would cut it as the user types and the bar would widen it
again. An action that destroys something is marked destructive in the menu
and tinted red on the bar. A setting is UIKit's two-state bar button
(`changesSelectionAsPrimaryAction`), selected while on, and checked
(`UIAction.state`) behind the overflow. A clear bar is UIKit's transparent bar: nothing
under it and no line - an opaque bar of a clear color would draw its line
under nothing. A tabbed view's bar is its chosen tab's page's, but for its
title: the page the window is named by ([the window's
chrome](../../host/pages.md#the-windows-chrome)) - tabs pushed onto a stack
by their own title, else by the page beneath - which names the window's
scene too. Every bar in the window is written again as the window is shown,
so a bar always says what its page says now.

A bar's button holding a menu is a bar button with a menu: its tap opens it
where the button has no click of its own, else holding it does - UIKit's bar
offers no arrow part, so a split stands as held. The menu carries its
element's identifier, as an action does.

## Pictures on the bars

A picture on a bar - an action's - stands 20 points tall, as a symbol stands
in the glass circle of a bar's button with room around it, and a tab's 25,
UIKit's own tab icon size, each as wide as its shape makes it
(`PictureArithmetic.glyph`); on a phone on its side, whose bars stand
lower, both stand 18 points tall (`landscapeImagePhone`). The picture keeps
its pixels and is drawn smaller: at its file's size it stands far taller
than the system's own pictures beside it. An icon is its SF Symbol
(`Icon.sfSymbol`), a template image the bar colors as it does its own.

## A page's background

A page paints its background behind the whole screen it stands on, the bars
and the notch included. A page that says none paints the window's - what the
window is made of under a page that paints nothing of its own, which a
UIKit window shows only through its pages: each controller's view is opaque
by convention - and with neither the system's background. The window's
background is the window's `backgroundColor`, so a page reads it as it
appears, and the window has every page under it paint again when its
background changes. A split view's sidebar page that paints nothing stands
on the split view's material for its place instead ([a sidebar's
material](../../host/pages.md#a-sidebars-material)) - over the detail, the
window's background when the split view says none, the system's where the
window says none too - and
the split view has its pages paint again as its room or its materials
change. A blur or glass behind a window shows its color
(`HostMaterial.painted`): iPadOS draws an application's window opaque.

## A navigation stack

A NavigationStack is UIKit's navigation controller over its pages, the top
one showing, and the bar hidden where the top page hides it. Pages joining on
top are pushed, the last arriving, and pages taken from the top are popped in
one move back, as UIKit does it, by the host layer's rule
([a path that changes](../../host/pages.md#a-path-that-changes)); any other
change, or one for a user who asked for less motion, shows without a move. The user taking pages away - the back button, the edge swipe, the
back button's menu - is told to the stack as how many stay, as the index of
its top; where the application keeps its pages, the stack stays as it is.
UIKit tells it once the move ends, so a render while the pages go still
describes them: the stack does not show them again, which would undo the
user's way back. A page comes in already wearing its bar: UIKit takes the
bar's look as the move starts, and a layout in the same turn - a sidebar
going away - can start it before the window's chrome is composed. A page
shown without a move - the top replaced by another - is laid out at once: a
move begun in the same turn, a sidebar going away, then carries it from its
place, where UIKit would lay it out within that move and grow it from nothing.

## Tabs

A TabView is UIKit's tab bar controller, each tab named by its page's
title and picture. Which tab shows is the host layer's rule: none chosen
until the tree or the user chooses one, a tab the tree asks for anew chosen,
the user's choice standing where it is a tab there is. The user's choice is
told as the tab before and the tab now; one the program makes is not.

## A split view

A SplitView is UIKit's split view controller: its sidebar the first column,
its detail the second, a page standing alone in a column under the column's
own bar. It is never one column. In a narrow room - a phone, upright or on
its side - the sidebar slides over the detail from the leading edge, the
detail shaded behind it, opened by the sidebar button UIKit puts on the
detail's bar or a swipe from the edge and closed by a tap on the shade; in a
wide room it stands beside the detail. UIKit shows that button unless the
split view offers none (`displayModeButtonVisibility` `.never`); the swipe
stays. The split view says it is wide
whatever the room (`traitOverrides`), so UIKit never folds it into one
column, and each column says the room's own width, so the tabs, sheets and
bars inside stand as a phone's.

A sidebar the application paints ([a sidebar's
material](../../host/pages.md#a-sidebars-material)) stands apart from the
detail by a line of UIKit's separator color, one point down its column's
edge, the host's own: it stands on UIKit's sidebar material like the
platform's own sidebar, which UIKit parts by no line. UIKit's plain column
(`primaryBackgroundStyle` `.none`) would part them by its own, but the detail
of a plain column takes its new width at once as the sidebar shows or hides,
where under the sidebar material it slides with it. A blur or glass for the sidebar's
place is UIKit's own effect under what the sidebar page shows - a blur's tint
washed over it, glass tinted in itself - beside the detail and over it alike;
a color is the page's own background.

Whether the sidebar shows is the display mode the host prefers: over or beside
the detail while the tree asks for it, the detail alone while not. The tree's
move is UIKit's own (`show`/`hide` of the sidebar's column), which moves the
columns together with a page pushed in the same turn; an animation of the
host's own would lay the page's first frame out inside it and grow it from
nothing. The sidebar showing or hiding on screen is heard as the display mode
changes, whoever moved it; the program's own move and the host's adapting to a
new room are not told back. The traps: sliding over the detail, UIKit tells no
column shown or hidden (`willShow`/`willHide` stay silent for the sidebar);
entering its window it settles a display mode of its own before the first
layout, which is no user's move; and its sidebar button item is handed out
bare - the one on the bar is UIKit's own.

Beside a wide detail the detail's column spans the whole room under the
sidebar and never moves, and UIKit gives its page the safe area of where the
sidebar is going at once. So the detail's shown pages follow the slide
themselves ([a sidebar sliding](../../host/motion.md#a-sidebar-sliding)): as
the display mode changes, a `SplitSlide` follows UIKit's own spring - its
time, never slowed - and each frame stands every shown page's content as far
from its leading edge as the sidebar has come, in place of the safe area's
inset; resting, the page takes its safe area again. The sidebar's column
moves under UIKit's presentation modifiers, with no animation to read, so a
page following where the column is drawn stands a frame behind it: the
slide follows the spring, not the column.

## Sheets

A stack in a sheet brings its navigation bar, whose pages offer UIKit's close
button at the trailing edge (`UIBarButtonItem` `.close`) unless a page says it
offers none.

The pages a window's views present are UIKit's form sheets - a card in the
middle of a wide screen, rising from the bottom of a narrow one; a page sheet
would stand over nearly the whole of an iPad's screen. A sheet asks UIKit for
its page's size ([a sheet's size](../../host/pages.md#a-sheets-size)) by its
`preferredContentSize` - at least 320 x 180, within the window less 32 points
a side - which a wide screen keeps and a narrow one passes over; a page asking
none asks nothing, and stands at UIKit's own size. A sheet's page stands on
its window's background as every page does ([a page's
ground](../../host/pages.md#a-pages-ground)). Each is presented over the one
before once that one stands - UIKit presents over a controller only then -
and all of them only once the window stands on screen: a sheet presented
before, UIKit takes away again at once and tells as the user's. Which stay
and which go is the host layer's rule ([sheets](../../host/pages.md#sheets),
`SheetChange`): those standing as asked, counted from the bottom, stay; the
rest go from the top. Nor does UIKit present over a controller whose sheet
is still coming or going: it drops the request and says nothing, and the
window would hold a sheet never shown. So while a sheet the
window presented or took away still moves, what is asked waits - the latest
asking - and comes as that movement ends. The user swiping the top sheet down
is the window's way back, false written onto its state. UIKit does not always
tell the presentation's delegate: on an iPad, form sheets over one another
swiped down one by one tell only every other one. So each sheet tells the root
as it leaves the screen (`UIKitSheetStanding`), and the root holds its sheets
against UIKit's own: from the first being taken away or gone, each over it is
the user's; a window that leaves tells
nobody of its sheets, which leave with it. A window whose scene iOS lets go of
and brings back takes nothing UIKit kept presented over its root - UIKit takes
that away in its own time, dropping what is presented over it meanwhile - so
the root takes it away first and presents what is asked for anew; a movement
that began in the window gone ends there and does nothing.

The overlays are laid over the window's pages within the safe area, the first
lowest, and a touch beside what one holds reaches the page under it.

## What passes over the sheets

A question, a file dialog and a preview pass over what the window shows, and
UIKit presents one thing over a controller at a time: a question asked in the
turn a sheet is asked for would be dropped, or would stop every sheet after it.
So the window's root presents everything (`UIKitRootViewController.pass`):
what passes waits until no sheet moves, then stands over the top sheet -
centered, where it stands as a popover with nothing to point at - and the
sheets asked for while it stands wait until it has gone. It goes with its
answer (`passed`): UIKit's own dismissal is let finish, else the root
dismisses it, and then what waited comes - the sheets first, then the next
thing passing.

## A popover

A view's popover is a controller presented in UIKit's popover style from
its anchor's view, sized to what it holds - a popover on a phone too. What it
holds stands in the popover's safe area by the rule every room keeps ([the
safe area](../../host/layout.md#the-safe-area)): iOS 26 lays the controller's
view under the arrow and says so by its safe area, iOS 27 moves the view clear
of the arrow itself. It passes over what the window shows like everything else that
passes ([what passes over the sheets](#what-passes-over-the-sheets)), so it
waits for a sheet in motion. A tap beside it or a swipe reaches its
delegate, which tells the host.

## Menus

A menu is UIKit's, built from the host layer's walk of its entries: an
action for each item, which tells its element when the user chooses it, a
submenu for each menu, and the entries between two separators a group of
their own, as UIKit parts a menu. UIKit holds no menu out of reach itself: a
menu out of reach holds each of its entries out of reach.

A view's context menu is UIKit's context menu interaction, which asks for
the menu as the user holds the view; it is built then from what the tree says
now. The menus the page the user sees composes (`chromeMenus`) are the
application's main menu - on an iPad its menu bar. One whose identity is a
standard menu stands as a section at the end of UIKit's own menu of that
identity (`UIMenu.Identifier.file`), one UIKit keeps none of where UIKit's
would stand - View after Edit, Help after Window - and any other before
Window. UIKit changes no built menu in place, so the main menu is built again
whenever they show something else - a word, a check, a destructive mark, a
picture, a shortcut - or an entry answers another element, as the host layer
says them (`MenuEntry.Said`): every action carries its element's identifier
(`actionIdentifier`), which UIKit keeps in the copies it makes, so a page's
Save standing in the window's place with the same words still rebuilds it.
