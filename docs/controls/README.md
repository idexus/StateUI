# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with what each target host's tests proved of it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer colour on a label and a drawn fill on an outlined layout.

<!-- legend:begin -->
| Mark | Meaning |
| :---: | --- |
| ✅ | Proven by every test of it that ran on that host. |
| ☑️ | Proven, the host recording what is missing. |
| – | Never on that host's family, which meets the contract there. |
| 🧩 | Left to the application, which registers its own control for it with that host. |
| ❌ | A test of it failed. |
| ◐ | Some of its tests proved it, another could not run or read. |
| 🔌 | Proven only through the host's own entry or record, not the toolkit's. |
| · | The driver cannot yet do or read what its test needs. |
| ⏸ | Its test waits on a member the host does not realize. |
| ⌛ | Said at another revision of its family than it stands at. |
| empty | Not realized, or no run - the note says which. |
<!-- legend:end -->

A host's column is its tests' verdicts: each host's suite runs the conformance families - one for each contract, a case for every cell of every page - and writes what each said under `exports/marks/<host>/`, one line a member of an element, read here. A host's register - its records, what its runtime registers, what it never has - decides whether a case runs and what its verdict says, and nothing it declares marks a cell by itself. A tier's member is marked on every element wearing the tier, each by its own case. A row has one Notes cell for every host: AppKit's note as written, then each other host's as `Android Views: …`, joined by `; `. Nothing on a page is written by hand: `ControlDictionaryTests` fails when a page or a table below differs from the contracts and the verdicts, or when a verdict names what no contract declares, and `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes them again.

## Controls

The elements a layout positions - every one wears [View](tiers/View.md).

<!-- controls:begin -->
| Control | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](ActivityIndicator.md) | 68 | 25 ✅ · 1 ☑️ · 3 – | 26 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 – | 41 ✅ · 4 – |  |
| [Button](Button.md) | 86 | 40 ✅ · 1 ☑️ | 41 ✅ · 3 – | 59 ✅ · 1 ☑️ · 3 – | 71 ✅ | 54 ✅ · 1 – |  |
| [Canvas](Canvas.md) | 70 | 26 ✅ · 1 ☑️ · 3 – | 25 ✅ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 52 ✅ · 3 – | 43 ✅ · 4 – |  |
| [CheckBox](CheckBox.md) | 69 | 32 ✅ · 1 ☑️ | 26 ✅ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 56 ✅ | 44 ✅ · 1 – |  |
| [ColorBox](ColorBox.md) | 68 | 27 ✅ · 3 – | 26 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 – | 41 ✅ · 4 – |  |
| [DatePicker](DatePicker.md) | 80 | 36 ✅ · 1 ☑️ | 29 ✅ · 3 – | 58 ✅ · 1 ☑️ · 3 – | 63 ✅ · 1 ☑️ | 45 ✅ · 1 – |  |
| [Ellipse](Ellipse.md) | 76 | 25 ✅ · 1 ☑️ · 3 – | 26 ✅ · 3 – | 49 ✅ · 1 ☑️ · 3 – | 58 ✅ · 3 – | 44 ✅ · 4 – |  |
| [Grid](Grid.md) | 77 | 32 ✅ · 3 – | 34 ✅ · 3 – | 55 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 – | 47 ✅ · 4 – |  |
| [HStack](HStack.md) | 74 | 29 ✅ · 3 – | 31 ✅ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 56 ✅ · 3 – | 44 ✅ · 4 – |  |
| [Image](Image.md) | 69 | 27 ✅ · 1 ☑️ · 3 – | 26 ✅ · 3 – | 50 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 – | 41 ✅ · 4 – |  |
| [ItemsView](ItemsView.md) | 76 | 33 ✅ · 1 ☑️ | 29 ✅ · 3 – | 60 ✅ · 1 ☑️ | 60 ✅ | 51 ✅ · 1 – |  |
| [Label](Label.md) | 81 | 38 ✅ · 1 ☑️ · 3 – | 39 ✅ · 3 – | 61 ✅ · 1 ☑️ · 3 – | 63 ✅ · 3 – | 52 ✅ · 4 – |  |
| [Line](Line.md) | 80 | 29 ✅ · 1 ☑️ · 3 – | 30 ✅ · 3 – | 53 ✅ · 1 ☑️ · 3 – | 62 ✅ · 3 – | 48 ✅ · 4 – |  |
| [Map](Map.md) | 74 |  |  | 74 🧩 | 74 🧩 | 74 🧩 |  |
| [Path](Path.md) | 77 | 26 ✅ · 1 ☑️ · 3 – | 27 ✅ · 3 – | 50 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 – | 45 ✅ · 4 – |  |
| [Picker](Picker.md) | 82 | 38 ✅ · 1 ☑️ | 25 ✅ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 65 ✅ | 49 ✅ · 7 – |  |
| [Polygon](Polygon.md) | 78 | 27 ✅ · 1 ☑️ · 3 – | 28 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 60 ✅ · 3 – | 46 ✅ · 4 – |  |
| [Polyline](Polyline.md) | 78 | 27 ✅ · 1 ☑️ · 3 – | 28 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 60 ✅ · 3 – | 46 ✅ · 4 – |  |
| [ProgressBar](ProgressBar.md) | 68 | 26 ✅ · 1 ☑️ · 3 – | 26 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 50 ✅ · 3 – | 40 ✅ · 4 – |  |
| [RadioButton](RadioButton.md) | 81 | 38 ✅ · 1 ☑️ | 34 ✅ · 3 – | 59 ✅ · 1 ☑️ · 3 – | 63 ✅ | 51 ✅ · 1 – |  |
| [Rectangle](Rectangle.md) | 77 | 26 ✅ · 1 ☑️ · 3 – | 27 ✅ · 3 – | 50 ✅ · 1 ☑️ · 3 – | 59 ✅ · 3 – | 45 ✅ · 4 – |  |
| [ScrollView](ScrollView.md) | 77 | 32 ✅ · 2 ☑️ · 3 – | 33 ✅ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 60 ✅ · 3 – | 50 ✅ · 1 – |  |
| [SearchField](SearchField.md) | 89 | 41 ✅ · 1 – | 45 ✅ | 65 ✅ · 1 ☑️ · 1 – | 64 ✅ · 1 ☑️ | 59 ✅ · 1 – |  |
| [Slider](Slider.md) | 73 | 34 ✅ · 1 ☑️ | 30 ✅ · 3 – | 55 ✅ · 1 ☑️ · 3 – | 57 ✅ | 46 ✅ · 3 – |  |
| [Stepper](Stepper.md) | 71 | 31 ✅ · 1 ☑️ | 27 ✅ · 3 – | 50 ✅ · 1 ☑️ · 3 – | 57 ✅ | 47 ✅ · 1 – |  |
| [Switch](Switch.md) | 69 | 31 ✅ · 1 ☑️ | 27 ✅ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 56 ✅ | 44 ✅ · 1 – |  |
| [TextEditor](TextEditor.md) | 87 | 46 ✅ · 1 ☑️ | 46 ✅ | 65 ✅ · 1 ☑️ · 1 – | 70 ✅ | 59 ✅ · 1 – |  |
| [TextField](TextField.md) | 90 | 42 ✅ · 1 ☑️ | 46 ✅ | 66 ✅ · 1 ☑️ · 1 – | 69 ✅ · 1 ☑️ | 60 ✅ · 1 – |  |
| [TimePicker](TimePicker.md) | 78 | 34 ✅ · 1 ☑️ | 30 ✅ | 58 ✅ · 1 ☑️ · 3 – | 58 ✅ | 45 ✅ · 1 – |  |
| [VStack](VStack.md) | 74 | 29 ✅ · 3 – | 31 ✅ · 3 – | 52 ✅ · 1 ☑️ · 3 – | 56 ✅ · 3 – | 44 ✅ · 4 – |  |
| [WebView](WebView.md) | 77 |  | 11 ✅ | 10 ✅ | 20 ✅ · 15 – | 52 ✅ · 1 – |  |
| [ZStack](ZStack.md) | 73 | 28 ✅ · 3 – | 30 ✅ · 3 – | 51 ✅ · 1 ☑️ · 3 – | 55 ✅ · 3 – | 43 ✅ · 4 – |  |
| **Met** - ✅, – and 🧩 | 2447 | 1007 of 2447 met | 1017 of 2447 met | 1800 of 2447 met | 1928 of 2447 met | 1627 of 2447 met |  |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 12 | 7 ✅ | 6 ✅ | 4 ✅ | 12 ✅ | 11 ✅ |  |
| [ContextMenu](ContextMenu.md) | 0 |  |  |  |  |  |  |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ |  |
| [MenuBar](MenuBar.md) | 1 |  |  | 1 ✅ | 1 ✅ | 1 ✅ |  |
| [MenuItem](MenuItem.md) | 6 | 3 ✅ · 1 ☑️ | 6 ✅ | 4 ✅ · 2 – | 6 ✅ | 3 ✅ · 3 – |  |
| [MenuSeparator](MenuSeparator.md) | 0 |  |  |  |  |  |  |
| [ModalStack](ModalStack.md) | 7 | 4 ✅ | 4 ✅ · 2 – | 3 ✅ · 2 – | 6 ✅ | 4 ✅ · 3 – |  |
| [NavigationStack](NavigationStack.md) | 9 | 4 ✅ | 7 ✅ · 2 – | 3 ✅ · 2 – | 9 ✅ | 5 ✅ · 4 – |  |
| [Overlay](Overlay.md) | 0 |  |  |  |  |  |  |
| [Page](Page.md) | 12 | 7 ✅ | 11 ✅ | 7 ✅ | 10 ✅ | 8 ✅ · 1 – |  |
| [Pin](Pin.md) | 6 |  |  | 6 🧩 | 6 🧩 | 6 🧩 |  |
| [Scene](Scene.md) | 6 | 6 ✅ | 4 ✅ | 4 ✅ | 6 ✅ | 6 ✅ |  |
| [Span](Span.md) | 12 |  |  |  | 9 ✅ | 9 ✅ |  |
| [Spans](Spans.md) | 0 |  |  |  |  |  |  |
| [SplitView](SplitView.md) | 10 | 6 ✅ | 8 ✅ · 2 – | 3 ✅ · 2 – | 10 ✅ | 6 ✅ · 4 – |  |
| [TabbedView](TabbedView.md) | 10 | 5 ✅ | 8 ✅ · 2 – | 3 ✅ · 2 – | 10 ✅ | 6 ✅ · 4 – |  |
| [TitleView](TitleView.md) | 0 |  |  |  |  |  |  |
| [ToolbarItem](ToolbarItem.md) | 8 | 2 ✅ | 6 ✅ | 4 ✅ · 1 – | 8 ✅ | 7 ✅ · 1 – |  |
| [ToolbarItems](ToolbarItems.md) | 2 | 2 ✅ | 2 ✅ | 1 – | 2 ✅ | 2 ✅ |  |
| [Window](Window.md) | 22 | 15 ✅ | 3 ✅ | 2 ✅ | 22 ✅ | 8 ✅ · 8 – |  |
| **Met** - ✅, – and 🧩 | 125 | 63 of 125 met | 74 of 125 met | 58 of 125 met | 119 of 125 met | 112 of 125 met |  |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [PropertyContainer](tiers/PropertyContainer.md) - What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.
- [StackBase](tiers/StackBase.md) - What both stacks have: the space between their children.
- [InputView](tiers/InputView.md) - What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.
- [TextElement](tiers/TextElement.md) - What every element showing words has: the words, and the case they are drawn in.
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
