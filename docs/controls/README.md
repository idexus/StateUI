# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with what each target host's tests proved of it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer colour on a label and a drawn fill on an outlined layout.

Marks: ✅ proven on that host by its own passing test · ☑️ proven by its test, but the host records what is missing - the note says what · – never on that host's family, which meets the contract there - its register says why · empty: not proven on that host yet - the note says why where its run said.

A host's column is its tests' verdicts: each host's suite runs the conformance families - one for each contract, a case for every cell of every page - and writes what each said under `exports/marks/<host>/`, one line a member of an element, read here. A host's register - its records, what its runtime registers, what it never has - decides whether a case runs and what its verdict says, and nothing it declares marks a cell by itself. A tier's member is marked on every element wearing the tier, each by its own case. A row has one Notes cell for every host: AppKit's note as written, then each other host's as `Android Views: …`, joined by `; `. Nothing on a page is written by hand: `ControlDictionaryTests` fails when a page or a table below differs from the contracts and the verdicts, or when a verdict names what no contract declares, and `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes them again.

## Controls

The elements a layout positions - every one wears [View](tiers/View.md).

<!-- controls:begin -->
| Control | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](ActivityIndicator.md) | 68 |  |  | 14 ✅ |  | 52 ✅ |  |
| [Button](Button.md) | 86 |  |  | 16 ✅ |  | 65 ✅ |  |
| [Canvas](Canvas.md) | 70 |  |  |  |  | 54 ✅ |  |
| [CheckBox](CheckBox.md) | 69 |  |  | 15 ✅ |  | 55 ✅ |  |
| [ColorBox](ColorBox.md) | 68 |  |  | 13 ✅ |  | 52 ✅ |  |
| [DatePicker](DatePicker.md) | 80 |  |  |  |  | 62 ✅ · 1 ☑️ |  |
| [Ellipse](Ellipse.md) | 76 |  |  | 13 ✅ |  | 60 ✅ |  |
| [Grid](Grid.md) | 77 |  |  | 13 ✅ |  | 61 ✅ |  |
| [HStack](HStack.md) | 74 |  |  | 13 ✅ |  | 58 ✅ |  |
| [Image](Image.md) | 69 |  |  | 13 ✅ |  | 52 ✅ |  |
| [Label](Label.md) | 81 |  |  | 15 ✅ |  | 63 ✅ |  |
| [Line](Line.md) | 80 |  |  | 13 ✅ |  | 64 ✅ |  |
| [Map](Map.md) | 74 |  |  |  |  |  |  |
| [Path](Path.md) | 77 |  |  | 13 ✅ |  | 61 ✅ |  |
| [Picker](Picker.md) | 82 |  |  | 16 ✅ |  | 64 ✅ |  |
| [Polygon](Polygon.md) | 78 |  |  | 13 ✅ |  | 62 ✅ |  |
| [Polyline](Polyline.md) | 78 |  |  | 13 ✅ |  | 62 ✅ |  |
| [PositionIndicator](PositionIndicator.md) | 74 |  |  |  |  |  |  |
| [ProgressBar](ProgressBar.md) | 68 |  |  | 14 ✅ |  | 52 ✅ |  |
| [RadioButton](RadioButton.md) | 81 |  |  | 18 ✅ |  | 62 ✅ |  |
| [Rectangle](Rectangle.md) | 77 |  |  | 13 ✅ |  | 61 ✅ |  |
| [ScrollView](ScrollView.md) | 77 |  |  | 13 ✅ |  | 62 ✅ |  |
| [SearchField](SearchField.md) | 89 |  |  | 16 ✅ |  | 60 ✅ |  |
| [Slider](Slider.md) | 73 |  |  | 17 ✅ |  | 56 ✅ |  |
| [Stepper](Stepper.md) | 71 |  |  | 18 ✅ |  | 56 ✅ |  |
| [Switch](Switch.md) | 69 |  |  | 15 ✅ |  | 55 ✅ |  |
| [TextEditor](TextEditor.md) | 87 |  |  | 16 ✅ |  | 68 ✅ |  |
| [TextField](TextField.md) | 90 |  |  | 17 ✅ |  | 67 ✅ |  |
| [TimePicker](TimePicker.md) | 78 |  |  |  |  | 57 ✅ |  |
| [TitleBar](TitleBar.md) | 70 |  |  |  |  |  |  |
| [VStack](VStack.md) | 74 |  |  | 13 ✅ |  | 58 ✅ |  |
| [WebView](WebView.md) | 77 |  |  |  |  |  |  |
| [ZStack](ZStack.md) | 73 |  |  | 13 ✅ |  | 57 ✅ |  |
| **Met** - ✅ and – | 2515 |  |  | 376 of 2515 met |  | 1718 of 2515 met |  |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 12 |  |  |  |  | 11 ✅ |  |
| [Content](Content.md) | 0 |  |  |  |  |  |  |
| [ContextMenu](ContextMenu.md) | 0 |  |  |  |  |  |  |
| [LeadingContent](LeadingContent.md) | 0 |  |  |  |  |  |  |
| [Menu](Menu.md) | 2 |  |  |  |  | 2 ✅ |  |
| [MenuBar](MenuBar.md) | 0 |  |  |  |  |  |  |
| [MenuItem](MenuItem.md) | 6 |  |  |  |  | 4 ✅ |  |
| [MenuSeparator](MenuSeparator.md) | 0 |  |  |  |  |  |  |
| [ModalStack](ModalStack.md) | 0 |  |  |  |  |  |  |
| [NavigationStack](NavigationStack.md) | 6 |  |  |  |  | 3 ✅ |  |
| [Overlay](Overlay.md) | 0 |  |  |  |  |  |  |
| [Page](Page.md) | 12 |  |  |  |  | 9 ✅ |  |
| [Pin](Pin.md) | 6 |  |  |  |  |  |  |
| [Scene](Scene.md) | 6 |  |  |  |  | 3 ✅ |  |
| [Span](Span.md) | 12 |  |  |  |  | 6 ✅ |  |
| [Spans](Spans.md) | 0 |  |  |  |  |  |  |
| [SplitView](SplitView.md) | 5 |  |  |  |  | 4 ✅ |  |
| [TabbedView](TabbedView.md) | 6 |  |  |  |  | 4 ✅ |  |
| [TitleView](TitleView.md) | 0 |  |  |  |  |  |  |
| [ToolbarItem](ToolbarItem.md) | 8 |  |  |  |  | 6 ✅ |  |
| [ToolbarItems](ToolbarItems.md) | 0 |  |  |  |  |  |  |
| [TrailingContent](TrailingContent.md) | 0 |  |  |  |  |  |  |
| [Window](Window.md) | 23 |  |  |  |  | 5 ✅ |  |
| **Met** - ✅ and – | 104 |  |  |  |  | 57 of 104 met |  |
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
- [BarElement](tiers/BarElement.md) - The bar a page arrangement draws: its colour.
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
