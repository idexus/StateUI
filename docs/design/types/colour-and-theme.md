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

A colour crosses as its own kind of value, four channels of a byte. It is
the value a tree carries most of and the cheapest to say exactly, and no host
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
name and value - but `transparent`, a white let through to nothing
(`#00FFFFFF`) where CSS's is black; any other colour is one hex literal away.
`darkGray` is lighter than `gray`, as its CSS value is.

## A pair for each theme

`Color(light:dark:)` is one value that goes wherever a colour goes. It
travels as both halves, `PropValue.themed`, until the differ builds the
element wearing it. The differ then picks the half the application's
`info.colorScheme` says and records that read against the element.

```text
  Color(light: .white, dark: .black)          written in a body, a style,
       |                                      or a session from a handler
       |  .themed(light: .color(white), dark: .color(black))
       v
  the differ builds the element wearing it
       |  resolvingTheme() reads application.info.colorScheme,
       |  and the element reads the theme from then on
       v
  .color(white) in the patch                  a theme change builds exactly
                                              this element again
```

A theme change therefore builds exactly the elements wearing a pair and
nothing around them. A pair written outside every build - into a session
from a handler, or in a style sheet made once - is right in both themes,
because it is resolved where it is worn. `.themed` never reaches a host. A
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

## A material

`Material` is what a surface is made of, and every background takes one - a
view's, a page's, a run of words', a window's: a colour, a gradient, a blur
of what lies behind it, or the platform's glass, each kind with only its own
modifiers so the type decides what applies. A constructor per kind keeps one
spelling: a brush of one colour is that colour, a pair of colours is the
colour pair.

It crosses as the colour itself for a colour and as its brush for a
gradient, so a colour's channel - `.background($color)`, which the host walks
- writes a material as it is: the channel stays the colour's, and a test
holds the two encodings equal. A blur and glass cross as their kind (4 and 5,
after the brush's three), what the kind takes, and last what stands in for
them, decided once in the core: glass carries the blur as clear as the glass
is, a blur the colour of the theme let through as the blur is, which the
differ resolves as any pair. A tint lies over a blur; glass takes the
platform's own tint.

A pair - `Material(light:dark:)` - crosses as the theme's pair of its two
halves, a nil half as nothing, which leaves the host its own: a window's and a
bar's native look, or no background. The differ resolves it as it builds the
element, which so reads the theme. A material with no pair is the same choice
in both themes; a blur and glass still follow the theme as the platform draws
them.

The host layer reads it (`HostMaterial`): the paint - the colour, the
gradient, or the tint over a blur or glass - the blur behind, the glass, and
the stand-in, taking a pair a typed member encoded again as the half of the
theme in force (`HostThemes.current`). Each host draws the first its toolkit
has - glass, the blur, the colour - and one that blurs nothing paints the
paint laid over the stand-in as a colour with an alpha lies over another
(`painted`). A view's background is cut to its shape; a window's lies under
everything it draws, the desktop showing through it where the host can show
it.

## A blur

Five thicknesses, a platform's own five where it has them; a platform whose
blurs are by role draws the role whose translucency stands in that place,
measured.

## Glass

Glass is regular or clear, tinted or not, answering the user's touch or not.
A host with glass lays the platform's own under what the box holds, cut to its
shape; interactive glass takes the press it answers, which the box hears as it
rises.

## The accent in force

`Color.accent` crosses as the system's colour, its alpha with it, and the
differ resolves it as the element is built from `info.accentColor` - which
the host reports - so the element is the accent's reader, as a pair's is the
theme's. A host never meets it. On a carried state it crosses as the accent in
force, the pair's way.
