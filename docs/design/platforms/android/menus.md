# Menus on Android

How the Android Views host shows StateUI's menus: a stack's bar's actions and
a view's context menu, both Android's own menus, written from the same
entries. What a menu promises is
[navigation](../../../navigation-and-presentation.md#menu-bars-and-context-menus)'s.

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
picture in place of its words, and the rest are the overflow's entries.

## A context menu

A view whose element carries a context menu takes a long press - and, with a
mouse, a secondary click - for Android's own context menu, anchored where the
finger or the pointer is. The menu is written from the element's slot as the
user asks for it, never before, so a menu that changed shows what it says
now, and an empty one shows nothing. The items are held by their elements
until the next time the menu is written, and an item chosen is heard by the
element it was written from. Android's context menus draw no pictures, so an
item's picture is not read. When the slot goes, the view gives back whether
it took a long press before.

A page's menu bar has no surface on Android and is not shown.
