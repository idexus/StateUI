# Controls on the Web

Every control is the browser's own element, in the look the browser gives it
and the theme the user's system chose, until the application gives it a look
of its own.

## A view

A view holds one DOM element, which the relay keeps under its number, from
the view's making until its element leaves the tree: it then takes the
element off the page and lets go of every listener hung on it. A CSS property
is sent only when its value changes.

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

## Pictures

An Image is an `<img>` showing one of the application's pictures, which
`run-app.sh` lays beside the page in `Images/`. A name stands for its files in
the host layer's order - a PNG, then the SVG of the same name - and the
element shows the next when one is not found. Its content mode is
`object-fit`.
