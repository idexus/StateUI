# Closed vocabularies

A closed vocabulary is a set of choices StateUI names: a line break, an
alignment, an easing curve, a timing law, a battery state, a gesture phase.
Each crosses to a host as a number, never as its spelling, and the host maps
that number onto its own toolkit's member.

## The numbers belong to StateUI

A case's number is part of StateUI's contract, never a toolkit's. What a
case promises is what its documentation says; the number is only how it
crosses. A host translates its native value onto this vocabulary on the way
in and out, so a native enum's numbering never reaches the patch, and a
platform release cannot reinterpret a stored or reported value.

A vocabulary that crosses is declared `: Int32`, the width `.enumeration`
carries. It crosses as `.enumeration`, which one line of
`HostRepresentable` conformance gives it.

## Written out and appended

The numbers follow declaration order from 0, and every case writes its
number out. A case inserted in the middle would renumber every case after it,
silently: every patch and every dump would say another number for the same
member, with nothing failing anywhere. Seeing the numbers is what makes that
hard to do by accident.

Appending a case is free; inserting or reordering one is not.
`ClosedVocabularyTests` holds every case of a crossing enum to a written
number, refuses an enum whose raw value is its spelling, and refuses a raw
value written out as text.

## Flag sets carry bits

`FontAttributes`, `TextDecorations` and `SwipeDirection` are option sets, so `.bold` and `[.bold, .italic]` both
work. Their bits are StateUI's own by the same rule, `1 << 0` upwards in
declaration order, and a composite such as `.all` or `.position` is the OR of
its parts. A set crosses as one `.enumeration` holding its bits.

## A kind first

Some values are one of several kinds, each made of different parts: a grid
length, a border shape, a brush, a drawing instruction. Such a value crosses
as a list whose first value is the kind's number and whose rest is what that
kind is made of.

```text
  GridLength.proportional(2)       [1, 2]
  GridLength.auto                  [2, 1]      every length carries both parts
  ContainerShape.roundedRectangle(12) [1, 12]
  ContainerShape.ellipse              [2]
  Brush.solidColor(.red)           [1, #FFFF0000]
```

Each type numbers its kinds in an internal `Kind` enum, written out by the
rule above. `Brush.Kind` numbers from 1 rather than 0: the contract asks
only that both sides say the same number. A grid length's `.auto` carries a
1, so every length is the same two parts and a host reads each one the same
way.

`SafeAreaEdges` is one member for all four edges, or four members in the
order left, top, right, bottom. The four cross as a list of four
`.enumeration` values, never as `.numbers`: a member is not a quantity.

## Choices a state can carry

A vocabulary a property can take as `$x` conforms to `StateChoice`. It rides
the state image as one lane holding its member's number, and the host
resolves that number through the same table a described property goes
through, so every member the tree can say, a state can say too. A choice has
no half-way: the host sets it as it stands, and writing the state rebuilds
nothing. Each conformance is one line beside the type's other conformances.

## An unknown member

A number a vocabulary has no case for reads back as nil, and the property or
payload holding it is refused.
