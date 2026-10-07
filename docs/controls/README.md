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
| [ActivityIndicator](ActivityIndicator.md) | 70 | 28 ✅ · 2 ☑️ · 36 ✓ · 3 – | 30 ✅ · 2 ☑️ · 35 ✓ · 3 – | 54 ✅ · 2 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 4 – | 43 ✅ · 1 ☑️ · 22 ✓ · 4 – | 46 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Button](Button.md) | 88 | 43 ✅ · 2 ☑️ · 37 ✓ · 1 – | 45 ✅ · 1 ☑️ · 37 ✓ · 3 – | 61 ✅ · 2 ☑️ · 10 ✓ · 4 – | 75 ✅ · 12 ✓ | 56 ✅ · 1 ☑️ · 28 ✓ · 1 – | 59 ✅ · 1 ☑️ · 20 ✓ |
| [Canvas](Canvas.md) | 72 | 29 ✅ · 2 ☑️ · 38 ✓ · 3 – | 29 ✅ · 2 ☑️ · 38 ✓ · 3 – | 56 ✅ · 2 ☑️ · 10 ✓ · 3 – | 54 ✅ · 14 ✓ · 3 – | 45 ✅ · 1 ☑️ · 22 ✓ · 4 – | 48 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 71 | 34 ✅ · 2 ☑️ · 35 ✓ | 30 ✅ · 2 ☑️ · 36 ✓ · 3 – | 55 ✅ · 2 ☑️ · 10 ✓ · 3 – | 59 ✅ · 12 ✓ | 46 ✅ · 1 ☑️ · 23 ✓ · 1 – | 50 ✅ · 1 ☑️ · 20 ✓ |
| [ColorBox](ColorBox.md) | 70 | 30 ✅ · 1 ☑️ · 35 ✓ · 3 – | 30 ✅ · 2 ☑️ · 35 ✓ · 3 – | 54 ✅ · 2 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 4 – | 43 ✅ · 1 ☑️ · 22 ✓ · 4 – | 46 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [DatePicker](DatePicker.md) | 82 | 38 ✅ · 2 ☑️ · 36 ✓ · 1 – | 32 ✅ · 1 ☑️ · 35 ✓ · 8 – | 60 ✅ · 2 ☑️ · 13 ✓ · 3 – | 67 ✅ · 1 ☑️ · 12 ✓ | 53 ✅ · 2 ☑️ · 24 ✓ · 1 – | 54 ✅ · 1 ☑️ · 20 ✓ |
| [Ellipse](Ellipse.md) | 78 | 36 ✅ · 2 ☑️ · 35 ✓ · 5 – | 38 ✅ · 2 ☑️ · 35 ✓ · 3 – | 60 ✅ · 2 ☑️ · 10 ✓ · 5 – | 60 ✅ · 13 ✓ · 4 – | 49 ✅ · 1 ☑️ · 22 ✓ · 6 – | 54 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Grid](Grid.md) | 79 | 38 ✅ · 1 ☑️ · 35 ✓ · 3 – | 38 ✅ · 1 ☑️ · 35 ✓ · 3 – | 61 ✅ · 2 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 3 – | 52 ✅ · 1 ☑️ · 21 ✓ · 4 – | 54 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [HStack](HStack.md) | 76 | 35 ✅ · 1 ☑️ · 35 ✓ · 3 – | 35 ✅ · 1 ☑️ · 35 ✓ · 3 – | 58 ✅ · 2 ☑️ · 10 ✓ · 3 – | 58 ✅ · 13 ✓ · 3 – | 49 ✅ · 1 ☑️ · 21 ✓ · 4 – | 51 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Image](Image.md) | 71 | 30 ✅ · 2 ☑️ · 35 ✓ · 3 – | 30 ✅ · 2 ☑️ · 35 ✓ · 3 – | 53 ✅ · 2 ☑️ · 10 ✓ · 3 – | 52 ✅ · 13 ✓ · 4 – | 43 ✅ · 1 ☑️ · 22 ✓ · 4 – | 45 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 78 | 36 ✅ · 2 ☑️ · 39 ✓ | 33 ✅ · 2 ☑️ · 39 ✓ · 3 – | 63 ✅ · 2 ☑️ · 11 ✓ | 65 ✅ · 12 ✓ | 53 ✅ · 1 ☑️ · 21 ✓ · 1 – | 55 ✅ · 1 ☑️ · 21 ✓ |
| [Line](Line.md) | 82 | 40 ✅ · 2 ☑️ · 35 ✓ · 5 – | 42 ✅ · 2 ☑️ · 35 ✓ · 3 – | 64 ✅ · 2 ☑️ · 10 ✓ · 5 – | 64 ✅ · 13 ✓ · 4 – | 53 ✅ · 1 ☑️ · 22 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Map](Map.md) | 76 | 35 ✅ · 2 ☑️ · 36 ✓ · 3 – | 35 ✅ · 2 ☑️ · 36 ✓ · 3 – | 76 🧩 | 76 🧩 | 76 🧩 | 76 🧩 |
| [Path](Path.md) | 79 | 39 ✅ · 2 ☑️ · 35 ✓ · 3 – | 39 ✅ · 2 ☑️ · 35 ✓ · 3 – | 63 ✅ · 2 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 4 – | 52 ✅ · 1 ☑️ · 22 ✓ · 4 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Picker](Picker.md) | 84 | 40 ✅ · 2 ☑️ · 36 ✓ · 1 – | 35 ✅ · 2 ☑️ · 38 ✓ · 3 – | 60 ✅ · 2 ☑️ · 11 ✓ · 3 – | 69 ✅ · 12 ✓ | 51 ✅ · 1 ☑️ · 22 ✓ · 7 – | 52 ✅ · 1 ☑️ · 20 ✓ |
| [Polygon](Polygon.md) | 80 | 40 ✅ · 2 ☑️ · 35 ✓ · 3 – | 40 ✅ · 2 ☑️ · 35 ✓ · 3 – | 64 ✅ · 2 ☑️ · 10 ✓ · 3 – | 62 ✅ · 13 ✓ · 4 – | 53 ✅ · 1 ☑️ · 22 ✓ · 4 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Polyline](Polyline.md) | 80 | 40 ✅ · 2 ☑️ · 35 ✓ · 3 – | 40 ✅ · 2 ☑️ · 35 ✓ · 3 – | 64 ✅ · 2 ☑️ · 10 ✓ · 3 – | 62 ✅ · 13 ✓ · 4 – | 53 ✅ · 1 ☑️ · 22 ✓ · 4 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 70 | 29 ✅ · 2 ☑️ · 35 ✓ · 3 – | 30 ✅ · 2 ☑️ · 35 ✓ · 3 – | 54 ✅ · 2 ☑️ · 10 ✓ · 3 – | 54 ✅ · 12 ✓ · 4 – | 42 ✅ · 1 ☑️ · 23 ✓ · 4 – | 46 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [RadioButton](RadioButton.md) | 83 | 40 ✅ · 2 ☑️ · 35 ✓ · 1 – | 37 ✅ · 2 ☑️ · 36 ✓ · 3 – | 61 ✅ · 2 ☑️ · 10 ✓ · 3 – | 66 ✅ · 12 ✓ | 53 ✅ · 1 ☑️ · 23 ✓ · 1 – | 54 ✅ · 1 ☑️ · 20 ✓ |
| [Rectangle](Rectangle.md) | 79 | 39 ✅ · 2 ☑️ · 35 ✓ · 3 – | 39 ✅ · 2 ☑️ · 35 ✓ · 3 – | 63 ✅ · 2 ☑️ · 10 ✓ · 3 – | 61 ✅ · 13 ✓ · 4 – | 52 ✅ · 1 ☑️ · 22 ✓ · 4 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 79 | 35 ✅ · 3 ☑️ · 37 ✓ · 3 – | 38 ✅ · 1 ☑️ · 35 ✓ · 3 – | 63 ✅ · 2 ☑️ · 10 ✓ · 3 – | 63 ✅ · 13 ✓ · 3 – | 56 ✅ · 1 ☑️ · 21 ✓ · 1 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [SearchField](SearchField.md) | 91 | 45 ✅ · 1 ☑️ · 36 ✓ · 3 – | 50 ✅ · 2 ☑️ · 35 ✓ | 72 ✅ · 2 ☑️ · 10 ✓ · 1 – | 68 ✅ · 1 ☑️ · 12 ✓ · 1 – | 61 ✅ · 1 ☑️ · 23 ✓ · 2 – | 64 ✅ · 1 ☑️ · 20 ✓ |
| [Slider](Slider.md) | 75 | 36 ✅ · 2 ☑️ · 35 ✓ | 33 ✅ · 2 ☑️ · 37 ✓ · 3 – | 59 ✅ · 2 ☑️ · 10 ✓ · 3 – | 61 ✅ · 12 ✓ | 48 ✅ · 1 ☑️ · 23 ✓ · 3 – | 52 ✅ · 20 ✓ · 1 – |
| [Stepper](Stepper.md) | 73 | 36 ✅ · 2 ☑️ · 35 ✓ | 33 ✅ · 2 ☑️ · 35 ✓ · 3 – | 57 ✅ · 2 ☑️ · 10 ✓ · 3 – | 61 ✅ · 12 ✓ | 49 ✅ · 1 ☑️ · 22 ✓ · 1 – | 52 ✅ · 1 ☑️ · 20 ✓ |
| [Switch](Switch.md) | 71 | 33 ✅ · 2 ☑️ · 35 ✓ | 31 ✅ · 2 ☑️ · 35 ✓ · 3 – | 54 ✅ · 2 ☑️ · 10 ✓ · 3 – | 59 ✅ · 12 ✓ | 46 ✅ · 1 ☑️ · 22 ✓ · 2 – | 50 ✅ · 1 ☑️ · 20 ✓ |
| [Text](Text.md) | 83 | 41 ✅ · 2 ☑️ · 35 ✓ · 4 – | 42 ✅ · 1 ☑️ · 35 ✓ · 3 – | 65 ✅ · 2 ☑️ · 10 ✓ · 3 – | 67 ✅ · 12 ✓ · 3 – | 54 ✅ · 1 ☑️ · 23 ✓ · 4 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 89 | 48 ✅ · 2 ☑️ · 36 ✓ · 1 – | 49 ✅ · 2 ☑️ · 35 ✓ | 71 ✅ · 2 ☑️ · 10 ✓ · 1 – | 74 ✅ · 12 ✓ | 60 ✅ · 2 ☑️ · 23 ✓ · 1 – | 65 ✅ · 1 ☑️ · 20 ✓ |
| [TextField](TextField.md) | 92 | 46 ✅ · 2 ☑️ · 36 ✓ · 3 – | 52 ✅ · 2 ☑️ · 35 ✓ | 73 ✅ · 2 ☑️ · 10 ✓ · 2 – | 73 ✅ · 1 ☑️ · 12 ✓ · 1 – | 62 ✅ · 1 ☑️ · 23 ✓ · 3 – | 67 ✅ · 1 ☑️ · 20 ✓ |
| [TimePicker](TimePicker.md) | 80 | 36 ✅ · 2 ☑️ · 36 ✓ · 1 – | 33 ✅ · 1 ☑️ · 35 ✓ · 5 – | 60 ✅ · 2 ☑️ · 11 ✓ · 3 – | 62 ✅ · 12 ✓ | 52 ✅ · 1 ☑️ · 23 ✓ · 1 – | 52 ✅ · 1 ☑️ · 20 ✓ |
| [VStack](VStack.md) | 76 | 35 ✅ · 1 ☑️ · 35 ✓ · 3 – | 35 ✅ · 1 ☑️ · 35 ✓ · 3 – | 58 ✅ · 2 ☑️ · 10 ✓ · 3 – | 58 ✅ · 13 ✓ · 3 – | 49 ✅ · 1 ☑️ · 21 ✓ · 4 – | 51 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [WebView](WebView.md) | 79 | 41 ✅ · 2 ☑️ · 36 ✓ | 41 ✅ · 2 ☑️ · 36 ✓ | 63 ✅ · 2 ☑️ · 10 ✓ · 3 – | 46 ✅ · 13 ✓ · 19 – | 55 ✅ · 1 ☑️ · 22 ✓ · 1 – | 52 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ZStack](ZStack.md) | 75 | 34 ✅ · 1 ☑️ · 35 ✓ · 3 – | 34 ✅ · 1 ☑️ · 35 ✓ · 3 – | 57 ✅ · 2 ☑️ · 10 ✓ · 3 – | 57 ✅ · 13 ✓ · 3 – | 48 ✅ · 1 ☑️ · 21 ✓ · 4 – | 50 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| ✅ |  | 1185 | 1178 | 1880 | 1903 | 1581 | 1662 |
| ✓ |  | 1140 | 1138 | 316 | 389 | 693 | 621 |
| – |  | 71 | 91 | 90 | 82 | 95 | 55 |
| **Met** | 2511 | **2396** | **2407** | **2286** | **2374** | **2369** | **2338** |
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
| [MenuItem](MenuItem.md) | 6 | 4 ✅ · 1 ☑️ | 6 ✅ | 4 ✅ · 2 – | 6 ✅ | 3 ✅ · 3 – | 6 ✅ |
| [ModalStack](ModalStack.md) | 6 | 4 ✅ | 4 ✅ · 2 – | 3 ✅ · 1 ☑️ · 2 – | 6 ✅ | 4 ✅ · 2 – | 5 ✅ · 1 – |
| [NavigationStack](NavigationStack.md) | 9 | 5 ✅ · 1 ✓ | 7 ✅ · 2 – | 6 ✅ · 1 ☑️ · 2 – | 9 ✅ | 5 ✅ · 4 – | 7 ✅ · 1 – |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 11 | 8 ✅ | 11 ✅ | 10 ✅ · 1 – | 10 ✅ · 1 – | 8 ✅ · 2 – | 9 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [SplitView](SplitView.md) | 10 | 7 ✅ | 8 ✅ · 2 – | 5 ✅ · 1 ☑️ · 2 ✓ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TabView](TabView.md) | 10 | 6 ✅ · 1 ✓ | 8 ✅ · 2 – | 7 ✅ · 1 ☑️ · 2 – | 10 ✅ | 6 ✅ · 4 – | 8 ✅ · 1 – |
| [TextSpan](TextSpan.md) | 12 | 9 ✅ | 9 ✅ | 7 ✅ · 1 – | 9 ✅ | 9 ✅ | 9 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](ToolbarItem.md) | 8 | 3 ✅ · 1 ✓ · 1 – | 7 ✅ · 1 – | 5 ✅ · 1 – | 8 ✅ | 7 ✅ · 1 – | 8 ✅ |
| [ToolbarItemGroup](ToolbarItemGroup.md) | 2 | 2 ✅ | 2 ✅ | 1 ✅ · 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [Window](Window.md) | 22 | 15 ✅ · 6 ✓ | 3 ✅ · 4 ✓ · 9 – | 3 ✅ · 4 ✓ · 13 – | 22 ✅ | 8 ✅ · 6 ✓ · 8 – | 3 ✅ · 4 ✓ · 15 – |
| ✅ |  | 82 | 80 | 63 | 114 | 76 | 83 |
| ✓ |  | 20 | 17 | 15 | 2 | 12 | 9 |
| – |  | 1 | 18 | 27 | 1 | 28 | 20 |
| **Met** | 126 | **103** | **115** | **105** | **117** | **116** | **112** |
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
