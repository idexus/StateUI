# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with what each target host's tests proved of it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer colour on a label and a drawn fill on an outlined layout.

<!-- legend:begin -->
| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| ✓ | Proven only through the host's own entry or record, not the toolkit's; it counts as met. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |
<!-- legend:end -->

A host's column is its tests' verdicts: each host's suite runs the conformance families - one for each contract, a case for every cell of every page - and writes what each said under `exports/marks/<host>/`, one line a member of an element, read here. A host's register - its records, what its runtime registers, what it never has - decides whether a case runs and what its verdict says, and nothing it declares marks a cell by itself. A tier's member is marked on every element wearing the tier, each by its own case. What the hosts note of a member stands in a row beneath it, across every cell but its name, a line for each thing noted, the hosts noting it named before it: `AppKit, UIKit: …`. Nothing on a page is written by hand: `ControlDictionaryTests` fails when a page or a table below differs from the contracts and the verdicts, or when a verdict names what no contract declares, and `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes them again.

## Controls

The elements a layout positions - every one wears [View](tiers/View.md).

<!-- controls:begin -->
| Control | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](ActivityIndicator.md) | 68 | 26 ✅ · 1 ☑️ · 26 ✓ · 3 – | 28 ✅ · 25 ✓ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 45 ✅ · 10 ✓ |
| [Button](Button.md) | 86 | 41 ✅ · 1 ☑️ · 27 ✓ · 1 – | 43 ✅ · 27 ✓ · 3 – | 60 ✅ · 1 ☑️ · 3 – | 73 ✅ · 2 ✓ | 55 ✅ · 18 ✓ · 1 – | 55 ✅ · 10 ✓ |
| [Canvas](Canvas.md) | 70 | 27 ✅ · 1 ☑️ · 28 ✓ · 3 – | 27 ✅ · 28 ✓ · 3 – | 54 ✅ · 1 ☑️ · 3 – | 53 ✅ · 3 ✓ · 3 – | 44 ✅ · 11 ✓ · 4 – | 47 ✅ · 10 ✓ |
| [CheckBox](CheckBox.md) | 69 | 33 ✅ · 1 ☑️ · 25 ✓ | 28 ✅ · 26 ✓ · 3 – | 54 ✅ · 1 ☑️ · 3 – | 58 ✅ · 2 ✓ | 45 ✅ · 12 ✓ · 1 – | 46 ✅ · 10 ✓ |
| [ColorBox](ColorBox.md) | 68 | 28 ✅ · 25 ✓ · 3 – | 28 ✅ · 25 ✓ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 45 ✅ · 10 ✓ |
| [DatePicker](DatePicker.md) | 80 | 37 ✅ · 1 ☑️ · 26 ✓ · 1 – | 31 ✅ · 25 ✓ · 3 – | 59 ✅ · 1 ☑️ · 3 ✓ · 3 – | 65 ✅ · 1 ☑️ · 2 ✓ | 52 ✅ · 1 ☑️ · 13 ✓ · 1 – | 50 ✅ · 10 ✓ |
| [Ellipse](Ellipse.md) | 76 | 26 ✅ · 1 ☑️ · 25 ✓ · 3 – | 28 ✅ · 25 ✓ · 3 – | 50 ✅ · 1 ☑️ · 3 – | 58 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 53 ✅ · 10 ✓ |
| [Grid](Grid.md) | 77 | 33 ✅ · 25 ✓ · 3 – | 35 ✅ · 25 ✓ · 3 – | 56 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 ✓ · 3 – | 48 ✅ · 11 ✓ · 4 – | 54 ✅ · 10 ✓ |
| [HStack](HStack.md) | 74 | 30 ✅ · 25 ✓ · 3 – | 32 ✅ · 25 ✓ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 56 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 51 ✅ · 10 ✓ |
| [Image](Image.md) | 69 | 28 ✅ · 1 ☑️ · 25 ✓ · 3 – | 28 ✅ · 25 ✓ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 ✓ · 3 – | 42 ✅ · 11 ✓ · 4 – | 44 ✅ · 10 ✓ |
| [ItemsView](ItemsView.md) | 76 | 34 ✅ · 1 ☑️ · 29 ✓ | 31 ✅ · 29 ✓ · 3 – | 61 ✅ · 1 ☑️ · 1 ✓ | 62 ✅ · 2 ✓ | 52 ✅ · 11 ✓ · 1 – | 51 ✅ · 11 ✓ |
| [Line](Line.md) | 80 | 30 ✅ · 1 ☑️ · 25 ✓ · 3 – | 32 ✅ · 25 ✓ · 3 – | 54 ✅ · 1 ☑️ · 3 – | 62 ✅ · 3 ✓ · 3 – | 49 ✅ · 11 ✓ · 4 – | 57 ✅ · 10 ✓ |
| [Map](Map.md) | 74 | 33 ✅ · 1 ☑️ · 26 ✓ · 3 – | 33 ✅ · 26 ✓ · 3 – | 74 🧩 | 74 🧩 | 74 🧩 | 74 🧩 |
| [Path](Path.md) | 77 | 27 ✅ · 1 ☑️ · 25 ✓ · 3 – | 29 ✅ · 25 ✓ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 ✓ · 3 – | 46 ✅ · 11 ✓ · 4 – | 54 ✅ · 10 ✓ |
| [Picker](Picker.md) | 82 | 39 ✅ · 1 ☑️ · 26 ✓ · 1 – | 28 ✅ · 28 ✓ · 3 – | 54 ✅ · 1 ☑️ · 1 ✓ · 3 – | 67 ✅ · 2 ✓ | 50 ✅ · 11 ✓ · 7 – | 48 ✅ · 10 ✓ |
| [Polygon](Polygon.md) | 78 | 28 ✅ · 1 ☑️ · 25 ✓ · 3 – | 30 ✅ · 25 ✓ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 60 ✅ · 3 ✓ · 3 – | 47 ✅ · 11 ✓ · 4 – | 55 ✅ · 10 ✓ |
| [Polyline](Polyline.md) | 78 | 28 ✅ · 1 ☑️ · 25 ✓ · 3 – | 30 ✅ · 25 ✓ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 60 ✅ · 3 ✓ · 3 – | 47 ✅ · 11 ✓ · 4 – | 55 ✅ · 10 ✓ |
| [ProgressBar](ProgressBar.md) | 68 | 27 ✅ · 1 ☑️ · 25 ✓ · 3 – | 28 ✅ · 25 ✓ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 52 ✅ · 2 ✓ · 3 – | 41 ✅ · 12 ✓ · 4 – | 45 ✅ · 10 ✓ |
| [RadioButton](RadioButton.md) | 81 | 39 ✅ · 1 ☑️ · 25 ✓ · 1 – | 36 ✅ · 26 ✓ · 3 – | 60 ✅ · 1 ☑️ · 3 – | 65 ✅ · 2 ✓ | 52 ✅ · 12 ✓ · 1 – | 50 ✅ · 10 ✓ |
| [Rectangle](Rectangle.md) | 77 | 27 ✅ · 1 ☑️ · 25 ✓ · 3 – | 29 ✅ · 25 ✓ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 ✓ · 3 – | 46 ✅ · 11 ✓ · 4 – | 54 ✅ · 10 ✓ |
| [ScrollView](ScrollView.md) | 77 | 33 ✅ · 2 ☑️ · 27 ✓ · 3 – | 35 ✅ · 25 ✓ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 61 ✅ · 3 ✓ · 3 – | 51 ✅ · 11 ✓ · 1 – | 55 ✅ · 10 ✓ |
| [SearchField](SearchField.md) | 89 | 42 ✅ · 26 ✓ · 3 – | 48 ✅ · 25 ✓ | 70 ✅ · 1 ☑️ · 1 – | 66 ✅ · 1 ☑️ · 2 ✓ | 60 ✅ · 12 ✓ · 1 – | 60 ✅ · 10 ✓ |
| [Slider](Slider.md) | 73 | 35 ✅ · 1 ☑️ · 25 ✓ | 32 ✅ · 27 ✓ · 3 – | 56 ✅ · 1 ☑️ · 3 – | 59 ✅ · 2 ✓ | 47 ✅ · 12 ✓ · 3 – | 48 ✅ · 10 ✓ |
| [Stepper](Stepper.md) | 71 | 32 ✅ · 1 ☑️ · 25 ✓ | 29 ✅ · 25 ✓ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 59 ✅ · 2 ✓ | 48 ✅ · 11 ✓ · 1 – | 48 ✅ · 10 ✓ |
| [Switch](Switch.md) | 69 | 32 ✅ · 1 ☑️ · 25 ✓ | 29 ✅ · 25 ✓ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 58 ✅ · 2 ✓ | 45 ✅ · 12 ✓ · 1 – | 46 ✅ · 10 ✓ |
| [Text](Text.md) | 81 | 39 ✅ · 1 ☑️ · 25 ✓ · 4 – | 41 ✅ · 25 ✓ · 3 – | 62 ✅ · 1 ☑️ · 3 – | 65 ✅ · 2 ✓ · 3 – | 53 ✅ · 13 ✓ · 4 – | 58 ✅ · 10 ✓ |
| [TextEditor](TextEditor.md) | 87 | 47 ✅ · 1 ☑️ · 26 ✓ · 1 – | 48 ✅ · 25 ✓ | 69 ✅ · 1 ☑️ · 1 – | 72 ✅ · 2 ✓ | 59 ✅ · 1 ☑️ · 12 ✓ · 1 – | 61 ✅ · 10 ✓ |
| [TextField](TextField.md) | 90 | 43 ✅ · 1 ☑️ · 26 ✓ · 3 – | 50 ✅ · 25 ✓ | 71 ✅ · 1 ☑️ · 2 – | 71 ✅ · 1 ☑️ · 2 ✓ | 61 ✅ · 12 ✓ · 1 – | 63 ✅ · 10 ✓ |
| [TimePicker](TimePicker.md) | 78 | 35 ✅ · 1 ☑️ · 26 ✓ · 1 – | 32 ✅ · 25 ✓ | 59 ✅ · 1 ☑️ · 1 ✓ · 3 – | 60 ✅ · 2 ✓ | 51 ✅ · 12 ✓ · 1 – | 48 ✅ · 10 ✓ |
| [VStack](VStack.md) | 74 | 30 ✅ · 25 ✓ · 3 – | 32 ✅ · 25 ✓ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 56 ✅ · 3 ✓ · 3 – | 45 ✅ · 11 ✓ · 4 – | 51 ✅ · 10 ✓ |
| [WebView](WebView.md) | 77 | 39 ✅ · 1 ☑️ · 26 ✓ | 39 ✅ · 26 ✓ | 61 ✅ · 1 ☑️ · 3 – | 45 ✅ · 3 ✓ · 18 – | 54 ✅ · 11 ✓ · 1 – | 51 ✅ · 10 ✓ |
| [ZStack](ZStack.md) | 73 | 29 ✅ · 25 ✓ · 3 – | 31 ✅ · 25 ✓ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 55 ✅ · 3 ✓ · 3 – | 44 ✅ · 11 ✓ · 4 – | 50 ✅ · 10 ✓ |
| ✅ |  | 1057 | 1060 | 1737 | 1845 | 1508 | 1598 |
| ✓ |  | 820 | 818 | 6 | 78 | 361 | 311 |
| – |  | 67 | 81 | 85 | 69 | 87 | 0 |
| **Met** | 2447 | **1944** | **1959** | **1828** | **1992** | **1956** | **1909** |
| 🧩 |  | 0 | 0 | 74 | 74 | 74 | 74 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 17 | 7 ✅ · 10 ✓ | 7 ✅ · 10 ✓ | 6 ✅ · 9 ✓ | 15 ✅ · 2 ✓ | 11 ✅ · 1 ✓ | 12 ✅ · 5 ✓ |
| [ContextMenu](ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Divider](Divider.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 6 | 3 ✅ · 1 ☑️ | 6 ✅ | 4 ✅ · 2 – | 6 ✅ | 3 ✅ · 3 – | 6 ✅ |
| [ModalStack](ModalStack.md) | 6 | 4 ✅ | 4 ✅ · 2 – | 3 ✅ · 2 – | 6 ✅ | 4 ✅ · 2 – | 5 ✅ · 1 – |
| [NavigationStack](NavigationStack.md) | 9 | 4 ✅ · 1 ✓ | 7 ✅ · 2 – | 3 ✅ · 2 – | 9 ✅ | 5 ✅ · 4 – | 7 ✅ · 1 – |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 11 | 7 ✅ | 11 ✅ | 8 ✅ · 1 – | 9 ✅ | 7 ✅ · 1 – | 9 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [SplitView](SplitView.md) | 10 | 6 ✅ | 8 ✅ · 2 – | 3 ✅ · 2 ✓ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TabView](TabView.md) | 10 | 5 ✅ · 1 ✓ | 8 ✅ · 2 – | 3 ✅ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TextSpan](TextSpan.md) | 12 |  |  |  | 9 ✅ | 9 ✅ | 9 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](ToolbarItem.md) | 8 | 2 ✅ · 1 ✓ · 1 – | 6 ✅ · 1 – | 4 ✅ · 1 – | 8 ✅ | 7 ✅ · 1 – | 8 ✅ |
| [ToolbarItemGroup](ToolbarItemGroup.md) | 2 | 2 ✅ | 2 ✅ | 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [Window](Window.md) | 22 | 15 ✅ · 6 ✓ | 3 ✅ · 4 ✓ · 9 – | 2 ✅ · 4 ✓ | 22 ✅ | 8 ✅ · 6 ✓ · 8 – | 7 ✅ · 15 – |
| ✅ |  | 67 | 70 | 42 | 113 | 75 | 87 |
| ✓ |  | 20 | 17 | 15 | 2 | 7 | 5 |
| – |  | 1 | 18 | 13 | 0 | 27 | 20 |
| **Met** | 126 | **88** | **105** | **70** | **115** | **109** | **112** |
| 🧩 |  | 0 | 0 | 6 | 6 | 6 | 6 |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [PropertyContainer](tiers/PropertyContainer.md) - What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.
- [Stack](tiers/Stack.md) - What both stacks have: the space between their children.
- [TextInput](tiers/TextInput.md) - What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.
- [TextualElement](tiers/TextualElement.md) - What every element showing words has: the words, and the case they are drawn in.
- [TextStyleElement](tiers/TextStyleElement.md) - How text looks wherever it is drawn: its colour and the space between its letters.
- [FontElement](tiers/FontElement.md) - The font text is drawn in: its family, its size, its weight and slant, and whether it follows the user's text-size setting.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where text sits inside the space its own element was given.
- [LineHeightElement](tiers/LineHeightElement.md) - How far apart the lines of text are.
- [DecorableTextElement](tiers/DecorableTextElement.md) - The lines drawn through or under text.
- [PaddingElement](tiers/PaddingElement.md) - The space kept inside an element, around what it holds.
- [BorderElement](tiers/BorderElement.md) - What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.
- [ImageElement](tiers/ImageElement.md) - How a picture fills the room it was given.
- [TintElement](tiers/TintElement.md) - A control's one accent colour.
- [BarElement](tiers/BarElement.md) - What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.
- [MenuItemElement](tiers/MenuItemElement.md) - What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.
- [PageElement](tiers/PageElement.md) - What a page shows about itself where another container presents it as an item - a title and a picture.
<!-- tiers:end -->

## Layers

Which layer realizes an element or a member - the word each page and each row uses.

<!-- layers:begin -->
- `native` - Every base host presents it with its native toolkit.
- `adaptive` - Every base host presents it by its platform's conventions, keeping StateUI's state contract.
- `stateUI` - StateUI composes it from smaller primitives before a host receives the tree.
- `structure` - It carries structure or protocol data rather than configuring a visual platform object.
- `provider` - An optional provider supplies it: a package, or the application that registers it with its hosts.
<!-- layers:end -->
