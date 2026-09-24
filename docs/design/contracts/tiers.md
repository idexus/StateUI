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
  |   |   |-- Layout  (+ PaddingElement) safe area, clipping, input through empty space
  |   |   |   '-- StackBase              spacing between children
  |   |   |-- InputView                  text limits, caret, keyboard, placeholder
  |   |   '-- Shape                      fill, stroke, a transform of its own drawing
  |   |-- PaddingElement                 space inside an element
  |   '-- TextAlignmentElement           where text sits in its element
  |-- TextStyleElement                   text colour, space between letters
  |   '-- TextElement                    the words and their case
  |-- FontElement                        family, size, weight and slant, text-size scaling
  |-- LineHeightElement                  space between lines
  |-- DecorableTextElement               underline and strikethrough
  |-- BorderElement                      a control's own outline and corner radius
  |-- ImageElement                       how a picture fills its room
  |-- TintElement                        a control's one accent colour
  |-- BarElement                         a page arrangement's bar colour
  '-- MenuItemElement                    an item the user chooses: caption, icon, action

  PageElement                            a title and an icon; wears nothing
```

## Who wears what

```text
  View               ActivityIndicator, Border, Button, Canvas, CheckBox, ColorBox,
                     DatePicker, Image, Label, Map, Picker, PositionIndicator,
                     ProgressBar, RadioButton, ScrollView, Slider, Stepper,
                     Switch, TimePicker, TitleBar, WebView
  Layout             AbsoluteLayout, Grid
  StackBase          HStack, VStack
  InputView          SearchField, TextEditor, TextField
  Shape              Ellipse, Line, Path, Polygon, Polyline, Rectangle
  MenuItemElement    MenuItem, ToolbarItem
  PageElement        Page, NavigationStack, TabbedView, SplitView
  text tiers only    Span
  no tier            Application, Scene, Window, Menu, MenuSeparator, ContextMenu,
                     ModalStack, Overlay, VisualState, and the slots and collections
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

A tier is worn by whatever carries its values, not only by views. A `Span`,
one run of text inside a label, wears the text tiers and no view. A `Style`
is a property container, so it can carry any member a control can. A page
and a page arrangement say their title and icon under the same keys, so both
wear `PageElement`, and it wears nothing: a page carries its title and its
icon and no other value an element carries.
