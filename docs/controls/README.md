# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with how far each target host realizes it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer colour on a label and a path fill on a border.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet.

A host's column is what that host declares it realizes - AppKit's `AppKitRealization` and MAUI's `MauiRealization`, each in its host's sources - and a realization records itself there in the same change. A row has one Notes cell for every host: AppKit's note as written, then each other host's as `MAUI: …`, joined by `; `. Nothing on a page is written by hand: `ControlDictionaryTests` fails when a page or a table below differs from the contracts and the declarations, or when a declaration names what no contract declares, and `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes them again.

## Controls

The elements a layout positions - every one wears [View](tiers/View.md).

<!-- controls:begin -->
| Control | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [AbsoluteLayout](AbsoluteLayout.md) | 72 | 69 ✅ | 53 ✅ · 2 ✅* |  |  |  |  |  |
| [ActivityIndicator](ActivityIndicator.md) | 70 | 67 ✅ | 52 ✅ · 2 ✅* |  |  |  |  |  |
| [Border](Border.md) | 77 | 74 ✅ | 56 ✅ · 2 ✅* |  |  |  |  |  |
| [Button](Button.md) | 88 | 84 ✅ | 67 ✅ · 3 ✅* |  |  |  |  |  |
| [Canvas](Canvas.md) | 72 | 69 ✅ | 56 ✅ · 2 ✅* |  |  |  |  |  |
| [CheckBox](CheckBox.md) | 71 | 68 ✅ | 55 ✅ · 2 ✅* |  |  |  |  |  |
| [ColorBox](ColorBox.md) | 70 | 67 ✅ | 54 ✅ · 2 ✅* |  |  |  |  |  |
| [DatePicker](DatePicker.md) | 82 | 79 ✅ | 60 ✅ · 2 ✅* |  |  |  |  |  |
| [Ellipse](Ellipse.md) | 78 | 75 ✅ | 59 ✅ · 3 ✅* |  |  |  |  |  |
| [Grid](Grid.md) | 76 | 73 ✅ | 58 ✅ · 2 ✅* |  |  |  |  |  |
| [HStack](HStack.md) | 73 | 70 ✅ | 55 ✅ · 2 ✅* |  |  |  |  |  |
| [Image](Image.md) | 71 | 68 ✅ | 55 ✅ · 2 ✅* |  |  |  |  |  |
| [Label](Label.md) | 83 | 80 ✅ | 66 ✅ · 2 ✅* |  |  |  |  |  |
| [Line](Line.md) | 82 | 79 ✅ | 65 ✅ · 3 ✅* |  |  |  |  |  |
| [Map](Map.md) | 76 | 65 ✅ · 6 ✅* |  |  |  |  |  |  |
| [Path](Path.md) | 79 | 76 ✅ | 62 ✅ · 3 ✅* |  |  |  |  |  |
| [Picker](Picker.md) | 84 | 81 ✅ | 65 ✅ · 2 ✅* |  |  |  |  |  |
| [Polygon](Polygon.md) | 80 | 77 ✅ | 63 ✅ · 3 ✅* |  |  |  |  |  |
| [Polyline](Polyline.md) | 80 | 77 ✅ | 63 ✅ · 3 ✅* |  |  |  |  |  |
| [PositionIndicator](PositionIndicator.md) | 76 | 73 ✅ |  |  |  |  |  |  |
| [ProgressBar](ProgressBar.md) | 70 | 67 ✅ | 52 ✅ · 2 ✅* |  |  |  |  |  |
| [RadioButton](RadioButton.md) | 83 | 80 ✅ | 62 ✅ · 2 ✅* |  |  |  |  |  |
| [Rectangle](Rectangle.md) | 79 | 76 ✅ | 60 ✅ · 3 ✅* |  |  |  |  |  |
| [RefreshView](RefreshView.md) | 73 | 70 ✅ |  |  |  |  |  |  |
| [ScrollView](ScrollView.md) | 76 | 72 ✅ | 59 ✅ · 2 ✅* |  |  |  |  |  |
| [SearchField](SearchField.md) | 91 | 88 ✅ | 68 ✅ · 2 ✅* |  |  |  |  |  |
| [Slider](Slider.md) | 75 | 72 ✅ | 59 ✅ · 2 ✅* |  |  |  |  |  |
| [Stepper](Stepper.md) | 73 | 70 ✅ | 57 ✅ · 2 ✅* |  |  |  |  |  |
| [SwipeView](SwipeView.md) | 72 | 69 ✅ |  |  |  |  |  |  |
| [Switch](Switch.md) | 71 | 68 ✅ | 54 ✅ · 2 ✅* |  |  |  |  |  |
| [TextEditor](TextEditor.md) | 89 | 86 ✅ | 68 ✅ · 2 ✅* |  |  |  |  |  |
| [TextField](TextField.md) | 92 | 89 ✅ | 69 ✅ · 2 ✅* |  |  |  |  |  |
| [TimePicker](TimePicker.md) | 80 | 77 ✅ | 58 ✅ · 2 ✅* |  |  |  |  |  |
| [TitleBar](TitleBar.md) | 72 | 69 ✅ | 4 ✅ · 1 ✅* |  |  |  |  |  |
| [VStack](VStack.md) | 73 | 70 ✅ | 55 ✅ · 2 ✅* |  |  |  |  |  |
| [WebView](WebView.md) | 79 | 72 ✅ |  |  |  |  |  |  |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | MAUI | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 12 | 5 ✅ | 3 ✅ |  |  |  |  |  |
| [Content](Content.md) | 0 |  |  |  |  |  |  |  |
| [ContextMenu](ContextMenu.md) | 0 |  |  |  |  |  |  |  |
| [LeadingContent](LeadingContent.md) | 0 |  |  |  |  |  |  |  |
| [Menu](Menu.md) | 2 | 2 ✅ | 2 ✅ |  |  |  |  |  |
| [MenuBar](MenuBar.md) | 0 |  |  |  |  |  |  |  |
| [MenuItem](MenuItem.md) | 6 | 5 ✅ | 5 ✅ · 1 ✅* |  |  |  |  |  |
| [MenuSeparator](MenuSeparator.md) | 0 |  |  |  |  |  |  |  |
| [ModalStack](ModalStack.md) | 0 |  |  |  |  |  |  |  |
| [NavigationStack](NavigationStack.md) | 6 | 5 ✅ | 6 ✅ |  |  |  |  |  |
| [Overlay](Overlay.md) | 0 |  |  |  |  |  |  |  |
| [Page](Page.md) | 12 | 12 ✅ | 12 ✅ |  |  |  |  |  |
| [Pin](Pin.md) | 6 | 0 ✅ · 6 ✅* |  |  |  |  |  |  |
| [Scene](Scene.md) | 6 | 6 ✅ | 6 ✅ |  |  |  |  |  |
| [Setters](Setters.md) | 0 |  |  |  |  |  |  |  |
| [Span](Span.md) | 12 | 11 ✅ | 3 ✅ |  |  |  |  |  |
| [Spans](Spans.md) | 0 |  |  |  |  |  |  |  |
| [SplitView](SplitView.md) | 5 | 4 ✅ | 5 ✅ |  |  |  |  |  |
| [SwipeAction](SwipeAction.md) | 8 | 7 ✅ |  |  |  |  |  |  |
| [SwipeActions](SwipeActions.md) | 3 | 3 ✅ |  |  |  |  |  |  |
| [TabbedView](TabbedView.md) | 6 | 5 ✅ | 6 ✅ |  |  |  |  |  |
| [TitleView](TitleView.md) | 0 |  |  |  |  |  |  |  |
| [ToolbarItem](ToolbarItem.md) | 8 | 8 ✅ | 6 ✅ |  |  |  |  |  |
| [ToolbarItems](ToolbarItems.md) | 0 |  |  |  |  |  |  |  |
| [TrailingContent](TrailingContent.md) | 0 |  |  |  |  |  |  |  |
| [VisualState](VisualState.md) | 2 | 2 ✅ |  |  |  |  |  |  |
| [Window](Window.md) | 23 | 20 ✅ · 1 ✅* | 23 ✅ |  |  |  |  |  |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [PropertyContainer](tiers/PropertyContainer.md) - What anything carrying values in the tree has - a control, a `Style`, a text run: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.
- [StackBase](tiers/StackBase.md) - What both stacks have: the space between their children.
- [InputView](tiers/InputView.md) - What every field a reader types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.
- [TextElement](tiers/TextElement.md) - What every element showing words has: the words, and the case they are drawn in.
- [TextStyleElement](tiers/TextStyleElement.md) - How text looks wherever it is drawn: its colour and the space between its letters.
- [FontElement](tiers/FontElement.md) - The font text is drawn in: its family, its size, its weight and slant, and whether it follows the reader's text-size setting.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where text sits inside the space its own element was given.
- [LineHeightElement](tiers/LineHeightElement.md) - How far apart the lines of text are.
- [DecorableTextElement](tiers/DecorableTextElement.md) - The lines drawn through or under text.
- [PaddingElement](tiers/PaddingElement.md) - The space kept inside an element, around what it holds.
- [BorderElement](tiers/BorderElement.md) - The line around a control's own box, and how round its corners are.
- [ImageElement](tiers/ImageElement.md) - How a picture fills the room it was given.
- [TintElement](tiers/TintElement.md) - A control's one accent colour.
- [BarElement](tiers/BarElement.md) - The bar a page arrangement draws: its colour.
- [MenuItemElement](tiers/MenuItemElement.md) - What every item a reader chooses from has - a menu's entry, a toolbar's item, a swipe's action: a caption, a picture, and something to run.
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
