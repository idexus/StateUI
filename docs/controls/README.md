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
| [ActivityIndicator](ActivityIndicator.md) | 68 | 29 ✅ · 2 ☑️ · 36 ✓ · 1 – | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 54 ✅ · 3 ☑️ · 10 ✓ | 52 ✅ · 1 ☑️ · 13 ✓ · 1 – | 44 ✅ · 1 ☑️ · 22 ✓ · 1 – | 47 ✅ · 1 ☑️ · 20 ✓ |
| [Button](Button.md) | 97 | 54 ✅ · 2 ☑️ · 37 ✓ · 2 – | 52 ✅ · 1 ☑️ · 39 ✓ · 4 – | 70 ✅ · 3 ☑️ · 14 ✓ · 4 – | 84 ✅ · 1 ☑️ · 12 ✓ | 68 ✅ · 2 ☑️ · 26 ✓ · 1 – | 76 ✅ · 1 ☑️ · 20 ✓ |
| [Canvas](Canvas.md) | 70 | 30 ✅ · 2 ☑️ · 38 ✓ | 29 ✅ · 2 ☑️ · 38 ✓ · 1 – | 56 ✅ · 3 ☑️ · 10 ✓ | 55 ✅ · 14 ✓ | 46 ✅ · 1 ☑️ · 22 ✓ · 1 – | 49 ✅ · 1 ☑️ · 20 ✓ |
| [Capsule](Capsule.md) | 74 | 36 ✅ · 2 ☑️ · 35 ✓ | 35 ✅ · 2 ☑️ · 35 ✓ · 1 – | 59 ✅ · 3 ☑️ · 10 ✓ | 59 ✅ · 13 ✓ · 1 – | 50 ✅ · 1 ☑️ · 22 ✓ | 52 ✅ · 1 ☑️ · 20 ✓ |
| [CheckBox](CheckBox.md) | 74 | 37 ✅ · 2 ☑️ · 35 ✓ | 30 ✅ · 2 ☑️ · 38 ✓ · 4 – | 55 ✅ · 3 ☑️ · 12 ✓ · 3 – | 61 ✅ · 1 ☑️ · 12 ✓ | 47 ✅ · 1 ☑️ · 25 ✓ · 1 – | 53 ✅ · 1 ☑️ · 20 ✓ |
| [DatePicker](DatePicker.md) | 86 | 43 ✅ · 2 ☑️ · 36 ✓ · 5 – | 32 ✅ · 1 ☑️ · 37 ✓ · 12 – | 63 ✅ · 3 ☑️ · 15 ✓ · 3 – | 71 ✅ · 3 ☑️ · 12 ✓ | 57 ✅ · 2 ☑️ · 26 ✓ · 1 – | 60 ✅ · 1 ☑️ · 20 ✓ · 4 – |
| [Divider](Divider.md) | 66 | 29 ✅ · 2 ☑️ · 35 ✓ | 28 ✅ · 2 ☑️ · 35 ✓ · 1 – | 52 ✅ · 3 ☑️ · 10 ✓ | 51 ✅ · 1 ☑️ · 13 ✓ | 42 ✅ · 1 ☑️ · 22 ✓ · 1 – | 45 ✅ · 1 ☑️ · 20 ✓ |
| [Ellipse](Ellipse.md) | 74 | 37 ✅ · 2 ☑️ · 35 ✓ | 36 ✅ · 2 ☑️ · 35 ✓ · 1 – | 60 ✅ · 3 ☑️ · 10 ✓ | 60 ✅ · 13 ✓ · 1 – | 50 ✅ · 1 ☑️ · 22 ✓ · 1 – | 53 ✅ · 1 ☑️ · 20 ✓ |
| [Grid](Grid.md) | 79 | 41 ✅ · 1 ☑️ · 35 ✓ | 38 ✅ · 1 ☑️ · 37 ✓ · 1 – | 61 ✅ · 3 ☑️ · 12 ✓ | 64 ✅ · 1 ☑️ · 12 ✓ · 1 – | 53 ✅ · 1 ☑️ · 23 ✓ · 2 – | 57 ✅ · 1 ☑️ · 20 ✓ |
| [HStack](HStack.md) | 76 | 38 ✅ · 1 ☑️ · 35 ✓ | 35 ✅ · 1 ☑️ · 37 ✓ · 1 – | 58 ✅ · 3 ☑️ · 12 ✓ | 61 ✅ · 1 ☑️ · 12 ✓ · 1 – | 50 ✅ · 1 ☑️ · 23 ✓ · 2 – | 54 ✅ · 1 ☑️ · 20 ✓ |
| [Image](Image.md) | 69 | 31 ✅ · 2 ☑️ · 35 ✓ | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 53 ✅ · 3 ☑️ · 10 ✓ | 54 ✅ · 13 ✓ · 1 – | 44 ✅ · 1 ☑️ · 22 ✓ · 1 – | 47 ✅ · 1 ☑️ · 20 ✓ |
| [ItemsView](ItemsView.md) | 81 | 39 ✅ · 2 ☑️ · 39 ✓ | 33 ✅ · 2 ☑️ · 41 ✓ · 4 – | 63 ✅ · 3 ☑️ · 13 ✓ | 67 ✅ · 1 ☑️ · 12 ✓ | 54 ✅ · 1 ☑️ · 23 ✓ · 1 – | 58 ✅ · 1 ☑️ · 21 ✓ |
| [Line](Line.md) | 77 | 40 ✅ · 2 ☑️ · 35 ✓ | 39 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 3 ☑️ · 10 ✓ | 63 ✅ · 13 ✓ · 1 – | 53 ✅ · 1 ☑️ · 22 ✓ · 1 – | 56 ✅ · 1 ☑️ · 20 ✓ |
| [Map](Map.md) | 74 | 36 ✅ · 2 ☑️ · 36 ✓ | 35 ✅ · 2 ☑️ · 36 ✓ · 1 – | 74 🧩 | 74 🧩 | 74 🧩 | 74 🧩 |
| [Path](Path.md) | 77 | 40 ✅ · 2 ☑️ · 35 ✓ | 39 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 3 ☑️ · 10 ✓ | 63 ✅ · 13 ✓ · 1 – | 53 ✅ · 1 ☑️ · 22 ✓ · 1 – | 56 ✅ · 1 ☑️ · 20 ✓ |
| [Picker](Picker.md) | 88 | 46 ✅ · 2 ☑️ · 36 ✓ · 1 – | 38 ✅ · 3 ☑️ · 40 ✓ · 4 – | 63 ✅ · 4 ☑️ · 13 ✓ · 3 – | 75 ✅ · 1 ☑️ · 12 ✓ | 56 ✅ · 1 ☑️ · 24 ✓ · 7 – | 62 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Polygon](Polygon.md) | 78 | 41 ✅ · 2 ☑️ · 35 ✓ | 40 ✅ · 2 ☑️ · 35 ✓ · 1 – | 64 ✅ · 3 ☑️ · 10 ✓ | 64 ✅ · 13 ✓ · 1 – | 54 ✅ · 1 ☑️ · 22 ✓ · 1 – | 57 ✅ · 1 ☑️ · 20 ✓ |
| [Polyline](Polyline.md) | 78 | 41 ✅ · 2 ☑️ · 35 ✓ | 40 ✅ · 2 ☑️ · 35 ✓ · 1 – | 64 ✅ · 3 ☑️ · 10 ✓ | 64 ✅ · 13 ✓ · 1 – | 54 ✅ · 1 ☑️ · 22 ✓ · 1 – | 57 ✅ · 1 ☑️ · 20 ✓ |
| [ProgressBar](ProgressBar.md) | 68 | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 54 ✅ · 3 ☑️ · 10 ✓ | 55 ✅ · 12 ✓ · 1 – | 43 ✅ · 1 ☑️ · 23 ✓ · 1 – | 47 ✅ · 1 ☑️ · 20 ✓ |
| [RadioButton](RadioButton.md) | 84 | 45 ✅ · 2 ☑️ · 35 ✓ · 1 – | 40 ✅ · 2 ☑️ · 38 ✓ · 4 – | 64 ✅ · 3 ☑️ · 12 ✓ · 3 – | 71 ✅ · 1 ☑️ · 12 ✓ | 57 ✅ · 1 ☑️ · 25 ✓ · 1 – | 63 ✅ · 1 ☑️ · 20 ✓ |
| [Rectangle](Rectangle.md) | 77 | 40 ✅ · 2 ☑️ · 35 ✓ | 39 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 3 ☑️ · 10 ✓ | 63 ✅ · 13 ✓ · 1 – | 53 ✅ · 1 ☑️ · 22 ✓ · 1 – | 56 ✅ · 1 ☑️ · 20 ✓ |
| [ScrollView](ScrollView.md) | 82 | 39 ✅ · 3 ☑️ · 37 ✓ · 3 – | 38 ✅ · 1 ☑️ · 37 ✓ · 4 – | 63 ✅ · 3 ☑️ · 12 ✓ · 3 – | 66 ✅ · 1 ☑️ · 12 ✓ · 3 – | 57 ✅ · 1 ☑️ · 23 ✓ · 1 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [SearchField](SearchField.md) | 93 | 50 ✅ · 3 ☑️ · 36 ✓ · 1 – | 53 ✅ · 2 ☑️ · 37 ✓ · 1 – | 75 ✅ · 3 ☑️ · 12 ✓ · 1 – | 75 ✅ · 4 ☑️ · 12 ✓ · 2 – | 65 ✅ · 2 ☑️ · 25 ✓ · 1 – | 72 ✅ · 1 ☑️ · 20 ✓ |
| [Slider](Slider.md) | 78 | 39 ✅ · 2 ☑️ · 35 ✓ | 33 ✅ · 2 ☑️ · 39 ✓ · 4 – | 59 ✅ · 3 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 12 ✓ | 49 ✅ · 1 ☑️ · 25 ✓ · 3 – | 57 ✅ · 20 ✓ · 1 – |
| [Spacer](Spacer.md) | 66 | 29 ✅ · 2 ☑️ · 35 ✓ | 28 ✅ · 2 ☑️ · 35 ✓ · 1 – | 52 ✅ · 3 ☑️ · 10 ✓ | 51 ✅ · 1 ☑️ · 13 ✓ | 42 ✅ · 1 ☑️ · 22 ✓ · 1 – | 45 ✅ · 1 ☑️ · 20 ✓ |
| [Stepper](Stepper.md) | 76 | 39 ✅ · 2 ☑️ · 35 ✓ | 33 ✅ · 2 ☑️ · 37 ✓ · 4 – | 57 ✅ · 3 ☑️ · 12 ✓ · 3 – | 62 ✅ · 2 ☑️ · 12 ✓ | 50 ✅ · 1 ☑️ · 24 ✓ · 1 – | 55 ✅ · 1 ☑️ · 20 ✓ |
| [Switch](Switch.md) | 74 | 36 ✅ · 2 ☑️ · 35 ✓ · 1 – | 31 ✅ · 2 ☑️ · 37 ✓ · 4 – | 54 ✅ · 3 ☑️ · 12 ✓ · 3 – | 61 ✅ · 1 ☑️ · 12 ✓ | 47 ✅ · 1 ☑️ · 24 ✓ · 2 – | 53 ✅ · 1 ☑️ · 20 ✓ |
| [Text](Text.md) | 84 | 45 ✅ · 2 ☑️ · 35 ✓ · 1 – | 46 ✅ · 1 ☑️ · 35 ✓ · 1 – | 69 ✅ · 3 ☑️ · 10 ✓ | 71 ✅ · 1 ☑️ · 12 ✓ | 59 ✅ · 1 ☑️ · 23 ✓ · 1 – | 63 ✅ · 1 ☑️ · 20 ✓ |
| [TextEditor](TextEditor.md) | 92 | 53 ✅ · 2 ☑️ · 36 ✓ · 1 – | 52 ✅ · 2 ☑️ · 37 ✓ · 1 – | 74 ✅ · 3 ☑️ · 12 ✓ · 1 – | 79 ✅ · 1 ☑️ · 12 ✓ | 64 ✅ · 2 ☑️ · 25 ✓ · 1 – | 71 ✅ · 1 ☑️ · 20 ✓ |
| [TextField](TextField.md) | 95 | 51 ✅ · 3 ☑️ · 36 ✓ · 2 – | 55 ✅ · 2 ☑️ · 37 ✓ · 1 – | 76 ✅ · 3 ☑️ · 12 ✓ · 2 – | 79 ✅ · 3 ☑️ · 12 ✓ | 66 ✅ · 2 ☑️ · 25 ✓ · 2 – | 73 ✅ · 1 ☑️ · 20 ✓ |
| [TimePicker](TimePicker.md) | 84 | 41 ✅ · 2 ☑️ · 36 ✓ · 5 – | 33 ✅ · 1 ☑️ · 37 ✓ · 9 – | 63 ✅ · 3 ☑️ · 13 ✓ · 3 – | 66 ✅ · 2 ☑️ · 12 ✓ | 56 ✅ · 1 ☑️ · 25 ✓ · 1 – | 58 ✅ · 1 ☑️ · 20 ✓ · 4 – |
| [VStack](VStack.md) | 76 | 38 ✅ · 1 ☑️ · 35 ✓ | 36 ✅ · 1 ☑️ · 36 ✓ · 1 – | 59 ✅ · 3 ☑️ · 11 ✓ | 61 ✅ · 1 ☑️ · 12 ✓ · 1 – | 51 ✅ · 1 ☑️ · 22 ✓ · 2 – | 54 ✅ · 1 ☑️ · 20 ✓ |
| [WebView](WebView.md) | 82 | 44 ✅ · 2 ☑️ · 36 ✓ | 41 ✅ · 2 ☑️ · 38 ✓ · 1 – | 63 ✅ · 3 ☑️ · 12 ✓ · 3 – | 49 ✅ · 13 ✓ · 19 – | 56 ✅ · 1 ☑️ · 24 ✓ · 1 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ZStack](ZStack.md) | 75 | 37 ✅ · 1 ☑️ · 35 ✓ | 34 ✅ · 1 ☑️ · 37 ✓ · 1 – | 57 ✅ · 3 ☑️ · 12 ✓ | 60 ✅ · 1 ☑️ · 12 ✓ · 1 – | 49 ✅ · 1 ☑️ · 23 ✓ · 2 – | 53 ✅ · 1 ☑️ · 20 ✓ |
| ✅ |  | 1344 | 1261 | 2023 | 2100 | 1739 | 1872 |
| ✓ |  | 1210 | 1245 | 375 | 410 | 770 | 661 |
| – |  | 25 | 80 | 38 | 38 | 46 | 18 |
| **Met** | 2672 | **2579** | **2586** | **2436** | **2548** | **2555** | **2551** |
| 🧩 |  | 0 | 0 | 74 | 74 | 74 | 74 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Application](Application.md) | 18 | 8 ✅ · 10 ✓ | 8 ✅ · 10 ✓ | 7 ✅ · 1 ☑️ · 9 ✓ | 16 ✅ · 2 ✓ | 12 ✅ · 6 ✓ | 13 ✅ · 5 ✓ |
| [ButtonMenu](ButtonMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 9 | 8 ✅ · 1 ☑️ | 8 ✅ · 1 ☑️ | 7 ✅ · 2 – | 9 ✅ | 6 ✅ · 3 – | 9 ✅ |
| [MenuSeparator](MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ModalStack](ModalStack.md) | 6 | 5 ✅ · 1 ☑️ | 4 ✅ · 2 – | 3 ✅ · 1 ☑️ · 2 – | 6 ✅ | 4 ✅ · 2 – | 5 ✅ · 1 – |
| [NavigationStack](NavigationStack.md) | 9 | 6 ✅ · 1 ☑️ · 1 ✓ | 7 ✅ · 2 – | 6 ✅ · 1 ☑️ · 2 – | 9 ✅ | 5 ✅ · 4 – | 8 ✅ · 1 – |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 12 | 9 ✅ | 12 ✅ | 11 ✅ · 1 – | 11 ✅ · 1 – | 9 ✅ · 2 – | 11 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [SplitView](SplitView.md) | 12 | 9 ✅ · 1 ☑️ · 1 – | 9 ✅ · 1 ✓ · 2 – | 5 ✅ · 2 ☑️ · 3 ✓ · 2 – | 10 ✅ · 2 ☑️ | 6 ✅ · 2 ✓ · 4 – | 9 ✅ · 2 ☑️ · 1 – |
| [TabView](TabView.md) | 10 | 7 ✅ · 1 ☑️ · 1 ✓ | 8 ✅ · 2 – | 7 ✅ · 1 ☑️ · 2 – | 10 ✅ | 6 ✅ · 4 – | 9 ✅ · 1 – |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](ToolbarItem.md) | 9 | 5 ✅ · 1 ✓ · 1 – | 7 ✅ · 1 ✓ · 1 – | 6 ✅ · 1 – | 9 ✅ | 7 ✅ · 1 ✓ · 1 – | 9 ✅ |
| [ToolbarItemGroup](ToolbarItemGroup.md) | 2 | 2 ✅ | 2 ✅ | 1 ✅ · 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [Window](Window.md) | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 96 | 88 | 72 | 121 | 84 | 96 |
| ✓ |  | 20 | 19 | 16 | 2 | 16 | 9 |
| – |  | 3 | 17 | 26 | 2 | 27 | 19 |
| **Met** | 134 | **119** | **124** | **114** | **125** | **127** | **124** |
| 🧩 |  | 0 | 0 | 6 | 6 | 6 | 6 |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [AutomationElement](tiers/AutomationElement.md) - What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the screen's unsafe strips it keeps clear of, and whether its children are clipped or let input through.
- [Stack](tiers/Stack.md) - What both stacks have: the space between their children.
- [TextInput](tiers/TextInput.md) - What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: the line along it, how it fits its room, and a transform of its own drawing.
- [FilledShape](tiers/FilledShape.md) - A shape enclosing an area its fill paints - every shape but a line.
- [CorneredShape](tiers/CorneredShape.md) - A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path; neither a line nor an ellipse.
- [TextualElement](tiers/TextualElement.md) - What every element showing words has: the words, and the case they are drawn in.
- [TextStyleElement](tiers/TextStyleElement.md) - How text looks wherever it is drawn: its colour.
- [FontElement](tiers/FontElement.md) - The font text is drawn in: its step of the platform's type ramp, its family, its size, its weight and slant, and whether it follows the user's text-size setting.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where text sits across the space its own element was given.
- [LineHeightElement](tiers/LineHeightElement.md) - How far apart the lines of text are.
- [TrackingElement](tiers/TrackingElement.md) - The space between the letters of words an element draws as written - a text, a button's caption, a run.
- [DecorableTextElement](tiers/DecorableTextElement.md) - The lines drawn through or under text.
- [PaddingElement](tiers/PaddingElement.md) - The space kept inside an element, around what it holds.
- [BorderElement](tiers/BorderElement.md) - What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.
- [ImageElement](tiers/ImageElement.md) - How a picture fills the room it was given.
- [TintElement](tiers/TintElement.md) - A control's one accent colour.
- [KeyboardElement](tiers/KeyboardElement.md) - An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.
- [FocusElement](tiers/FocusElement.md) - An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.
- [BarElement](tiers/BarElement.md) - What an arrangement declares of the bar while it stands on the visible path: its colours, and the application's name, line and mark in the bar.
- [MenuItemElement](tiers/MenuItemElement.md) - What every item a user chooses from has - a menu's entry, a toolbar's item: a caption, a picture, and something to run.
- [PageElement](tiers/PageElement.md) - What a page shows about itself where another container presents it as an item - a title and a picture.
<!-- tiers:end -->

## Layers

Which layer realizes an element or a member - the word each page and each row uses.

<!-- layers:begin -->
- `native` - Every base host presents it with its native toolkit.
- `adaptive` - Every base host presents it by its platform's conventions, keeping StateUI's state contract.
- `stateUI` - StateUI decides its geometry, its arrangement or its composition - in the core or the shared host layer - and a host draws what was decided.
- `structure` - It carries structure or protocol data rather than configuring a visual platform object.
- `provider` - An optional provider supplies it: a package, or the application that registers it with its hosts.
<!-- layers:end -->
