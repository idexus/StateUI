# Control dictionary

Every element StateUI declares - each control, and each part an application, its windows and its pages are made of - member by member, with what each target host's tests proved of it.

A page is its element's contract rendered: the members it declares itself, then one section per tier it wears, each linking that tier's page. Every member shows its kind - a property, an event or an act - its value, the layer that realizes it, and a mark for each platform, because a host realizes the same inherited member differently on different elements: a background is a layer color on a label and a drawn fill on an outlined layout.

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
| [Button](Button.md) | 103 | 59 ✅ · 2 ☑️ · 37 ✓ · 3 – | 57 ✅ · 1 ☑️ · 39 ✓ · 5 – | 74 ✅ · 5 ☑️ · 14 ✓ · 4 – | 84 ✅ · 1 ☑️ · 13 ✓ · 5 – | 69 ✅ · 2 ☑️ · 26 ✓ · 6 – | 79 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Canvas](Canvas.md) | 75 | 35 ✅ · 2 ☑️ · 38 ✓ | 34 ✅ · 2 ☑️ · 38 ✓ · 1 – | 59 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 15 ✓ · 5 – | 46 ✅ · 1 ☑️ · 22 ✓ · 6 – | 51 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Capsule](Capsule.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 40 ✅ · 3 ☑️ · 35 ✓ · 1 – | 62 ✅ · 6 ☑️ · 10 ✓ | 58 ✅ · 1 ☑️ · 14 ✓ · 6 – | 49 ✅ · 2 ☑️ · 22 ✓ · 6 – | 54 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 82 | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 37 ✅ · 2 ☑️ · 38 ✓ · 5 – | 61 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 25 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [DatePicker](DatePicker.md) | 91 | 46 ✅ · 2 ☑️ · 36 ✓ · 7 – | 36 ✅ · 1 ☑️ · 37 ✓ · 13 – | 66 ✅ · 5 ☑️ · 15 ✓ · 3 – | 70 ✅ · 3 ☑️ · 13 ✓ · 5 – | 57 ✅ · 2 ☑️ · 26 ✓ · 6 – | 62 ✅ · 1 ☑️ · 20 ✓ · 7 – |
| [Ellipse](Ellipse.md) | 79 | 42 ✅ · 2 ☑️ · 35 ✓ | 40 ✅ · 3 ☑️ · 35 ✓ · 1 – | 62 ✅ · 6 ☑️ · 10 ✓ | 58 ✅ · 1 ☑️ · 14 ✓ · 6 – | 49 ✅ · 2 ☑️ · 22 ✓ · 6 – | 54 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [Fill](Fill.md) | 74 | 38 ✅ · 1 ☑️ · 35 ✓ | 36 ✅ · 2 ☑️ · 35 ✓ · 1 – | 58 ✅ · 5 ☑️ · 10 ✓ | 56 ✅ · 1 ☑️ · 14 ✓ · 3 – | 46 ✅ · 1 ☑️ · 21 ✓ · 6 – | 50 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Grid](Grid.md) | 84 | 46 ✅ · 1 ☑️ · 35 ✓ | 42 ✅ · 2 ☑️ · 37 ✓ · 1 – | 64 ✅ · 5 ☑️ · 12 ✓ | 65 ✅ · 1 ☑️ · 13 ✓ · 4 – | 53 ✅ · 1 ☑️ · 23 ✓ · 7 – | 59 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [HStack](HStack.md) | 81 | 43 ✅ · 1 ☑️ · 35 ✓ | 39 ✅ · 2 ☑️ · 37 ✓ · 1 – | 61 ✅ · 5 ☑️ · 12 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 4 – | 50 ✅ · 1 ☑️ · 23 ✓ · 7 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Image](Image.md) | 74 | 36 ✅ · 2 ☑️ · 35 ✓ | 35 ✅ · 2 ☑️ · 35 ✓ · 1 – | 56 ✅ · 5 ☑️ · 10 ✓ | 53 ✅ · 14 ✓ · 6 – | 44 ✅ · 1 ☑️ · 22 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 89 | 43 ✅ · 2 ☑️ · 39 ✓ · 4 – | 40 ✅ · 2 ☑️ · 41 ✓ · 5 – | 69 ✅ · 5 ☑️ · 13 ✓ | 66 ✅ · 1 ☑️ · 13 ✓ · 8 – | 54 ✅ · 1 ☑️ · 23 ✓ · 9 – | 60 ✅ · 1 ☑️ · 21 ✓ · 6 – |
| [LayoutEngine](LayoutEngine.md) | 90 | 38 ✅ · 1 ☑️ · 44 ✓ · 1 – | 36 ✅ · 2 ☑️ · 46 ✓ · 2 – | 61 ✅ · 5 ☑️ · 16 ✓ · 1 – | 53 ✅ · 1 ☑️ · 26 ✓ · 8 – | 46 ✅ · 1 ☑️ · 30 ✓ · 8 – | 58 ✅ · 2 ☑️ · 24 ✓ · 4 – |
| [Line](Line.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 2 ☑️ · 35 ✓ · 1 – | 66 ✅ · 5 ☑️ · 10 ✓ | 62 ✅ · 14 ✓ · 6 – | 53 ✅ · 1 ☑️ · 22 ✓ · 6 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Link](Link.md) | 81 | 42 ✅ · 2 ☑️ · 36 ✓ · 1 – | 36 ✅ · 2 ☑️ · 38 ✓ · 5 – | 59 ✅ · 5 ☑️ · 13 ✓ · 3 – | 61 ✅ · 1 ☑️ · 14 ✓ · 5 – | 49 ✅ · 1 ☑️ · 25 ✓ · 6 – | 56 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Map](Map.md) | 79 | 40 ✅ · 2 ☑️ · 36 ✓ · 1 – | 39 ✅ · 2 ☑️ · 36 ✓ · 2 – | 79 🧩 | 79 🧩 | 79 🧩 | 79 🧩 |
| [Path](Path.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 43 ✅ · 3 ☑️ · 35 ✓ · 1 – | 65 ✅ · 6 ☑️ · 10 ✓ | 61 ✅ · 1 ☑️ · 14 ✓ · 6 – | 52 ✅ · 2 ☑️ · 22 ✓ · 6 – | 57 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [Picker](Picker.md) | 93 | 50 ✅ · 2 ☑️ · 36 ✓ · 2 – | 42 ✅ · 3 ☑️ · 40 ✓ · 5 – | 66 ✅ · 6 ☑️ · 13 ✓ · 3 – | 74 ✅ · 1 ☑️ · 13 ✓ · 5 – | 56 ✅ · 1 ☑️ · 24 ✓ · 12 – | 64 ✅ · 1 ☑️ · 20 ✓ · 6 – |
| [Polygon](Polygon.md) | 83 | 46 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 3 ☑️ · 35 ✓ · 1 – | 66 ✅ · 6 ☑️ · 10 ✓ | 62 ✅ · 1 ☑️ · 14 ✓ · 6 – | 53 ✅ · 2 ☑️ · 22 ✓ · 6 – | 58 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [Polyline](Polyline.md) | 83 | 46 ✅ · 2 ☑️ · 35 ✓ | 44 ✅ · 3 ☑️ · 35 ✓ · 1 – | 66 ✅ · 6 ☑️ · 10 ✓ | 62 ✅ · 1 ☑️ · 14 ✓ · 6 – | 53 ✅ · 2 ☑️ · 22 ✓ · 6 – | 58 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 73 | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 57 ✅ · 5 ☑️ · 10 ✓ | 54 ✅ · 13 ✓ · 6 – | 43 ✅ · 1 ☑️ · 23 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Rectangle](Rectangle.md) | 82 | 45 ✅ · 2 ☑️ · 35 ✓ | 43 ✅ · 3 ☑️ · 35 ✓ · 1 – | 65 ✅ · 6 ☑️ · 10 ✓ | 61 ✅ · 1 ☑️ · 14 ✓ · 6 – | 52 ✅ · 2 ☑️ · 22 ✓ · 6 – | 57 ✅ · 2 ☑️ · 20 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 88 | 42 ✅ · 3 ☑️ · 36 ✓ · 7 – | 43 ✅ · 2 ☑️ · 37 ✓ · 4 – | 66 ✅ · 5 ☑️ · 13 ✓ · 3 – | 66 ✅ · 1 ☑️ · 13 ✓ · 8 – | 55 ✅ · 1 ☑️ · 23 ✓ · 9 – | 58 ✅ · 1 ☑️ · 20 ✓ · 9 – |
| [SearchField](SearchField.md) | 98 | 54 ✅ · 4 ☑️ · 35 ✓ · 2 – | 57 ✅ · 2 ☑️ · 37 ✓ · 2 – | 78 ✅ · 5 ☑️ · 12 ✓ · 1 – | 73 ✅ · 5 ☑️ · 13 ✓ · 7 – | 64 ✅ · 3 ☑️ · 25 ✓ · 6 – | 74 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Separator](Separator.md) | 71 | 33 ✅ · 2 ☑️ · 35 ✓ · 1 – | 32 ✅ · 2 ☑️ · 35 ✓ · 2 – | 55 ✅ · 5 ☑️ · 10 ✓ | 50 ✅ · 1 ☑️ · 14 ✓ · 5 – | 42 ✅ · 1 ☑️ · 22 ✓ · 6 – | 47 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Slider](Slider.md) | 83 | 42 ✅ · 2 ☑️ · 35 ✓ · 2 – | 37 ✅ · 2 ☑️ · 39 ✓ · 5 – | 62 ✅ · 5 ☑️ · 12 ✓ · 3 – | 62 ✅ · 1 ☑️ · 13 ✓ · 5 – | 49 ✅ · 1 ☑️ · 25 ✓ · 8 – | 59 ✅ · 20 ✓ · 4 – |
| [Space](Space.md) | 74 | 38 ✅ · 1 ☑️ · 35 ✓ | 36 ✅ · 2 ☑️ · 35 ✓ · 1 – | 58 ✅ · 5 ☑️ · 10 ✓ | 56 ✅ · 1 ☑️ · 14 ✓ · 3 – | 46 ✅ · 1 ☑️ · 21 ✓ · 6 – | 50 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Spinner](Spinner.md) | 73 | 33 ✅ · 2 ☑️ · 36 ✓ · 2 – | 34 ✅ · 2 ☑️ · 35 ✓ · 2 – | 57 ✅ · 5 ☑️ · 10 ✓ | 51 ✅ · 1 ☑️ · 14 ✓ · 6 – | 44 ✅ · 1 ☑️ · 22 ✓ · 6 – | 49 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Stepper](Stepper.md) | 81 | 43 ✅ · 2 ☑️ · 35 ✓ · 1 – | 37 ✅ · 2 ☑️ · 37 ✓ · 5 – | 60 ✅ · 5 ☑️ · 12 ✓ · 3 – | 61 ✅ · 2 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 24 ✓ · 6 – | 57 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Switch](Switch.md) | 82 | 43 ✅ · 2 ☑️ · 35 ✓ · 2 – | 38 ✅ · 2 ☑️ · 37 ✓ · 5 – | 60 ✅ · 5 ☑️ · 12 ✓ · 3 – | 63 ✅ · 1 ☑️ · 13 ✓ · 5 – | 50 ✅ · 1 ☑️ · 24 ✓ · 7 – | 58 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [Text](Text.md) | 89 | 50 ✅ · 2 ☑️ · 35 ✓ · 1 – | 51 ✅ · 1 ☑️ · 35 ✓ · 1 – | 72 ✅ · 5 ☑️ · 10 ✓ | 70 ✅ · 1 ☑️ · 13 ✓ · 5 – | 59 ✅ · 1 ☑️ · 23 ✓ · 6 – | 65 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 97 | 57 ✅ · 3 ☑️ · 35 ✓ · 2 – | 56 ✅ · 2 ☑️ · 37 ✓ · 2 – | 77 ✅ · 5 ☑️ · 12 ✓ · 1 – | 77 ✅ · 2 ☑️ · 13 ✓ · 5 – | 63 ✅ · 3 ☑️ · 25 ✓ · 6 – | 73 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TextField](TextField.md) | 100 | 55 ✅ · 4 ☑️ · 35 ✓ · 3 – | 59 ✅ · 2 ☑️ · 37 ✓ · 2 – | 79 ✅ · 5 ☑️ · 12 ✓ · 2 – | 77 ✅ · 4 ☑️ · 13 ✓ · 5 – | 65 ✅ · 3 ☑️ · 25 ✓ · 7 – | 75 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [TimePicker](TimePicker.md) | 89 | 44 ✅ · 2 ☑️ · 36 ✓ · 7 – | 37 ✅ · 1 ☑️ · 37 ✓ · 10 – | 66 ✅ · 5 ☑️ · 13 ✓ · 3 – | 65 ✅ · 2 ☑️ · 13 ✓ · 5 – | 56 ✅ · 1 ☑️ · 25 ✓ · 6 – | 60 ✅ · 1 ☑️ · 20 ✓ · 7 – |
| [VStack](VStack.md) | 81 | 43 ✅ · 1 ☑️ · 35 ✓ | 40 ✅ · 2 ☑️ · 36 ✓ · 1 – | 62 ✅ · 5 ☑️ · 11 ✓ | 62 ✅ · 1 ☑️ · 13 ✓ · 4 – | 51 ✅ · 1 ☑️ · 22 ✓ · 7 – | 56 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| [WebView](WebView.md) | 87 | 48 ✅ · 2 ☑️ · 36 ✓ · 1 – | 45 ✅ · 2 ☑️ · 38 ✓ · 2 – | 66 ✅ · 5 ☑️ · 12 ✓ · 3 – | 49 ✅ · 13 ✓ · 24 – | 56 ✅ · 1 ☑️ · 24 ✓ · 6 – | 57 ✅ · 1 ☑️ · 20 ✓ · 6 – |
| [ZStack](ZStack.md) | 80 | 42 ✅ · 1 ☑️ · 35 ✓ | 38 ✅ · 2 ☑️ · 37 ✓ · 1 – | 60 ✅ · 5 ☑️ · 12 ✓ | 61 ✅ · 1 ☑️ · 13 ✓ · 4 – | 49 ✅ · 1 ☑️ · 23 ✓ · 7 – | 55 ✅ · 1 ☑️ · 20 ✓ · 3 – |
| ✅ |  | 1572 | 1481 | 2241 | 2182 | 1823 | 2040 |
| ✓ |  | 1286 | 1326 | 403 | 483 | 820 | 706 |
| – |  | 53 | 101 | 39 | 207 | 232 | 130 |
| **Met** | 3012 | **2911** | **2908** | **2683** | **2872** | **2875** | **2876** |
| 🧩 |  | 0 | 0 | 79 | 79 | 79 | 79 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Anchor](Anchor.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](Application.md) | 24 | 12 ✅ · 11 ✓ · 1 – | 14 ✅ · 10 ✓ | 11 ✅ · 1 ☑️ · 11 ✓ · 1 – | 19 ✅ · 4 ✓ · 1 – | 16 ✅ · 6 ✓ · 1 – | 18 ✅ · 6 ✓ |
| [ButtonMenu](ButtonMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 4 ✅ · 3 – | 7 ✅ |
| [MenuSeparator](MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuToggle](MenuToggle.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 5 ✅ · 2 – | 7 ✅ |
| [NavigationStack](NavigationStack.md) | 8 | 3 ✅ · 1 ☑️ · 1 ✓ · 2 – | 6 ✅ · 2 – | 5 ✅ · 1 ☑️ · 2 – | 6 ✅ · 2 – | 4 ✅ · 4 – | 8 ✅ |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 14 | 11 ✅ | 14 ✅ | 13 ✅ · 1 – | 13 ✅ · 1 – | 11 ✅ · 2 – | 13 ✅ |
| [Popover](Popover.md) | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [Sheet](Sheet.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [SplitView](SplitView.md) | 13 | 8 ✅ · 1 ☑️ · 3 – | 9 ✅ · 2 ✓ · 2 – | 5 ✅ · 2 ☑️ · 4 ✓ · 2 – | 9 ✅ · 2 ☑️ · 2 – | 7 ✅ · 2 ✓ · 4 – | 11 ✅ · 2 ☑️ |
| [TabView](TabView.md) | 9 | 4 ✅ · 1 ☑️ · 1 ✓ · 2 – | 7 ✅ · 2 – | 6 ✅ · 1 ☑️ · 2 – | 7 ✅ · 2 – | 5 ✅ · 4 – | 9 ✅ |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](ToolbarButton.md) | 10 | 5 ✅ · 2 ✓ · 1 – | 6 ✅ · 1 ☑️ · 1 ✓ · 2 – | 6 ✅ · 1 ☑️ · 2 – | 8 ✅ · 1 ☑️ · 1 – | 8 ✅ · 1 ✓ · 1 – | 10 ✅ |
| [ToolbarGroup](ToolbarGroup.md) | 5 | 3 ✅ | 3 ✅ | 2 ✅ · 1 ☑️ | 3 ✅ | 3 ✅ | 3 ✅ |
| [ToolbarToggle](ToolbarToggle.md) | 9 | 7 ✅ · 1 – | 8 ✅ · 1 – | 6 ✅ · 1 ☑️ · 1 – | 9 ✅ | 8 ✅ · 1 – | 9 ✅ |
| [Window](Window.md) | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 105 | 105 | 86 | 130 | 101 | 120 |
| ✓ |  | 23 | 21 | 20 | 5 | 17 | 10 |
| – |  | 11 | 17 | 28 | 10 | 29 | 15 |
| **Met** | 157 | **139** | **143** | **134** | **145** | **147** | **145** |
| 🧩 |  | 0 | 0 | 6 | 6 | 6 | 6 |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [AutomationElement](tiers/AutomationElement.md) - What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the edges it runs under what stands over its page on, and whether its children are clipped or let input through.
- [Stack](tiers/Stack.md) - What both stacks have: the space between their children.
- [TextInput](tiers/TextInput.md) - What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: the line along it, how it fits its room, and a transform of its own drawing.
- [FilledShape](tiers/FilledShape.md) - A shape enclosing an area its fill paints - every shape but a line.
- [CorneredShape](tiers/CorneredShape.md) - A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path; neither a line nor an ellipse.
- [TextualElement](tiers/TextualElement.md) - What every element showing words has: the words, and the case they are drawn in.
- [TextColorElement](tiers/TextColorElement.md) - The color of text, wherever it is drawn.
- [FontElement](tiers/FontElement.md) - The font text is drawn in: its step of the platform's type ramp, its family, its size, its weight and slant, and whether it follows the user's text-size setting.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where text sits across the space its own element was given.
- [LineHeightElement](tiers/LineHeightElement.md) - How far apart the lines of text are.
- [TrackingElement](tiers/TrackingElement.md) - The space between the letters of words an element draws as written - a text, a button's caption, a run.
- [DecorableTextElement](tiers/DecorableTextElement.md) - The lines drawn through or under text.
- [PaddingElement](tiers/PaddingElement.md) - The space kept inside an element, around what it holds.
- [BorderElement](tiers/BorderElement.md) - What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.
- [ImageElement](tiers/ImageElement.md) - How a picture fills the room it was given.
- [TintElement](tiers/TintElement.md) - A control's one accent color.
- [KeyboardElement](tiers/KeyboardElement.md) - An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.
- [FocusElement](tiers/FocusElement.md) - An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.
- [RefreshElement](tiers/RefreshElement.md) - An element the user pulls to refresh what it shows - a scroller, a list.
- [BarElement](tiers/BarElement.md) - What an arrangement declares of the bar while it stands on the visible path: its look.
- [MenuItemElement](tiers/MenuItemElement.md) - What every item a user chooses from says - a menu's entry, a toolbar's item, an action or a setting: a caption, a picture, whether it can be chosen, and the keys that choose it.
- [ActionElement](tiers/ActionElement.md) - What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks it.
- [ButtonMenuElement](tiers/ButtonMenuElement.md) - What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow saying so shows.
- [TextAndIconElement](tiers/TextAndIconElement.md) - What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.
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
