# Controls on the Web

Every control is the browser's own element, in the look the browser gives it
and the theme the user's system chose, until the application gives it a look
of its own.

## A view

A view holds one DOM element, which the relay keeps under its number, from
the view's making until its element leaves the tree: it then takes the
element off the page and lets go of every listener hung on it. A CSS property
is sent only when its value changes.

## Drawn over its place

A view moved, turned or scaled about its pivot is drawn with the host layer's
matrix (`HostDrawingTransform.matrix`), as `matrix3d` from the view's top
left corner, for the view's size in its layout: the order of the moves and the
platform's sense of a turn are the host layer's, once.

## What assistive technology meets

An element's words for assistive technology are ARIA's: its label
`aria-label`, what it does `aria-description`, its level as a heading the
`heading` role with `aria-level`, hidden with what it holds `aria-hidden`, and
hidden alone the `none` role. Its identifier, which a driver finds it by, is
`data-identifier`.

## Words

A Text is a `<span>` whose words wrap at the width it is given and keep their
line breaks. A font, a colour and the room around the words are CSS's
`font-size`, `font-weight`, `font-style`, `font-family`, `color` and
`padding`; what the application leaves unsaid is the page's, and the page's
font is the system's own.

## Runs of words

A Text holding spans shows its runs in place of its own words, each a `<span>`
of its own look (`MountedElement.textRuns`). A run says only what it says
itself - its font, its colour, the space between its letters, its lines'
height, its decorations, what stands behind it - and takes the rest from the
text around it, as the page's styles inherit. A span is kept for each run by
its place, so the runs that change are the only ones written.

A text's lines break as its line break says: at words or anywhere onto more
lines, or on one line, cut short where they do not fit; the page cuts words
only at their end, so a cut at their head or in their middle stands at the end
too. The most lines a text stands on is `-webkit-line-clamp`, where its words
wrap (`LineBreak.lines`).

## A button

A Button is a `<button>`. With no fill, outline or shape of its own it is the
browser's button; with one, its box is the application's - its background,
its border, its corners - and the browser's look goes. It holds its words in
a `<span>` and its picture in an `<img>` beside them, the two in its middle:
the icon's position is the row's or column's direction, its spacing their
gap - 8 points where the tree says none - and a picture with no words fills
the button as its content mode says. Its words break as a label's do, on one
line where the tree says nothing.

## A field

A TextField is an `<input>`, a SearchField a search `<input>` and a TextEditor
a `<textarea>`, each reporting every change of its words, and a field the
Return key. The tree writes its words only where they differ from what the
field holds: writing the same words again would move the user's caret to
their end. The keyboard and the help the user's typing gets are the host
layer's traits (`InputTraits`): `inputmode`, `autocapitalize`, `spellcheck`,
`autocorrect` and `autocomplete`, and what the Return key says
`enterkeyhint`. The caret and the selection are placed in the page's own
units, UTF-16, counted from the characters the tree names. An editor growing
with its words stands as tall as they are, rather than scrolling them. A
field is as wide as its words or its placeholder - `field-sizing: content`,
and its `size` where the browser sizes no field by its content - as a native
field measures, not the browser's twenty characters, which in a row of a
phone's width would push what follows it out of the row. On iOS the page keeps
its scale as a field takes the keyboard - Safari zooms into a field whose words
are smaller than 16 points, and no native field does - by a viewport of at most
scale 1, set on iOS alone, where the user's fingers still zoom the page.

## Toggles

A Switch is the browser's checkbox with the role of a switch, drawn as one -
a track and a knob, the accent colour while it is on, the application's tint
in its place where it gives one - and a CheckBox the checkbox as it is. Each
says when the user turns it (`change`), and the tree turns it through its
`checked`. Each stands at its own size in the middle of a `<label>` that takes
the view's frame: the browser draws a checkbox over its whole box, so a frame
larger than the box - a touch target's 44 points - would draw a larger box,
where every other host draws its own at its size inside the frame. A click
anywhere in the frame turns it, and assistive technology meets the checkbox
by the view's name and hint. A RadioButton is a `<label>` holding the browser's radio button and
its caption, so a click anywhere on it chooses it. Its group is the host
layer's: the button holds no `name`, so the browser turns no peer off of
itself, and the peers the host layer turns off are turned off on the page.

## Values in a range

A Slider is the browser's range, which says each move of its thumb as it goes
(`input`). A Stepper is a field of words with the role of a spin button
between a button taking a step down and one taking a step up, the keyboard's
arrows a step too. A step is a whole step from where the number stands, kept
inside its range, and a number typed past an end stands at it. Words that are
not wholly a number - `5x` - leave the number where it was, and a step or
words that move nothing are heard by nobody. The trap: the browser's number
field drops what it takes for no number as it is typed, so `5x` stood as 5,
and its own steps snap to a grid counted from the minimum, so 1 stepped by
2.5 stood at 2.5. The range, the step
and the number of decimals are the host layer's (`ValueArithmetic`), and a
value the tree writes reaches the control only where the tree changed it or
its ends (`ElementValues.written`), so a hand on the thumb is never argued
with. The value standing on the page is where an animation of it starts.

## A picker

A Picker is the browser's `<select>`: its title first, an `<option>` hidden
and turned off - the field shows it while nothing is chosen, the open list
leaves it out - then an `<option>` for each choice. The choices and the
choice are written only where the tree changed them (`PickerChoices`), so the
user's own choice is never argued with; no choice stands as the title
selected. The choice the user makes is heard on `change`. The browser opens
a picker's list - and a day's calendar, a time's clock - at the user's press,
closes it at the user's hand and says nothing of either, so a picker's
opening is not the program's.

## A day and a time

A DatePicker is the browser's date `<input>`, a TimePicker its time
`<input>`: the browser writes the day and the time in the user's own way and
offers its own calendar and clock, so no format reaches them. A day the tree
writes stands within the range as on every host (`CalendarArithmetic.held`);
the range is the field's `min` and `max`, so the calendar offers no day past
it. A time is within the day (`CalendarArithmetic.clock`), written with its
seconds - and stepping by them - only while it has some.

What the user picks is heard on `change`. A field the user types into is
written again only as the user leaves it: a year typed digit by digit passes
through years far before the range, and each would otherwise be taken from
under the user's keys. A day typed past the range is told at its end, and the
field shows that end once left; a field left empty shows the day held. The
calendar opening and closing reach no event of the page's, so `isOpen`,
`opened` and `closed` stay unrealized.

## Indicators

A ProgressBar is the browser's `<progress>`, its share of the work done from 0
to 1, drawn as a thin rounded bar in the accent colour or the application's
tint across the middle of a box that takes the view's frame - a cell taller
than the bar leaves the bar thin and the frame the cell's. An ActivityIndicator is a ring turning while work goes on - the browser
has no spinner of its own - with the role of a busy progress bar; stopped, it
shows nothing and keeps its room, and it turns slower where the user asks for
less motion. The ring stands at its own size in the middle of the view's
frame, so a frame wider than it is leaves it a circle where it belongs.

## A web view

A WebView is the browser's own `<iframe>` over a box with no size of its
own, as every host's web view: an address it loads, a document
written in place shown at a `blob:` address of the page's own made for it -
of the page's own site, a `<base>` before it where the document says where
its links resolve - told by the same `data:` address every host tells such a
document by (`WebDocument`). The trap: the browser takes a `srcdoc` written
again in place of the one before, so a frame of documents written in place
had no way back; a frame's own navigation is a step in its history. The page hears
the frame's document load, and tells it navigated, for the reason the
program asked where it asked one (`WebNavigationCause`); a step the frame
takes - back, forward, the page again - tells its navigation began as it is
taken, as showing an address does.

The browser keeps a document of another site to itself: the page cannot
read where its user went inside it, nor its history, nor run a script in
it. So of such a document the page tells the address it gave the frame,
no step back or forward is offered, going back, forward or running a script
fails with that reason, and the page again loads the address the page
gave. A document of the page's own site - one written in place - the page
reaches whole: its address, its history where the browser says it
(`navigation.canGoBack`), its steps, and a script's answer by the host
layer's reading of its JSON (`ScriptAnswer`). A frame has no agent of its
own and no process the page could see end: `userAgent` and
`processTerminated` stay unrealized.

The user's pointer, clicks and wheel over a frame go to the frame's own
document, not to the page. Over a document of the page's own site the view
hears them there too - listened for again after every load, each told where
it is in the view - so a tap, a press dragged and a pinch over it are the
view's as on every host; coming and going the view hears itself. A document
of another site keeps them to itself.

## Pictures

An Image is an `<img>` showing one of the application's pictures, which
`run-app.sh` lays beside the page in `Images/`. A name stands for its files in
the host layer's order - a PNG, then the SVG of the same name - and the
element shows the next when one is not found. Its content mode is
`object-fit`. Its own size is the picture's, as every host's picture view
has it, its proportions binding neither length: the element holds its size
alone (`contain: size`), the picture's own given as it loads
(`contain-intrinsic-size`) - a picture across a stack's width stands as tall
as it is, where the browser's own would stand as tall as its proportions
make it. The trap: an SVG picture keeps its own proportions under
`object-fit: fill`, as the file's `preserveAspectRatio` says - stretched, it
stands fitted.
