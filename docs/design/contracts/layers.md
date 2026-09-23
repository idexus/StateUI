# Layers

Every element and every member declares the layer that realizes it. The
layer is what the contract promises about who does the work, and the
dictionary prints it beside every row.

## Five layers

| Layer | Who realizes it | Elements |
| --- | --- | --- |
| `native` | every base host, with its toolkit's own control | AbsoluteLayout, ActivityIndicator, Border, Button, Canvas, ColorBox, DatePicker, HStack, Image, Label, Picker, ProgressBar, ScrollView, SearchField, Slider, Stepper, Switch, TextEditor, TextField, TimePicker, VStack, WebView |
| `adaptive` | every base host, by its platform's conventions, keeping StateUI's state contract | NavigationStack, Page, SplitView, TabbedView, TitleBar |
| `stateUI` | StateUI, composed from smaller primitives before a host receives the tree | CheckBox, Ellipse, Grid, Line, Path, Polygon, Polyline, PositionIndicator, RadioButton, Rectangle, RefreshView, SwipeView |
| `structure` | nobody draws it: it carries structure or protocol data | Application, Scene, Window, the menus, the slots and collections, Span, VisualState |
| `provider` | an optional provider: a package, or the application that registers it | Map, Pin, and an application's own elements |

An application's own contract is `provider` unless it says otherwise, for the
element and for each member.

## An element and its members

A member's layer is its own and may differ from its element's. A `CheckBox`
is composed by StateUI, yet whether it is ticked is `native`: the primitive
it is composed from is drawn by the host. A `Picker` is native, yet its list
of options is `structure`, data the host lays into its control. A `Map` is a
provider's, yet whether a drag pans it is `native`. A member that carries a
state's number, a placement a layout reads, or a report fed back into a
state, such as `panXChannel`, `absoluteLayoutBounds` or `frame`, is
`structure`.

## Choosing a layer

A member stands for one capability native hosts can implement consistently,
and the platform toolkits and the Gallery supply the evidence. Where every
toolkit has the control, the layer is `native`. Where platforms answer the
same need their own way - a navigation bar, tabs, a sidebar, a safe area, an
on-screen keyboard's return key - it is `adaptive`, and the state it carries
still means the same everywhere. A derived layout or a richer control is
composed by StateUI over measurement, placement, scrolling and the
primitives, so every host does not re-create it: that is `stateUI`. A member
no target can honestly provide is not kept at all.

## The layer sentence

An element contract's `layer` carries one fixed sentence for each layer, so
every contract says it the same way:

```text
  native      Every base host presents it with its native control.
  adaptive    Every base host presents it by its platform's conventions, keeping StateUI's state contract.
  stateUI     StateUI composes it from smaller primitives before a host receives the tree.
  structure   It carries structure, not a platform control of its own.
  provider    An optional provider supplies it; no base host has to.
```

The dictionary takes a layer's meaning from the documentation of the
`ElementLayer` cases in `Core/Contract.swift`, not from these sentences.
