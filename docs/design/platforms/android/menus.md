# Menus on Android

How the Android Views host shows StateUI's menus: a stack's bar's actions,
the menus a page's path declares and a view's context menu, all Android's own
menus, written from the host layer's walk of the same entries (`MenuEntry`). What a menu promises is
[navigation](../../../interface/navigation-and-presentation.md#menu-bars-and-context-menus)'s.

## A menu's entries

A menu is written into Android's `Menu` in one call, whatever its size: each
entry is an int of its kind - an item, a submenu, its end, a line - and its
flags, and each item and submenu takes the next words and picture. A line
starts a new group, and Android draws a line between groups from Android 9.
An item that cannot be undone has its words, and its picture, in the theme's
error colour. One that cannot be chosen runs nothing and keeps the platform's
disabled colour, which a colour of its own would hide, and its picture is
dimmed as the theme dims what is disabled: Android dims no menu's picture
itself. An item
chosen comes back by its place among the items, which its Android id is too,
plus one: a submenu has none.

## The bar's actions

A stack's bar's actions are its toolbar's menu, written again whenever they
change: a primary action stands beside the title where there is room, its
picture in place of its words - its words beside it where it shows them
(`showsActionWords`) and the bar has room, as Android lets a bar with room
show both - and the rest are the overflow's entries.

## A page's menus

Android keeps no menu bar: the menus the visible page's path composes
(`chromeMenus`) stand in its stack's bar, behind the overflow after its
actions, each a submenu of the toolbar's menu with its entries inside, after
a line where actions stand in the overflow too. A `StandardMenu` is an
ordinary menu there. A page on no stack has no bar, and its menus stand
nowhere.

## A context menu

A view whose element carries a context menu takes a long press - and, with a
mouse, a secondary click - for Android's own context menu, anchored where the
finger or the pointer is. The menu is written from the element's slot as the
user asks for it, never before, so a menu that changed shows what it says
now, and an empty one shows nothing. The items are held by their elements
until the next time the menu is written, and an item chosen is heard by the
element it was written from. Android's menus - a context menu, a bar's
overflow and its submenus - draw no pictures, so an entry's picture is not
read. When the slot goes, the view gives back whether it took a long press
before.

Each item's element keeps its place in the menu it last stood in
(`menuPlace`), its Android id less one.
