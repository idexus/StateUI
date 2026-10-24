# Controls on GTK

How the GTK host presents the controls a user changes - a switch, a slider, a
field - and hears what the user does to them. The value a control carries
belongs to a state; the host writes the control where the tree changed that
value and reports the user's change back ([patches](../../host/patches.md)).

## Words

A label's words are a `GtkLabel`'s, and how they look is one list of Pango
attributes written whole whenever any of it changes: the font's size in
logical pixels, its weight, slant and family, the color, the space between
the letters, a line's height as a multiple of the font's own, and the lines
under or through the words - each GTK's own where the tree says nothing.

A label wraps at word boundaries, breaking a word only where it alone is
wider than the label, or at any character, on as many lines as it is allowed,
the last cut short with an ellipsis; cut short where the tree asks, it keeps
one line, however many it is allowed ([runs of words](../../host/tree.md#runs-of-words)), and shows
the ellipsis at its start, middle or end. Its lines stand
from its leading edge, in its middle or at its trailing edge, which GTK turns
over for a language written from the right, and at its top unless the tree
stands them in its middle or at its bottom - GTK's own is the middle.

A label's padding is room inside its own box, around its words
([a widget's own box](drawing.md#a-widgets-own-box)), and its background a
class filling that box in its color - a brush's first color. A button's caption is
the `GtkLabel` the button shows it in, and takes the same look, font and
color, and the button its padding.

## The user's text size

Words follow GNOME's text scaling (`isFontAutoScalingEnabled`, on unless said),
which writes the desktop's dots an inch (`gtk-xft-dpi`): a size stands in
typographic points where the words scale - CSS `pt`, Pango's
`pango_attr_size_new`, both measured against those dots - and in pixels where
not, CSS `px` and `pango_attr_size_new_absolute`. A StateUI point is a pixel
at 96 dots an inch, so 20 is 15 typographic points. Words that do not scale
and are given no size stand at the desktop font's size before its scale
(`GTKEnvironment.fontSize`). A CSS class setting `-gtk-dpi` on one widget
changes nothing GTK 4.14 measures, so the driver doubles `gtk-xft-dpi` itself.

## A button's box

A button the tree gives a fill, an outline or a shape wears a class of the
host's style sheet drawing them - the fill as its background, the outline as
its border, the shape as its corners' radius - a capsule's wider than the
button, which GTK cuts down to half its shorter side, an oval's half of each
side - and
what the tree says nothing of stays the theme's. The sheet stands above the
theme, so its fill would stand under the pointer and pressed too: the class
draws the fill a little fainter under the pointer and fainter again pressed,
as the theme's own buttons answer.

A button opening a menu is a `GtkMenuButton`, a split button libadwaita's
`AdwSplitButton`, and each draws its face with the buttons it holds - GTK's
documented nodes `menubutton > button`, `splitbutton > button` and
`splitbutton > menubutton > button`. A menu button's class leaves the outer
node bare and draws the box on the button it holds: one face, not the theme's
button standing inside the class's box. A split button wears the box whole,
its two buttons bare but for a shade under the pointer and a deeper one
pressed - each rounded at its outer corners alone, by the direction of the
words - and the line between them, which the theme leaves to the gap
between two filled buttons, drawn in the color of its words. The padding
goes to the buttons, which hold the words.

## A button's picture

A button with a picture shows it as an Image draws one
([pictures](#pictures)), as GNOME's buttons compose a picture and words:
with words, a `GtkBox` holds the picture and a label of the button's own,
across them or down them as the icon's position says - before, above, after
or below - the icon spacing apart, else libadwaita's 6. The box stands in
the button's middle however wide the button is, so a button filling its row
keeps the picture beside its words in the middle: a box left to fill the
button lays both from its leading edge. With no words, the
picture alone fills the room inside the padding as its aspect says. The
button wears GTK's own classes for each, `image-text-button` and
`image-button`. Its words break as a label's do where the tree says how, and
stand on one line where it says nothing, as GTK's own buttons stand.

A press is heard as it goes down and as it ends, wherever the pointer ends
up: a drag gesture of the button's own, which claims nothing, so the button
still clicks.

## Runs of words

A label's spans are its words, run by run: the label's text is their words
joined, and each run's look - its color, size, weight, slant, lines and
background - covers its own bytes of it, the label's look where the run says
nothing. The runs stand in place of the label's own words; a label whose
spans are taken away shows its own words again. A span that changes has its
label apply again, so the runs are laid down whole each time.

## On or off

A Switch is GTK's `GtkSwitch` and a CheckBox its `GtkCheckButton`, one view
kind in the host: it writes whether the control is on and whether it can be
turned, and hears the turn the user makes through the property GTK notifies,
`active`, on the control that turns. A check box's words are its button's
label, beside its box, in the look the tree gives them; with none, it is the
box alone.

## A switch's words

`GtkSwitch` has no label, so a switch with words is a row of two: a label
from its start and the switch at its end, as GNOME's settings set a switch
in a row; the row, its label and its switch take the view's direction, so
right to left mirrors them. The words belong to the switch: a click on them
activates it, and assistive technology meets the switch alone, named by the
element's label or else by its words, the label beside it hidden - every
word for assistive technology goes on the control the view presents
(`presentedControl`), its heading role too.

## Nothing the program writes is heard

Every native write of an element - a patch applied, a display frame
presented - runs inside `ProgramWrite`. GTK tells of a change inside the call
that makes it: a `GtkSwitch`'s `active` notice, a `GtkScale`'s
`value-changed`, a `GtkEntry`'s `changed` come from the host's own setter as
from the user's hand. A report during the program's write is the write's echo,
and the element reports nothing. A control keeps no flag of its own.

## A slider and its range

A slider is a horizontal `GtkScale` that draws no number. A scale rounds the
value the hand sets to its digits; the host asks for no rounding, so the
value reported is where the thumb stands. The keyboard's step is a hundredth
of the range, a page a tenth. A new range keeps the value the thumb stands
at, inside the range, unless the tree wrote a new value with it: a hand on the
thumb is never argued with.

## A stepper

A stepper is a `GtkSpinButton`: its number, which the user can also type,
the buttons beside it and the arrow keys moving it a step, Page Up ten. The
number is written with as many decimals as the step, the range and the value
take ([a value in a range](../../host/runtime.md#a-value-in-a-range)), and the
value is kept inside the range; a number typed past an end stands at that
end.

The box reads its words as GTK does, with `g_strtod`, from its own `input`
handler. GTK's own reading takes empty words for 0 and, under the update
policy that keeps the value inside the range, puts words that say no number
at the range's lower end. The handler answers with the number the box stands
at instead, so such words leave it where it was, heard by nobody, and GTK
writes it back into the box.

## A field and its words

A field is a `GtkEntry`. It reports all its words from `changed`, which GTK
raises once for each change - a key, a paste, or a program's write. A report
comes back as the value of the state it carries: the host writes the words
only where they differ from the field's own, so the render a keystroke causes
leaves the user's words and caret alone. Words the program writes put the
caret after them.

`maximumLength` and `textCase` are kept as words go in: GTK holds no case and
bounds code points, so the `insert-text` of the entry's own `GtkText` takes
what goes in in the field's case and its first characters that fit, as the
contract counts them ([typed words](../../host/runtime.md#typed-words)) - from
a key, a paste and a program's write alike. An editor's buffer does the same.

A field submits when Enter is pressed in it, through the entry's `activate`.
A test types as the keyboard does: through the key bindings' signals of the
field's text - `delete-from-cursor` over what it replaces,
`insert-at-cursor` - which a read-only field refuses.

A field's words stand in its `GtkText`, the text widget a `GtkEntry` and a
`GtkSearchEntry` both hold, so the two are one view. How the words are taken
is the tree's where it says so and GTK's where it does not: read only, and
what the input method is told - the traits the host layer reads once ([what
typing is given](../../host/runtime.md#what-typing-is-given)) as GTK's input
hints and purpose: checking, the next word suggested, emoji, capitals at a
sentence's start, and the keys. GTK holds no hint for correction.
GTK's text widgets mark no spelling themselves; the input method is what
checks. A password field hides each character behind a dot. The words stand
across the field as their alignment says, and the caret and the selection are
put where the tree put them, in the characters GTK counts, only where the
tree changed them: the caret at the selection's end, as GTK selects. GNOME
selects a field's words whole as it takes the focus; a caret or a selection
the program put stands over the field's first focus, written again once GTK
has selected - and once that focus has passed or the user has changed the
words, GNOME's own way stands.

A field's font and color are a class of the display-wide sheet
([a widget's own box](drawing.md#a-widgets-own-box)) rather than Pango
attributes, since an editor's text view takes none: the class sets the font
and the color, which the placeholder takes too. GTK dims a placeholder with
opacity; a placeholder color is drawn in full.

## An editor

A TextEditor is a `GtkTextView` whose Enter starts a new line and submits
nothing, its words wrapped, in a scrolled window drawn as an entry is - filled
faintly, its corners rounded, ringed while it holds the focus - with an
entry's room around its words. It is as wide as the room it is offered, its
words wrapping in it; growing with its words it is as tall as they are, and
not growing it keeps a line's height, whatever it holds - the room its
layout gives it is the room it scrolls in. GTK allows a scrolled window no
less than its scrollbar's length, so an editor is never shorter than that.

A text view has no placeholder: the editor's is a label laid over its first
line, shown only while it holds no words. A text view has no bound either:
words going in past the editor's bound are cut in the buffer's `insert-text`
to the first that fit, as a field's text cuts them, from a key, a paste and a
program's write alike - so the words are never changed from inside the
buffer's own `changed`, where GTK still holds its iterators.

## A search field

A SearchField is a `GtkSearchEntry` - its search icon and a button clearing
it - taking its words as a field does; Enter submits it.

## Pictures

An Image is a panel of the host's showing a picture from the application's
folder ([the application's pictures](drawing.md#the-applications-pictures)),
its own size, whatever room its layout offers: an SVG the size it declares,
a bitmap its pixels, both as gdk-pixbuf reads them from the file.

The panel draws the picture in the place its layout gives it, as the aspect
says - whole in its room, covering it, stretched across it, or at its own
size in the middle - cut at the room's edge. A bitmap is read once. An SVG is
read at the size it shows at, at the display's scale, and again only for more
pixels, so a size in motion does not read it every frame - a stretched one at
its room's own size, its proportions let go as it is read, so it is sharp both
ways ([a picture](../../host/layout.md#a-picture)) - never enlarged.

## A picker

A Picker is a `GtkDropDown` over a `GtkStringList` of its choices' words, the
chosen one shown on its button. The chosen one is written only where the tree
changed it or the choices changed, so the user's choice is never argued with,
and the user's choice is reported onto the state it is carried in. GTK gives a
drop-down no placeholder and tells no one its list opened or closed, so the
placeholder and the list's opening and closing are not planned. The words of
the chosen one - on the drop-down's `button` node - take the tree's font and
color; the list keeps the theme's. A GNOME drop-down wears no accent: a
check in its words' color marks the choice, so a picker takes no tint.

## A day and a time

A DatePicker and a TimePicker are each a `GtkMenuButton`: its words - a
label of its own beside the button's arrow - the day or the time, and its
popover the face the user picks from. Only the user's opening and closing of
the face are heard, by the host layer's rule
([a day and a time](../../host/runtime.md#a-day-and-a-time)).

A DatePicker's face is a `GtkCalendar`, which stays open as the user picks,
as GNOME's calendars do. Its day is written on the button in the user's own
way - `%x` - and `"D"` writes the long form, the weekday and the month by
name; another pattern writes the short form. GTK's calendar offers every
day: the range lives in the host, and a day the user picks past it is moved
to that end, as a day the program writes is.

GTK has no time picker. A TimePicker's face is the clock GNOME's own
applications set a time with: the hour and the minute, each an upright
`GtkSpinButton` going round past its ends and written in two digits, and on
a twelve-hour clock a button turning the half of the day, named as the
locale names it. Each wheel the user moves is one change, heard at once. The
time is written on the button in the user's clock, hours and minutes; the
format is not read.

## What shows work

A progress bar is a `GtkProgressBar` over the range 0 to 1, a fraction past
either end standing at that end; a spinner is a `GtkSpinner`,
turning while its work runs and drawing nothing while it does not.

## A control's accent

A control's tint is its one accent color, where GNOME's theme draws its
accent: a switch's track while it is on, a ticked box, a slider's track up to
its thumb, a progress bar's done part and a spinner. Each is a node GTK
documents for the control, so the tint is a class of the display-wide sheet
([a widget's own box](drawing.md#a-widgets-own-box)) filling that node -
`switch:checked`, `check:checked`, `trough > highlight`, `trough > progress` -
and the spinner's color; the
theme's light under the pointer and pressed lies over it as over its own
accent.

## What assistive technology meets

What an element says for assistive technology is the host layer's
([what assistive technology meets](../../host/tree.md#what-assistive-technology-meets));
the host puts it on the widget as GTK's accessible label and description,
reset where the element says nothing so a widget's own words stand. A heading
takes GTK's heading role with its level. GTK fixes a widget's role once
assistive technology has met it, so a widget becomes a heading only while it
stands in no window - as the element's first properties find it - and a GTK
widget in a role other than its own is not named by the words it shows, so a
heading's label is its words, written again as they change. A kind is a
role too, and the class a widget is made of fixes it, so the host says none;
GTK says a value only of a range, a role of its own.

GTK 4 tells assistive technology no identifier before 4.22, and from 4.22
only a GtkBuilder file's id, which no public call sets on a widget made in
code; so `accessibilityIdentifier` is not planned on GTK. A hidden state leaves out the element itself and passes its
children up to its parent, which is what a hidden element asks; an element
left out with its children takes the same state on its own widget alone, and
the widgets under it keep theirs.

A word said to a screen reader goes through the window's accessible, and only
where its context is GTK's AT-SPI one: without the accessibility bus GTK
stands a context of no assistive technology, which GTK 4.14 announces through
a call it lacks - the process dies. There no one listens, and the act is
answered all the same.

## A web view

The web view on GTK is a backend, `lib/Backends/WebView.GTK`: WebKitGTK
6.0's web view, made through the GTK host's registration of an
application's own controls, so an application that shows none links no
WebKit. A page at an address is loaded; a document written in place is shown
at its own address, and one with none is gone to as a `data:` address, which
WebKit keeps in the page's history ([a document with no
address](../../host/web.md#a-document-with-no-address)). A page asked for is
loaded once the element's values are applied, so the agent the tree gives
is the one it is asked with; no page given leaves the page as it is, and
the page given after it is loaded again, whatever the user went to
meanwhile. What the page does comes back as WebKit tells
it: a navigation as its load starts, why it began by the host layer's rule -
the program's step, else what WebKit's decision on it says (a link or a form
a new page, a reload the page again, a step through the history back or
forward by where it lands among the pages behind as the page shown arrived,
since by its decision WebKit's list already stands at the step's end) - and
as its load
finishes, or fails, a load called off a cancel; whether there is a page
behind and ahead, said as the history changes; and the end of its web
process. A script's answer is the JSON WebKit writes its value in, read by
the host layer's rule. WebKit's calls are declared by the backend itself
over untyped pointers, as GTK's headers belong to the host's own module.

## A text style

Words in a text style stand at the size and weight libadwaita gives its style
class for it: `.display` `title-1`, `.title` `title-2`, `.subtitle`
`title-4`, `.headline` `heading`, `.body` `body` and `.caption` `caption`.
The numbers are the theme's own: a label of each class, never shown, is read
for them each time (`GTKTypeRamp`), so they follow the desktop's font, and a
style's weight stands at the theme's own number - 800 for the largest titles -
where the tree gives none. The
size and weight the tree gives stand over the style's (`TextLook.standing`),
and both reach a label and a run as Pango attributes and a field as its words'
class. Digits of one width are the font feature `tnum`: a Pango font-features
attribute on a label and a run, `font-feature-settings` in a picker's class,
and in words a user types - a field's, an editor's - the words' own attribute
(`gtk_text_set_attributes`, a tag laid over an editor's words again as they
change), as GTK keeps what its style gives typed words to itself.

## A picker's segments and radio buttons

A picker offered as segments is a row of GTK's toggle buttons in a box of the
`linked` class, which libadwaita draws as one strip; one offered as radio
buttons is a column of its check buttons, which a group draws as radio
buttons (`GTKChoiceGroupView`). Each set is one group, so GTK keeps one
active; a button turned on tells the choice, and the program's writes are
dropped as every program write is. The words' class stands on the box, and
GTK's CSS hands the font and color on to the buttons.

