# Controls

A control is a node of its contract's type and the modifiers written on it.
Each control file holds the control, its own properties protocol, the events
and acts it declares, and the binding twins of its values.

## A control is a node and its modifiers

```text
  public struct Slider: ElementView, TintElement, SliderProperties {
      public var node: Node                      Node(contract: SliderContract.self)
      init()                                     nothing set: what a Style<Slider> uses
      init(_ value: Double)                      the purpose value, one-way
      init(_ value: Binding<Double>)             the purpose value, two-way
      func value(_:) / minimum(_:) / …           properties, from SliderProperties
      func onValueChanged(_:)                    events, through onEvent(member)
  }
  extension Aim where Target == Map { … }       a control's acts, through call(member)
```

What gives a control its purpose - a label's text, a picker's options, a
path's outline, an image's source - goes in the initializer; everything else is
a modifier (composition.md, what goes in the initializer). A two-way control
whose bound value is its purpose takes its binding in the initializer and in a
modifier of the same name; a picker and a radio button, whose initializers take
their options and their caption, take it in the modifier alone (bindings.md,
both spellings).

## Closed vocabularies are numbered here

A closed vocabulary a control uses - `IconPosition`, `MapType`,
`WebNavigationType`, `WebNavigationResult` - crosses as an `.enumeration`
whose numbers are the library's own, in declaration order, the rule of
[closed vocabularies](../types/vocabularies.md#written-out-and-appended). A
host translates its toolkit's value onto the member
that means the same. A toolkit's own numbers stay out of it: a toolkit release
free to renumber its enumeration would otherwise make every report read as a
different member, silently. A member a host has no case for arrives as
`.unknown` where the vocabulary has one.

## A color stroke is a solid brush

`stroke(_ value: Color)` is written over the brush form, on a layout as on a
shape, so a layout's outline and a shape's put the same value in the patch for
the same color. A bare
color written out instead would make one property arrive in two shapes and
leave the host carrying a branch to tell them apart.

## Opening a picker

A picker's, a date picker's and a time picker's `isOpen` asks the host to show
or dismiss the list, calendar or clock face; it is a presentation request, not
another selection state. `onOpened` answers the user opening it and not an
`isOpen(true)` write: the tree opening it opens the platform's own and raises
nothing, since an application that opened it from a button of its own already
knows. The user can still close it by choosing, tapping away or pressing
Escape, which `onClosed` reports.

A date picker and a time picker take `textColor` through `TextColorElement`
but have no `text` and no letter spacing: the field shows the formatted value,
which a native picker spaces as it does. The
host does the formatting, where the calendar and the user's locale are, so
month names and a 12- or 24-hour clock come out in the user's own terms. There
is no `today` to hand, since the host's clock answers a time of day with no
date beside it, so a page whose limit is the current day holds that day in
state.

## A picker chooses a value

A picker chooses one of its values, not a place in its list: `Picker(items,
selection: $value) { caption }` crosses as the values' captions (`options`) and
the chosen value's place among them (`selectedIndex`), worked out again at
each build, so the list can change its order and the choice stays the value
it was. A choice the user makes comes back as its place and lands on the
state as the value standing there; a place outside the list changes nothing.
The state is read where the picker is built, so a choice builds that body
again - the host cannot carry an application's own value. Nothing is chosen
while the state holds nil, or a value the list does not hold, and the
placeholder shows. A value needs only to be `Equatable`; it shows by its
description unless the picker is given a caption.

## A picker's presentation

`.presentation(.menu/.segmented/.radio)` says how a picker offers its values:
the platform's pop-up or drop-down field, a row of segments, or a radio button
for each. Each is another control, so another presentation makes the picker
anew (`remakes`), and a host makes the one the picker is made with
(`PickerChoices.presentation(made:)`). A list opens only from a menu: on
segments and radio buttons `isOpen` asks for nothing, and `onOpened` and
`onClosed` never come.

## Where a map opens

Where a map opens belongs in its initializer rather than in an act from
`.onCreated`: a region given there is kept by the host and applied once the
platform's map is ready, while the act lands an instant after the native map
exists and the platform's own opening region overwrites it. Moving a map that
is already up is the act `moveToRegion`.

A marker, a map, a web page and a navigation report what happened; handlers on
them observe. A handler runs a boundary away, after the platform has already
decided: a marker's tap handler cannot keep the callout shut, and a web view's
`onNavigating` cannot cancel the navigation - a page that must not be left is a
page not navigated to.

## Web view

What a web view is told to do is an act - `goBack()`, `reload()`,
`evaluateJavaScript(_:)` - because a description has no control to call a
method on; what it reports travels the other way, into a binding
(`.canGoBack($hasBack)`). Its source crosses as its kind and then what it is
made of: an address as the kind and the address, a document as the kind, the
document and its base address or nothing - three values whether or not there
is a base address, so the host reads the same places every time and never tells
the two apart by shape. WebView2 and WebKitGTK do not tell a step back from one
forward, so a step through the history the program did not ask for reports
`.unknown` there: an ordinary answer, not a fault.

## Canvas and path

A canvas drawing travels as data - its canvas calls, in order - because an
object with a draw method is the one thing the boundary cannot carry; the host
replays the calls on the platform's own canvas. A drawing reading a state is
described again when the state changes, and so redrawn.

A path's outline crosses as SVG path text, and a parser shared by the hosts
normalizes it to absolute moves, lines, curves, arcs and closes before each
toolkit draws that closed set, so the grammar accepted is not any one
platform's. A toolkit with no SVG arc draws each as the cubic Bézier segments
the shared parser works out, a quarter turn at most each, so an arc bends the
same on every host.

## Text runs

A `TextSpan` is one run of text inside a Text, with its own color, size and
weight; text in two colors is two runs. It is named `TextSpan` rather than
`Span` because the standard library's `Span<Element>` is in scope in every file
without an import: an application writing `Span("…")` would get "no exact
matches in call to initializer", and a plain `[Span]` "reference to generic
type 'Span' requires arguments". The node in the patch is `TextSpan` all the same,
the vocabulary's name for a run.

## Images

An image's source is a file among the application's resources, never an
address: a name that looks like a url is looked for among the resources like
any other and is not found. Artwork kept as an SVG is asked for by its PNG
name. A source with a half for each theme carries both halves to the differ,
which picks the one the theme asks for as it builds the view, so a theme change
builds again only the views wearing a pair. An `Image` has no padding: a
modifier that compiles into nothing is worse than no modifier. Whether an
animated picture runs is a property rather than an act, so a paused animation
is a state the tree describes and a rebuild cannot lose.

## Items that are not views

A menu, a menu entry, a separator, a toolbar item and a map marker are elements
but not views: each has a caption, a picture or a point and something to run,
and no layout of its own. Of the modifiers a view has they take only `.id()`,
and `.accessibilityIdentifier` on a menu entry or a toolbar item; they belong
in one place - a page's toolbar, a menu, a map - and are matched there by
their `.id()` or their position.

## A button's menu

`Button.menu { … }` writes a slot, `ButtonMenu`, after the button's children,
holding what a menu holds; written again it stands in for the last. How the
menu opens (`ButtonMenuOpening`) follows from the menu, the click and the kind
asked (`ButtonMenuKind`):

- no menu: a button;
- a menu and no `.onClicked`: the click opens the menu, and an arrow pointing
  down says so unless `.showsMenuArrow(false)` takes it away - never an arrow
  up and down, which says a choice of values, as a picker's;
- a click of its own, or `.split`: a split button, its click its own action,
  its arrow a part of its own opening the menu;
- `.held`: the click its own action, the menu opened by holding the button,
  and no arrow.

Each toolkit makes a control of its own of each - GTK's menu button and
libadwaita's split button; WinUI's DropDownButton, a Button with a flyout, its
SplitButton - and a control is made once, so the differ makes a button opening
its menu otherwise, or showing its arrow otherwise, again
(`Node+ButtonMenu.swift`, `remakes`), and a host reads how it opens from the
patch the element is made from (`ButtonMenu.opening(made:)`). Where a toolkit
draws no split button - UIKit, Android, the browser - or its menu buttons take
no style - AppKit's - the host gives its own button the arrow. Holding is
each platform's: a held mouse button on AppKit and GTK, a finger held on a
touch screen, and on Windows and in the browser the user's asking for a
menu - a finger or a pen held still, the mouse's other button. A button holding
a menu offers no context menu of its own: on AppKit and WinUI the button's menu
and the view's are one property.
