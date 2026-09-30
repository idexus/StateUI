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
pop changes which page the stack holds; nothing is built again for it.

## The bar

A stack's bar is Android's own toolbar. It carries the title of the page the
window is named by ([the window's chrome](../../host/pages.md#the-windows-chrome)):
tabs pushed onto a stack by their own title, else by the page beneath. A page
with a title view shows that view instead, across the room between the
navigation button and the actions. The bar also carries the stack's bar
colours and the page's actions: the primary ones beside
the title, by priority and then in their order, the rest behind the
toolbar's overflow - each an entry of the toolbar's menu, written as
[menus](menus.md) says. Its navigation button is the way back on a pushed page
whose back button is not taken away; at the root of a split view's detail,
where the sidebar slides over it, it is the sidebar page's picture - Android's
menu glyph where the page has none - and opens the sidebar. The bar's words'
colour - the one written, or white or black against a written background -
is its title's, its navigation button's, its overflow button's and its
actions' pictures'. The actions' words follow the bar's theme, as Android's
own bars do: the toolbar is made in Android's overlay for a dark bar, its
action words light, or for a light one, their words dark - by the host
layer's reading of the bar's colour (`BandWords.light`), as a desktop host
picks its bar's theme - and in the activity's theme where the tree paints no
bar. A view's theme is fixed as it is made, so a bar painted again in the
other shade is made again. A page without a navigation bar hides it. The bar
shows only what changed since it last showed.

A picture on the bar - the navigation button's, an action's - and a tab's
stands at Android's icon size, 24 dp tall and as wide as its shape, whatever
size the picture is drawn at elsewhere: the platform draws its own at that
size, and a picture at its own size stood twice as tall as theirs.

## A split view

Where the room is narrower than 720 points - a phone, a tablet upright - the
sidebar is a drawer sliding over the detail from the leading edge, the
detail shaded behind it; a tap on the shade closes it. Where the room is
wider, the sidebar stands beside the detail while it shows. The slide is
Android's own animation, so the system's "remove animations" setting takes
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
bottom, one for each tab with its picture over its title. On a bar colour
the tree writes, the words are white where the colour is dark and the
text's own where it is light, the chosen tab full and the others dimmed. A
tab the user chooses shows its page, and is reported into the selection; a
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

## A modal stack

The pages a window's modal stack presents stand over its page in the
activity's root, in order, the top one in front, each in a holder on the
theme's window background that takes every touch meant for the page beneath.
A page rises from the bottom as it comes and goes down as it leaves - at once
where the user asks for less motion. The page in front is the one presented:
the page beneath hears it disappear, and appear again when the one over it
goes. Back is the page in front's own way first - a stack inside it pops -
and then that page going down, which the window reports as `modalPopped`
with the pages left, so the state that holds the stack follows.

A page the program takes off the stack has already left the tree when the
stack is shown again, so the host holds each presented page, and the shown
arrangement, by its mounted element, which owns its Android half: the page is
still whole as it goes down, and is let go with its holder.

## The window's overlay

What a window lays over everything it shows - the inspector docked in it -
stands in the activity's root as its top child, over the page and over every
page the modal stack presents: a page that rises after it lifts the overlay
over itself again. It is laid out over the whole root, and takes no touch of
its own, as no StateUI layout on Android does: a touch beside what it holds
goes on to the page under it. The host holds the overlay by its mounted
element, as it does the arrangement, and takes its view out of the root when
the window no longer describes it.
