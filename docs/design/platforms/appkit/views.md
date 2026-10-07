# Views on AppKit

What the AppKit half's views are given by the host rather than finding for
themselves.

## Pictures

What crosses the boundary for a picture is a name, and the files behind it
belong to the renderer: it knows the application's resource directory and
keeps the cache over it, so one name is loaded once however many views draw
it. A registration is made once for the whole process and has no renderer to
ask, so the host hands every view it makes, through `AppKitPictureResolving`,
the means to resolve a name. A name the application has no file for resolves
to nothing.

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

A scroller's box is its layer's alone: a colour behind what it shows, a
colour's outline on a rectangle or a rounded one, and the cut of what it shows
to its shape, always. AppKit repaints a scroller's layer as it displays it and
clears its colour and outline, so the scroller puts them back each time it
updates its layer. An oval scroller cuts and draws no outline.

## A sidebar's material

A split view's sidebar is AppKit's own sidebar item, on the system's sidebar
material. The material its split view says for it beside the detail
(`sidebarBackground`) stands in its pane as a layout's box does - a colour on
the pane's layer, a blur or glass a view of its own under the page - over
the system's. A Mac sidebar never slides over the detail: a window too narrow
for both hides it, so the flyout's material is never shown.

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
`NSTextField` label lays its whole text out again for every strip: a listing
of 1275 characters cost 6.4 ms a strip, the Appearance sample's 756 by 3424
point listing 200 ms, each frame of the first pass and every time the label
drew again (a theme turned, the window resized). A label that wraps and shows
every line therefore draws from a layout of its words it keeps in TextKit
(`NSLayoutManager`), laid out again only when its words or its width change,
drawing only the lines the strip shows; its lines stand where the cell's do,
2 points in from each side. A truncated label draws as its cell does.

## A button's icon beside its words

A button keeps its icon beside its words, the two together in the middle
(`imageHugsTitle`), however wide the layout stands it. Left to its default,
AppKit puts the icon at the button's edge and the words alone in the middle:
a sidebar's "Log out" stretched across the sidebar had its icon at the far
side of it.

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
in the field's font. A placeholder in a colour of its own is attributed text,
which takes no alignment from its field as a plain one does, so it carries the
field's alignment itself. An editor's placeholder is a label over the text
view, as wide as the text view's room, so the alignment has room to move it.

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

A WebView is WebKit's own web view, as on UIKit
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
