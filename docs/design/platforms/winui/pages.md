# Pages on WinUI

How the WinUI host presents a window's arrangement of pages - a navigation
stack, a split view, a set of tabs - as a Windows desktop application
presents its own: one chrome across the top of the window, WinUI's own
navigation pane, and the way back the mouse and the keyboard offer. StateUI
keeps every page, the path and the selection; WinUI is given no second
navigation model to reconcile with them.

## The window's chrome

A window has one chrome: WinUI's `TitleBar`, across the top of a window
whose content extends under its title bar, over a Mica backdrop, as
Windows' own applications stand. The renderer composes it again from what
the window shows after every render, and after every change the user makes
that the application may not render for - a tab chosen, the sidebar shown:

- the title of the page that names the window, on the chrome and to the
  system - the visible page, but tabs on a stack name it by their own title,
  else by the page beneath ([the window's chrome](../../host/pages.md#the-windows-chrome));
- the way back is the chrome's own back button, while the visible stack's
  top page can go back;
- a split view adds the chrome's pane toggle, which shows and hides its
  sidebar;
- the visible page's actions stand on a command bar at the chrome's trailing
  side, in their priority's order, those it places in overflow behind the
  bar's own "more"; an action with a picture - the first of the files its
  name stands for that the application's pictures hold
  ([pictures](controls.md#pictures)) - shows its words at the picture's
  right where it `showsText`, the command bar's own place for them, and
  otherwise the picture alone, its words naming it to Narrator and in its
  tip (`MountedElement.showsActionWords`); a destructive one stands in the theme's critical colour
  ([a destructive entry](#a-destructive-entry));
- the page's title view stands at the chrome's centre, where an application
  puts its search;
- an authored `TitleBar`'s own title, subtitle and picture stand in the
  chrome's title, subtitle and icon, as WinUI 3 Gallery names itself on its
  title bar, while the visible page's title still names the window to the
  system - the taskbar, Alt+Tab; its picture is read from the application's
  pictures by its address;
- an authored `TitleBar` adds its leading, centre and trailing content, each
  standing in the middle of the bar's height, and
  the bars' colours paint the chrome: its title and the actions on it, a
  destructive one excepted, stand
  in the colour written for what stands on the bars, else white on a dark
  band and black on a light one ([words on a painted
  band](../../host/layout.md#words-on-a-painted-band)); the chrome takes the
  dark theme on a dark band and the light one on a light band, for its
  buttons and a pointer over an action; an action behind "more" keeps the
  menu's colours on the menu's background, and the window's own caption
  buttons keep Windows' colours;
- the visible page's menus stand on a menu bar beneath the chrome
  ([menus](#menus)).

A page that hides its navigation bar puts neither the way back nor its
actions on the chrome.

WinUI's `TitleBar` keeps a column at each edge for the window's own buttons,
as wide as the window's insets - which it takes in pixels as though they were
DIPs (microsoft-ui-xaml #10344): at 200% the actions stand a caption's width
short of the bar's end. The relay caps each column at the inset over the
window's scale, whenever the bar is loaded or changes size; a column WinUI
sizes right stays as it is. The drag column WinUI keeps beside the buttons
stays too.

The leading, centre and trailing places are content controls, which Tab
stops at by default though they show nothing of their own: each is no stop,
so Tab walks the chrome's buttons and what the places hold, and never lands
where nothing shows.

## A navigation stack

A navigation stack shows its top page across its whole frame; the pages below
are kept by their elements and held by no view, so each keeps what it showed
for when the user comes back to it. Its bar is the window's chrome.

## The way back

The way back is the chrome's back button, the mouse's back button, Alt+Left
and the Back key - each the window's, as Windows applications offer it - and
it pops the visible stack's top page. The window's content holds those keys,
and Escape, with their tip hidden: WinUI would otherwise say them under the
pointer over everything the window shows.

## A split view

A split view's sidebar stands in WinUI's `NavigationView` pane, the detail in
its content: WinUI decides, as for any Windows application, whether the pane
stands beside the detail - from 1008 DIPs, where its navigation pane expands -
or opens over it, closed by a click beside it. The view shows none of its own
buttons, which the window's chrome carries, and no compact rail: a sidebar is
a page, with no icons to stand in one. The pane's own content stands, in
WinUI's template, in a row sized to what it holds, however tall - a sidebar's
scroller would hold all its rows and never scroll - so once the view is
loaded that row takes the pane's room, and the row of the items the view
holds none of takes only theirs. The row exists only once WinUI has measured
the view, so the sidebar has been laid out in it by then; everything in the
pane is measured again, or a layout inside keeps the places that first layout
gave it - a footer under a scroller stood below the window. A closed pane
beside the detail stands there at no width, where the keyboard's Tab and
Narrator would still reach what it holds - a sign-out button among them - so
the sidebar is collapsed while its pane is closed: shown as the pane starts to
open, collapsed once a pane over the detail has closed, and at once beside
it, where WinUI tells no closing.

Whether the sidebar shows is StateUI's binding, which follows what WinUI
shows: the pane opening or closing of WinUI's accord - a click beside it, the
window's room - reaches the binding. The host's one adaptation is that a
window wide enough for both panes opens with the sidebar shown; after that,
the user and the application decide. The window learns its room inside a
layout pass, so the binding hears it in the turn after it.

## A native arrangement

WinUI's navigation view lays its pages out in the room it is arranged in, and
a page it places is measured by it at that room. So the host measures the
navigation view at the size it last arranged it at - in the first pass at
the room offered - and a new room measures it again at the new size before it
is arranged there; the second pass then asks for what the first gave, and the
layout settles ([no room asked](layout.md#no-room-asked)).

The split view answers WinUI with what the navigation view asked and never
measures its pages itself. WinUI arranges an element at no less than it was
last measured, so a detail page measured at the split's whole width would
keep that width beside an open pane and run past the window's edge by the
pane's width.

## Tabs

A tabbed view's tabs are a `SelectorBar`. The first tabbed view down the
visible page path - through stacks and split views' details - gives its tabs
to the window: they stand across the window beneath its chrome, or across a
split view's detail, beside the sidebar and never over it. Any other tabbed
view - in a sidebar, in a tab of another, inside content - shows its tabs in a
row of its own above its page. Each tab says the title of the page it
presents and shows that page's picture before it, as the `SelectorBarItem`'s
`ImageIcon` - the first of the files its name stands for that the
application's pictures hold ([pictures](controls.md#pictures)) - as tall as the
theme's tab icons (`TabViewItemHeaderIconSize`) and as wide as its shape makes
it. The tab's template bounds no icon, and an SVG tells WinUI a size of
thousands of pixels: an icon given no height stands the row as tall as the
window. Choosing a tab
is the user choosing it: the pages hear it, then the selection's state, and
the chrome follows at once.

## A page's phases

A page hears its phases as the host layer tells them ([a page's
phases](../../host/pages.md#a-pages-phases)); WinUI supplies the tab the user
chose and whether the navigation view's pane shows, which the layer reads to
know what an arrangement shows.

## The modal stack

The pages a window's modal stack presents stand over everything the window
shows, as WinUI presents a dialog: each on a card over a veil across the
whole window - the chrome and the tabs too - the last on top. The card is a
dialog's own - its background, outline and corners, no wider than a dialog
and clear of the window's edges - with the presented page's title above the
page, and it enters as a dialog enters. The veil takes every click meant for
what is beneath, and the keyboard goes round inside the top card.

What the user sees is the top sheet, else the window's arrangement: when that
changes, the page that stops showing hears it and then the one that starts,
as a move. Escape takes the top sheet away, and so does the window's way back
while a sheet shows, once the sheet's own stack has no page to go back to;
the window is told how many sheets remain.

## The window's overlay

What a window lays over everything it shows - the inspector docked in it -
stands where the page stands, beneath the chrome, over the page and over
every sheet, whichever came first. It has no background of its own, so a
click beside what it holds goes on to the page or the sheet under it. It and
the sheets are layers of the window, not the content of a row: the chrome and
the menu bar standing again, as a page's menus come and go, leave both where
they are. The window takes the overlay out when it no longer describes it.

## Menus

The menus the visible page composes (`chromeMenus`) stand on WinUI's
`MenuBar` in a row of the window beneath its chrome, above the window's tabs
- each menu one of the bar's, its entries within it - while there are any;
a path with none leaves no row. WinUI keeps no menus of its own, so a
`StandardMenu` is an ordinary menu of the application's. The bar is written again only when what it draws changes: a render that
changes nothing on it leaves the bar, and a menu open on it, as they are.

A view's context menu is WinUI's `MenuFlyout` on the view: a right click and a
long press open it where the user asked, and on a view that holds the
keyboard, the menu key and Shift+F10 too. Its items
are `MenuFlyoutItem`s, its separators `MenuFlyoutSeparator`s and its submenus
`MenuFlyoutSubItem`s, one level inside another as the tree nests them; an
entry that cannot be chosen is shown dimmed. An item with a picture shows it
before its words, as the item's `ImageIcon` - the first of the files its name
stands for that the application's pictures hold ([pictures](controls.md#pictures)) -
and WinUI keeps every item's words in line beside it; a destructive item's
words stand in the theme's critical colour ([a destructive
entry](#a-destructive-entry)). The host hands the relay the menu flat - an
item, a separator, a submenu opening and closing, each with its caption, an
item with its picture and its mark - and hears a choice by the item's place
among the items, submenus' included; the item's own handler runs. A bar's
menus are written the same way. Any entry the tree changes, adds or removes
gives the view its menu again, and a menu with no entries is none.

A stack with a menu is hit across its bounds, as a listening one is
([listening](input.md#listening)): a right click anywhere across it opens the
menu, not only on its children.

## A destructive entry

A menu's item or a bar's action whose choice destroys something says so in
the theme's critical colour, the one Windows gives an error. Its words'
brushes - at rest, under the pointer and pressed - are named again in the
entry's own resources, as lightweight styling names them
(`MenuFlyoutItemForeground`, `AppBarButtonForeground` and their states); one
out of reach keeps the theme's dimmed words. Each brush takes its colour
from the theme resource `SystemFillColorCritical`, in a theme dictionary for
the light theme and one for the dark, so it follows the entry's own theme: a
bar the tree paints dark stands its destructive action in the dark theme's
lighter red. A brush looked up from code, or an alias of the theme's brush,
keeps the colour of the application's theme at the moment it is written.
The entry is marked before it stands, so its template reads the brushes as
it first draws.

The bar's words' colour paints every action on the bar but a destructive
one. Whether an entry is marked is read from its own theme dictionaries,
walked: `HasKey` and `Lookup` look on into the application's theme
([a control's accent](controls.md#a-controls-accent)).
