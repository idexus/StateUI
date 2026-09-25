# Controls on WinUI

How the WinUI host presents the controls a user changes - a switch, a slider,
a field - and hears what the user does to them. The value a control carries
belongs to a state; the host writes the control where the tree changed that
value and reports the user's change back ([patches](../../host/patches.md)).

## Words

How words look is one road for every element showing them, a `TextBlock` or a
control: the font - its size, weight, slant and family - the colour, and the
room around them, each the platform's where the tree says nothing. A label
adds its lines, its alignment across itself, the space between its letters
and its lines, and the lines under or through its words.

WinUI spaces letters in thousandths of an em and lines in DIPs, where StateUI
gives the first in points and the second as a multiple of the font's own
line: both are worked out against the font's size, a line of Segoe UI taken as
four thirds of it. A `TextBlock` cuts words short only at their end, so a label
cut at its start or in its middle is cut at its end.

A button drawn in the application's colours keeps them under the pointer and
pressed: its fill is drawn a little fainter each time, as WinUI's own buttons
are, its words and outline as they are - WinUI's template otherwise draws
those states in the platform's colours.

## Runs of words

A label's spans are its words, run by run: each a `Run` among the text
block's inlines, taking the colour, size, weight, slant and lines its span
says and the label's own where it says nothing. A run's background is a
`TextHighlighter` over its part of the words - a text block has no background
per run - keeping the run's colour on them. The runs stand in place of the
label's own words; a label whose spans are taken away shows its own words
again. A span that changes has its label apply again, so the runs are laid
down whole each time.

## Nothing the program writes is heard

Every native write of an element - a patch applied, a display frame presented
- runs inside `ProgramWrite`. WinUI raises a `ToggleSwitch`'s `Toggled`, a
`Slider`'s `ValueChanged` and a `TextBox`'s `TextChanging` inside the write
that sets the value, so a report during that write is the write's echo, and
the element reports nothing. A control keeps no flag of its own.

## A slider in steps

A `Slider` snaps its value to `StepFrequency`. The host sets the step to a
ten-thousandth of the range, so a value the user drags to has that as its
finest step. On a desktop the keyboard moves a slider too: an arrow key
moves it a hundredth of the range and Page Up a tenth, as WinUI's own slider
steps 1 and 10 across 0 to 100. A new range keeps the value the thumb stands
at, inside the range, unless the tree wrote a new value with it: a hand on the
thumb is never argued with. The range is widened before it is narrowed, so
neither end clamps the value on its way.

## A field and its words

A field is a `TextBox` on one line. It reports all its words from
`TextChanging`, which WinUI raises inside the write that changes them - a
key, a paste, or a program's write - where `TextChanged` comes later, once
the write has ended and `ProgramWrite` with it. A report comes back as the
value of the state it carries: the host writes the words only where they
differ from the field's own, so the render a keystroke causes leaves the
user's words and caret alone. Words the program writes put the caret after
them.

`maximumLength` counts characters, as the contract does. The field keeps the
first characters that fit and writes them back, as the program, when typing
goes past the bound.

A test types by writing the field's words outside a program's write, which
WinUI reports as it reports the user's. UI Automation's value pattern on a
`TextBox` fails inside a test process that holds WinUI embedded, so a test
does not type through it; a button, a switch and a slider are driven through
their automation patterns.

## Return

A field submits when Enter goes down in it; the key's release reaches nothing.

## Pictures

An Image shows a picture from the application's `Images` folder, beside the
executable, by the file name the tree gives it. Where the tree asks for a PNG
the folder holds as an SVG, the SVG is shown: the application's pictures are
written once, as SVGs, for every host.

A picture is its own size, whatever room its layout offers: an SVG the size
it declares - its width and height, or its viewBox - and a bitmap its pixels,
once WinUI has read it. WinUI measures an `Image` at as much room as it is
offered, and an SVG at the size it last drew it, so the host reads the size
itself, and the image asks WinUI for no room
([no room asked](layout.md#no-room-asked)): it is drawn in the place its
layout gives it. A bitmap is read after its layouts were measured; once it
is, the relay asks the layout holding it to measure again
([a change told upward](layout.md#a-change-told-upward)).

WinUI draws an SVG into pixels and takes those pixels for DIPs. The host has
it drawn at the size it shows at in its room, in its own proportions, at the
display's scale - again only for more pixels, so a size in motion does not
draw it every frame - and WinUI's `Stretch` fits it, fills with it, or
centres it. A centred SVG gives the image its declared size, in the middle
of the room. A stretched picture keeps no proportions, and WinUI draws a
stretched SVG at its room's size, where the SVG would keep its own and leave
bands: the relay hands WinUI the picture from memory with its proportions
let go (`preserveAspectRatio="none"`).
