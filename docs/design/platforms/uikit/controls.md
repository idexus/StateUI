# Controls on UIKit

Which of UIKit's own controls each element is, and what the host does around
them.

## Toggles, values and indicators

A Switch is UIKit's switch; a Slider, a Stepper, a ProgressBar and an
ActivityIndicator are UIKit's own too, an indicator standing still - shown -
while its work does not run. UIKit has no check box and no radio button, so
each is a button of its own showing the system's symbol for a box or a
circle, ticked or not, before a radio button's caption: a tap turns a box
either way and a radio button only on, and the host layer takes the tick from
the rest of its set. What the program writes is only shown - UIKit's controls
send no event for a value set in code - and what the user does is reported.

## Pickers

A Picker is UIKit's pop-up button: its menu holds the choices, the chosen one
ticked and its caption on the button, and the picker's title stands there
while nothing is chosen, which UIKit's own selection-changing button cannot
say, so the host keeps the tick itself. A menu cannot be opened from code, so
a picker's `isOpen` is left unrealized; its opening and closing are heard.

A DatePicker and a TimePicker are UIKit's date picker, compact. A day of the
calendar and a time of the clock belong to no zone, so the picker counts and
shows them in the Gregorian calendar at UTC: the day the user picks is the day
the tree reads.

## A field and its words

A TextField is UIKit's field, a SearchField its search field, a TextEditor its
text view; each takes the words the tree changed and leaves the user's typing
and caret alone. One delegate serves them all: it reports the user's words,
cut to the view's bound, keeps them unchanged while the view is read only,
and hears the return key as submitting a field. A caret and a selection are
counted in characters and handed to UIKit in its UTF-16 units. A text view has
no placeholder of its own, so an editor shows one in a label over itself; an
editor that grows with its words asks for their whole height instead of
scrolling them.

## A label's words

A Label is UIKit's label showing its words - or its spans' runs, each its
own look over the label's - as attributed text: the font, the colour, what
stands behind the words, the space between the letters, a line's height and
the lines under or through them. Its padding is room it keeps around the
words, as it measures them and as it draws them, standing them down its room
as the tree says, which UIKit's label does not do of itself. Its background -
a colour or a brush - fills its whole box, that room included, painted
before the words: they are the label's own drawing, which a layer laid over
it would cover.

A Button is UIKit's button, its configuration what the tree says: its words
and their look, an icon beside them, the box behind them - its colour, its
outline and its shape, an oval a capsule - and the room inside it.


## Accessibility

What VoiceOver meets of a view is what the tree says of it - its label, hint
and heading, whether it is met - over what the view says of itself. A view
holding no children of the tree's - a date or time picker, a spinner - is one
thing to the user, though UIKit offers VoiceOver the parts inside it: hidden,
it hides them too. A layout hidden from VoiceOver keeps its children met; only
a layout hidden with its children hides them.

## A web view

A WebView is WebKit's own web view. A page at an address is loaded; a
document written in place with an address of its own is shown there, and
one with none is gone to as a `data:` address - WebKit keeps no history of a
document shown without one, and the user's way back and forward is the page's
history. What the page does comes back as the element's events: a navigation
as it starts, with why, and as it ends, with how; whether there is a page
behind and ahead, said as a whole as a navigation commits and ends - the way
back first, and only a flag that changed; its web process dying. A step back,
forward or a load again the program asks for carries that as its cause; a
page still coming, which WebKit reloads without asking, is asked for again. A script's value answers as text: words
as they are, a number as it is written, anything else as JSON.
