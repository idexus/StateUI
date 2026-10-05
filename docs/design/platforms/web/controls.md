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

## A button

A Button is a `<button>`. With no fill, outline or shape of its own it is the
browser's button; with one, its box is the application's - its background,
its border, its corners - and the browser's look goes.

## A field

A TextField is an `<input>`, reporting each change of its words and the Return
key. The tree writes its words only where they differ from what the field
holds: writing the same words again would move the user's caret to their end.

## Toggles

A Switch is the browser's checkbox with the role of a switch, drawn as one -
a track and a knob, the accent colour while it is on, the application's tint
in its place where it gives one - and a CheckBox the checkbox as it is. Each
says when the user turns it (`change`), and the tree turns it through its
`checked`. A RadioButton is a `<label>` holding the browser's radio button and
its caption, so a click anywhere on it chooses it. Its group is the host
layer's: the button holds no `name`, so the browser turns no peer off of
itself, and the peers the host layer turns off are turned off on the page.

## Values in a range

A Slider is the browser's range, which says each move of its thumb as it goes
(`input`). A Stepper is a number field between a button taking a step down
and one taking a step up; the field's own steps (`stepUp`, `stepDown`) keep
the number inside its range, and a number typed past an end stands at it.
Words that say no number leave the number where it was. The range, the step
and the number of decimals are the host layer's (`ValueArithmetic`), and a
value the tree writes reaches the control only where the tree changed it or
its ends (`ElementValues.written`), so a hand on the thumb is never argued
with. The value standing on the page is where an animation of it starts.

## A picker

A Picker is the browser's `<select>`, an `<option>` for each choice. The
choices and the choice are written only where the tree changed them
(`PickerChoices`), so the user's own choice is never argued with; no choice
stands as no option selected. The choice the user makes is heard on
`change`.

## Indicators

A ProgressBar is the browser's `<progress>`, its share of the work done from 0
to 1, drawn as a thin rounded bar in the accent colour or the application's
tint. An ActivityIndicator is a ring turning while work goes on - the browser
has no spinner of its own - with the role of a busy progress bar; stopped, it
shows nothing and keeps its room, and it turns slower where the user asks for
less motion.

## Pictures

An Image is an `<img>` showing one of the application's pictures, which
`run-app.sh` lays beside the page in `Images/`. A name stands for its files in
the host layer's order - a PNG, then the SVG of the same name - and the
element shows the next when one is not found. Its content mode is
`object-fit`.
