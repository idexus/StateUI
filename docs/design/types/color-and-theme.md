# Color and theme

A color is held as what it is, four channels, and a color or a picture that
differs between the light and dark themes is one value with a half for each.
The half in force is picked in the core, where an element is built, and
nothing in a host binds anything.

## Four channels

`Color` holds four 8-bit sRGB channels. Every initializer produces them, so
nothing the API can express is lost, and equality means the color rather
than its spelling: `Color(hex: 0xFF0000)` and `.red` are one value, so two
spellings of one color are not a change and nothing is sent for them.

A color crosses as its own kind of value, four channels of a byte. It is
the value a tree carries most of and the cheapest to say exactly, and no host
parses a color or has to know what one may look like. On a state the host
carries, a color lies as four lanes from 0 to 1, which is what a color
half way between two others is made of.

## As a toolkit holds it

A toolkit holds a color as one number, eight bits a channel with alpha
highest, or as four fractions of full from 0 to 1. The host layer turns
either into the four channels and back (`ColorComponent`, `Color(argb:)`,
`Color(fractions:)`, `HostValue.fractions`): a fraction stands at its nearest
channel, held to the range. The accent a host reports and the color it
draws are converted by that one rule, so the same color stands at the same
channels whichever toolkit reported it, and a channel taken to a fraction and
back is the channel it was.

## A color is a number in code, text only in data

A color in code is a hex number, `Color(hex: 0x512BD4)`, the digits a design
gives, with how opaque it is apart - `Color(hex: 0x000000, opacity: 0.4)`, as
`opacity(_:)` lets a color through - or channels, or a name. A number holds no
digit that is not hex, so a color written in code cannot be misspelled the way
text can; what a number cannot refuse by its type, a seventh digit, stops the
program with a message, since the alpha is `opacity`.

Text is read only where data holds a color - a theme file, a server's answer -
by `Color(parsing:)`, which answers nil for what is not one, so the data's own
fallback stands. The reader is the core's and reads hex alone: `#RGB`, `#ARGB`,
`#RRGGBB` or `#AARRGGBB`, with or without the `#`, the alpha first when it is
written. Three and four digits are the shorthand where each digit stands for
both of its pair. Leaving the reading to a host would put the definition of a
color inside that host's parser, and every other host would have to reproduce
it exactly or differ in silence.

A color's name is `Color.red` and its kin, which the compiler checks. Channels
given as numbers outside 0 to 255 are held to the range. There is no way back
to hex text: a color crosses as bytes wherever it crosses. Two spellings of
one color are equal and hash alike, so a color is a key and a choice.

## Named colors

The named colors are the ones that come up in practice, each with its CSS
name and value - but `transparent`, a white let through to nothing
(`Color(hex: 0xFFFFFF, opacity: 0)`) where CSS's is black; any other color is one hex number away.
`darkGray` is lighter than `gray`, as its CSS value is.

## A pair for each theme

`Color(light:dark:)` is one value that goes wherever a color goes. It
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

A half may be the accent in force: `Color(light: .accent, dark: .white)` keeps
which halves are the accent (`accentHalves`) and crosses that half as
`.systemColor`, resolved like the whole accent where it is worn. A pair handed
as a half gives the half of its own theme - the dark half of the pair handed as
the dark one - so `Color(light: .gray, dark: surface)` is `surface`'s dark half
in the dark.

## A pair on a carried state

A pair written into a state the host carries crosses as the half in force,
read without recording anything: laying a value is no reason to build
anything. The state keeps the pair, and the element handing that state on
reads the theme, so a theme change builds that element again and the host
animates the color to the other half, as it would a pair written on a node.

## Pictures for each theme

A picture may be two pictures: black artwork that reads well on a white page
disappears on a dark one. `ImageSource(light:dark:)` names two files and
crosses as a themed pair of file names, picked by the differ as a color
pair is, so one name reaches the host and the element showing it builds
again when the theme changes. A tint would not do: it paints a picture in
one color, while a second file keeps artwork of any colors as it was drawn.

## A material

`Material` is what a surface is made of, and every background takes one - a
view's, a page's, a run of words', a window's: a color, a gradient, a blur
of what lies behind it, or the platform's glass, each kind with only its own
modifiers so the type decides what applies. A constructor per kind keeps one
spelling: a brush of one color is that color, a pair of colors is the
color pair.

It crosses as the color itself for a color and as its brush for a
gradient, so a color's channel - `.background($color)`, which the host walks
- writes a material as it is: the channel stays the color's, and a test
holds the two encodings equal. A blur and glass cross as their kind (4 and 5,
after the brush's three), what the kind takes, and last what stands in for
them, decided once in the core: glass carries the blur as clear as the glass
is, a blur the color of the theme let through as the blur is, which the
differ resolves as any pair. A tint lies over a blur; glass takes the
platform's own tint.

A pair - `Material(light:dark:)` - crosses as the theme's pair of its two
halves, a nil half as nothing, which leaves the host its own: a window's and a
bar's native look, or no background. The differ resolves it as it builds the
element, which so reads the theme. A material with no pair is the same choice
in both themes; a blur and glass still follow the theme as the platform draws
them.

The host layer reads it (`HostMaterial`): the paint - the color, the
gradient, or the tint over a blur or glass - the blur behind, the glass, and
the stand-in, taking a pair a typed member encoded again as the half of the
theme in force (`HostThemes.current`). Each host draws the first its toolkit
has - glass, the blur, the color - and one that blurs nothing paints the
paint laid over the stand-in as a color with an alpha lies over another
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

`Color.accent` crosses as the system's color, its alpha with it, and the
differ resolves it as the element is built from `info.accentColor` - which
the host reports - so the element is the accent's reader, as a pair's is the
theme's. A host never meets it. On a carried state it crosses as the accent in
force, the pair's way.
