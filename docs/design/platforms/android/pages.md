# Pages on Android

How the Android Views host shows a window's pages: a stack under its bar,
a sidebar that slides over the detail, tabs along the bottom, the phases each
page hears, and the way back. The arrangements are the application's state,
as [navigation](../../../navigation-and-presentation.md) says; the host shows
what the tree says and reports what the user does into the same bindings.

## A navigation stack

A stack shows its top page under its bar. The pages below are kept by their
elements and held by no view, so each keeps what it showed - where it was
scrolled, what was typed - for when the user comes back to it. A push or a
pop changes which page the stack holds; nothing is built again for it.

## The bar

A stack's bar is Android's own toolbar. It carries the visible page's title -
or its title view, standing across the room between the navigation button and
the actions in the title's place - the stack's bar colours, and the page's
actions: the primary ones beside
the title, by priority and then in their order, the rest behind the
toolbar's overflow - each an entry of the toolbar's menu, written as
[menus](menus.md) says. Its navigation button is the way back on a pushed page
whose back button is not taken away; at the root of a split view's detail,
where the sidebar slides over it, it is the sidebar page's picture and opens
the sidebar. A page without a navigation bar hides it. The bar shows only
what changed since it last showed.

## A split view

Where the room is narrower than 720 points - a phone, a tablet upright - the
sidebar is a drawer sliding over the detail from the leading edge, the
detail shaded behind it; a tap on the shade closes it. Where the room is
wider, the sidebar stands beside the detail while it shows. The slide is
Android's own animation, so the system's "remove animations" setting takes
it away. Whether the sidebar shows is the split's binding: the user's
opening and closing are reported into it, and a value the tree writes moves
the drawer.

## Tabs

A tabbed view shows the chosen tab's page over a row of tabs along the
bottom, one for each tab with its picture over its title. On a bar colour
the tree writes, the words are white where the colour is dark and the
text's own where it is light, the chosen tab full and the others dimmed. A
tab the user chooses shows its page, and is reported into the selection; a
value the tree writes chooses the tab.

## A page's phases

A page hears that it appears and disappears, and on a stack that it is
navigated to and from, once Android shows what the tree shows. Each phase is
rendered before the next one is heard, so the application sees every one: a
push says the leaving page's phases, then the arriving page's. A page that
has left the tree hears nothing more.

## The way back

The way back is the innermost the page in front offers - a presented page
first, then the shown arrangement: a sidebar open over the detail closes, a
stack with a page pushed pops it - through tabs and split views to the stack
the user sees. The system's back asks the host
first, and the host tells the activity whenever it has a way back, so from
Android 13 the system's predictive back animates to the launcher only where
the application has nowhere to go back to.

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
