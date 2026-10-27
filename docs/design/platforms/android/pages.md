# Pages on Android

How the Android Views host shows a window's pages: a stack under its bar,
a sidebar that slides over the detail, tabs along the bottom, the phases each
page hears, and the way back. The arrangements are the application's state,
as [navigation](../../../interface/navigation-and-presentation.md) says; the host shows
what the tree says and reports what the user does into the same bindings.

## A navigation stack

A stack shows its top page under its bar. The pages below are kept by their
elements and held by no view, so each keeps what it showed - where it was
scrolled, what was typed - for when the user comes back to it. A push or a
pop changes which page the stack holds; nothing is built again for it. The
change moves by Android's own transition (`TransitionManager`): a page pushed
slides in from the end over the one it covers going toward the start, one
popped back to the other way, as the host layer says the path changed
([a path that changes](../../host/pages.md#a-path-that-changes)). Both slides
run on one easing: a `Slide` eases a page arriving and a page leaving each its
own way, which crosses them; on one, the arriving page's edge travels on the
leaving one's. Each page stands on its ground
([a page's ground](../../host/pages.md#a-pages-ground)), so even crossing they
would not mix.

## The bar

A stack's bar is Android's own toolbar - a setting among its actions a
checkable item, its state shown on the bar by its on picture alone and by
its check behind the overflow. It carries the title of the page the
window is named by ([the window's chrome](../../host/pages.md#the-windows-chrome)):
tabs pushed onto a stack by their own title, else by the page beneath. A page
with a title view shows that view instead, across the room between the
navigation button and the actions. The bar also carries the line under the
title and the colors the page's path declares, the nearest of each - a blur
as its color, as Android blurs nothing behind a bar, a gradient drawn as a
view's background is, fitted to each size the bar is placed at
([the bar a path declares](../../host/pages.md#the-bar-a-path-declares)) -
an arrangement changing one refreshes every bar under it. A color that
travels, and what a page says of the bar from a state - its title, its way
back, the bar itself - land on a frame, where nothing arranges the stack:
where the host layer says the frame moved the window's chrome
([one frame](../../host/runtime.md#one-frame)), every bar the window and its
sheets show is shown again. The bar carries the actions the page declares: the ones on the bar
beside the title, as the host layer composes them - the leading groups
first, the bar having no leading edge beside its navigation button, each group
a group of the toolbar's menu, drawn in one row as Android's toolbar draws its
actions - the rest behind the toolbar's overflow - each an entry of the
toolbar's menu, written as
[menus](menus.md) says, and the menus the path declares behind the overflow
after them. Its navigation button is the way back on a pushed page
whose back button is not taken away. On every page of a split view's detail,
while the sidebar does not stand beside it shown and the split view offers its
toggle (`offersSidebarToggle`), the navigation button is
the sidebar's toggle - the sidebar page's picture, Android's menu glyph where
the page has none - which shows the sidebar, and the way back stands right
after it: the toolbar lays its own title out before any view it holds, so
the title then stands in a row of the bar's after that button, in the
appearances the toolbar's style names for its own words. The bar stands at
least the theme's bar height (`actionBarSize`) under what it reaches
beneath, actions or none, so a split view's two bars stand as one. The bar's words'
color - the one written, or white or black against a written background -
is its title's, its overflow button's, its actions' pictures' and its back
arrow's or menu glyph's; a sidebar page's own picture keeps its colors.
The actions' words follow the bar's theme, as Android's own bars do: the
toolbar is made in Android's overlay for a dark bar, its action words light,
or for a light one, their words dark - by the host layer's reading of the
bar's color (`BandWords.light`), as a desktop host picks its bar's theme -
and in the activity's theme where the tree paints no bar. A view's theme is fixed as it is made, so a bar painted again in the
other shade is made again. A page without a navigation bar hides it. The bar
shows only what changed since it last showed.

A picture on the bar - the navigation button's, an action's - and a tab's
stands at Android's icon size, 24 dp tall and as wide as its shape, whatever
size the picture is drawn at elsewhere: the platform draws its own at that
size, and a picture at its own size would stand twice as tall as theirs.

A bar's button holding a menu its click opens stands on the bar as a
submenu - Android's action item opening its menu - counted among the items,
its id its place plus one. One that splits or is held stands as its action,
its menu behind the overflow under its words: the bar has no arrow part and no
hold of its own. Android numbers the items in the order the menu is written,
so each item's place is given in that order: an action, the entries of a menu
it opens there, and the overflow's menus after every action.

The weight the path gives the bar's buttons' words is a typeface span over
the words of each item standing on the bar - an action, a menu it opens there
- and of none behind the overflow, whose rows are a menu's, not the bar's
buttons. A change of it on an arrangement shows the bars under it again, as
their colors do (`barValues`).

## A split view

Each column stands under a bar of its own, Android's toolbar as a stack's
is (`AndroidColumnView`), and the split view's one bar stands in two parts
over them ([a page's actions](../../host/pages.md#a-pages-actions)). The
sidebar's shows the title area the sidebar's page names the application with
(`titleArea(applicationName:)`) - its title, else the application's name,
the line under it and its picture as the mark before them - in the colors its
path declares, the sidebar's toggle in Android's menu glyph, which hides the
sidebar, and the actions of the sidebar's part after it - Android's toolbar
stands its menu of actions last. A detail
that is a page shows its own as a stack's top page does - its title, the line
under it, the actions of the detail's part and its menus, the sidebar's toggle
first where the sidebar does not stand beside it; a stack or a tabbed view in
the detail brings its own bars. The bar reaches under what stands over the
top, the column's page below it. Beside the detail the column stands apart
from it by the theme's line between panes (`dividerVertical`) down its edge
toward the detail; a drawer over the detail stands on its own edge.

Where the room is narrower than 720 points - a phone, a tablet upright - the
sidebar is a drawer sliding over the detail from the leading edge, the
detail shaded behind it; a tap on the shade closes it. The drawer stands on
the theme's floating surface (`colorBackgroundFloating`), its end corners
rounded as a modal drawer's, with the split view's overlay material - else the
window's background - laid over it, so a clear window still leaves the drawer
opaque. Where the room
is wider, the sidebar stands beside the detail while it shows, on the split
view's sidebar material, else on nothing: the window shows through
([a sidebar's material](../../host/pages.md#a-sidebars-material)); it moves
in from the leading edge by its own width as it shows and out as it hides,
the detail narrowing and widening with it by Android's own transition
(`ChangeBounds`, the detail's alone, on the sidebar's easing and length) - a
`Slide` would travel the whole split's width and take whatever appears with
it, the detail's bar's new title among them - and the detail's bar changes in
place; at once where the user asks for less motion. Android
blurs nothing behind a view, so a blur stands as its color. The
slide is Android's own animation, so the system's "remove animations" setting takes
it away. Opening the drawer lays the page out again - the bar changes - and a
layout leaves a sliding drawer sliding: only a new room, the drawer wider or
beside the detail, puts it in place at once. A closed drawer holds nothing
the keyboard or assistive technology reaches: it stands invisible once it has
slid away, and shows as it starts to slide open. Whether the sidebar shows is the split's binding: the user's
opening and closing are reported into it, and a value the tree writes moves
the drawer. The first room at least 720 points wide shows the sidebar, said as
the user's ([a sidebar on the first
room](../../host/pages.md#a-sidebar-on-the-first-room)).

## Tabs

A tabbed view shows the chosen tab's page over a row of tabs along the
bottom, one for each tab with its picture over its title. On a bar color
the tree writes, the words are white where the color is dark and the
text's own where it is light, the chosen tab full and the others dimmed; the
chosen one is selected, so TalkBack says which it is. A tab the user chooses shows its page, and is reported into the selection; a
value the tree writes chooses the tab, by the host layer's rule
([tabs](../../host/pages.md#tabs)); the row stands at the bottom edge
(`RowEdge`).

## A page's phases

A page hears that it appears and disappears, and on a stack that it is
navigated to and from, once Android shows what the tree shows, by the host
layer's rule ([a page's phases](../../host/pages.md#a-pages-phases)). Each phase is
rendered before the next one is heard, so the application sees every one: a
push says the leaving page's phases, then the arriving page's. A page that
has left the tree hears nothing more.

## The way back

The system's back takes a sidebar open over the detail first - it closes -
then the way back the host layer says the window offers ([the way
back](../../host/pages.md#the-way-back)): the top sheet's own stack, else the
top sheet, else the arrangement's stack. Android's back is the system's, not
the bar's, so a page hiding its bar still goes back by it where it keeps its
way back. A sheet going only tells the window how many remain; the sheet
goes as the tree follows. The system's back asks the host first, and the host
tells the activity whenever it has a way back, so from Android 13 the
system's predictive back animates to the launcher only where the application
has nowhere to go back to.

## The safe area

The activity draws edge to edge on every system it runs on - its window
behind the status bar, the navigation bar and a cutout, the bars clear and
their words dark on a light theme - and its root hears what stands over each
edge as it changes: the system's bars and a cutout, and the keyboard, which
no longer makes the window smaller, its height counted at the bottom where it
is taller. Each arrangement passes that down ([the safe
area](../../host/layout.md#the-safe-area)): a stack's bar reaches under the
top, its words clear of it and of the sides (`Clearance.underABarAtTheTop`),
a row of tabs under the bottom (`overABarAtTheBottom`), a split view's sidebar
and detail under the whole; each leaves its page the rest. A page stands its
content clear of what is left, or under it where the content says so, and a
scroller let under keeps it as Android's own padding with its content drawn
through, so its offset counts from its first row as Android counts it. A
sheet filling the window stands under the same; a card stands clear in the
middle.

## Sheets

A stack in a sheet brings its bar; where its page offers no way back, the
bar's navigation button is the sheet's close - Material's cross - unless the
page says it offers none.

The pages a window's views present stand over its arrangement in the
activity's root, in the order they showed, the top one in front, each in a holder that takes every touch meant for
the page beneath. In a window narrower than 600 points the holder fills it on
the theme's window background, the page rising from the bottom as it comes and
going down as it leaves. In a wider one the page stands on a card in the
middle as the platform's dialog does - the theme's background, its
`dialogCornerRadius`, over the shade of its `backgroundDimAmount` - as large
as its page asks ([a sheet's size](../../host/pages.md#a-sheets-size)): at
least 280 x 180 points, 560 x 640 for a page asking none, at most a dialog's
560 wide and the window less 24 a side; it fades in and out. The card, or
the holder filling a narrow window, stands on its window's background laid
over the theme's own ([a page's ground](../../host/pages.md#a-pages-ground)),
the theme's alone where the window says none, and is grounded again as that
background changes. Either moves at
once where the user asks for less motion; the window's size is the
configuration's, known before the root is laid out. The page in front is the one presented:
the page beneath hears it disappear, and appear again when the one over it
goes. Back is the page in front's own way first - a stack inside it pops -
and then that page going down, false written onto its sheet's state.

A page the program takes away has already left the tree when the window
shows again, so the host holds each presented page, and the shown
arrangement, by its mounted element, which owns its Android half: the page is
still whole as it goes down, and is let go with its holder.

## A popover

A view's popover is the relay's `StateUIPopover`: Android's `PopupWindow`,
made with the theme's popup style - its background, its elevation, its
animations - holding the popover's view at the size the view measures,
below its anchor, above it where there is no room below. It takes the
focus, so a touch beside it and Back take it away. The program's own
closing is told apart; a dismissal it did not ask for reaches the host as
the view's `closed`. An anchor not yet in a window shows its popover once
it is attached.

## The window's overlays

What a window lays over everything it shows - the overlays the pages on its
visible path declare, then the inspector docked in it - stand in the
activity's root as its top children, the first lowest, over the page and over
every sheet: a page that rises after them lifts them
over itself again. Each is laid out over the whole root, and takes no touch
of its own, as no StateUI layout on Android does: a touch beside what it
holds goes on to the page under it. The host holds the overlays by their
mounted elements, as it does the arrangement, and takes their views out of
the root and lays them again when the list it is told changes.
