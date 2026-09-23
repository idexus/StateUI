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

A stack's bar is Android's own toolbar. It carries the visible page's title,
the stack's bar colours, and the page's actions: the primary ones beside
the title, by priority and then in their order, the rest behind the
toolbar's overflow. Its navigation button is the way back on a pushed page
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

The way back is the innermost the shown arrangement offers: a sidebar open
over the detail closes, a stack with a page pushed pops it - through tabs and
split views to the stack the user sees. The system's back asks the host
first, and the host tells the activity whenever it has a way back, so from
Android 13 the system's predictive back animates to the launcher only where
the application has nowhere to go back to.
