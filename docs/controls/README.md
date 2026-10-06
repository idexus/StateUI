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
| [ActivityIndicator](ActivityIndicator.md) | 70 | 28 ✅ · 1 ☑️ · 36 ✓ · 3 – | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 54 ✅ · 1 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 3 – | 44 ✅ · 21 ✓ · 4 – | 46 ✅ · 20 ✓ |
| [Button](Button.md) | 88 | 42 ✅ · 1 ☑️ · 37 ✓ · 1 – | 44 ✅ · 37 ✓ · 3 – | 60 ✅ · 1 ☑️ · 10 ✓ · 4 – | 74 ✅ · 12 ✓ | 57 ✅ · 28 ✓ · 1 – | 56 ✅ · 20 ✓ |
| [Canvas](Canvas.md) | 72 | 29 ✅ · 1 ☑️ · 38 ✓ · 3 – | 29 ✅ · 1 ☑️ · 38 ✓ · 3 – | 56 ✅ · 1 ☑️ · 10 ✓ · 3 – | 54 ✅ · 13 ✓ · 3 – | 46 ✅ · 21 ✓ · 4 – | 48 ✅ · 20 ✓ |
| [CheckBox](CheckBox.md) | 71 | 34 ✅ · 1 ☑️ · 35 ✓ | 29 ✅ · 1 ☑️ · 36 ✓ · 3 – | 55 ✅ · 1 ☑️ · 10 ✓ · 3 – | 59 ✅ · 12 ✓ | 47 ✅ · 22 ✓ · 1 – | 47 ✅ · 20 ✓ |
| [ColorBox](ColorBox.md) | 70 | 30 ✅ · 35 ✓ · 3 – | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 53 ✅ · 1 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 3 – | 44 ✅ · 21 ✓ · 4 – | 46 ✅ · 20 ✓ |
| [DatePicker](DatePicker.md) | 82 | 38 ✅ · 1 ☑️ · 36 ✓ · 1 – | 32 ✅ · 35 ✓ · 4 – | 60 ✅ · 1 ☑️ · 13 ✓ · 3 – | 66 ✅ · 1 ☑️ · 12 ✓ | 54 ✅ · 1 ☑️ · 23 ✓ · 1 – | 51 ✅ · 20 ✓ |
| [Ellipse](Ellipse.md) | 78 | 28 ✅ · 1 ☑️ · 35 ✓ · 3 – | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 57 ✅ · 1 ☑️ · 10 ✓ · 3 – | 60 ✅ · 13 ✓ · 3 – | 47 ✅ · 21 ✓ · 4 – | 54 ✅ · 20 ✓ |
| [Grid](Grid.md) | 79 | 35 ✅ · 35 ✓ · 3 – | 37 ✅ · 35 ✓ · 3 – | 58 ✅ · 1 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 3 – | 49 ✅ · 21 ✓ · 4 – | 55 ✅ · 20 ✓ |
| [HStack](HStack.md) | 76 | 32 ✅ · 35 ✓ · 3 – | 34 ✅ · 35 ✓ · 3 – | 55 ✅ · 1 ☑️ · 10 ✓ · 3 – | 58 ✅ · 13 ✓ · 3 – | 46 ✅ · 21 ✓ · 4 – | 52 ✅ · 20 ✓ |
| [Image](Image.md) | 71 | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 53 ✅ · 1 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 3 – | 44 ✅ · 21 ✓ · 4 – | 45 ✅ · 20 ✓ |
| [ItemsView](ItemsView.md) | 78 | 36 ✅ · 1 ☑️ · 39 ✓ | 33 ✅ · 1 ☑️ · 39 ✓ · 3 – | 63 ✅ · 1 ☑️ · 11 ✓ | 64 ✅ · 12 ✓ | 54 ✅ · 21 ✓ · 1 – | 52 ✅ · 21 ✓ |
| [Line](Line.md) | 82 | 32 ✅ · 1 ☑️ · 35 ✓ · 3 – | 34 ✅ · 1 ☑️ · 35 ✓ · 3 – | 61 ✅ · 1 ☑️ · 10 ✓ · 3 – | 64 ✅ · 13 ✓ · 3 – | 51 ✅ · 21 ✓ · 4 – | 58 ✅ · 20 ✓ |
| [Map](Map.md) | 76 | 35 ✅ · 1 ☑️ · 36 ✓ · 3 – | 35 ✅ · 1 ☑️ · 36 ✓ · 3 – | 76 🧩 | 76 🧩 | 76 🧩 | 76 🧩 |
| [Path](Path.md) | 79 | 29 ✅ · 1 ☑️ · 35 ✓ · 3 – | 31 ✅ · 1 ☑️ · 35 ✓ · 3 – | 58 ✅ · 1 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 3 – | 48 ✅ · 21 ✓ · 4 – | 55 ✅ · 20 ✓ |
| [Picker](Picker.md) | 84 | 40 ✅ · 1 ☑️ · 36 ✓ · 1 – | 29 ✅ · 1 ☑️ · 38 ✓ · 3 – | 55 ✅ · 1 ☑️ · 11 ✓ · 3 – | 68 ✅ · 12 ✓ | 52 ✅ · 21 ✓ · 7 – | 49 ✅ · 20 ✓ |
| [Polygon](Polygon.md) | 80 | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 32 ✅ · 1 ☑️ · 35 ✓ · 3 – | 59 ✅ · 1 ☑️ · 10 ✓ · 3 – | 62 ✅ · 13 ✓ · 3 – | 49 ✅ · 21 ✓ · 4 – | 56 ✅ · 20 ✓ |
| [Polyline](Polyline.md) | 80 | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 32 ✅ · 1 ☑️ · 35 ✓ · 3 – | 59 ✅ · 1 ☑️ · 10 ✓ · 3 – | 62 ✅ · 13 ✓ · 3 – | 49 ✅ · 21 ✓ · 4 – | 56 ✅ · 20 ✓ |
| [ProgressBar](ProgressBar.md) | 70 | 29 ✅ · 1 ☑️ · 35 ✓ · 3 – | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 54 ✅ · 1 ☑️ · 10 ✓ · 3 – | 54 ✅ · 12 ✓ · 3 – | 43 ✅ · 22 ✓ · 4 – | 46 ✅ · 20 ✓ |
| [RadioButton](RadioButton.md) | 83 | 40 ✅ · 1 ☑️ · 35 ✓ · 1 – | 37 ✅ · 1 ☑️ · 36 ✓ · 3 – | 61 ✅ · 1 ☑️ · 10 ✓ · 3 – | 66 ✅ · 12 ✓ | 54 ✅ · 22 ✓ · 1 – | 51 ✅ · 20 ✓ |
| [Rectangle](Rectangle.md) | 79 | 29 ✅ · 1 ☑️ · 35 ✓ · 3 – | 31 ✅ · 1 ☑️ · 35 ✓ · 3 – | 58 ✅ · 1 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 3 – | 48 ✅ · 21 ✓ · 4 – | 55 ✅ · 20 ✓ |
| [ScrollView](ScrollView.md) | 79 | 35 ✅ · 2 ☑️ · 37 ✓ · 3 – | 37 ✅ · 35 ✓ · 3 – | 55 ✅ · 1 ☑️ · 10 ✓ · 3 – | 63 ✅ · 13 ✓ · 3 – | 53 ✅ · 21 ✓ · 1 – | 56 ✅ · 20 ✓ |
| [SearchField](SearchField.md) | 91 | 43 ✅ · 36 ✓ · 3 – | 49 ✅ · 1 ☑️ · 35 ✓ | 72 ✅ · 1 ☑️ · 10 ✓ · 1 – | 67 ✅ · 1 ☑️ · 12 ✓ | 62 ✅ · 22 ✓ · 1 – | 61 ✅ · 20 ✓ |
| [Slider](Slider.md) | 75 | 36 ✅ · 1 ☑️ · 35 ✓ | 33 ✅ · 1 ☑️ · 37 ✓ · 3 – | 57 ✅ · 1 ☑️ · 10 ✓ · 3 – | 60 ✅ · 12 ✓ | 49 ✅ · 22 ✓ · 3 – | 49 ✅ · 20 ✓ |
| [Stepper](Stepper.md) | 73 | 33 ✅ · 1 ☑️ · 35 ✓ | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 52 ✅ · 1 ☑️ · 10 ✓ · 3 – | 60 ✅ · 12 ✓ | 50 ✅ · 21 ✓ · 1 – | 49 ✅ · 20 ✓ |
| [Switch](Switch.md) | 71 | 33 ✅ · 1 ☑️ · 35 ✓ | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 54 ✅ · 1 ☑️ · 10 ✓ · 3 – | 59 ✅ · 12 ✓ | 47 ✅ · 22 ✓ · 1 – | 47 ✅ · 20 ✓ |
| [Text](Text.md) | 83 | 41 ✅ · 1 ☑️ · 35 ✓ · 4 – | 42 ✅ · 35 ✓ · 3 – | 64 ✅ · 1 ☑️ · 10 ✓ · 3 – | 67 ✅ · 12 ✓ · 3 – | 55 ✅ · 23 ✓ · 4 – | 59 ✅ · 20 ✓ |
| [TextEditor](TextEditor.md) | 89 | 48 ✅ · 1 ☑️ · 36 ✓ · 1 – | 49 ✅ · 1 ☑️ · 35 ✓ | 71 ✅ · 1 ☑️ · 10 ✓ · 1 – | 73 ✅ · 12 ✓ | 61 ✅ · 1 ☑️ · 22 ✓ · 1 – | 62 ✅ · 20 ✓ |
| [TextField](TextField.md) | 92 | 44 ✅ · 1 ☑️ · 36 ✓ · 3 – | 51 ✅ · 1 ☑️ · 35 ✓ | 73 ✅ · 1 ☑️ · 10 ✓ · 2 – | 72 ✅ · 1 ☑️ · 12 ✓ | 63 ✅ · 22 ✓ · 1 – | 64 ✅ · 20 ✓ |
| [TimePicker](TimePicker.md) | 80 | 36 ✅ · 1 ☑️ · 36 ✓ · 1 – | 33 ✅ · 35 ✓ · 1 – | 60 ✅ · 1 ☑️ · 11 ✓ · 3 – | 61 ✅ · 12 ✓ | 53 ✅ · 22 ✓ · 1 – | 49 ✅ · 20 ✓ |
| [VStack](VStack.md) | 76 | 32 ✅ · 35 ✓ · 3 – | 34 ✅ · 35 ✓ · 3 – | 55 ✅ · 1 ☑️ · 10 ✓ · 3 – | 58 ✅ · 13 ✓ · 3 – | 46 ✅ · 21 ✓ · 4 – | 52 ✅ · 20 ✓ |
| [WebView](WebView.md) | 79 | 41 ✅ · 1 ☑️ · 36 ✓ | 41 ✅ · 1 ☑️ · 36 ✓ | 63 ✅ · 1 ☑️ · 10 ✓ · 3 – | 46 ✅ · 13 ✓ · 19 – | 56 ✅ · 21 ✓ · 1 – | 52 ✅ · 20 ✓ |
| [ZStack](ZStack.md) | 75 | 31 ✅ · 35 ✓ · 3 – | 33 ✅ · 35 ✓ · 3 – | 54 ✅ · 1 ☑️ · 10 ✓ · 3 – | 57 ✅ · 13 ✓ · 3 – | 45 ✅ · 21 ✓ · 4 – | 51 ✅ · 20 ✓ |
| ✅ |  | 1109 | 1111 | 1819 | 1893 | 1566 | 1629 |
| ✓ |  | 1140 | 1138 | 316 | 388 | 671 | 621 |
| – |  | 67 | 83 | 86 | 70 | 87 | 0 |
| **Met** | 2511 | **2316** | **2332** | **2221** | **2351** | **2324** | **2250** |
| 🧩 |  | 0 | 0 | 76 | 76 | 76 | 76 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 17 | 7 ✅ · 10 ✓ | 7 ✅ · 10 ✓ | 6 ✅ · 9 ✓ | 15 ✅ · 2 ✓ | 11 ✅ · 6 ✓ | 12 ✅ · 5 ✓ |
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
| [Window](Window.md) | 22 | 15 ✅ · 6 ✓ | 3 ✅ · 4 ✓ · 9 – | 2 ✅ · 4 ✓ | 22 ✅ | 8 ✅ · 6 ✓ · 8 – | 3 ✅ · 4 ✓ · 15 – |
| ✅ |  | 67 | 70 | 42 | 113 | 75 | 83 |
| ✓ |  | 20 | 17 | 15 | 2 | 12 | 9 |
| – |  | 1 | 18 | 13 | 0 | 27 | 20 |
| **Met** | 126 | **88** | **105** | **70** | **115** | **114** | **112** |
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
