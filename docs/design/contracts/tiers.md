# Tiers

A tier is a contract with no node type of its own: members several elements
share, declared once. Every text control's font size is one member of one
tier, `FontElement`, so a host realizes it once and the dictionary shows it
once. An element names the tiers it wears, and a tier may wear tiers, as the
Swift protocols behind them refine each other.

## The tier tree

```text
  AutomationElement                      the name automation finds an element by
  |-- VisualElement  (+ EnabledElement, BackgroundElement, StyledElement)
  |   |                                  size, visibility, transform, input, accessibility
  |   |-- View  (+ HoverElement)         place in a layout, margin, gestures, drag and drop, frame
  |   |   |-- Layout  (+ PaddingElement, BorderElement, KeyboardElement)
  |   |   |   |                          safe area, clipping, own box, input through empty space
  |   |   |   '-- Stack                  spacing between children
  |   |   |-- TextInput  (+ FocusElement, PlaceholderElement)
  |   |   |                              text limits, caret, keyboard
  |   |   '-- Shape  (+ ContentModeElement)
  |   |       |                          stroke, dashes and ends, a transform of its own drawing
  |   |       |-- FilledShape            what fills the area it encloses
  |   |       '-- CorneredShape          how its corners join
  |   '-- TextAlignmentElement           where text sits across its element
  '-- ActionElement  (+ ClickElement)    what choosing an item does: an action, or one that destroys

  TextElement                            the words an element shows
  TextColorElement                       the words' color
  '-- TextualElement  (+ TextElement)    the case the words are drawn in
  FontElement                            family, size, weight and slant, text-size scaling
  LineHeightElement                      space between lines
  LineBreakElement                       what words too long for their room do
  TrackingElement                        space between letters
  DecorableTextElement                   underline and strikethrough
  PlaceholderElement                     the words shown while an element holds nothing
  PaddingElement                         space inside an element
  BorderElement                          the shape of an element's own box, and its outline
  BackgroundElement                      what an element is painted on
  StyledElement                          the keyed style an element wears
  ContentModeElement                     how a picture or a shape fills its room
  PointsShape                            the points a shape is drawn through, and its fill rule
  TintElement                            a control's one accent color
  IconElement                            a picture
  TextAndIconElement                     whether the words stand beside the picture
  EnabledElement                         whether the hand reaches an element
  HoverElement                           the pointer coming over it and leaving
  PressElement                           a press beginning and ending
  ClickElement                           a click
  ShortcutElement                        the keys that choose it
  ToggleElement                          a position the user turns on and off
  RangeElement                           a number in a range
  PopupElement                           a list that opens and closes
  SubmitElement                          a submission, and its key's caption
  ButtonMenuElement                      a menu a button opens
  RefreshElement                         a refresh the user pulls
  KeyboardElement                        keys taken while it holds the keyboard
  '-- FocusElement                       the keyboard put on it and taken off
  PageElement  (+ BackgroundElement, IconElement)
                                         a title, an icon, a link its window is given
  BarElement                             an arrangement's bar: colors, title area
  PresentedElement                       whether a sheet or a popover is shown
  SessionElement                         a scene's and a window's phases

  A tier on the second list wears only what it names: a text run wears the text tiers and the ground it
  stands on, and no name automation finds it by.
```

## Who wears what

```text
  VisualElement        every TextAlignmentElement, every View
  View                 Button, Canvas, CheckBox, ColorPicker, DatePicker,
                       Fill, Image, ItemsView, Link, Map, Picker,
                       ProgressBar, ScrollView, Separator, Slider, Space,
                       Spinner, Stepper, Switch, Text, TimePicker, WebView,
                       every Layout, every Shape, every TextInput
  Layout               Grid, MotionLayout, ZStack, every Stack
  Stack                HStack, VStack
  TextInput            SearchField, TextEditor, TextField
  Shape                Line, every CorneredShape, every FilledShape
  FilledShape          Capsule, Ellipse, Path, Polygon, Polyline, Rectangle
  CorneredShape        Path, Polygon, Polyline, Rectangle
  AutomationElement    MenuItem, MenuToggle, NavigationStack, SplitView,
                       TabView, ToolbarButton, ToolbarToggle, every
                       ActionElement, every VisualElement
  ActionElement        MenuItem, ToolbarButton
  TextElement          Menu, MenuItem, MenuToggle, ToolbarButton,
                       ToolbarLabel, ToolbarToggle, every TextualElement
  TextualElement       Button, CheckBox, Link, SearchField, Switch, Text,
                       TextEditor, TextField, TextSpan
  TextColorElement     DatePicker, Picker, TimePicker, ToolbarButton,
                       ToolbarToggle, every TextualElement
  FontElement          Button, DatePicker, Picker, SearchField, Text,
                       TextEditor, TextField, TextSpan, TimePicker,
                       ToolbarButton, ToolbarToggle
  TextAlignmentElement Picker, SearchField, Text, TextEditor, TextField
  LineHeightElement    Text
  LineBreakElement     Button, Text
  TrackingElement      Button, Text, TextSpan
  DecorableTextElement Text, TextSpan
  PlaceholderElement   Picker, every TextInput
  PaddingElement       Button, ScrollView, Text, ToolbarButton,
                       ToolbarGroup, ToolbarToggle, every Layout
  BorderElement        Button, Fill, ScrollView, SearchField, Space,
                       TextEditor, TextField, ToolbarButton, ToolbarGroup,
                       ToolbarToggle, every Layout
  BackgroundElement    TextSpan, ToolbarButton, ToolbarGroup, ToolbarToggle,
                       Window, every PageElement, every VisualElement
  StyledElement        ToolbarButton, ToolbarGroup, ToolbarToggle, every
                       VisualElement
  ContentModeElement   Button, Image, every Shape
  PointsShape          Polygon, Polyline
  TintElement          CheckBox, Picker, ProgressBar, Slider, Spinner,
                       Switch
  IconElement          Button, MenuItem, MenuToggle, ToolbarButton,
                       ToolbarLabel, ToolbarToggle, every PageElement
  TextAndIconElement   Button, ToolbarButton, ToolbarToggle
  EnabledElement       Menu, MenuItem, MenuToggle, ToolbarButton,
                       ToolbarGroup, ToolbarToggle, every VisualElement
  HoverElement         ToolbarButton, ToolbarGroup, ToolbarToggle, every
                       View
  PressElement         Button, Slider, ToolbarButton, ToolbarToggle
  ClickElement         Button, Link, every ActionElement
  ShortcutElement      Button, MenuItem, MenuToggle, ToolbarButton,
                       ToolbarToggle
  ToggleElement        CheckBox, MenuToggle, Switch, ToolbarToggle
  RangeElement         Slider, Stepper
  PopupElement         DatePicker, Picker, TimePicker
  SubmitElement        SearchField, TextField
  ButtonMenuElement    Button, ToolbarButton
  RefreshElement       ItemsView, ScrollView
  KeyboardElement      every FocusElement, every Layout
  FocusElement         Button, CheckBox, ColorPicker, DatePicker, ItemsView,
                       Link, Picker, ScrollView, Slider, Stepper, Switch,
                       TimePicker, WebView, every TextInput
  PageElement          NavigationStack, Page, SplitView, TabView
  BarElement           NavigationStack, SplitView, TabView
  PresentedElement     Popover, Sheet
  SessionElement       Scene, Window
  no tier              Anchor, Application, BottomBar, ButtonMenu,
                       ContextMenu, Marker, MenuBar, MenuSeparator, Overlay,
                       TextSpans, TitleView
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

## One owner for each member

A member several elements say alike - their words, their picture, a click -
is one member of one tier they all wear, so a host reads it by one key and
the dictionary shows it once. A tier promises its every member on every
element wearing it: a member alone in a bigger tier goes into one of its own
when a wearer cannot honor the rest - a menu wears `TextElement`, not
`TextualElement`, whose case and color no native menu gives. A tier owns at
least one member (`LibraryContractTests`): one left with none goes, and its
wearers wear its tiers.

## Wearing without a view

A tier is worn by whatever carries its values, not only by views. A `TextSpan`,
one run of text inside a label, wears the text tiers and no view. A `Style`
is a property container typed by its control: `Style<Button>` carries any
property a button carries, and nothing else. A page
and a page arrangement say their title and icon under the same keys, so both
wear `PageElement`, which wears only `BackgroundElement` and `IconElement`: a
page carries its title, its ground and its icon and no other value an element
carries.
