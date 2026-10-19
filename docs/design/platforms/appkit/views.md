# Views on AppKit

What the AppKit half's views are given by the host rather than finding for
themselves.

## Pictures

What crosses the boundary for a picture is a name, and the files behind it
belong to the renderer: it knows the application's resource directory and
keeps the cache over it, so one name is loaded once however many views draw
it. The cache lets go of pictures under memory pressure, as the system asks;
a picture something still holds - a view showing it - stays found by its
name through a table that holds it weakly, so a view handed it again finds
the same image and nothing changed. A registration is made once for the whole process and has no renderer to
ask, so the host hands every view it makes, through `AppKitPictureResolving`,
the means to resolve a name. A name the application has no file for resolves
to nothing. An icon resolves to its SF Symbol (`Icon.sfSymbol`), a template
image in the colour of the control holding it, and bytes to the image they
encode. An image view tints a template in the label colour, as the words
beside it; left untinted, it draws one in the secondary label colour. A
bordered button tints a template in the platform's colour alone, so where
its words stand in one of their own - a role's red, the tree's colour - it
shows a copy of the icon drawn in theirs.

## Accessibility on the control

A host view that wraps one native control hands assistive technology that
control in its own place, through `AppKitAccessibilityPresenting`. The
author's words, the role and whether the element takes part are written where
VoiceOver meets the control, not on the view around it.

## A stated size

A size the tree states for a view - its width, height and bounds - is what
StateUI's layouts measure and place it by; the view also carries it as a
constraint, for a measurement of AppKit's own to read. That constraint stands
just short of required: a layout of StateUI's places the view by its frame,
whose constraints stand over it until the first layout gives that frame,
and two required answers to one width are a conflict AppKit reports.

## A layout's own box

A stack, a grid or a ZStack paints its own box. A plain colour on a plain
rectangle is its layer's background colour: the view draws nothing and keeps
no backing store, which is what almost every layout is. An outline, a
rounded or oval shape, or a gradient makes the view draw instead - the
background on the shape, the outline inside the bounds, half its width either
side of the shape's edge, in a colour alone (AppKit's brush strokes no
gradient). With `clipsContent` the layer cuts what the layout holds: to its
bounds, its rounded corners, or an oval mask; without it nothing is cut.

A blur or glass background is a view of its own under what the layout
holds - an `NSGlassEffectView` in the glass's tint, or an
`NSVisualEffectView` within the window of the role whose translucency stands
in that thickness (`fullScreenUI`, `popover`, `menu`,
`underWindowBackground`, measured, and `windowBackground` for the thickest) -
cut to the box's shape and edged with its outline on its own layer, as the
layout's own drawing lies under it. A blur's tint lies over it in a view of
its own (`AppKitBoxWash`), the material's top view, hidden while it paints
nothing. Laying out the children keeps the surface beneath them. Glass that
answers the user takes the press, which rises to the layout; any other
surface takes none. A window's blur carries the same wash for its tint.
The trap: macOS draws an inactive window's glass without its tint, but never
what the glass holds. So glass wears its tint while its window stands key or
main in the application in front, and in its content (the wash) otherwise,
following the window's and the application's notices.

A scroller's box is its layer's alone: a colour behind what it shows, a
colour's outline on a rectangle or a rounded one, and the cut of what it shows
to its shape, always. AppKit repaints a scroller's layer as it displays it and
clears its colour and outline, so the scroller puts them back each time it
updates its layer. An oval scroller's outline is a shape layer over what it
shows: under the oval's mask a layer's border would show only as slivers.

## A sidebar's material

A split view's sidebar is AppKit's own sidebar item, on the system's sidebar
material. The material its split view says for it beside the detail
(`sidebarBackground`) stands in its pane as a layout's box does - a colour on
the pane's layer, a blur or glass a view of its own under the page - over
the system's. A Mac sidebar never slides over the detail: a window too narrow
for both hides it, so the flyout's material is never shown.

## A child turned in place

A ZStack whose run turns its drawing order - two cards swapping ranks as a
layout engine's run passes halfway between them - sets its `subviews` in the
new order (`ZStackArithmetic.drawingOrder`), which moves each child it keeps
without taking it out. A child taken out and added again leaves the window
for a moment, and AppKit cancels a gesture under way on it: a pointer drag of
the scroller lying over the cards would end at the first swap, and the run go
back to the target it left.

## Scroll bars

A ScrollView and an ItemsView lay their scroll bars over what they show,
whatever the Mac is set to show. StateUI gives what they hold their whole
width - a list's item as wide as the list - and a bar standing beside it
takes 17 points of that: a Mac with a mouse and no trackpad shows its bars
always, beside the content, and a hosted CI runner is such a Mac. The style
is set before the scroll view first lays out; set later, its clip keeps the
narrower width until it lays out again. To see the runner's bars on a
desktop, run the suite after `defaults write com.apple.dt.xctest.tool
AppleShowScrollBars Always`, and delete that key afterwards.

## A long text

AppKit draws a layer-backed view only where it is visible, so a scroller
uncovering a label a few points at a time draws it strip by strip - and an
`NSTextField` label lays its whole text out again for every strip, each frame
of the first pass and every time the label draws again (a theme turned, the
window resized). A label that wraps and shows every line therefore draws
from a layout of its words it keeps in TextKit (`NSLayoutManager`), laid out
again only when its words or its width change, drawing only the lines the
strip shows; its lines stand where the cell's do, 2 points in from each
side. A truncated label draws as its cell does, and so does one held to some
lines, its last line ending with an ellipsis (`truncatesLastVisibleLine`).

## A view under a transform

AppKit measures what of a view is visible - its `visibleRect`, which bounds
what a layer-backed view draws - from the frames of the view and its
ancestors, without their layers' transforms. A view standing past the edge of
what clips it, turned or scaled back inside it - a card of a fan at the side
of a deck - would be drawn only where its unturned frame shows, cut along a
straight line across the card. Every view that draws takes the whole of its
bounds for visible where it or an ancestor stands under a transform
(`drawnRect(visible:)`); one standing straight keeps what AppKit measures, so
a scroller uncovering a long label still draws it strip by strip (A long
text).

## A button's icon beside its words

A button keeps its icon beside its words, the two together in the middle
(`imageHugsTitle`), however wide the layout stands it. Left to its default,
AppKit puts the icon at the button's edge and the words alone in the middle,
so a wide button's icon stands far from its words.

## A button's padding

A button's padding is room on its size - the cell's own measurement and the
padding round it - and room inside it: the cell stands its words and its
picture within it (`AppKitButtonCell`). A button drawing a box of its own -
a fill, an outline - takes no bezel, and AppKit would otherwise scale a
picture alone up to the whole button, whatever room the tree kept. A button
in AppKit's own bezel placed taller than the push button stands in the
flexible push button's, which is as tall as it is placed: the push button's
keeps one height, and a square button of a picture would stand as a short
wide one.

## A button's role

A role draws where the tree draws nothing of its own ([a button's
role](../../host/layout.md#a-buttons-role)): the main action's bezel in the
accent - with Return its key, AppKit's own default button - and a destructive
one's words the system's red, as macOS's alerts mark one; AppKit also marks
it for the system (`hasDestructiveAction`), which draws nothing on a button
standing alone.

## A button's menu

AppKit's own menu buttons - the pull-down button and the combo button - take
no box and no colour of their words, so a button holding a menu is the host's
own AppKit button, which wears what the tree says, and its menu an `NSMenu`
opened under it, at least as wide, as a pull-down opens its:

- where its click opens the menu, it opens as the button is pressed, the
  button pressed while it is open, and an arrow pointing down stands just
  after the words; the button is a menu button to assistive technology;
- a split button's arrow is a part of its own at its trailing edge, the whole
  height, set off by a line, opening the menu as it is pressed;
- a held button is let go before half a second for its click, and held past
  it opens its menu, the press going on into it - AppKit's own event tracking
  reads the press, with no timer.

The button keeps room at its trailing edge for the arrow: its own size grows
by it, and its cell sets its words and picture in the rest, its bezel the whole
button's. Assistive technology asking for the menu of any of them opens it; a
split button's arrow part, a view inside a button, is not met on its own.

## A radio button's set

StateUI owns a radio button's set - its name, across the whole window - and
turns the others of a set off as one is checked. AppKit keeps sets of its own:
the radio buttons of one superview sharing one action turn each other off as
one is clicked, whatever sets StateUI put them in. So the host's radio button
takes a turn only from StateUI's own writes and from a click on itself, which
its cell makes; AppKit's turning off of the others is refused.

## A field's placeholder

A text field's, a search field's and an editor's placeholder stands where the
field's own words would: across the field as `horizontalTextAlignment` says,
a plain placeholder in the field's font. A placeholder in a colour of its own
is attributed text, which takes no alignment from its field as a plain one
does, so it carries the field's alignment itself. An editor's placeholder is
a label over the text view, in the editor's font, as wide as the text view's
room, so the alignment has room to move it.

## What typing is given

A field's traits ([what typing is given](../../host/runtime.md#what-typing-is-given))
reach the text view a user types in: continuous spell checking, automatic
spelling correction and text replacement, text completion and inline
prediction, each on or off. Capitals are the text checking's own: macOS puts
the first letter of a sentence in capitals as the user's setting says, and a
field overrides that setting in the options the checking asks its delegate
for - a field, a search and an editor are their text view's delegate. Plain
words keep their letters as typed whatever the setting; text starts its
sentences in capitals; the default leaves the setting alone. A Mac has no
keyboard on the screen, so a purpose picks no keys - the register records it.

## A web view

A WebView is WebKit's own web view
([the host layer's web rules](../../host/web.md)): a page at an address is
loaded; a document written in place with an address of its own is shown
there, and one with none is gone to as a `data:` address. What the page does
comes back as the element's events - a navigation as it starts, with why, and
as it ends, with how; the way back and forward said as a navigation commits
and ends, only a flag that changed; its web process dying. A step back,
forward or a load again the program asks for carries that as its cause; a
page still coming is asked for again. macOS's WebKit also declares a legacy
`WebHistory` class, so the host names the host layer's `StateUIHost.WebHistory`
in full.

## A text style

Words in a text style stand in AppKit's font for it
(`NSFont.preferredFont(forTextStyle:)`): `.display` the large title, `.title`
the first title, `.subtitle` the second, `.headline`, `.body` and `.caption`
the first caption. The style's size and weight stand under the tree's
(`TextLook.standing`), and the font is made again at the size and weight that
stand - the system font, or the named family with that weight in its
descriptor; italic is AppKit's italic trait. A weight is AppKit's
`NSFont.Weight`, and a font's weight reads back from its descriptor's traits.
A Mac gives an application no text size of the user's to follow.
