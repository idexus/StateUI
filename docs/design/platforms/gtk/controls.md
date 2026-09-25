# Controls on GTK

How the GTK host presents the controls a user changes - a switch, a slider, a
field - and hears what the user does to them. The value a control carries
belongs to a state; the host writes the control where the tree changed that
value and reports the user's change back ([patches](../../host/patches.md)).

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
