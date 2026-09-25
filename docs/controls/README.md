# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with how far each target host realizes it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer colour on a label and a drawn fill on an outlined layout.

Marks: ✅ realized by that host and covered by its tests · ☑️ realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet.

A host's column comes from its runtime wherever it can: each host's suite writes what its registry realizes to `exports/` - `appkit.txt`, and `android.txt` from the Android suite on a device - read here and joined with the contracts, so each member is named under the contract declaring it and no owner is written by hand. A member a tier declares is marked on the tier only where the host realizes it on every element it registers that wears the tier; otherwise it is marked on those elements alone. What a registry cannot know stays declared in the host's sources (`AppKitRealization`, `AndroidRealization`) - every judgement: what a realization is missing, what a host realizes none of, and what it presents with no view of its own. A written note about a tier's member holds on every element wearing the tier. A row has one Notes cell for every host: AppKit's note as written, then each other host's as `Android Views: …`, joined by `; `. Nothing on a page is written by hand: `ControlDictionaryTests` fails when a page or a table below differs from the contracts and the declarations, or when a declaration names what no contract declares, and `STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes them again.

## Controls

The elements a layout positions - every one wears [View](tiers/View.md).

<!-- controls:begin -->
| Control | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [ActivityIndicator](ActivityIndicator.md) | 68 | 54 ✅ · 2 ☑️ |  | 47 ✅ | 54 ✅ · 1 ☑️ | 52 ✅ |  |
| [Button](Button.md) | 86 | 66 ✅ · 5 ☑️ |  | 58 ✅ | 70 ✅ · 2 ☑️ | 65 ✅ |  |
| [Canvas](Canvas.md) | 70 | 56 ✅ · 2 ☑️ |  |  | 56 ✅ · 1 ☑️ | 54 ✅ |  |
| [CheckBox](CheckBox.md) | 69 | 56 ✅ · 2 ☑️ |  | 48 ✅ | 56 ✅ · 1 ☑️ | 55 ✅ |  |
| [ColorBox](ColorBox.md) | 68 | 54 ✅ · 2 ☑️ |  | 47 ✅ | 54 ✅ · 1 ☑️ | 52 ✅ |  |
| [DatePicker](DatePicker.md) | 80 | 61 ✅ · 2 ☑️ |  |  | 65 ✅ · 1 ☑️ | 62 ✅ · 1 ☑️ |  |
| [Ellipse](Ellipse.md) | 76 | 61 ✅ · 3 ☑️ |  | 55 ✅ | 62 ✅ · 1 ☑️ | 60 ✅ |  |
| [Grid](Grid.md) | 77 | 62 ✅ · 2 ☑️ |  | 57 ✅ | 62 ✅ · 1 ☑️ | 61 ✅ |  |
| [HStack](HStack.md) | 74 | 59 ✅ · 2 ☑️ |  | 54 ✅ | 59 ✅ · 1 ☑️ | 58 ✅ |  |
| [Image](Image.md) | 69 | 55 ✅ · 2 ☑️ |  | 47 ✅ | 54 ✅ · 1 ☑️ | 52 ✅ |  |
| [Label](Label.md) | 81 | 66 ✅ · 2 ☑️ |  | 58 ✅ | 66 ✅ · 1 ☑️ | 63 ✅ |  |
| [Line](Line.md) | 80 | 65 ✅ · 3 ☑️ |  | 59 ✅ | 66 ✅ · 1 ☑️ | 64 ✅ |  |
| [Map](Map.md) | 74 |  |  |  |  |  |  |
| [Path](Path.md) | 77 | 62 ✅ · 3 ☑️ |  | 56 ✅ | 63 ✅ · 1 ☑️ | 61 ✅ |  |
| [Picker](Picker.md) | 82 | 66 ✅ · 2 ☑️ |  | 49 ✅ | 65 ✅ · 2 ☑️ | 64 ✅ |  |
| [Polygon](Polygon.md) | 78 | 63 ✅ · 3 ☑️ |  | 57 ✅ | 64 ✅ · 1 ☑️ | 62 ✅ |  |
| [Polyline](Polyline.md) | 78 | 63 ✅ · 3 ☑️ |  | 57 ✅ | 64 ✅ · 1 ☑️ | 62 ✅ |  |
| [PositionIndicator](PositionIndicator.md) | 74 |  |  |  |  |  |  |
| [ProgressBar](ProgressBar.md) | 68 | 54 ✅ · 2 ☑️ |  | 47 ✅ | 54 ✅ · 1 ☑️ | 52 ✅ |  |
| [RadioButton](RadioButton.md) | 81 | 63 ✅ · 2 ☑️ |  | 56 ✅ | 63 ✅ · 1 ☑️ | 62 ✅ |  |
| [Rectangle](Rectangle.md) | 77 | 62 ✅ · 3 ☑️ |  | 56 ✅ | 63 ✅ · 1 ☑️ | 61 ✅ |  |
| [ScrollView](ScrollView.md) | 77 | 62 ✅ · 3 ☑️ |  | 57 ✅ | 63 ✅ · 1 ☑️ | 62 ✅ |  |
| [SearchField](SearchField.md) | 89 | 70 ✅ · 2 ☑️ |  |  | 66 ✅ · 1 ☑️ | 60 ✅ |  |
| [Slider](Slider.md) | 73 | 60 ✅ · 2 ☑️ |  | 50 ✅ | 60 ✅ · 1 ☑️ | 56 ✅ |  |
| [Stepper](Stepper.md) | 71 | 58 ✅ · 2 ☑️ |  | 51 ✅ | 58 ✅ · 1 ☑️ | 56 ✅ |  |
| [Switch](Switch.md) | 69 | 56 ✅ · 2 ☑️ |  | 48 ✅ | 55 ✅ · 1 ☑️ | 55 ✅ |  |
| [TextEditor](TextEditor.md) | 87 | 69 ✅ · 2 ☑️ |  |  | 65 ✅ · 1 ☑️ | 68 ✅ |  |
| [TextField](TextField.md) | 90 | 70 ✅ · 2 ☑️ |  | 51 ✅ | 67 ✅ · 1 ☑️ | 68 ✅ |  |
| [TimePicker](TimePicker.md) | 78 | 59 ✅ · 2 ☑️ |  |  | 63 ✅ · 1 ☑️ | 57 ✅ · 1 ☑️ |  |
| [TitleBar](TitleBar.md) | 70 | 4 ✅ · 1 ☑️ |  | 47 ✅ |  |  |  |
| [VStack](VStack.md) | 74 | 59 ✅ · 2 ☑️ |  | 54 ✅ | 59 ✅ · 1 ☑️ | 58 ✅ |  |
| [WebView](WebView.md) | 77 |  |  |  | 63 ✅ · 1 ☑️ |  |  |
| [ZStack](ZStack.md) | 73 | 58 ✅ · 2 ☑️ |  | 53 ✅ | 58 ✅ · 1 ☑️ | 57 ✅ |  |
| **Met** - ✅ and – | 2515 | 1773 of 2515 met |  | 1319 of 2515 met | 1837 of 2515 met | 1719 of 2515 met |  |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 12 | 3 ✅ |  | 11 ✅ | 11 ✅ | 11 ✅ |  |
| [Content](Content.md) | 0 |  |  |  |  |  |  |
| [ContextMenu](ContextMenu.md) | 0 |  |  |  |  |  |  |
| [LeadingContent](LeadingContent.md) | 0 |  |  |  |  |  |  |
| [Menu](Menu.md) | 2 | 2 ✅ |  |  | 2 ✅ | 2 ✅ |  |
| [MenuBar](MenuBar.md) | 0 |  |  |  |  |  |  |
| [MenuItem](MenuItem.md) | 6 | 5 ✅ · 1 ☑️ |  |  | 5 ✅ | 4 ✅ |  |
| [MenuSeparator](MenuSeparator.md) | 0 |  |  |  |  |  |  |
| [ModalStack](ModalStack.md) | 0 |  |  |  |  |  |  |
| [NavigationStack](NavigationStack.md) | 6 | 6 ✅ |  | 1 ✅ | 6 ✅ | 2 ✅ |  |
| [Overlay](Overlay.md) | 0 |  |  |  |  |  |  |
| [Page](Page.md) | 12 | 12 ✅ |  | 7 ✅ | 11 ✅ | 7 ✅ |  |
| [Pin](Pin.md) | 6 |  |  |  |  |  |  |
| [Scene](Scene.md) | 6 | 6 ✅ |  |  | 4 ✅ |  |  |
| [Span](Span.md) | 12 | 3 ✅ |  | 6 ✅ | 2 ✅ | 6 ✅ |  |
| [Spans](Spans.md) | 0 |  |  |  |  |  |  |
| [SplitView](SplitView.md) | 5 | 5 ✅ |  | 2 ✅ | 4 ✅ | 3 ✅ |  |
| [TabbedView](TabbedView.md) | 6 | 6 ✅ |  | 2 ✅ | 5 ✅ | 3 ✅ |  |
| [TitleView](TitleView.md) | 0 |  |  |  |  |  |  |
| [ToolbarItem](ToolbarItem.md) | 8 | 7 ✅ |  | 6 ✅ | 8 ✅ | 6 ✅ |  |
| [ToolbarItems](ToolbarItems.md) | 0 |  |  |  |  |  |  |
| [TrailingContent](TrailingContent.md) | 0 |  |  |  |  |  |  |
| [Window](Window.md) | 23 | 23 ✅ |  |  | 8 ✅ | 1 ✅ |  |
| **Met** - ✅ and – | 104 | 78 of 104 met |  | 35 of 104 met | 66 of 104 met | 45 of 104 met |  |
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
