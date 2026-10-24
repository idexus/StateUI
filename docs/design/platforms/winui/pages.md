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
the window shows after every render that changed what it is made of ([a
render that touches the chrome](../../host/pages.md#a-render-that-touches-the-chrome)),
and after every change the user makes that the application may not render
for - a tab chosen, the sidebar shown:

- the title of the page that names the window, on the chrome and to the
  system - the visible page, but tabs on a stack name it by their own title,
  else by the page beneath ([the window's chrome](../../host/pages.md#the-windows-chrome));
- the way back is the chrome's own back button, while the visible stack's
  top page can go back;
- a split view adds the chrome's pane toggle, which shows and hides its
  sidebar, unless it offers none (`showsSidebarToggle`);
- the groups of actions the visible page declares
  ([a page's actions](../../host/pages.md#a-pages-actions)) stand
  on a command bar at the chrome's edge they declare - the leading one in its
  left header, after the way back and the toggle, shown only while it holds
  an action; the trailing one in its right header - each group apart from the
  one before it by WinUI's own line between commands (`AppBarSeparator`),
  a setting WinUI's two-state `AppBarToggleButton`, checked while on,
  and those placed in overflow behind the trailing bar's own "more"; an
  action with a picture - the first of the files its
  name stands for that the application's pictures hold
  ([pictures](controls.md#pictures)) - shows its words at the picture's
  right where it `showsText`, the command bar's own place for them, and
  otherwise the picture alone, its words naming it to Narrator and in its
  tip (`MountedElement.showsActionWords`); a destructive one stands in the theme's critical color
  ([a destructive entry](#a-destructive-entry)); one that cannot be chosen
  fades its picture as far as the theme fades its words - the bar's
  disabled brush's alpha over its own - since WinUI fades a glyph with the
  words and leaves the application's own picture as drawn;
- the page's title view stands at the chrome's center, where an application
  puts its search;
- the title area the path declares - the application's name, the line under
  it and its mark ([the bar a path declares](../../host/pages.md#the-bar-a-path-declares))
  - stands in the chrome's title, subtitle and icon, as WinUI 3 Gallery names
  itself on its title bar, while the visible page's title still names the
  window to the system - the taskbar, Alt+Tab; its picture is read from the
  application's pictures by its address; and
  the bars' colors paint the chrome: its title and the actions on it, a
  destructive one excepted, stand
  in the color written for what stands on the bars, else white on a dark
  band and black on a light one ([words on a painted
  band](../../host/layout.md#words-on-a-painted-band)); the chrome takes the
  dark theme on a dark band and the light one on a light band, for its
  buttons and a pointer over an action; an action behind "more" keeps the
  menu's colors on the menu's background, and the window's own caption
  buttons keep Windows' colors;
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
stays too. It is the one template part the host reaches into, as a true
defect earns: the columns are found by the names WinUI's template gives them
(`LeftPaddingColumn`, `RightPaddingColumn`), a host test fails where they are
not, and the cap goes once #10344 ships.

The title view's place is a content control, which Tab stops at by default
though it shows nothing of its own: it is no stop, so Tab walks the chrome's
buttons and what the place holds, and never lands where nothing shows.

## A navigation stack

A navigation stack shows its top page across its whole frame; the pages below
are kept by their elements and held by no view, so each keeps what it showed
for when the user comes back to it. Its bar is the window's chrome. A page
pushed enters from the end and one popped back to from the start, by WinUI's
own entrance (`EntranceThemeTransition` on the panel's children), as the host
layer says the path changed
([a path that changes](../../host/pages.md#a-path-that-changes)).

## A page's heading

Where the window's chrome names the application - a title area declared on the
visible path - the page that would name the window is headed by its own
title, as Windows' own applications head a page under a title bar naming the
application: a row across the top of the page's room in WinUI's title style,
24 DIPs from its top and sides, the page's content under it - a tab view
naming the window by its own title is headed over its tabs, which then stand
in its own row under the heading rather than across the window over it: the
title names what the tabs are tabs of. The window heads one page at a time,
the one its chrome composes from, and takes the heading from the one it
headed before.

## The way back

The way back is the chrome's back button, the mouse's back button, Alt+Left
and the Back key - each the window's, as Windows applications offer it - and
it pops the visible stack's top page. The window's content holds those keys,
and Escape, with their tip hidden: WinUI would otherwise say them under the
pointer over everything the window shows.

## A split view

A split view's sidebar stands in WinUI's `SplitView` pane, the detail in its
content: beside the detail from 1008 DIPs, where a Windows application's
navigation pane expands (`Inline`), over it below, closed by a click beside
it (`Overlay`). `SplitView` places by no width of itself, so the host places
it by the host layer's rule (`SidebarAdaptation.place`), and a sidebar beside
the detail closes as the window narrows it over, as WinUI's own navigation
panes do. The pane holds the sidebar page at its whole height, so a sidebar's
scroller scrolls and a footer stands at the pane's foot. As the window's
height changes, everything in the pane is measured again
(`stateui_winui_split_measure_pane_again`): WinUI applies an arrange inside
the pane only to what it measured in that pass, and a footer would keep its
place in the taller window, below the shorter one. The view shows none
of its own buttons, which the window's chrome carries. A closed pane would
keep what it holds where the keyboard's Tab and Narrator still reach it - a
sign-out button among them - so the sidebar is collapsed while its pane is
closed: shown as the pane starts to open, collapsed once it has closed, and
at once beside the detail.

WinUI's `SplitView` animates its pane alone and lays a detail beside it out at
its end width at once, so the host slides a pane beside the detail itself, by
the host layer's `SplitSlide` ([a sidebar sliding](../../host/motion.md#a-sidebar-sliding)):
the pane opens as the slide sets out, its `OpenPaneLength` follows the slide
each frame, and it closes as a slide out rests, the sidebar standing at the
pane's whole width - the theme's `SplitViewOpenPaneThemeLength` - against its
trailing edge, and a closed pane stands none wide, the width its slide opens
from, where WinUI's own animation of opening and closing has nothing to move.
A pane over the detail, which keeps its width, WinUI slides in itself at its
whole width; the host slides it out, as WinUI's own takes a tenth of a second.
A pane WinUI closes of its own accord - a click beside a pane over the detail -
stays open while it slides out: the host closes only a pane none wide, so no
close WinUI tells late can keep one open.

Whether the sidebar shows is StateUI's binding, which follows what WinUI
shows: the pane closing of WinUI's accord - a click beside it, the window's
room - reaches the binding. The host's one adaptation is that a window wide
enough for both panes opens with the sidebar shown; after that, the user and
the application decide. The window learns its room inside a layout pass, so
the binding hears it in the turn after it.

The detail stands on a card, as a Windows application's content stands
beside its navigation pane: WinUI's layer under it and its edge, by the
theme resources that card is named by (`NavigationViewContentBackground`,
`NavigationViewContentGridBorderBrush`), which a window writing its
background clears ([a window's backdrop](runtime.md#a-windows-backdrop)). Beside the sidebar the edge runs
along the top and the pane's side, its corner rounded where they meet; under
a pane over the detail it runs along the top alone.

The pane stands on a ground of its own for each place ([a sidebar's
material](../../host/pages.md#a-sidebars-material)), its `PaneBackground`:
the split view's material for that place - a color, or a blur as WinUI's
in-app acrylic in its color, its luminosity and tint by its thickness as the
window's acrylic ([a window's backdrop](runtime.md#a-windows-backdrop)) -
else the sidebar page's background, else the brush WinUI's theme gives a
navigation pane there (`NavigationViewExpandedPaneBackground` beside,
`NavigationViewDefaultPaneBackground` over), in the theme the split stands
in and again as it turns. WinUI has no glass: glass is the acrylic at its
fallback thickness.

## A native arrangement

WinUI's split view lays its pages out in the room it is arranged in, and a
page it places is measured by it at that room. So the host measures the
split view at the size it last arranged it at - in the first pass at the room
offered - and a new room measures it again at the new size before it is
arranged there; the second pass then asks for what the first gave, and the
layout settles ([no room asked](layout.md#no-room-asked)).

The split view answers WinUI with what WinUI's view asked and never measures
its pages itself. WinUI arranges an element at no less than it was last
measured, so a detail page measured at the split's whole width would keep
that width beside an open pane and run past the window's edge by the pane's
width.

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
chose and whether the split view's pane shows, which the layer reads to
know what an arrangement shows.

## Sheets

The pages a window's views present stand over
everything the window shows, as WinUI presents a dialog: each on a card over a veil across the
whole window - the chrome and the tabs too - the last on top. The card is a
dialog's own - its background, outline and corners, no wider than a dialog
and clear of the window's edges - and it enters as a dialog enters. It stands
as large as its page asks ([a sheet's size](../../host/pages.md#a-sheets-size)):
in the middle, at least 320 x 184 and at most a dialog's 548 wide; one whose
page asks none - a stack among them - stretches to 548 x 640, which WinUI's
layout holds within the window less the card's 48 a side. A stack it
holds brings its bar to the card's head, above the page: the way back as WinUI
draws one outside a navigation view (`NavigationBackButtonSmallStyle`), the
top page's title, and - unless the page says not - the button closing the
sheet, an `AppBarButton` of the Cancel symbol at the trailing edge, which
writes false onto the sheet's state as Escape does; a page alone shows no head
(`bringsABar`). The veil takes every click meant for
what is beneath, and the keyboard goes round inside the top card.

The sheets stand in one layer of the window's root over its rows by their own
depth (`Canvas.ZIndex` 1, the overlays' 2), never by their place among the
root's children. The trap: a page stood in a row is put on the end of them,
so a window arranged anew after a first sheet - a sidebar beside a stack
once signed in - would stand over every sheet presented after it, the veil
and the card under the page; it shows rarely, only where a sheet comes
before the arrangement.

Which sheets stay, leave and come is the host layer's rule
([sheets](../../host/pages.md#sheets)), a sheet standing as asked where its
page is the same; the relay pushes a sheet over those before it - the sheet
taking the keyboard at its first place that does - and pops the top one.
Every presentation writes each kept sheet's title and page again, as the card
shows the page's title itself.

What the user sees is the top sheet, else the window's arrangement: when that
changes, the page that stops showing hears it and then the one that starts,
as a move. Escape takes the top sheet away, and so does the window's way back
while a sheet shows, once the sheet's own stack has no page to go back to;
the stack is told how many sheets remain.

## A popover

A view's popover is the relay's `StateUIPopover`: WinUI's `Flyout`,
derived to keep whether the program wants it shown - a flyout is no
`FrameworkElement` and has no `Tag` to keep it in. It holds the popover's
panel and shows at its anchor (`ShowAt`) once the anchor is loaded: one not
loaded has no root to show over. `Closed` while the program wants it shown
is the user's - a click beside it, Escape - told through `presented`; the
program's own `Hide` is heard by nobody.

## The window's overlays

What a window lays over everything it shows - the overlays the pages on its
visible path declare, then the inspector docked in it - stands where the page
stands, beneath the chrome, over the page and over every sheet, whichever
came first, the first lowest. None has a background of its own, so a click
beside what one holds goes on to the page or the sheet under it. They and the
sheets are layers of the window, not the content of a row: the chrome and the
menu bar standing again, as a page's menus come and go, leave both where they
are. The window takes the overlays' layer out when it is told none.

## Menus

The menus the visible page composes (`chromeMenus`) stand on WinUI's
`MenuBar` in a row of the window beneath its chrome, above the window's
tabs - each menu one of the bar's, its entries within it - while there are
any; a path with none leaves no row. WinUI keeps no menus of its own, so a
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
words stand in the theme's critical color ([a destructive
entry](#a-destructive-entry)). The host hands the relay the menu flat - an
item, a separator, a submenu opening and closing, each with its caption, an
item with its picture and its mark - and hears a choice by the item's place
among the items, submenus' included; the item's own handler runs. A bar's
menus are written the same way. Any entry the tree changes, adds or removes
gives the view its menu again, and so does the view's own reach turning - a
branch disabled or enabled around it - as its entries are in reach with it; a
menu with no entries is none.

The window's menu bar is one of its bars: it wears the bars' color as the
title bar does, its `Background` and the theme of its words - light on a dark
bar - and its menus' words take the bars' color through
`MenuBarItemForeground`, the brush their template reads, written into the
bar's own resources. Where nothing is declared it keeps the platform's own.

A stack with a menu is hit across its bounds, as a listening one is
([listening](input.md#listening)): a right click anywhere across it opens the
menu, not only on its children.

## The Edit menu

WinUI keeps no Edit menu of its own, so a menu joining `StandardMenu.edit`
holds the host layer's entries (`ChromeMenus.editing`), Redo's keys
Windows' Ctrl+Y. Each is the text box's own act through the relay
(`stateui_winui_field_edit`): `Undo`, `Redo`, `CutSelectionToClipboard`,
`CopySelectionToClipboard`, `PasteFromClipboard`, the selection emptied,
`SelectAll` - a password box gives none of its words away, so it only pastes
and selects all. A menu takes the focus as it opens, so every field hears the
focus whatever the tree hears and the last one the user typed into is kept
(`WinUIEditing`), handed the focus back as the entry acts. The entries' keys
give way to a field holding the keyboard, which takes them itself: the menu
bar's accelerator acts only where no field holds the keyboard, never twice.

## A destructive entry

A menu's item or a bar's action whose choice destroys something says so in
the theme's critical color, the one Windows gives an error. Its words'
brushes - at rest, under the pointer and pressed - are named again in the
entry's own resources, as lightweight styling names them
(`MenuFlyoutItemForeground`, `AppBarButtonForeground` and their states); one
out of reach keeps the theme's dimmed words. Each brush takes its color
from the theme resource `SystemFillColorCritical`, in a theme dictionary for
the light theme and one for the dark, so it follows the entry's own theme: a
bar the tree paints dark stands its destructive action in the dark theme's
lighter red. A brush looked up from code, or an alias of the theme's brush,
keeps the color of the application's theme at the moment it is written.
The entry is marked before it stands, so its template reads the brushes as
it first draws.

The bar's words' color paints every action on the bar but a destructive
one. Whether an entry is marked is read from its own theme dictionaries,
walked: `HasKey` and `Lookup` look on into the application's theme
([a control's accent](controls.md#a-controls-accent)).
