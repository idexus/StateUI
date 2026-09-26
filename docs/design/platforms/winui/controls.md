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
four thirds of it. The lines a label's break allows are the host layer's
([runs of words](../../host/tree.md#runs-of-words)); a `TextBlock` cuts words
short only at their end, so a label cut at its start or in its middle is cut
at its end.

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
check box's or a radio button's `Checked` and `Unchecked`, a `Slider`'s and a
`NumberBox`'s `ValueChanged` and a `TextBox`'s `TextChanging` inside the write
that sets the value, so a report during that write is the write's echo, and
the element reports nothing. A control keeps no flag of its own.

## On or off

A Switch is WinUI's `ToggleSwitch`, a CheckBox its `CheckBox` and a
RadioButton its `RadioButton`, one view kind in the host: whether it is on,
whether it can be turned, and the turn the user makes, each telling it through
the same callback. A check box has no caption, so it takes no caption's room:
the box alone, where WinUI's own style would reserve the width of words.

Which of a radio button's set loses its check is the host's. A set is named
across the window, or is the buttons beside one that names none, and only
the tree knows who is in it: the button the user checks reports that it is
on, and the host takes the check off each other button of its set, each
reporting that it is off, in one transaction. WinUI's own grouping would
uncheck the button's neighbours by itself - and the one that lost would be
heard twice - so every button stands in a group of its own.

A background given to one of them is what it is drawn over in every state:
its templates paint their own backgrounds under the pointer, pressed and
disabled - transparent until then - so the host writes the brush into each of
those resources on the control as well, and the control reads its theme
again so its template takes them. A checked radio button's wash is its
Checked visual state's background, which the core lays as the user chooses.

## A control's accent

A control's tint is its one accent colour, where WinUI draws the system's
accent: a ticked box, a switch's track while it is on, a slider's thumb and
the track up to it, a progress bar and a spinner. A progress bar and a spinner
draw with their foreground, which the tint is. The other templates take their
brushes from resources named
for the control - `CheckBoxCheckBackgroundFillChecked`, `ToggleSwitchFillOn`,
`SliderTrackValueFill` and their kin - so the tint is written into the
control's own resources under those names, the colour itself and fainter
under the pointer and pressed, by the host layer's shares ([a
box](../../host/layout.md#a-box)), as WinUI's accent brushes are. A template reads its resources as its theme is read, so the control
reads its theme again at once; a tint changed after the control is drawn is
drawn. No tint takes the names away, and the system's accent returns.

## A picker

A Picker is WinUI's `ComboBox`: its choices, the one chosen, its title as the
placeholder it shows while none is, its words' font and colour, and its
choices standing across it - the one shown and each in the list alike, the
list's through a style for its items. The chosen one is written only where the
tree changed it or the choices changed, so the user's choice is never argued
with. `isOpen` opens and closes the list; the user's opening and closing are
reported and the program's are not, so the user closing a list the program
opened is reported. The chosen choice's mark in the list is the picker's tint.

## A day and a time

A DatePicker is WinUI's `CalendarDatePicker`: its day written short or long -
"d" and "D" - in the user's own pattern, which WinUI's own formatter gives,
between the bounds the tree set or WinUI's hundred years each way, and its
calendar, whose opening and closing follow a picker's list. A day crosses as
its year, month and day in the user's calendar, taken at noon so that no
change of the clock moves it to another day.

A TimePicker is WinUI's `TimePicker`, in the user's clock: hours and minutes,
as the user's 12- or 24-hour choice writes them. WinUI's time picker has no
way to open its face or to hear it open, so a time picker's `isOpen`,
`onOpened` and `onClosed` are not realized, and a format beyond the user's
own clock - seconds, a pattern - is not written.

The user's day or time is reported, the program's is only shown.

## What shows work

A ProgressBar is WinUI's `ProgressBar` over the range 0 to 1, a fraction past
either end standing at that end ([a value in a
range](../../host/runtime.md#a-value-in-a-range)); an ActivityIndicator is its `ProgressRing`,
turning while its work runs and gone while it does not.

## A stepper

A Stepper is WinUI's `NumberBox` with its spin buttons beside its number: the
number the user can also type, the buttons and the arrow keys moving it a
step, Page Up ten. The number is written in the user's own way with as many
decimals as the step and the range take, and the value is kept inside the
range ([a value in a range](../../host/runtime.md#a-value-in-a-range)). Words
that say no number - an emptied box among them - leave the number where it
was: the box is given it back, and nobody hears it as the user's.

## What assistive technology meets

What an element says for assistive technology - its identifier, its label,
its hint and its heading level - is WinUI's `AutomationProperties`:
`AutomationId`, `Name`, `HelpText` and `HeadingLevel`, level for level. A word
the element does not say is cleared, not written empty, so a control's own
name - a button's caption - stands where no label replaces it.

Whether it is met at all is its accessibility view: an element hidden is
`Raw`, which assistive technology skips while it still meets what stands in
it; an element that says it is not hidden is `Content`; one that says
nothing keeps the view its control has. An element left out with its
children is `Raw`, and a layout so left out answers assistive technology with
no children at all, its panel's automation peer holding them back. A control
needs nothing more: what its template draws - a button's words - WinUI
already keeps out of what is read.

Assistive technology meets an element only through its automation peer, and
WinUI gives a shape, a colour box and a canvas none: the words written on
them reach nobody. A menu's item and a toolbar's are WinUI's own, and carry
no identifier yet. The registry says so
(`WinUIRegistrations.unmetByAssistiveTechnology`), so the dictionary shows
those cells empty rather than promise what no screen reader hears; a peer of
the host's own on each is what fills them. A control whose template holds
parts with peers of their own - an activity indicator, a date picker, a
search box, a slider, a stepper, a switch, a time picker, a field and an
editor - left out with its children still offers its parts
(`partsMetWhenLeftOut`); a peer that holds them back, as a layout's panel
holds its children back, is what fills those cells.

## A slider in steps

A `Slider` snaps its value to `StepFrequency`. The host sets the step to a
ten-thousandth of the range - WinUI's own, where the other steps are the host
layer's - so a value the user drags to has that as its
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
goes past the bound. An editor's `TextBox` ends each line with a carriage
return, where StateUI's words end it with a line feed: the host reads and
hears every line's end as a line feed.

A test types by writing the field's words outside a program's write, which
WinUI reports as it reports the user's. UI Automation's value pattern on a
`TextBox` fails inside a test process that holds WinUI embedded, so a test
does not type through it; a button, a switch and a slider are driven through
their automation patterns.

How the words are taken is the tree's where it says so and WinUI's where it
does not: read only, spell checked and predicting the next word - WinUI's
defaults, both on - and what they are for, which is the text box's input
scope and so the on-screen keyboard. The words stand across the box as their
alignment says, the placeholder takes its colour, and the caret and the
selection are put where the tree put them, in the characters WinUI counts,
only where the tree changed them.

A test of a search box types into the text box its template holds: the
search box's own words written from outside are the program's to it, and
reported as such. The search box tells those words a moment after it takes
them, so a test waits for them before it submits the query - as a key is
told before the next is pressed - and submits through the search box's
automation peer, as its own button does.

## Return

A field submits when Enter goes down in it; the key's release reaches nothing.

## An editor

A TextEditor is a `TextBox` of several lines whose Enter starts a new line and
submits nothing, its words wrapped and scrolled inside it. Growing with its
words, it is measured with the room below it open and takes the height they
take, WinUI telling its layout as they change; not growing, it is measured
with none and keeps a line's height, whatever it holds - the height the
layout gives it is the room it scrolls in.

## A search field

A SearchField is WinUI's `AutoSuggestBox` with its search glyph: its words and
placeholder are the box's, its query - Enter or the glyph - submits, and only
a change the box calls the user's is reported.

## Pictures

An Image shows a picture from the application's `Images` folder, beside the
executable, by the file name the tree gives it: the first of the files the
name stands for that the folder holds ([a
picture](../../host/layout.md#a-picture)), so where the tree asks for a PNG
the folder holds as an SVG, the SVG is shown - the application's pictures are
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
