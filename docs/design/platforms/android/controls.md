# Controls on Android

How the Android Views host presents the controls a user changes - a switch, a
slider, a field - and hears what the user does to them. The value a control
carries belongs to a state; the host writes the control where the tree
changed that value and reports the user's change back
([patches](../../host/patches.md)).

## One listener a view

Android tells a view's owner what its user did through listener interfaces:
a click, a turn, a thumb moved, words typed, a Return. The Java layer has one
listener class for all of them, `StateUIListener`, made for one view with that
view's number, which forwards each call to Swift by the number
([JNI](jni.md)). A view hands the same listener to every setter it needs, so a
field's typing and its Return reach the same Swift view.

## Nothing the program writes is heard

Every native write of an element - a patch applied, a display frame presented
- runs inside `ProgramWrite`. Android calls a switch's, a slider's and a
field's listener while the value is being set, so the listener's call during
that write is the write's echo, and the element reports nothing. A control
does not keep a flag of its own.

## A slider in steps

`SeekBar` moves in whole steps from zero. The host gives it ten thousand steps
across the range and turns a step into a value and back, so a value the user
reports has the range's ten-thousandth as its finest step. A new range keeps
the value the thumb stands at, inside the range, unless the tree wrote a new
value with it: a hand on the thumb is never argued with.

## A field and its words

A field reports all its words after every change, and a report comes back as
the value of the state it carries: the host writes the words only where they
differ from the field's own, so the render a keystroke causes leaves the
user's words and caret alone. Words the program writes put the caret after
them.

`maximumLength` counts characters, as the contract does. The field keeps the
first characters that fit and writes them back, as the program, when typing
goes past the bound.

A password field is a field whose input type hides what is typed. Android
resets the typeface when the input type changes, so the field puts its weight
back after it.

## Return, once

A keyboard's action reaches the listener with no key event; a hardware Return
reaches it as the key goes down and again as it comes up. The listener
submits on the action and on the key going down, and takes the key's release
itself, so one Return is one submission.

## The background a view is made with

A button, a field, a switch and a slider draw their own background. A colour
the tree describes replaces it, and a colour the tree takes away gives back
the background the view was made with, read before the first change.

A background brings its own padding - the room a button's drawing leaves
around its words - and Android takes the view's padding from each new one. A
padding the tree describes is put back over it, so a button with a colour and
a padding keeps its room; one whose padding is taken away gives back the
padding it was made with.

## A layout does not delay a press

A layout that does not scroll tells its children to show a press at once.
Android's default holds a press back in case the touch becomes a scroll,
which makes a slider inside a layout wait for the finger to move before its
thumb follows.

## A tap on any view

A view with a tap handler is given the same listener a button has, and a
click on it is its tap: Android's own touch handling decides what a tap is,
and a drag that becomes a scroll is no tap. A view whose handler goes away is
no longer clickable, so it stops taking touches. A StateUI layout that
ignores input takes no touch at all, and the touch goes to whatever stands
behind it.

## A label's words

A label's words are one text, or the runs its spans describe, laid down as
one spanned text: each run in its own colour, size, weight, background and
decorations where it has its own. A run's size is in points the user's font
scale applies to, as the label's is. The label's letter spacing is in points
and Android counts it in the text's own size, so it is worked out again
whenever the size changes; a run's own spacing is not drawn. A line that is
cut or truncated is one line and only a truncated one says so; otherwise the
label wraps, to at most as many lines as it allows. A stated width is the
width a view is measured at, so wrapped words are as tall as they will stand.

## A button's size

A button is as big as its words and its padding. Android's theme gives every
button a least size of its own - 88 by 48 density-independent pixels - which
would widen a short caption and push a row of buttons past a phone's edge;
the host takes that floor away as it makes the button, and a least size is
then the author's, `minimumWidth` and `minimumHeight`, as on every host. The
stepper's buttons keep a square of 48 points, the room a finger needs, as
the stepper's own choice.

## A button's look

A button says nothing of its look and keeps its theme's: a background with
its own pressed ripple. A fill, an outline or corners make it one shape -
the host's shape drawable - under Android's pressed ripple in the theme's
highlight colour, kept within the same shape, so a drawn button still
answers a finger as the platform's do. The shape dims while the button is
disabled, to the theme's `disabledAlpha`, and so do words in a colour the
tree gave, as the theme's own colours do.

An icon beside words is a compound drawable at the picture's own size,
before, after, above or below them, the icon spacing apart or the
platform's gap. With no words it stands alone in the middle of the button,
over its background, sized to the room inside the padding: fitted, as `.fit`
and `.fill` both say - a button has no covering scale - stretched, or at its
own size for `.center`. That size is worked out as the button is placed, and
sent again only when the room changes.

## Work under way

A progress bar is Android's horizontal bar, the share done in 10 000 steps.
An activity indicator is Android's turning bar: it is drawn only while it
runs, and keeps its room while it does not, so starting the work moves
nothing around it; hidden, it takes no room.

## A stepper

Android has no stepper, so the host builds one from its own buttons: one a
step down, one a step up, side by side, each off at its end of the range. A
step is the user's report, held in the range; the value the tree writes is
put where it said, within it.
