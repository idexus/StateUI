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
| [ActivityIndicator](ActivityIndicator.md) | 70 | 31 ✅ · 2 ☑️ · 36 ✓ · 1 – | 32 ✅ · 2 ☑️ · 35 ✓ · 1 – | 54 ✅ · 5 ☑️ · 10 ✓ | 51 ✅ · 1 ☑️ · 14 ✓ · 3 – | 44 ✅ · 1 ☑️ · 22 ✓ · 3 – | 49 ✅ · 1 ☑️ · 20 ✓ |
| [Button](Button.md) | 99 | 56 ✅ · 2 ☑️ · 37 ✓ · 2 – | 54 ✅ · 1 ☑️ · 39 ✓ · 4 – | 70 ✅ · 5 ☑️ · 14 ✓ · 4 – | 83 ✅ · 1 ☑️ · 13 ✓ · 2 – | 68 ✅ · 2 ☑️ · 26 ✓ · 3 – | 78 ✅ · 1 ☑️ · 20 ✓ |
| [Canvas](Canvas.md) | 72 | 32 ✅ · 2 ☑️ · 38 ✓ | 31 ✅ · 2 ☑️ · 38 ✓ · 1 – | 56 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 15 ✓ · 2 – | 46 ✅ · 1 ☑️ · 22 ✓ · 3 – | 51 ✅ · 1 ☑️ · 20 ✓ |
| [Capsule](Capsule.md) | 76 | 39 ✅ · 2 ☑️ · 35 ✓ | 38 ✅ · 2 ☑️ · 35 ✓ · 1 – | 60 ✅ · 5 ☑️ · 10 ✓ | 59 ✅ · 14 ✓ · 3 – | 50 ✅ · 1 ☑️ · 22 ✓ · 3 – | 55 ✅ · 1 ☑️ · 20 ✓ |
| [CheckBox](CheckBox.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 35 ✅ · 2 ☑️ · 38 ✓ · 4 – | 58 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 2 – | 50 ✅ · 1 ☑️ · 25 ✓ · 3 – | 58 ✅ · 1 ☑️ · 20 ✓ |
| [DatePicker](DatePicker.md) | 88 | 44 ✅ · 2 ☑️ · 36 ✓ · 6 – | 34 ✅ · 1 ☑️ · 37 ✓ · 12 – | 63 ✅ · 5 ☑️ · 15 ✓ · 3 – | 70 ✅ · 3 ☑️ · 13 ✓ · 2 – | 57 ✅ · 2 ☑️ · 26 ✓ · 3 – | 62 ✅ · 1 ☑️ · 20 ✓ · 4 – |
| [Divider](Divider.md) | 68 | 31 ✅ · 2 ☑️ · 35 ✓ | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 52 ✅ · 5 ☑️ · 10 ✓ | 50 ✅ · 1 ☑️ · 14 ✓ · 2 – | 42 ✅ · 1 ☑️ · 22 ✓ · 3 – | 47 ✅ · 1 ☑️ · 20 ✓ |
| [Ellipse](Ellipse.md) | 76 | 39 ✅ · 2 ☑️ · 35 ✓ | 38 ✅ · 2 ☑️ · 35 ✓ · 1 – | 60 ✅ · 5 ☑️ · 10 ✓ | 59 ✅ · 14 ✓ · 3 – | 50 ✅ · 1 ☑️ · 22 ✓ · 3 – | 55 ✅ · 1 ☑️ · 20 ✓ |
| [Grid](Grid.md) | 81 | 43 ✅ · 1 ☑️ · 35 ✓ | 40 ✅ · 1 ☑️ · 37 ✓ · 1 – | 61 ✅ · 5 ☑️ · 12 ✓ | 65 ✅ · 1 ☑️ · 13 ✓ · 1 – | 53 ✅ · 1 ☑️ · 23 ✓ · 4 – | 59 ✅ · 1 ☑️ · 20 ✓ |
| [HStack](HStack.md) | 78 | 40 ✅ · 1 ☑️ · 35 ✓ | 37 ✅ · 1 ☑️ · 37 ✓ · 1 – | 58 ✅ · 5 ☑️ · 12 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 1 – | 50 ✅ · 1 ☑️ · 23 ✓ · 4 – | 56 ✅ · 1 ☑️ · 20 ✓ |
| [Image](Image.md) | 71 | 33 ✅ · 2 ☑️ · 35 ✓ | 32 ✅ · 2 ☑️ · 35 ✓ · 1 – | 53 ✅ · 5 ☑️ · 10 ✓ | 53 ✅ · 14 ✓ · 3 – | 44 ✅ · 1 ☑️ · 22 ✓ · 3 – | 49 ✅ · 1 ☑️ · 20 ✓ |
| [ItemsView](ItemsView.md) | 83 | 41 ✅ · 2 ☑️ · 39 ✓ | 35 ✅ · 2 ☑️ · 41 ✓ · 4 – | 63 ✅ · 5 ☑️ · 13 ✓ | 66 ✅ · 1 ☑️ · 13 ✓ · 2 – | 54 ✅ · 1 ☑️ · 23 ✓ · 3 – | 60 ✅ · 1 ☑️ · 21 ✓ |
| [LayoutEngine](LayoutEngine.md) | 87 | 35 ✅ · 1 ☑️ · 44 ✓ · 1 – | 34 ✅ · 1 ☑️ · 46 ✓ · 2 – | 58 ✅ · 5 ☑️ · 16 ✓ · 1 – | 53 ✅ · 1 ☑️ · 26 ✓ · 5 – | 46 ✅ · 1 ☑️ · 30 ✓ · 5 – | 58 ✅ · 2 ☑️ · 24 ✓ · 1 – |
| [Line](Line.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 3 – | 53 ✅ · 1 ☑️ · 22 ✓ · 3 – | 58 ✅ · 1 ☑️ · 20 ✓ |
| [Map](Map.md) | 76 | 38 ✅ · 2 ☑️ · 36 ✓ | 37 ✅ · 2 ☑️ · 36 ✓ · 1 – | 76 🧩 | 76 🧩 | 76 🧩 | 76 🧩 |
| [Path](Path.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 3 – | 53 ✅ · 1 ☑️ · 22 ✓ · 3 – | 58 ✅ · 1 ☑️ · 20 ✓ |
| [Picker](Picker.md) | 90 | 48 ✅ · 2 ☑️ · 36 ✓ · 1 – | 40 ✅ · 3 ☑️ · 40 ✓ · 4 – | 63 ✅ · 6 ☑️ · 13 ✓ · 3 – | 74 ✅ · 1 ☑️ · 13 ✓ · 2 – | 56 ✅ · 1 ☑️ · 24 ✓ · 9 – | 64 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Polygon](Polygon.md) | 80 | 43 ✅ · 2 ☑️ · 35 ✓ | 42 ✅ · 2 ☑️ · 35 ✓ · 1 – | 64 ✅ · 5 ☑️ · 10 ✓ | 63 ✅ · 14 ✓ · 3 – | 54 ✅ · 1 ☑️ · 22 ✓ · 3 – | 59 ✅ · 1 ☑️ · 20 ✓ |
| [Polyline](Polyline.md) | 80 | 43 ✅ · 2 ☑️ · 35 ✓ | 42 ✅ · 2 ☑️ · 35 ✓ · 1 – | 64 ✅ · 5 ☑️ · 10 ✓ | 63 ✅ · 14 ✓ · 3 – | 54 ✅ · 1 ☑️ · 22 ✓ · 3 – | 59 ✅ · 1 ☑️ · 20 ✓ |
| [ProgressBar](ProgressBar.md) | 70 | 32 ✅ · 2 ☑️ · 35 ✓ · 1 – | 32 ✅ · 2 ☑️ · 35 ✓ · 1 – | 54 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 13 ✓ · 3 – | 43 ✅ · 1 ☑️ · 23 ✓ · 3 – | 49 ✅ · 1 ☑️ · 20 ✓ |
| [Rectangle](Rectangle.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 3 – | 53 ✅ · 1 ☑️ · 22 ✓ · 3 – | 58 ✅ · 1 ☑️ · 20 ✓ |
| [ScrollView](ScrollView.md) | 82 | 40 ✅ · 3 ☑️ · 36 ✓ · 3 – | 38 ✅ · 1 ☑️ · 37 ✓ · 4 – | 61 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 5 – | 55 ✅ · 1 ☑️ · 23 ✓ · 3 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [SearchField](SearchField.md) | 95 | 52 ✅ · 4 ☑️ · 35 ✓ · 1 – | 55 ✅ · 2 ☑️ · 37 ✓ · 1 – | 75 ✅ · 5 ☑️ · 12 ✓ · 1 – | 73 ✅ · 5 ☑️ · 13 ✓ · 4 – | 64 ✅ · 3 ☑️ · 25 ✓ · 3 – | 74 ✅ · 1 ☑️ · 20 ✓ |
| [Slider](Slider.md) | 80 | 40 ✅ · 2 ☑️ · 35 ✓ · 1 – | 35 ✅ · 2 ☑️ · 39 ✓ · 4 – | 59 ✅ · 5 ☑️ · 12 ✓ · 3 – | 62 ✅ · 1 ☑️ · 13 ✓ · 2 – | 49 ✅ · 1 ☑️ · 25 ✓ · 5 – | 59 ✅ · 20 ✓ · 1 – |
| [Spacer](Spacer.md) | 68 | 31 ✅ · 2 ☑️ · 35 ✓ | 30 ✅ · 2 ☑️ · 35 ✓ · 1 – | 52 ✅ · 5 ☑️ · 10 ✓ | 50 ✅ · 1 ☑️ · 14 ✓ · 2 – | 42 ✅ · 1 ☑️ · 22 ✓ · 3 – | 47 ✅ · 1 ☑️ · 20 ✓ |
| [Stepper](Stepper.md) | 78 | 41 ✅ · 2 ☑️ · 35 ✓ | 35 ✅ · 2 ☑️ · 37 ✓ · 4 – | 57 ✅ · 5 ☑️ · 12 ✓ · 3 – | 61 ✅ · 2 ☑️ · 13 ✓ · 2 – | 50 ✅ · 1 ☑️ · 24 ✓ · 3 – | 57 ✅ · 1 ☑️ · 20 ✓ |
| [Switch](Switch.md) | 79 | 41 ✅ · 2 ☑️ · 35 ✓ · 1 – | 36 ✅ · 2 ☑️ · 37 ✓ · 4 – | 57 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 2 – | 50 ✅ · 1 ☑️ · 24 ✓ · 4 – | 58 ✅ · 1 ☑️ · 20 ✓ |
| [Text](Text.md) | 86 | 47 ✅ · 2 ☑️ · 35 ✓ · 1 – | 48 ✅ · 1 ☑️ · 35 ✓ · 1 – | 69 ✅ · 5 ☑️ · 10 ✓ | 70 ✅ · 1 ☑️ · 13 ✓ · 2 – | 59 ✅ · 1 ☑️ · 23 ✓ · 3 – | 65 ✅ · 1 ☑️ · 20 ✓ |
| [TextEditor](TextEditor.md) | 94 | 55 ✅ · 3 ☑️ · 35 ✓ · 1 – | 54 ✅ · 2 ☑️ · 37 ✓ · 1 – | 74 ✅ · 5 ☑️ · 12 ✓ · 1 – | 77 ✅ · 2 ☑️ · 13 ✓ · 2 – | 63 ✅ · 3 ☑️ · 25 ✓ · 3 – | 73 ✅ · 1 ☑️ · 20 ✓ |
| [TextField](TextField.md) | 97 | 53 ✅ · 4 ☑️ · 35 ✓ · 2 – | 57 ✅ · 2 ☑️ · 37 ✓ · 1 – | 76 ✅ · 5 ☑️ · 12 ✓ · 2 – | 77 ✅ · 4 ☑️ · 13 ✓ · 2 – | 65 ✅ · 3 ☑️ · 25 ✓ · 4 – | 75 ✅ · 1 ☑️ · 20 ✓ |
| [TimePicker](TimePicker.md) | 86 | 42 ✅ · 2 ☑️ · 36 ✓ · 6 – | 35 ✅ · 1 ☑️ · 37 ✓ · 9 – | 63 ✅ · 5 ☑️ · 13 ✓ · 3 – | 65 ✅ · 2 ☑️ · 13 ✓ · 2 – | 56 ✅ · 1 ☑️ · 25 ✓ · 3 – | 60 ✅ · 1 ☑️ · 20 ✓ · 4 – |
| [VStack](VStack.md) | 78 | 40 ✅ · 1 ☑️ · 35 ✓ | 38 ✅ · 1 ☑️ · 36 ✓ · 1 – | 59 ✅ · 5 ☑️ · 11 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 1 – | 51 ✅ · 1 ☑️ · 22 ✓ · 4 – | 56 ✅ · 1 ☑️ · 20 ✓ |
| [WebView](WebView.md) | 84 | 46 ✅ · 2 ☑️ · 36 ✓ | 43 ✅ · 2 ☑️ · 38 ✓ · 1 – | 63 ✅ · 5 ☑️ · 12 ✓ · 3 – | 49 ✅ · 13 ✓ · 21 – | 56 ✅ · 1 ☑️ · 24 ✓ · 3 – | 57 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ZStack](ZStack.md) | 77 | 39 ✅ · 1 ☑️ · 35 ✓ | 36 ✅ · 1 ☑️ · 37 ✓ · 1 – | 57 ✅ · 5 ☑️ · 12 ✓ | 61 ✅ · 1 ☑️ · 13 ✓ · 1 – | 49 ✅ · 1 ☑️ · 23 ✓ · 4 – | 55 ✅ · 1 ☑️ · 20 ✓ |
| ✅ |  | 1403 | 1326 | 2022 | 2061 | 1729 | 1936 |
| ✓ |  | 1215 | 1253 | 379 | 455 | 775 | 665 |
| – |  | 28 | 78 | 36 | 99 | 115 | 19 |
| **Met** | 2745 | **2646** | **2657** | **2437** | **2615** | **2619** | **2620** |
| 🧩 |  | 0 | 0 | 76 | 76 | 76 | 76 |
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
| [SplitView](SplitView.md) | 13 | 10 ✅ · 1 ☑️ · 1 – | 10 ✅ · 1 ✓ · 2 – | 5 ✅ · 2 ☑️ · 4 ✓ · 2 – | 11 ✅ · 2 ☑️ | 7 ✅ · 2 ✓ · 4 – | 10 ✅ · 2 ☑️ · 1 – |
| [TabView](TabView.md) | 10 | 7 ✅ · 1 ☑️ · 1 ✓ | 8 ✅ · 2 – | 7 ✅ · 1 ☑️ · 2 – | 10 ✅ | 6 ✅ · 4 – | 9 ✅ · 1 – |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarItem](ToolbarItem.md) | 9 | 5 ✅ · 1 ✓ · 1 – | 7 ✅ · 1 ✓ · 1 – | 6 ✅ · 1 – | 9 ✅ | 7 ✅ · 1 ✓ · 1 – | 9 ✅ |
| [ToolbarItemGroup](ToolbarItemGroup.md) | 2 | 2 ✅ | 2 ✅ | 1 ✅ · 1 – | 2 ✅ | 2 ✅ | 2 ✅ |
| [Window](Window.md) | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 97 | 89 | 72 | 122 | 85 | 97 |
| ✓ |  | 20 | 19 | 17 | 2 | 16 | 9 |
| – |  | 3 | 17 | 26 | 2 | 27 | 19 |
| **Met** | 135 | **120** | **125** | **115** | **126** | **128** | **125** |
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
- [TextColorElement](tiers/TextColorElement.md) - The colour of text, wherever it is drawn.
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
