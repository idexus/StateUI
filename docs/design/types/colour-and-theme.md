# Colour and theme

A colour is held as what it is, four channels, and a colour or a picture that
differs between the light and dark themes is one value with a half for each.
The half in force is picked in the core, where an element is built, and
nothing in a host binds anything.

## Four channels

`Color` holds four 8-bit sRGB channels. Every initializer produces them, so
nothing the API can express is lost, and equality means the colour rather
than its spelling: `Color("#ff0000")` and `.red` are one value, so two
spellings of one colour are not a change and nothing is sent for them.

A colour crosses under the wire's own colour kind as four bytes. It is the
value a tree carries most of and the cheapest to say exactly, and no host
parses a colour or has to know what one may look like. On a state the host
carries, a colour lies as four lanes from 0 to 1, which is what a colour
half way between two others is made of.

## Hex is read in the core

A colour is written as hex, `Color("#512BD4")`, as channels, or by name. The
parser is the core's and reads hex alone: `#RGB`, `#ARGB`, `#RRGGBB` or
`#AARRGGBB`, with or without the `#`, the alpha first when it is written.
Three and four digits are the shorthand where each digit stands for both of
its pair. Leaving the reading to a host would put the definition of a colour
inside that host's parser, and every other host would have to reproduce it
exactly or differ in silence.

Text that is not hex stops the program with a message naming it. A colour is
written as a literal, so it fails the first time the code runs rather than
drawing something nobody chose, and a colour's name is `Color.red` and its
kin, which the compiler checks where a string could not. Channels given as
numbers outside 0 to 255 are held to the range. There is no way back to hex
text: a colour crosses as bytes wherever it crosses.

## Named colours

The named colours are the ones that come up in practice, each with its CSS
name and value; any other colour is one hex literal away. `darkGray` is
lighter than `gray`, as its CSS value is.

## A pair for each theme

`Color(light:dark:)` is one value that goes wherever a colour goes. It
travels as both halves, `PropValue.themed`, until the differ builds the
element wearing it. The differ then picks the half `AppInfo.requestedTheme`
says and records that read against the element.

```text
  Color(light: .white, dark: .black)          written in a body, a style,
       |                                      or a session from a handler
       |  .themed(light: .color(white), dark: .color(black))
       v
  the differ builds the element wearing it
       |  resolvingTheme() reads AppInfo.requestedTheme,
       |  and the element reads the theme from then on
       v
  .color(white) in the patch                  a theme change builds exactly
                                              this element again
```

A theme change therefore builds exactly the elements wearing a pair and
nothing around them. A pair written outside every build - into a session
from a handler, or in a style sheet made once - is right in both themes,
because it is resolved where it is worn. `.themed` never reaches the wire. A
brush holding a pair among its stops, and a drawing holding one among its
records, are resolved the same way.

## A pair on a carried state

A pair written into a state the host carries crosses as the half in force,
read without recording anything: laying a value is no reason to build
anything. The state keeps the pair, and the element handing that state on
reads the theme, so a theme change builds that element again and the host
animates the colour to the other half, as it would a pair written on a node.

## Pictures for each theme

A picture may be two pictures: black artwork that reads well on a white page
disappears on a dark one. `ImageSource(light:dark:)` names two files and
crosses as a themed pair of file names, picked by the differ as a colour
pair is, so one name reaches the host and the element showing it builds
again when the theme changes. A tint would not do: it paints a picture in
one colour, while a second file keeps artwork of any colours as it was drawn.

## A background is a colour or a brush

`Background` is one colour or one brush, and the two stay apart on the
wire: a colour crosses as its four bytes and a brush as its kind and parts,
so a host paints a plain colour as the plain colour it is.
