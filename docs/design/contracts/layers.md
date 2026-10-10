# Layers

Every element, property and event declares the layer that realizes it; an
act declares none. The layer is what the contract promises about who does the
work, and the dictionary prints it beside every row.

## Five layers

| Layer | Who realizes it | Elements |
| --- | --- | --- |
| `native` | every base host, with its toolkit's own control | ActivityIndicator, Button, Canvas, ColorBox, DatePicker, HStack, Image, ItemsView, Picker, ProgressBar, ScrollView, SearchField, Slider, Stepper, Switch, Text, TextEditor, TextField, TimePicker, VStack, WebView, ZStack |
| `adaptive` | every base host, by its platform's conventions, keeping StateUI's state contract | CheckBox, ModalStack, NavigationStack, Page, RadioButton, SplitView, TabView |
| `stateUI` | StateUI decides its geometry, its arrangement or its composition - in the core or the shared host layer - and a host draws what was decided | Ellipse, Grid, Line, Path, Polygon, Polyline, Rectangle |
| `structure` | nobody draws it: it carries structure or protocol data | Application, Scene, Window, the menus, the slots and collections, TextSpan |
| `provider` | an optional provider: a package, or the application that registers it | Map, Marker, and an application's own elements |

An application's own contract is `provider` unless it says otherwise, for the
element and for each member.

## An element and its members

A member's layer is its own and may differ from its element's. A `CheckBox`
is `adaptive` - its toolkit's own box where the toolkit has one, a box drawn
for it on UIKit - yet whether it is ticked is `native`. A `Picker` is native, yet its list
of options is `structure`, data the host lays into its control. A `Map` is a
provider's, yet whether a drag pans it is `native`. A member that carries a
state's number, a placement a layout reads, or a report fed back into a
state, such as `panXChannel`, `area` or `frame`, is
`structure`.

## Choosing a layer

A member stands for one capability native hosts can implement consistently,
and the platform toolkits and the Gallery supply the evidence. Where every
toolkit has the control, the layer is `native`. Where platforms answer the
same need their own way - a navigation bar, tabs, a sidebar, a safe area, an
on-screen keyboard's return key - it is `adaptive`, and the state it carries
still means the same everywhere. A derived layout or a richer control is
decided by StateUI - a grid's arithmetic, a shape's geometry, a view composed
of others - in the core or the shared host layer, so no host re-creates it,
and the host draws what was decided: that is `stateUI`. A member
no target can honestly provide is not kept at all.

## The layer sentence

An element contract's `layer` carries one fixed sentence for each layer, so
every contract says it the same way:

```text
  native      Every base host presents it with its native control.
  adaptive    Every base host presents it by its platform's conventions, keeping StateUI's state contract.
  stateUI     StateUI decides its geometry, its arrangement or its composition; a host draws what was decided.
  structure   It carries structure, not a platform control of its own.
  provider    An optional provider supplies it; no base host has to.
```

The dictionary takes a layer's meaning from the documentation of the
`ElementLayer` cases in `ElementLayer.swift`, not from these
sentences.
