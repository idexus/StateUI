# Controls on GTK

How the GTK host presents the controls a user changes - a switch, a slider, a
field - and hears what the user does to them. The value a control carries
belongs to a state; the host writes the control where the tree changed that
value and reports the user's change back ([patches](../../host/patches.md)).

## Words

A label's words are a `GtkLabel`'s, and how they look is one list of Pango
attributes written whole whenever any of it changes: the font's size in
logical pixels, its weight, slant and family, the colour, the space between
the letters, a line's height as a multiple of the font's own, and the lines
under or through the words - each GTK's own where the tree says nothing.

A label wraps at word boundaries, breaking a word only where it alone is
wider than the label, or at any character; cut short, it shows an ellipsis
where the tree asks. GTK cuts a word short at its start or middle on one line
only, so a label allowed several lines is cut at its end. Its lines stand
from its leading edge, in its middle or at its trailing edge, which GTK turns
over for a language written from the right.

A label's padding is room inside its own box, around its words
([a widget's own box](drawing.md#a-widgets-own-box)). A button's caption is
the `GtkLabel` the button shows it in, and takes the same look, font and
colour, and the button its padding.

## A button's box

A button the tree gives a fill, an outline or a shape wears a class of the
host's style sheet drawing them - the fill as its background, the outline as
its border, the shape as its corners' radius, an ellipse as round ends - and
what the tree says nothing of stays the theme's. The sheet stands above the
theme, so its fill would stand under the pointer and pressed too: the class
draws the fill a little fainter under the pointer and fainter again pressed,
as the theme's own buttons answer.

## Runs of words

A label's spans are its words, run by run: the label's text is their words
joined, and each run's look - its colour, size, weight, slant, lines and
background - covers its own bytes of it, the label's look where the run says
nothing. The runs stand in place of the label's own words; a label whose
spans are taken away shows its own words again. A span that changes has its
label apply again, so the runs are laid down whole each time.

## Nothing the program writes is heard

Every native write of an element - a patch applied, a display frame presented
- runs inside `ProgramWrite`. GTK tells of a change inside the call that makes
it: a `GtkSwitch`'s `active` notice, a `GtkScale`'s `value-changed`, a
`GtkEntry`'s `changed` come from the host's own setter as from the user's
hand. A report during the program's write is the write's echo, and the
element reports nothing. A control keeps no flag of its own.

## A slider and its range

A slider is a horizontal `GtkScale` that draws no number. A scale rounds the
value the hand sets to its digits; the host asks for no rounding, so the
value reported is where the thumb stands. The keyboard's step is a hundredth
of the range, a page a tenth. A new range keeps the value the thumb stands
at, inside the range, unless the tree wrote a new value with it: a hand on the
thumb is never argued with.

## A field and its words

A field is a `GtkEntry`. It reports all its words from `changed`, which GTK
raises once for each change - a key, a paste, or a program's write. A report
comes back as the value of the state it carries: the host writes the words
only where they differ from the field's own, so the render a keystroke causes
leaves the user's words and caret alone. Words the program writes put the
caret after them.

`maximumLength` is the entry's own bound, in characters, as the contract
counts them: GTK keeps the first characters that fit, from a key, a paste and
a program's write alike.

A field submits when Enter is pressed in it, through the entry's `activate`.
A test types by writing the entry's words outside a program's write, which
GTK reports as it reports the user's.

## Pictures

An Image is a panel of the host's showing a picture from the application's
folder ([the application's pictures](drawing.md#the-applications-pictures)),
its own size, whatever room its layout offers: an SVG the size it declares,
a bitmap its pixels, both as gdk-pixbuf reads them from the file.

The panel draws the picture in the place its layout gives it, as the aspect
says - whole in its room, covering it, stretched across it, or at its own
size in the middle - cut at the room's edge. A bitmap is read once. An SVG is
read at the size it shows at, at the display's scale, and again only for more
pixels, so a size in motion does not read it every frame. An SVG keeps its
own proportions as it is read, leaving bands where the room has others, so a
stretched one is read covering its room and drawn squeezed into it - never
enlarged.
