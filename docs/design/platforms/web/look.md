# The look of the Web

The Web host looks like a current web page, not like another platform's
application: one stylesheet of the host's, `stateui-web.css`, gives the window
its bar, the sidebar, the pages and the controls their look, light or dark as
the user's system is - a control in the window's room, on a sheet and over
every page alike, as the rules for controls name all three. What an application says of an element's look - a
colour, a font, a box, a shape - is that element's own style, which wins over
every rule of the stylesheet, so the application's look is always the one
shown.

## The parts

The page's colours, its radius and its bar's height are CSS variables on the
root, each colour one `light-dark()` pair of the light appearance's and the
dark's. The font is the system's own. The bar stands in the row above the
room, so nothing scrolls beneath it, translucent and blurred where the
application paints it nothing; its buttons are round and glassy - a veil of
the bar's own foreground colour - and the
buttons of one group of actions share one capsule. The sidebar is a surface of
its own beside the page, a drawer over it where the page is narrow. Buttons
and fields take a border, rounded corners and a ring in the accent colour
where the keyboard's focus is; a checkbox, a radio button, a slider and a
progress bar take the accent colour. A ScrollView's scroll bars are thin. A
control the host makes no element for yet is named in red, in a dashed box,
where it belongs.

## A field's padding

A select and a search field take 12 points of padding on one side and 34 on
the other, where their arrow or glass stands, and a box of the browser's is
never narrower than its padding and border. The width the layout writes for a
view is also written as `--stateui-width`, and those two fields' padding is
that width less the border, in the same shares, wherever it is less than 48:
a field stands as wide as the room it is given.

## A view's background

A view's plain background - one that paints no box of its own - is the CSS
background colour of its element, under its whole box: a colour, or a brush's
first colour; a layout and a button paint theirs as a box
([drawing](drawing.md#a-brush-on-a-box)). A field, a picker's `<select>`, a
date or a time is filled where the user writes, as the browser draws a field
the page colours. The trap: written as the `background` shorthand, the colour
would clear the picture the page's look draws in a field - a picker's chevron,
a search field's glass. A ColorBox's colour is a swatch filling its box, so
its background shows where rounded corners leave the box bare; a web view's
background shows where the page it shows paints none, and stands white where
the application gives none. The browser draws its slider over the slider's
whole box and paints no background under it, so a slider has none.

## Motion

The drawer slides, a pushed page rises into place, a sheet and a question
rise, a menu and the shade fade in - none of them where the user asks for less
motion.
