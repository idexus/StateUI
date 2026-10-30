# Layout in the runtime

StateUI owns its layouts' semantics: where a child of a stack, a grid, a
ZStack or a page goes is StateUI's arithmetic, the same on every native host,
where a toolkit only measures its own views and moves them; the Web host
writes the same semantics as each element's CSS, and the browser places it
([Web layout](../platforms/web/layout.md)). [The
runtime](runtime.md) draws where layout sits in a frame; [motion](motion.md)
says how a child travels to the place this arithmetic gives it.

## The layout arithmetic

```text
  MountedElement.layoutValues      margin, alignments, stated sizes,
          |                        grid cell, area
          v
  LayoutChild                      the toolkit's child: those values, whether
          |                        it shows, and its size for an offered width
          v
  StackArithmetic   GridArithmetic   ZStackArithmetic   SingleChildArithmetic
          |                        pure: the same children in, the same
          v                        rectangles out
  [Rect?]  one per child, nil for a hidden one
          |
          v
  the toolkit's layout view        stands each child there, or on its way
                                   there through LayoutMotion
```

A layout's values are read off the element once, by the host layer
(`MountedElement.layoutValues`), so every host
reads the same margin, alignment and stated size. The toolkit supplies only
what it alone knows: whether the child is shown, and how big its view is for a
width it is offered - a label wraps, an image keeps its ratio. The arithmetic
is pure, so a host calls it from its own layout pass - `layout()` on AppKit, a
`ViewGroup`'s layout on Android - and a test calls it with plain values.

## One axis of a slot

Along each axis a child has a slot: the room its layout offers it, less its
margin. A size the child states wins over every alignment and is held by its
own least and most size and by the slot. Without one, a filling child takes
the slot and any other takes its natural size, never more than the slot.
Where the least size is larger than the most, the least wins, so
contradictory bounds cannot leave a child with no answer. A child placed at
its start sits at the slot's start; at its end, at the end; centered, or
filling but stopped short by a stated or a most size, in the middle.

The layout owns the margin both ways: it takes the margin out of the width it
offers a child and adds it to the size the child answers, and a toolkit's
child measures its own view alone. A margin taken out twice narrows the
offer - words wrap where they had room, and on WinUI a label measured at two
widths in one pass keeps the pass from settling.

## Measured once

A view keeps the sizes it measured, by the width its parent offered, until
something that can change them happens: its own content, its arrangement, or a
change beneath it. A parent offers a child one or two widths in a pass - its
natural width and the width it then lays it out in - so four kept answers
cover a pass and the next. The host forgets them upward from the change,
every layout to the root - on AppKit to the nearest room - and an
ItemsView's entry stops at its cell, which measures it again
(`MountedElement.measuredUpward`); nothing beside
the change is measured again. Which change is which is one list on every
native host (`MountedElement.arrangedProperties`,
`unmeasuredProperties`): a property a parent reads into its child's place
arranges the parent again, and one that is only drawn - an opacity, a color,
a toggle's state, a transform, what assistive technology meets - measures
nothing.

## Words in a wider room

Words measured with no width offered stand on their natural lines, and in
any room at least that wide they stand the same: no line breaks earlier. So
a label's kept answers hold its natural size for every wider width
(`MeasurementCache(holdsWhenWider:)`), and only a narrower room asks its
toolkit again. A page whose width changes every frame - a sidebar sliding
beside it - measures its words once, not once a frame at each new width:
measuring large words is the costliest call a toolkit makes, and a frame that
makes it at every width stalls. A view that is not words keeps one answer a
width.

## Words across their room

Words aligned to a line's start or end stand at the edge the layout direction
reads (`TextAlignment.edge(in:)`): the start is the left left to right and
the right right to left, the end the other way, the middle either way - the
same on every host, so no host leaves the start to its toolkit's guess from
the words themselves. A canvas's words stand in the canvas's own coordinates
instead ([text in a box](../types/drawing.md#text-in-a-box)).

## A child measured

A layout measures a child the same way on every host: at its stated width,
within its bounds and the width offered - the width the layout places it at,
so its words wrap to it - else at the smaller of the width offered and its
most width; and its size is its stated width and height before what it
measured, each within its bounds (`LayoutValues.offer`, `sized`). A host
measures its native view at that width and nothing more.

The trap is a child measured at one width and placed at another: a stated
width wider than its room - a `GeometryReader`'s width a frame late as a
window is resized - wraps its words for the stated width while it stands
in the room. Most toolkits show the words cut; WinUI, which measures until
its layout settles, finds the words' size changing at every pass and ends
the application (`0xc000027b`, a layout cycle).

## Stacks

A stack sets its shown children one after another with its spacing between
them, inside its padding. Along its axis each child takes its natural size;
across, its slot's rule. A vertical stack offers each child its own width, so
wrapped text is measured at the width it will have; a horizontal stack offers
none, because the width is what the children decide. A hidden child takes no
room and no spacing.

## A row short of room

A row with less room than its shown children, their margins and the spacing
need takes it from its words: a label (`LaidOutWords.bare`) that states no
width of its own (`LayoutValues.yieldsInARow`) shares what the others leave
with the other labels, in proportion to their natural widths and within
their bounds; every other child keeps its natural width, and a space has
none left (`StackArithmetic.rowWidths`). A label narrowed is measured again
at its width, so its words wrap to it, and a row measured for a width works
its labels out at the widths it would place them at: it is as tall as they
stand there, and its natural width is still its words on one line, as a
grid's is - no label is measured at one width and placed at another, which
WinUI would measure until it gave up. Every host runs the arithmetic but the
Web, which hands its rows to the browser: a label there is a flex item that
shrinks by its natural width down to nothing (`flex: 0 1 auto`, `min-width:
0`), the same share.

## A space

A child that grows - a `Space` - takes the room the stack's shown children
leave along its axis: the stack's length less their natural lengths, their
margins and the spacing, shared alike among the spaces, none where nothing is
left. It measures as no room of its own, so a stack sized by its children
leaves it none, and its least and most lengths still bound it. A space that
states its length along the axis grows no more: it is a child of that length
like any other (`LayoutValues.grows(along:)`). The arithmetic is the host
layer's, so the room a space takes is the same on every host. The Web hands
its stacks to the browser, so there the same rule is written as CSS: a space
is a flex item growing from nothing (`flex: 1 1 0`), which the browser shares
alike. Each host stands a space in the view its `ZStack` stands in, so what it
is made of, its outline and its shape are drawn as a fill's are.

## A fill

A fill is a region that holds nothing and takes the room it is offered: in a
ZStack, a grid's cell or a page the whole room, and across a stack its
breadth, as every child whose alignment fills. Along a stack it measures as no
room of its own and grows no more than any other child does, so it is as long
as it states, and none where it states nothing. Each host stands it in the
view its `ZStack` stands in and draws its background, its outline and its
shape there as a layout's box (`LayoutMembers.regionMembers`, a layout's box
without the cut, as nothing stands inside to cut), so a blur or glass is drawn
where the platform draws one; it takes no padding.

## A separator in a stack

A `Separator` is a view: the toolkit's own line, across its stack and as thick
as the toolkit draws one. A line between a menu's entries is a
`MenuSeparator`, one of the entries a menu draws itself
(`NodeType.viewlessTypes`), so it never gets a view.

Each host draws the line its toolkit offers: AppKit's separator box, a hairline
in UIKit's separator color, the Android theme's list divider, WinUI's divider
stroke, GTK's separator - turned to run down a row - and the document's rule
on the Web. A hairline is one pixel, a third of a point on a dense screen, so
a test reads its thickness unrounded.

## Grids

A grid has as many rows and columns as it defines, or as its children reach,
whichever is more; an undefined track is a proportional track of one share.
A child's cell is its row and column, clamped into the grid, spanning its
spans.

## Tracks

A fixed track is its length. A child asks of the tracks it spans what they
lack: its size less theirs and the spacing between them. Taken from the
children spanning the fewest tracks, a child spanning no proportional track
shares its lack alike among its automatic tracks, so an automatic track
spanned alone is as large as its largest child. A proportional track divides
what the fixed and automatic tracks and the spacing leave, by its share;
measured with no room given, the proportional tracks share the least
remainder whose shares hold every child spanning one - its lack over the
shares it spans - so the grid placed at its natural size, or wider, holds
every child at the width it was measured for. A share of nothing still counts
as a sliver, so no division is by zero, and asks for no room.

The trap is a natural size taken track by track: two shares of 95 beside three
of 300 make a remainder of 395, which placement shares as 158 and 237, and the
words measured on one line at 300 stand wrapped at 237 - on WinUI a layout
cycle that ends the application. A child left out because it spans two tracks
is the same trap: two proportional columns holding only a button across both
measure as the spacing between them, the button's row is measured at that
width, its words a column of letters, and the row stands that tall however
wide the grid is placed.

The columns are settled first, and a row measures each of its children at
the width of the columns it stands in, so words that wrap in a column make
their row as tall as they will stand. A grid measured for a width narrower
than its natural one shares that width among its columns as its placement
would, and its rows are measured at those widths; its natural width stays
its children's.

## Layers

A ZStack stands each shown child in its area and places it there as one child
stands in its room: by its alignments, margins and stated sizes. The area is
the room within the stack's padding, or the rectangle the child names - in
points from the room's top left, or in fractions of the room. The stack's
natural size is the room its neediest child needs at its natural size: a
rectangle in points to its far corner, a fraction as much as leaves the child
its natural size in its share, and anything else its size and margins.

## A phase layout

A phase layout has no size of its own: it takes the room its layout gives
it, whatever its views need, as a shape does - its padding and nothing more.
Its views stand where arithmetic of that room puts them, so a size taken
from them, as a ZStack takes its children's, would feed the very room the
arithmetic is worked out from: a scroller's content is the room plus how far
the run reaches. Each host stands the engine on its ZStack and measures it
by `ZStackArithmetic.size(of:padding:width:engine:)`; on the Web, CSS's size
containment says the same.

## A placing run

A state that places a ZStack's children - a placing run - stands each child
where the run says, no size below nothing, drawn at the run's opacity within
0 and 1, and draws them back to front by their z-index, the earlier first
among equals, the children it places none of after them in their order
(`ZStackArithmetic.drawingOrder`, `HostPlacement.place`, `drawnOpacity`).

## A placed child

A child a run places is drawn moved, turned and scaled by the run over what
its own properties say, and a toolkit keeping one translation, rotation and
scale for a view takes the two composed, the same on every host
(`HostDrawingTransform.under`): the turns add, the scales multiply, and the
child's own move is turned and scaled by the run's before the run's is
added, all about the child's center. That is exact while a run's scales are
the same on both axes, which is what a run draws.

## Drawing order

A grid's, a ZStack's and a phase layout's children can overlap, so their
order is the order they are drawn in: by `zIndex`, lower first, and children of the same
`zIndex` in the order the view wrote them. The mounted element keeps
`children` in that order and remembers the order written, so a sparse change
or a bound `zIndex` moving in a frame restacks them and arranges the layout
once; a runtime hands `children` to its toolkit in that order and needs no
`zIndex` of its own. A stack's children never overlap and keep the order
written.

## One child

A page or a pane holds one child in its room, within the child's margin; the
space inside a page is its view's own padding. The child is measured only where
its natural size places it - on an axis it does not fill and states no size
for - so a child that fills both ways takes the room whatever it would measure.
A container with no shown child takes no room.

## A button's picture and words

A button's picture beside its words stands with them, the two together in the
middle of the room inside its padding, however wide the button is laid out. A
control that draws its picture at its own edge and its words in the middle is
given, on each side, half of what the picture, the gap and the words leave
(`ButtonArithmetic.sideRoom`) as more padding where it is placed; it is not the
button's, so it is left out of what the button measures. A picture above or
below its words is already in the middle with them. Beside its words a
picture stands at its own size, smaller where the button is, never stretched
over them; alone it fills the room as its aspect says - but an icon, which
stands at its own size alone too, as the platform's icon buttons do.

## A row beside a page

An arrangement's own row - a tabbed view's tabs where they stand in no window
row - stands across the top or the bottom of its room (`RowEdge`), and the
page takes the rest, never less than none; the arrangement's size is its
page's with the row's height added.

## A box

A box - a layout's, a button's, a rectangle's - is read the
same way on every host (`BoxArithmetic`): its corners' radii stand clockwise
from the top left, the order toolkits take them in, each never below nothing;
a corner is round and no more than half the shorter side, so a radius past
half a wide box's height rounds its ends whole - a capsule, not an oval; its
outline is a rectangle where the tree asks none, a rounded one's radius never
below nothing; a capsule's corners round by half the shorter side at whatever
size the box takes - one radius for a box's size, `BoxArithmetic.cornerRadius`,
which a host asks again as the size changes - and an oval is an oval on every
host, never a capsule, though a toolkit's control rounds only corners; a
`Capsule` shape is a rectangle drawn with `BoxArithmetic.capsule`, a radius
past any room - in a display's pixels too - which the rectangle's own drawing
fits to half its shorter side, so its ends round whole at every size without
a host asking its size; an outline is a rounded rectangle, its corners
clockwise (`BoxArithmetic.roundedCorners`), but for an oval of two lengths -
a circle is one, half its side round - which a toolkit shaping a view by its
corners alone, as glass is, cannot draw; and the
outline is drawn one wide where the tree gives it a color and no width, and
not at all without a color. A fill is read as the tree
sends it (`HostBrush`): a bare color is one color, a gradient's stops stand
between 0 and 1, a gradient given no geometry runs top to bottom, or from
the middle to the edge, and a gradient of one stop is its color, of none
nothing - whatever a toolkit makes of one that short. A line drawn in one
color takes the brush's first.
A fill a host draws for a control itself - a button's background, an accent -
keeps nine tenths of its opacity under the pointer and eight tenths pressed
(`PressedFill`), as the platforms' own controls fade theirs.

## A button's role

A button's role draws as each platform draws it where the tree draws nothing
of its own (`ButtonRoleLook`): the main action filled in the platform's
accent, an action that destroys something with its words in the platform's
color for one - the red its alerts and menus give such an action - and the
way out, like a button of no role, as the platform's plain one. A fill or a
color of words the tree states, by a style or on the button, wins: a role's
look is the platform's, and an application drawing its own buttons draws
their roles too (`Style<Button>(role:)`).

## The safe area

Every room a page stands in - a window, a sheet, a popover - has a safe area:
the part of it clear of what stands over the page. That is the platform's - a
phone's status bar, notch and home indicator, the keyboard - the room's - a
popover's arrow, a sheet's grabber - and the arrangement's own bars over the
page: a stack's, the tabs', a split view column's part of the bar. A page's
content stands in it (`SafeAreaArithmetic.room`); on each edge the content's
own layout ignores the safe area on (`ignoresSafeArea`, the start and the end
as it lays out) its room reaches out to the room's edge, so a background or a
gradient runs behind a bar or the status bar. What stands over an edge is one
answer whatever it is: no platform keeps a page clear of one thing over an
edge and under another. A column beside a page - a split view's sidebar
standing beside its detail - is no part of what the page runs under: where a
toolkit lays the page under that column, the page's room starts at its edge. A scroller let under keeps clear, on each edge it reaches under,
the depth of what stands over it there (`SafeAreaArithmetic.clearance`): its
content scrolls under the bars and its first and last rows stop clear of
them, as the platform's own lists do, and its offset counts from its first
row clear (`offset`, `native`) - the tree's nothing is that row in place. A
host gives each room's insets as its toolkit has them; a bar its platform
stands beside the page rather than over it insets nothing, and a desktop
window with nothing over its content has its whole room safe. The page's
background stands behind everything over it either way.

## A bar at the foot

A page's bottom bar (`.bottomBar`) is a view the page stands at its foot, in a
layer of its own the core wraps it in - no layout arranges what a slot holds,
so the layer places it as its values say. It stands across the safe area as
tall as it lays out at that width, measured again on every layout, its foot on
the safe area's foot (`BottomBarPlace`): above a phone's home indicator, its
ground running down to the room's edge, and on the keyboard while one shows.
What stands over a room's foot is the keyboard while it is the higher, else
the system's bar - never both (`SafeAreaArithmetic.bottom`). The innermost
declaration on a page's path wins, as a title view's does, and a bar declared
on a stack or tabs stands on the one page they show (`chromeBottomBar`): one
view stands in one place, so a host hands it from the page losing it to the
page taking it in that order.

The page's safe area ends above the bar: its content stands clear of it, and
a scroller let under scrolls under it, its last row stopping clear. A host
stands the bar as its platform's bars stand: over the page where they stand
over it - the page keeping clear what the bar and what stands under it take
(`safe`) - else beside it, the page's whole room the one above the bar
(`above`). What the bar holds is laid out as a page's own view, so a change
inside it - a word typed into its field - shows no chrome again; the bar's
coming and going does.

A bar stands on the page while nothing stands under it, and shows its edge
(`ScrollEdge`, the bar's `edge`) while its page's rows go on past it - under it
where they run under the room's foot (`BottomBarPlace.covers`), beyond its top
where it stands beside the page (`continues`), its scroller short of its end.
`.automatic` is the platform's: UIKit's own scroll edge effect under the bar
(`UIScrollEdgeElementContainerInteraction`, soft on iOS 26, hard on iOS 27),
GNOME's flat bottom bar, which shows its shadow while the content scrolls; on
AppKit and the Web, which draw none, a blur in the page's hue under the bar
(`BottomBarPlace.blur`, `tint`), and where the bar stands beside the page -
Android, WinUI - the hard one. `.hard` cuts the rows off at the bar: UIKit's
hard edge, the same blur with a line along its top on AppKit and the Web, the
theme's line along the bar where it stands beside the page, GNOME's bar with
its border. On iOS 27 the automatic edge takes its shape from the glass the
bar holds; a view StateUI draws shapes nothing.
`.none` shows the rows as they are - all but GNOME's flat bar, whose shadow
stays. A soft edge drawn by StateUI itself is no road yet: a masked blur
crossfades sharp rows into blurred ones rather than blurring them more, and
iOS 27 draws no soft edge at all.

A scroller standing at its end stays at its end as what it reaches moves with
its content the same - its room shrinking beside a growing bar, what it keeps
clear growing under one, the keyboard rising (`ScrollArithmetic.keptAtEnd`); one
elsewhere stays where it is, and one that reached nothing stays at its start,
so a field at the top of a short form stays in sight. The keeping is the
scroller's own move, told to the tree as the user's is, so the state says
where it stands. Content growing at the end moves nothing: a list that loads
more as it is reached must not follow what it loaded.

## Words on a painted band

Words on a band the tree paints - a bar, a row of tabs - take the color the
tree writes for them; where it writes none, a band is dark where its relative
luminance, by Rec. 709's weights, is below a half - a gradient's band the
mean of its stops' - and its words are white on a dark band, black on a light
one (`BandWords.color`). Every host decides it alike, whatever
its toolkit's own idea of a dark color.

## A picture

An application's picture is the file its name stands for, looked for in one
order (`PictureArithmetic.files`): the name, then - for a PNG - an SVG of the
same name, which a host drawing vector pictures reads in its place. A host
drawing no SVG reads the SVG's drawing made as the application is built,
`<name>@3x.png`, at three pixels a point (`PictureArithmetic.drawnFiles`). A
host drawing the picture itself stands it in its room by its aspect
(`PictureArithmetic.place`): fitted in or covering the room with its
proportions kept, or at its own size - each in the room's middle - or
stretched over the whole of it. A picture on a bar or a tab stands at the
platform's icon height, as wide as its shape makes it, whatever size it is
drawn at elsewhere (`PictureArithmetic.glyph`): the platform draws its own
pictures there at that size, and one at its file's size stands far taller. A
host drawing an SVG draws it at the size it shows at, in the display's pixels
- a stretched one at its room's own size, sharp both ways - and again only for
more pixels, so a size in motion does not draw it every frame
(`PictureArithmetic.vectorPixels`, `drawsAgain`).

## An icon

A picture is a file, an icon or bytes (`HostPicture`), read alike on every
host from the member's value. An icon is one of a closed set (`Icon`), each
drawn as its platform draws its own: an SF Symbol on AppKit and UIKit
(`Icon.sfSymbol`, which both share), Material Symbols on Android - its own
applications' icons, which the host brings, as Android ships none - a glyph
of Segoe Fluent Icons on WinUI, the theme's symbolic icon on GTK, and on the
Web a drawing of StateUI's own. An icon takes the color of what it stands in:
standing alone, the platform's primary words color, as a label beside it;
in a button, its words' - the platform's, its role's, the tree's own; in a
bar, the bar's. Where nothing gives it room, it stands at the platform's
own icon size. Bytes are a picture encoded whole - a
PNG, a JPEG - read where they are given, at one pixel a point.

## A shape's own geometry

A line, a path, a polygon and a polyline draw a geometry of their own
numbers, which every host places in the room the shape's layout gives it by
one rule (`ShapeArithmetic`): scaled by the shape's aspect - to fit keeping
its proportions, to cover, each axis on its own, or not at all - and centered;
then moved by the shape's own transform, as a transform moves a view after
its layout, so a translation shows under every aspect. A geometry flat along
one axis, a straight line, fits by the axis it has.

A polygon's and a polyline's points are joined by lines - the same curve
commands a path's data reads as - closed where the shape is, a point that is
no number left out; a stroke's dashes and gaps are measured in stroke widths
(`ShapeArithmetic.curves`, `dashLengths`). A host drawing in Swift takes the
commands as they are; one whose relay reads numbers hands it each command's.

## Right to left

A layout works its places out left to right, then turns each about the
middle of its room when it lays out right to left. That one rule is every
mirror a language written right to left needs: a row fills from the right, a
column's start stands at the right, a grid's column 0 is the rightmost, a
ZStack's area counts from the right edge, a scroller's content stands from
the right of its document, and padding and margins swap sides.
Nothing vertical changes, and no transform or drawing is turned.

An inset says its sides as `start` and `end`, never left and right, so the
same words are true both ways. A toolkit's own control that pads its content
by left and right - a text, a button - is given its padding's start and end
by its element's direction (`Insets.sides(in:)`), and given them again
whenever that direction turns; where a toolkit names its sides logically
(the Web's CSS) or mirrors a control whole (WinUI's `FlowDirection`), the
start goes as its leading side. The safe area's edges a layout lets its
content under take their start and end by the content's direction too
(`SafeAreaArithmetic.room`).

A phase layout's run is written left to right and stands as written, unless
the layout mirrors (`PhaseLayoutContract.mirrorsRightToLeft`): then, laid out
right to left, its run stands turned by the same rule - each place about the
room's middle, its move along and its turn the other way
(`HostPlacementRun.place(of:in:)`, `drawing(of:)`, the run carrying its
direction) - and the hand over it is told as the arithmetic reads it: its
moves and speeds the other way along, a view's point about the room's width,
two fingers' turn the other way round (`MountedElement.runDirection`).
A direction that turns presents the run again. A toolkit that stands a view
from the room's right edge itself - the Web, by CSS - takes the place as
written (`writtenPlace(of:)`) and moves the view left from the right corner,
reading no room.

The direction is the element's own `layoutDirection`, or - left at
`.inherited` - its parent's, and at the root the language's, as the host
reported the locale (`HostLocaleInfo.layoutDirection`). The mounted element
answers it (`MountedElement.layoutDirection`), and a runtime hands it to the
arithmetic with the room: each layout view keeps the direction its element
answers as it arranges its children, and the arithmetic takes it on every
call, with no default to forget. A direction that turns lays out again what
follows it - an element's own, every layout under it that inherits it; the
language's, the whole tree (`MountedTree.followTheLanguagesDirection`, which
a runtime calls after it reports the locale) - and nothing else.

## Scrolling

A scroller's content is held to the scroller's width when it scrolls only
down, or not at all, and offered no width when it scrolls across, where its
width is its own to decide. A filling child stated no width takes the width
it is held to. The document the content stands in is never smaller than the
viewport: along an axis the scroller scrolls it is as large as the content
with its padding and margin, and along any other it is the viewport's.

## An offset the tree writes

An offset the tree writes moves a scroller the same way on every host: one
that scrolls neither way stands at its origin; no offset, one that is no
number, or one it stands at already - within half a point, as the user's own
scrolling comes back as the state it wrote - moves nothing; any other moves
it, kept between its origin and what it reaches. An offset written before
the scroller's first layout waits for it, the last one written winning, and
one that scrolls neither way stands at its origin at once
(`ScrollerOffset`). A host moves its toolkit's scroller there as the
program's write.

## Where a scroller stands

`ScrollerOffset` holds where a scroller stands as its host last knew it, and
tells what the toolkit says apart, the same on every host. A word said inside
the program's write is the program's move, wherever the toolkit stopped the
scroller - the synchronous toolkits say it there. A toolkit that says the
move later - WinUI's view in a later frame, a browser's `scroll` event - is
heard arriving within half a point of where the program moved the scroller:
a scroller lands a fraction off, and half a point is less than a pixel. A
toolkit that keeps a move within what it reaches itself - Android's
scrollers, a browser - is read once asked, and its word to come is to say
where it stopped (`programLanded`). Any other word is the user's, from where
the scroller stood; the user taking hold makes a move of the program's still
on its way theirs. A move to where the scroller stands within half a point
moves nothing.
