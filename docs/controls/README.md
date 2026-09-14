# Control dictionary

Every control StateUI ships, and every part an application, its windows and its pages are made of, member by member, with how far each target host realizes it.

An entry's file opens with the members it declares itself, then one section per protocol it inherits, each linking that protocol's file. Every property and handler carries a mark for each platform, because a host realizes the same inherited member differently on different controls - a background is a layer colour on a label and a path fill on a border.

Marks: ✅ realized by that host and covered by its tests · ✅* realized and tested, but incomplete - the note says what is missing · empty: absent, partial and unverified, or not looked at yet.

A host's column is what that host declares it realizes - AppKit's is `AppKitRealization`, in its sources - and a realization records itself there in the same change. `ControlDictionaryTests` fails when a file's members differ from the code, when a ✅* has no note, or when a file is missing; `AppKitRealizationTests` fails when the AppKit column differs from the records. `python3 .scripts/controls-dictionary.py` rewrites the member lists and the columns, keeping every realization line already written.

## Controls

| Control | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Label](Label.md) | 78 | 34 ✅ · 2 ✅* |  |  |  |  |  |
| [Button](Button.md) | 83 | 32 ✅ · 2 ✅* |  |  |  |  |  |
| [TextField](TextField.md) | 87 | 37 ✅ · 2 ✅* |  |  |  |  |  |
| [TextEditor](TextEditor.md) | 84 | 36 ✅ · 2 ✅* |  |  |  |  |  |
| [SearchField](SearchField.md) | 86 | 36 ✅ · 2 ✅* |  |  |  |  |  |
| [Image](Image.md) | 65 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Picker](Picker.md) | 79 | 28 ✅ · 2 ✅* |  |  |  |  |  |
| [DatePicker](DatePicker.md) | 77 | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [TimePicker](TimePicker.md) | 75 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Switch](Switch.md) | 66 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [CheckBox](CheckBox.md) | 66 | 23 ✅ · 2 ✅* |  |  |  |  |  |
| [RadioButton](RadioButton.md) | 78 | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [Slider](Slider.md) | 70 | 27 ✅ · 2 ✅* |  |  |  |  |  |
| [Stepper](Stepper.md) | 68 | 25 ✅ · 2 ✅* |  |  |  |  |  |
| [ActivityIndicator](ActivityIndicator.md) | 65 | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [ProgressBar](ProgressBar.md) | 65 | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [ColorBox](ColorBox.md) | 65 | 22 ✅ · 1 ✅* |  |  |  |  |  |
| [Border](Border.md) | 72 | 21 ✅ · 1 ✅* |  |  |  |  |  |
| [PositionIndicator](PositionIndicator.md) | 71 |  |  |  |  |  |  |
| [VStack](VStack.md) | 68 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [HStack](HStack.md) | 68 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Grid](Grid.md) | 71 | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [AbsoluteLayout](AbsoluteLayout.md) | 67 | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [ScrollView](ScrollView.md) | 73 | 29 ✅ · 2 ✅* |  |  |  |  |  |
| [RefreshView](RefreshView.md) | 67 |  |  |  |  |  |  |
| [SwipeView](SwipeView.md) | 68 |  |  |  |  |  |  |
| [Map](Map.md) | 75 |  |  |  |  |  |  |
| [WebView](WebView.md) | 70 |  |  |  |  |  |  |
| [TitleBar](TitleBar.md) | 66 | 23 ✅ · 2 ✅* |  |  |  |  |  |
| [Canvas](Canvas.md) | 64 | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [Rectangle](Rectangle.md) | 74 | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [Ellipse](Ellipse.md) | 73 | 20 ✅ · 2 ✅* |  |  |  |  |  |
| [Line](Line.md) | 77 | 24 ✅ · 2 ✅* |  |  |  |  |  |
| [Path](Path.md) | 74 | 21 ✅ · 2 ✅* |  |  |  |  |  |
| [Polygon](Polygon.md) | 75 | 22 ✅ · 2 ✅* |  |  |  |  |  |
| [Polyline](Polyline.md) | 75 | 22 ✅ · 2 ✅* |  |  |  |  |  |

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, and the entries of a page's toolbar and menus.

| Part | Members | AppKit | UIKit | GTK 4 | Android Views | WinUI 3 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Scene](Scene.md) | 6 | 6 ✅ |  |  |  |  |  |
| [Window](Window.md) | 22 | 22 ✅ |  |  |  |  |  |
| [Page](Page.md) | 12 | 12 ✅ |  |  |  |  |  |
| [NavigationStack](NavigationStack.md) | 6 | 3 ✅ |  |  |  |  |  |
| [TabbedView](TabbedView.md) | 6 | 3 ✅ |  |  |  |  |  |
| [SplitView](SplitView.md) | 4 | 1 ✅ |  |  |  |  |  |
| [ToolbarItem](ToolbarItem.md) | 8 | 7 ✅ |  |  |  |  |  |
| [Menu](Menu.md) | 1 |  |  |  |  |  |  |
| [MenuItem](MenuItem.md) | 6 | 5 ✅ |  |  |  |  |  |

## Tiers

- [BarElement](tiers/BarElement.md) - The bar over a stack or a set of tabs.
- [BorderElement](tiers/BorderElement.md) - The outline of a control that draws one - the tier `Button` and `RadioButton` wear, and the one place the three properties that paint an outline are declared.
- [DecorableTextElement](tiers/DecorableTextElement.md) - A line under the text, through it, or both - the tier `Label` and `TextSpan` both wear.
- [FontElement](tiers/FontElement.md) - How the text of a control is set in type - its size, its family, its weight.
- [ImageElement](tiers/ImageElement.md) - The artwork half shared by `Image` and `Button`.
- [InputView](tiers/InputView.md) - A View the reader types into.
- [Layout](tiers/Layout.md) - A view that arranges children.
- [LineHeightElement](tiers/LineHeightElement.md) - The height of a text line, relative to the font's own - the tier `Label` and `TextSpan` both wear.
- [MenuItemElement](tiers/MenuItemElement.md) - What a toolbar item, a menu entry and a swipe action all share: `text`, `icon`, `isDestructive`, `isEnabled` - and `onClicked`, what choosing one does.
- [PaddingElement](tiers/PaddingElement.md) - The space a control keeps INSIDE itself, around its content.
- [PageElement](tiers/PageElement.md) - The identity shown for a constructed container page.
- [PropertyContainer](tiers/PropertyContainer.md) - Anything carrying property values, whether or not it is drawn - a control, a `Style`, a `TextSpan`.
- [Shape](tiers/Shape.md) - A drawn outline.
- [StackBase](tiers/StackBase.md) - A layout that stacks its children in one direction.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where a control's text sits INSIDE the control.
- [TextElement](tiers/TextElement.md) - The tier for a control whose text IS a property: everything `TextStyleElement` has, plus the text itself.
- [TextStyleElement](tiers/TextStyleElement.md) - The colour and letter spacing of a control's text, WITHOUT the text itself.
- [TintElement](tiers/TintElement.md) - A control's accent: the colour the platform draws what is chosen, filled or under way in - a switch that is on, the covered part of a slider, a ticked box, the filled part of a bar, a spinner.
- [View](tiers/View.md) - A VisualElement a layout positions.
- [VisualElement](tiers/VisualElement.md) - A control backed by a node, and drawn.
