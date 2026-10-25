# Controls on UIKit

Which of UIKit's own controls each element is, and what the host does around
them.

## Toggles, values and indicators

A Switch is UIKit's switch; a Slider, a Stepper, a ProgressBar and an
Spinner are UIKit's own too, an indicator standing still - shown -
while its work does not run. UIKit has no check box, so a CheckBox is a
button of its own showing the system's symbol for a box, ticked or not,
before its words: a tap turns it either way. A switch's color is its color
when on, a box's the color of its symbol. What the program writes is only
shown - UIKit's controls send no event for a value set in code - and what the
user does is reported.

## A switch's words

`UISwitch` has no words, so a switch with words is a view of two: the words
from its start and the switch at its end, mirrored right to left, the way
Settings sets a switch in a row. The switch is measured at its own size, the
words take the rest. The words belong to the switch: a tap on them turns it,
and VoiceOver meets the switch alone, named by the element's label or else by
its words, the label beside it left out (`UIKitAccessibilityPresenting`).

## Pickers

A Picker is UIKit's pop-up button: its menu holds the choices, the chosen one
ticked and its caption on the button, and the picker's title stands there
while nothing is chosen, which UIKit's own selection-changing button cannot
say, so the host keeps the tick itself. Its caption takes the font and color
the tree gives it, as a button's title does, and its tint colors the arrow
beside it alone. A menu cannot be opened from code, so a picker's `isOpen` is
left unrealized; its opening and closing are heard.

A DatePicker and a TimePicker are UIKit's date picker, compact. A day of the
calendar and a time of the clock belong to no zone, so the picker counts and
shows them in the Gregorian calendar at UTC: the day the user picks is the day
the tree reads. It draws its words in its own font and color.

## A field and its words

A TextField is UIKit's field, a SearchField its search field, a TextEditor its
text view; each takes the words the tree changed and leaves the user's typing
and caret alone. One delegate serves them all: it reports the user's words,
cut to the view's bound, keeps a field's words unchanged while it is read
only - a read-only editor is not editable - and hears the return key as
submitting a field. A caret and a selection are
counted in characters and handed to UIKit in its UTF-16 units. A text view has
no placeholder of its own, so an editor shows one in a label over itself; an
editor that grows with its words asks for their whole height instead of
scrolling them.

## A label's words

A Text is UIKit's label showing its words - or its spans' runs, each its
own look over the label's - as attributed text: the font, the color, what
stands behind the words, the space between the letters, a line's height and
the lines under or through them. Its padding is room it keeps around the
words, as it measures them and as it draws them, standing them down its room
as the tree says, which UIKit's label does not do of itself. Its background -
a color or a brush - fills its whole box, that room included, painted
before the words: they are the label's own drawing, which a layer laid over
it would cover.

A label resized draws its words again, whatever its height comes to. UIKit
does not always do so when the width alone changes - a label measured for
its new width first, its line count the same - and its old drawing then
stands stretched to the new box, its lines breaking anew only when something
else has it drawn, half a second later in a sidebar's slide.

## The user's text size

Words follow the user's text size (`isFontAutoScalingEnabled`, on unless
said) through `UIFontMetrics`: a size the tree gives, or the body's at the
platform's own text size, is scaled for the view's traits, and a field and
an editor carry `adjustsFontForContentSizeCategory`. A label builds its words
again, and a button, a picker and a check box update their configuration,
as the user's text size changes. Words that do not scale stand at their size
whatever the user chooses. A day's and a time's picker draws its words in
UIKit's own font, which follows the user always - `–` in the matrix.

## A button

A Button is UIKit's button, its configuration what the tree says: its words
and their look, an icon beside them, the box behind them - its color, its
outline and its shape - an oval a face of the button's own, the
configuration's background view, which its corners cannot draw - and the room
inside it. Its corners are rounded as it is laid out, by the host layer's
radius (`BoxArithmetic`): a capsule's half its shorter side. UIKit's own
capsule makes a button showing a picture alone a circle as wide as it is high,
whatever room the tree gives it beside the picture. What the tree leaves
unsaid is a plain configuration's own: an empty fill there is the tint's, so a
button whose style leaves takes the plain box again, never an empty one.

A role draws where the tree draws nothing of its own ([a button's
role](../../host/layout.md#a-buttons-role)): the main action wears UIKit's
filled configuration, the tint behind white words - the configuration worn
again with all the button set on the other - and a destructive one's words
the system's red, as UIKit's alerts and menus mark one. UIKit's own role,
which the button carries too, sets the main action's words semibold.

## A button's menu

A button whose tap opens its menu shows the menu as its primary action and
wears an arrow pointing down after its words, inside its padding - a mark,
the whole button taking the tap. UIKit's own menu indicator points up and
down, which says a choice of values, as a picker's. UIKit draws no split button,
so a split button keeps its tap and holds an arrow of its own: a `UIButton`
with a chevron at its trailing edge, the whole height, set off by a line,
opening the menu with a tap; the button keeps room for it inside its padding,
so its words never run under the arrow, which takes the words' color.

## A link

UIKit has no link control of its own. A link is a plain `UIButton`, its title
underlined in the configuration's foreground - the link color, or the tree's -
with the link trait, which VoiceOver names by its words. The color stays the
configuration's, not the title's own, so the button grays it while the link
cannot be chosen. Its tap is the button's; the host layer opens the address
(`host/runtime.md#a-link-chosen`).

## A color picker

A color picker is UIKit's `UIColorWell`: a tap presents the system's color
picker - a sheet on a phone, a popover on an iPad - and each color the user
chooses there changes `selectedColor` and says `valueChanged`, which the host
reports as the host layer reports a color (`host/runtime.md#a-color-chosen`).
The well's `supportsAlpha` is `choosesOpacity`. A color the program writes
sets `selectedColor` and says nothing.

## Accessibility

What VoiceOver meets of a view is what the tree says of it - its label, hint,
kind, value and heading, whether it is met by the host layer's rule - over
what the view says of itself, read before the tree says anything, to which it
returns where the tree stops saying. A kind is a trait, and one said takes
the place of the traits of a kind the view has of itself, keeping the rest -
selected, not enabled. Its actions are custom actions, and a view StateUI draws
that says it is adjustable takes VoiceOver's swipes up and down as its
increment and decrement; UIKit's own control steps as its own kind does, or
not at all. A view
holding no children of the tree's - a date or time picker, a spinner - is one
thing to the user, though UIKit offers VoiceOver the parts inside it: hidden,
it hides them too. A layout hidden from VoiceOver keeps its children met; only
a layout hidden with its children hides them.

## A web view

A WebView is WebKit's own web view, the one Apple's hosts share
([the web view on Apple's platforms](../apple/web.md#a-web-view)).

## A text style

Words in a text style stand in UIKit's font for it at the platform's own text
size (`UIFont.preferredFont(forTextStyle:compatibleWith:)` at `.large`):
`.display` the large title, `.title` the first title, `.subtitle` the second,
`.headline`, `.body` and `.caption` the first caption. The size and weight
the tree gives stand over the style's (`TextLook.standing`); the font is the
system's at the size and weight that stand, or the named family with that
weight in its descriptor. Where the words scale, the style's own metrics grow
them with the user's text size (`UIFontMetrics(forTextStyle:)`), so a title
grows as UIKit grows its titles; words with no style grow as the body does.
Digits of one width are the number-spacing feature in the font's descriptor
(`kMonospacedNumbersSelector`), which the grown font keeps.
A day's and a time's picker draw their words in UIKit's own font and take no
style.

## Selectable words

A `UILabel` selects nothing, so a Text whose words the user can select stands
in UIKit's text view instead (`UIKitSelectableTextView`): read only, not
scrolling, its container's padding gone, showing the words, runs, alignment
and breaks a label shows (`UIKitLabelWords`, through `UIKitLabel`), and
measured as the label is, wherever down its room the words stand. The
registration makes one or the other by the value the text is made with,
and another value makes the text anew. A disabled one selects nothing.

