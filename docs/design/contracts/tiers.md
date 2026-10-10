# Tiers

A tier is a contract with no node type of its own: members several elements
share, declared once. Every text control's font size is one member of one
tier, `FontElement`, so a host realizes it once and the dictionary shows it
once. An element names the tiers it wears, and a tier may wear tiers, as the
Swift protocols behind them refine each other.

## The tier tree

```text
  PropertyContainer                      the name automation finds an element by
  |-- VisualElement                      size, visibility, transform, input, focus, accessibility
  |   |-- View                           place in a layout, margin, gestures, drag and drop, frame
  |   |   |-- Layout  (+ PaddingElement, BorderElement) safe area, clipping, own box, input through empty space
  |   |   |   '-- Stack              spacing between children
  |   |   |-- TextInput                  text limits, caret, keyboard, placeholder
  |   |   '-- Shape                      fill, stroke, a transform of its own drawing
  |   |-- PaddingElement                 space inside an element
  |   '-- TextAlignmentElement           where text sits in its element
  |-- TextStyleElement                   text colour, space between letters
  |   '-- TextualElement                    the words and their case
  |-- FontElement                        family, size, weight and slant, text-size scaling
  |-- LineHeightElement                  space between lines
  |-- DecorableTextElement               underline and strikethrough
  |-- BorderElement                      the shape of an element's own box, and its outline
  |-- ImageElement                       how a picture fills its room
  |-- TintElement                        a control's one accent colour
  '-- MenuItemElement                    an item the user chooses: caption, icon, action

  PageElement                            a title and an icon; wears nothing
  BarElement                             an arrangement's bar: colours, title area;
                                         wears nothing
```

## Who wears what

```text
  View               ActivityIndicator, Button, Canvas, CheckBox, ColorBox,
                     DatePicker, Image, Text, Map, Picker, ProgressBar,
                     RadioButton, ScrollView, Slider, Stepper, Switch,
                     TimePicker, WebView, ItemsView
  Layout             Grid, ZStack
  Stack              HStack, VStack
  TextInput          SearchField, TextEditor, TextField
  Shape              Ellipse, Line, Path, Polygon, Polyline, Rectangle
  MenuItemElement    MenuItem, ToolbarItem
  PageElement        Page, NavigationStack, TabView, SplitView
  BarElement         NavigationStack, TabView, SplitView, ModalStack
  text tiers only    TextSpan
  no tier            Application, Scene, Window, Menu, Divider, ContextMenu,
                     Overlay, Marker, and the slots and collections
```

An element adds the smaller tiers it needs beside its main one: a `Button`
is a `View` with a caption in a font, padded, bordered, with a picture
fitted; a `Switch` is a `View` with a tint.

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
