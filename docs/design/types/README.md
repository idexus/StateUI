# Values an application passes

`lib/StateUI/Sources/Types` holds the values an application hands to StateUI:
colours, insets, rectangles, brushes, motion, transforms, placements, dates
and times, gestures, the closed vocabularies, and the objects that carry what
the host knows. Each value says how it crosses to a host and how it comes
back, so no host parses or guesses anything. These notes give the reasons;
the declarations' own documentation says how to use them.

The sources stand in a folder per topic: `Geometry` points, rectangles,
insets and transforms; `Layout` alignment, grid lengths, safe areas and
placements; `Colour` colours, gradients, brushes and backgrounds; `Drawing`
pictures, shapes, strokes and the canvas; `Text` names and the text and
keyboard vocabularies; `Time` days, times of day and zones; `Motion` the
timing laws and their groups; `Gestures` what a gesture reports;
`Environment` the standard providers and their vocabularies; `Sessions` the
application, scene, window and page sessions; `Controls` the vocabularies one
control takes.

## The notes

- [Closed vocabularies](vocabularies.md) - every enum and flag set crosses as
  a number StateUI owns.
- [How a value crosses](values.md) - which kind of `PropValue` each value
  becomes, and how it is read back.
- [Colour and theme](colour-and-theme.md) - four channels, and a half for
  each theme picked as an element builds.
- [Brushes](brushes.md) - a colour or a gradient, as typed parts.
- [Drawing on a canvas](drawing.md) - a drawing as a list of records.
- [Motion](motion.md) - the timing laws, the groups of values, a view's plan.
- [Transforms](transforms.md) - one transform, worked out in the core.
- [Placement](placement.md) - where a view of a placed layout goes, as
  twelve numbers.
- [Dates and time](dates-and-time.md) - days, times of day and time zones
  without Foundation.
- [Gestures](gestures.md) - what a gesture report carries.
- [The standard environment](environment.md) - what the host knows, as state.
- [Sessions](sessions.md) - the application, a scene, a window and a page as
  they run.

## From a value to a host

Every value a member holds is `HostRepresentable`: it turns itself into a
`PropValue` and back. A modifier writes it into the element's node through
the member its contract declares, and the differ carries it to the host.

```text
  an application's value              Color("#512BD4")   Insets(24)
                                      .tailTruncation    CalendarDate(year: 2026, month: 8, day: 2)
       |
       |  value.propValue             the type says what it is
       v
  PropValue                           .color(81, 43, 212, 255)   .numbers([24, 24, 24, 24])
                                      .enumeration(4)            .numbers([2026, 8, 2])
       |
       |  setValue(LabelContract.lineBreak, .tailTruncation)
       |  a modifier writes through its member
       v
  Node.props   [Prop: PropValue]      what the element says this render
       |
       |  the differ: styles applied, each .themed value resolved to the
       |  half in force, the result compared with the last render
       v
  HostPatch   (HostValue = PropValue)            Wire   (deterministic bytes)
       |                                           |
       v                                           v
  a Swift host                              a runtime in another language
  sets its native control                   reads the same values from bytes
```

## And back

A report from the host carries its values as a payload. The event's contract
declares their types, and the payload is read as exactly those or refused.

```text
  the user picks a day in a DatePicker
       |
       v
  payload   [PropValue]               [.numbers([2026, 8, 2])]
       |
       |  MemberValues.decode as ElementEvent<DatePickerContract, CalendarDate>
       |  one value of another shape refuses the whole payload,
       |  and the handler does not run
       v
  CalendarDate(propValue:)  ->  the handler's parameter
```

An act's answer takes the same road: `ClockTime.now()` reads four numbers
back as the types `ApplicationContract.currentTime` declares.

## The kinds of PropValue

| Kind | What it carries | Used by |
| --- | --- | --- |
| `.string` | text an author wrote | captions, placeholders, picture file names, path data, formats |
| `.name` | a word from an open vocabulary | `Name`: style keys, font families, radio groups, kept keys |
| `.enumeration` | a member's number, or a flag set's bits | every closed vocabulary, `FontAttributes`, `SwipeDirection` |
| `.number` | one number | `Double`, `Int`, a uniform `CornerRadius` |
| `.bool` | true or false | `Bool` |
| `.numbers` | a run of numbers in a stated order | `Insets`, `Rect`, `Point`, a list of points, `CalendarDate`, `ClockTime` |
| `.strings` | a list of text | a `Picker`'s options |
| `.color` | four channels | `Color` |
| `.values` | parts of different kinds | `Brush`, `GridLength`, `BorderShape`, `SafeAreaEdges`, `ViewTransform`, a drawing |
| `.nothing` | a position with no value | an optional argument or payload position |
| `.themed` | a half for each theme | `Color(light:dark:)`, `ImageSource(light:dark:)`; resolved by the differ, never on the wire |

## A state the host carries

A state handed to a control as `$x` does not go through a body. Its value is a
`StateValue`: it lies on the state image as numbers, one lane each, or as
text, and the host's state channel moves it.

```text
  @State var day = CalendarDate(year: 2026, month: 8, day: 2)
  DatePicker($day)
       |
       |  day.carried                 .lanes([2026, 8, 2])
       v
  the state image  <------------------------->  the host's state channel
       ^                                          |  sets the native control;
       |  CalendarDate(carried:)                  |  the user's change comes
       +------------------------------------------+  back as a report
```

A closed vocabulary rides a state as its member's number
([choices a state can carry](vocabularies.md#choices-a-state-can-carry)), and
a run of placements rides one as twelve numbers a view
([placement](placement.md#twelve-numbers-a-view)).

## What the host knows

The battery, the network, the display, the locale, the device, the
application's manifest and its phase are state only the host has. The host
writes them into one provider object each, and a view reads a provider with
`@Environment`.

```text
  the platform reports a change
       |
       |  a Swift host:                     StateUIHost.setDeviceInfo(...) and its kin
       |  a runtime in another language:    stateui_set_environment(bytes)
       |                                      -> StandardEnvironment.apply(domain, values)
       v
  Battery  Connectivity  DeviceDisplay  LocaleInfo  DeviceInfo  AppInfo  ApplicationSession
       |   each property a @State
       |
       v
  exactly the bodies that read the written property build again
```

[The standard environment](environment.md) has the reasons, and
[sessions](sessions.md) the objects that describe the application, its
scenes, windows and pages as they run.
