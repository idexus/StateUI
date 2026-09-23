# How a value crosses

Every value an application passes becomes one `PropValue` on its way to a
host and is read back from one. [The overview](README.md#the-kinds-of-propvalue)
lists the kinds; this note gives the rules that choose between them.

## One kind for one meaning

`PropValue` has one kind per meaning, and a value takes the kind that says
what it is. Text an author wrote is `.string`. A word from an open vocabulary
is `.name`. A member of a closed vocabulary is `.enumeration`. A quantity is
`.number`, or a run of `.numbers`. Parts of different kinds are `.values`. A
position with no value is `.nothing`. Keeping them apart lets every host read
a value as the thing it is, with nothing to parse and nothing to guess.

## Text and names

A `Name` is a word an application chose that repeats across a tree and means
the same thing every time: a style key, a font family, a radio group, a kept
value's key. It crosses as `.name`, which rides the session's dictionary as
a number, announced once and a couple of bytes afterwards. A member holding
a `String` crosses as text an author wrote. The member's declared type
decides which it is, so a contract declares `Name` or `String` by what the
words are.

A picture's file name crosses as text, not as a name, because its vocabulary
has no end. An application has a handful of styles and fonts, and numbering
them pays for itself on every row; a picture may be an address built per
item, an avatar or a thumbnail, and the session's dictionary is never
emptied, so numbering those would grow it without end for names used once. A
name is text when there can be no end of them.

## Runs of numbers

A value made of numbers in a fixed order crosses as one `.numbers` run.

```text
  Insets              left, top, right, bottom
  Rect                x, y, width, height
  CornerRadius        one .number, or top left, top right, bottom left, bottom right
  Point               x, y
  [Point]             x, y, x, y, ...   one flat run, a pair per point
  CalendarDate        year, month, day
  ClockTime           hour, minute, second
```

A day and a time of day cross in the order a picker reports them in, so the
two directions say the same thing. Each number crosses as its own bits:
nothing is formatted going out or parsed coming in.

## Parts rather than text

A structured value crosses as its typed parts, never as a string a host must
parse. A gradient spelled as text would put the definition of a gradient
inside whichever parser reads it, and a parser that read it only in part
would draw nothing, or the wrong thing, without saying a word. So a brush
crosses as its kind, its geometry and its stops, an outline's corners as
numbers rather than `20,0 40,40 0,40`, and a drawing as records of typed
arguments.

## Reading a value back

Every value has `init?(propValue:)`, which answers nil for any shape but its
own: a rectangle needs exactly four numbers, a colour the colour kind, a day
three whole numbers. A whole number is read as the whole part of a number,
and a number with none - infinity, not a number - reads as nil.

A payload is read as exactly the types its member declares, or refused
whole. The one leniency is at the end: an optional value there may be left
out, and reads as nil. A handler never runs on a guess; a report that does
not read leaves the handler alone and is said once.

## Nothing said out loud

A property that did not change is absent from a node. A position cannot be
absent: the third argument of an act and the second value of a list are
found by counting, so "no destructive button" or "no zone named" needs a
value that says so. `.nothing` is that value, and an optional crosses as its
value or as `.nothing`. An empty string, a -1 or an empty list would each be
indistinguishable from something someone meant. `TimeZoneInfo.utcOffset`
sends its zone and its day this way: nothing for the local zone, and nothing
for today.
