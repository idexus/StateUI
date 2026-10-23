# Tiers

A tier is a contract with no node type of its own: members several elements
share, declared once. Every text control's font size is one member of one
tier, `FontElement`, so a host realizes it once and the dictionary shows it
once. An element names the tiers it wears, and a tier may wear tiers, as the
Swift protocols behind them refine each other.

## The tier tree

```text
  AutomationElement                      the name automation finds an element by
  |-- VisualElement                      size, visibility, transform, input, accessibility
  |   |-- View                           place in a layout, margin, gestures, drag and drop, frame
  |   |   |-- Layout  (+ PaddingElement, BorderElement) safe area, clipping, own box, input through empty space
  |   |   |   '-- Stack              spacing between children
  |   |   |-- TextInput                  text limits, caret, keyboard, placeholder
  |   |   '-- Shape                      stroke, dashes and ends, a transform of its own drawing
  |   |       |-- FilledShape            what fills the area it encloses
  |   |       '-- CorneredShape          how its corners join
  |   |-- PaddingElement                 space inside an element
  |   '-- TextAlignmentElement           where text sits across its element
  '-- MenuItemElement                    an item the user chooses: caption, icon, action, shortcut

  TextColorElement                       text color
  '-- TextualElement                     the words and their case
  FontElement                            family, size, weight and slant, text-size scaling
  LineHeightElement                      space between lines
  TrackingElement                        space between letters
  DecorableTextElement                   underline and strikethrough
  BorderElement                          the shape of an element's own box, and its outline
  ImageElement                           how a picture fills its room
  TintElement                            a control's one accent color
  KeyboardElement                        keys taken while it holds the keyboard
  '-- FocusElement                       the keyboard put on it and taken off
  PageElement                            a title and an icon
  BarElement                             an arrangement's bar: colors, title area

  Each tier on the second list wears nothing above it: a text run wears the text tiers, and no name automation
  finds it by.
```

## Who wears what

```text
  View               ActivityIndicator, Button, Canvas, CheckBox,
                     DatePicker, Divider, Filler, Image, Text, Map, Picker,
                     ProgressBar, ScrollView, Slider, Spacer, Stepper,
                     Switch, TimePicker, WebView, ItemsView
  Layout             Grid, LayoutEngine, ZStack
  Stack              HStack, VStack
  TextInput          SearchField, TextEditor, TextField
  Shape              Capsule, Ellipse, Line, Path, Polygon, Polyline,
                     Rectangle
  FilledShape        Capsule, Ellipse, Path, Polygon, Polyline, Rectangle
  CorneredShape      Path, Polygon, Polyline, Rectangle
  AutomationElement  every View, MenuItem, ToolbarButton, NavigationStack,
                     TabView, SplitView
  MenuItemElement    MenuItem, ToolbarButton
  TrackingElement    Text, Button, TextSpan
  LineHeightElement  Text
  KeyboardElement    every Layout and every FocusElement
  FocusElement       Button, CheckBox, DatePicker, ItemsView, Picker,
                     ScrollView, Slider, Stepper, Switch, TimePicker,
                     WebView, every TextInput
  PageElement        Page, NavigationStack, TabView, SplitView
  BarElement         NavigationStack, TabView, SplitView
  text tiers only    TextSpan
  no tier            Application, Scene, Window, MenuBar, Menu, ButtonMenu,
                     MenuSeparator, ContextMenu, Overlay, Marker, and the
                     slots and collections
```

An element adds the smaller tiers it needs beside its main one: a `Button`
is a `View` with a caption in a font, padded, bordered, with a picture
fitted; a `Switch` is a `View` with a tint and the words it says beside it.

## Worn once nearest first

A contract's `worn` list is the contract and every tier it wears, each once,
in the order met: the contract, then each tier it names, each followed by
the tiers that tier wears. A tier reached twice, through two of the tiers
worn, counts where it was first met. The dictionary shows an element's own
members and then each tier's, in the dictionary's tier order.

No contract wears two members of one name, through its own list or its
tiers': a node's properties are one map, so two members of one name would
write each other's key.

## Wearing without a view

A tier is worn by whatever carries its values, not only by views. A `TextSpan`,
one run of text inside a label, wears the text tiers and no view. A `Style`
is a property container typed by its control: `Style<Button>` carries any
property a button carries, and nothing else. A page
and a page arrangement say their title and icon under the same keys, so both
wear `PageElement`, and it wears nothing: a page carries its title and its
icon and no other value an element carries.
