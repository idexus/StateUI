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
| [Button](Button.md) | 113 | 66 ✅ · 3 ☑️ · 38 ✓ · 4 – | 65 ✅ · 2 ☑️ · 40 ✓ · 5 – | 82 ✅ · 7 ☑️ · 13 ✓ · 5 – | 75 ✅ · 3 ☑️ · 29 ✓ · 6 – | 75 ✅ · 4 ☑️ · 27 ✓ · 7 – | 87 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Canvas](Canvas.md) | 82 | 42 ✅ · 3 ☑️ · 36 ✓ · 1 – | 42 ✅ · 3 ☑️ · 36 ✓ · 1 – | 63 ✅ · 5 ☑️ · 10 ✓ · 3 – | 44 ✅ · 3 ☑️ · 28 ✓ · 6 – | 49 ✅ · 4 ☑️ · 22 ✓ · 7 – | 56 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Capsule](Capsule.md) | 89 | 49 ✅ · 3 ☑️ · 36 ✓ · 1 – | 48 ✅ · 4 ☑️ · 36 ✓ · 1 – | 70 ✅ · 6 ☑️ · 10 ✓ · 2 – | 50 ✅ · 3 ☑️ · 29 ✓ · 7 – | 55 ✅ · 5 ☑️ · 22 ✓ · 7 – | 62 ✅ · 3 ☑️ · 21 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 92 | 51 ✅ · 3 ☑️ · 36 ✓ · 2 – | 45 ✅ · 3 ☑️ · 39 ✓ · 5 – | 69 ✅ · 6 ☑️ · 12 ✓ · 4 – | 56 ✅ · 3 ☑️ · 27 ✓ · 6 – | 56 ✅ · 4 ☑️ · 25 ✓ · 7 – | 66 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [ColorPicker](ColorPicker.md) | 89 | 48 ✅ · 3 ☑️ · 36 ✓ · 2 – | 43 ✅ · 3 ☑️ · 38 ✓ · 5 – | 89 – | 53 ✅ · 3 ☑️ · 27 ✓ · 6 – | 54 ✅ · 4 ☑️ · 24 ✓ · 7 – | 62 ✅ · 2 ☑️ · 21 ✓ · 4 – |
| [DatePicker](DatePicker.md) | 101 | 53 ✅ · 3 ☑️ · 37 ✓ · 8 – | 44 ✅ · 2 ☑️ · 38 ✓ · 13 – | 74 ✅ · 6 ☑️ · 15 ✓ · 4 – | 63 ✅ · 5 ☑️ · 27 ✓ · 6 – | 63 ✅ · 7 ☑️ · 24 ✓ · 7 – | 70 ✅ · 2 ☑️ · 21 ✓ · 7 – |
| [Ellipse](Ellipse.md) | 89 | 49 ✅ · 3 ☑️ · 36 ✓ · 1 – | 48 ✅ · 4 ☑️ · 36 ✓ · 1 – | 70 ✅ · 6 ☑️ · 10 ✓ · 2 – | 50 ✅ · 3 ☑️ · 29 ✓ · 7 – | 55 ✅ · 5 ☑️ · 22 ✓ · 7 – | 62 ✅ · 3 ☑️ · 21 ✓ · 3 – |
| [Fill](Fill.md) | 84 | 45 ✅ · 2 ☑️ · 36 ✓ · 1 – | 44 ✅ · 3 ☑️ · 36 ✓ · 1 – | 67 ✅ · 5 ☑️ · 10 ✓ · 2 – | 48 ✅ · 3 ☑️ · 29 ✓ · 4 – | 52 ✅ · 3 ☑️ · 22 ✓ · 7 – | 58 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Grid](Grid.md) | 95 | 55 ✅ · 2 ☑️ · 36 ✓ · 1 – | 52 ✅ · 3 ☑️ · 38 ✓ · 1 – | 76 ✅ · 5 ☑️ · 12 ✓ · 2 – | 59 ✅ · 3 ☑️ · 27 ✓ · 5 – | 60 ✅ · 3 ☑️ · 24 ✓ · 8 – | 69 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [HStack](HStack.md) | 95 | 56 ✅ · 2 ☑️ · 35 ✓ · 1 – | 52 ✅ · 3 ☑️ · 38 ✓ · 1 – | 76 ✅ · 5 ☑️ · 12 ✓ · 2 – | 60 ✅ · 3 ☑️ · 26 ✓ · 5 – | 60 ✅ · 3 ☑️ · 24 ✓ · 8 – | 69 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Image](Image.md) | 84 | 43 ✅ · 3 ☑️ · 36 ✓ · 1 – | 43 ✅ · 3 ☑️ · 36 ✓ · 1 – | 64 ✅ · 5 ☑️ · 10 ✓ · 2 – | 45 ✅ · 2 ☑️ · 29 ✓ · 7 – | 50 ✅ · 4 ☑️ · 22 ✓ · 7 – | 57 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 99 | 51 ✅ · 3 ☑️ · 40 ✓ · 5 – | 49 ✅ · 3 ☑️ · 42 ✓ · 5 – | 77 ✅ · 5 ☑️ · 13 ✓ · 3 – | 60 ✅ · 3 ☑️ · 27 ✓ · 9 – | 61 ✅ · 3 ☑️ · 24 ✓ · 10 – | 69 ✅ · 2 ☑️ · 22 ✓ · 6 – |
| [Line](Line.md) | 90 | 50 ✅ · 3 ☑️ · 36 ✓ · 1 – | 50 ✅ · 3 ☑️ · 36 ✓ · 1 – | 72 ✅ · 5 ☑️ · 10 ✓ · 2 – | 52 ✅ · 2 ☑️ · 29 ✓ · 7 – | 57 ✅ · 4 ☑️ · 22 ✓ · 7 – | 64 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Link](Link.md) | 91 | 49 ✅ · 3 ☑️ · 37 ✓ · 2 – | 44 ✅ · 3 ☑️ · 39 ✓ · 5 – | 67 ✅ · 6 ☑️ · 13 ✓ · 4 – | 54 ✅ · 3 ☑️ · 28 ✓ · 6 – | 55 ✅ · 4 ☑️ · 25 ✓ · 7 – | 64 ✅ · 2 ☑️ · 22 ✓ · 3 – |
| [Map](Map.md) | 89 | 47 ✅ · 3 ☑️ · 37 ✓ · 2 – | 47 ✅ · 3 ☑️ · 37 ✓ · 2 – | 89 🧩 | 89 🧩 | 89 🧩 | 89 🧩 |
| [MotionLayout](MotionLayout.md) | 97 | 53 ✅ · 2 ☑️ · 36 ✓ · 2 – | 52 ✅ · 3 ☑️ · 38 ✓ · 2 – | 74 ✅ · 5 ☑️ · 12 ✓ · 3 – | 58 ✅ · 3 ☑️ · 27 ✓ · 8 – | 57 ✅ · 3 ☑️ · 24 ✓ · 9 – | 70 ✅ · 2 ☑️ · 21 ✓ · 4 – |
| [Path](Path.md) | 92 | 52 ✅ · 3 ☑️ · 36 ✓ · 1 – | 51 ✅ · 4 ☑️ · 36 ✓ · 1 – | 73 ✅ · 6 ☑️ · 10 ✓ · 2 – | 53 ✅ · 3 ☑️ · 29 ✓ · 7 – | 58 ✅ · 5 ☑️ · 22 ✓ · 7 – | 65 ✅ · 3 ☑️ · 21 ✓ · 3 – |
| [Picker](Picker.md) | 103 | 57 ✅ · 3 ☑️ · 37 ✓ · 3 – | 50 ✅ · 4 ☑️ · 41 ✓ · 5 – | 74 ✅ · 6 ☑️ · 13 ✓ · 5 – | 67 ✅ · 3 ☑️ · 27 ✓ · 6 – | 62 ✅ · 4 ☑️ · 24 ✓ · 13 – | 58 ✅ · 1 ☑️ · 20 ✓ · 16 – |
| [Polygon](Polygon.md) | 93 | 53 ✅ · 3 ☑️ · 36 ✓ · 1 – | 52 ✅ · 4 ☑️ · 36 ✓ · 1 – | 74 ✅ · 6 ☑️ · 10 ✓ · 2 – | 54 ✅ · 3 ☑️ · 29 ✓ · 7 – | 59 ✅ · 5 ☑️ · 22 ✓ · 7 – | 66 ✅ · 3 ☑️ · 21 ✓ · 3 – |
| [Polyline](Polyline.md) | 93 | 53 ✅ · 3 ☑️ · 36 ✓ · 1 – | 52 ✅ · 4 ☑️ · 36 ✓ · 1 – | 74 ✅ · 6 ☑️ · 10 ✓ · 2 – | 54 ✅ · 3 ☑️ · 29 ✓ · 7 – | 59 ✅ · 5 ☑️ · 22 ✓ · 7 – | 66 ✅ · 3 ☑️ · 21 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 83 | 41 ✅ · 3 ☑️ · 36 ✓ · 3 – | 42 ✅ · 3 ☑️ · 36 ✓ · 2 – | 65 ✅ · 5 ☑️ · 10 ✓ · 2 – | 47 ✅ · 2 ☑️ · 27 ✓ · 7 – | 49 ✅ · 4 ☑️ · 23 ✓ · 7 – | 57 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Rectangle](Rectangle.md) | 92 | 54 ✅ · 3 ☑️ · 34 ✓ · 1 – | 53 ✅ · 4 ☑️ · 34 ✓ · 1 – | 73 ✅ · 6 ☑️ · 10 ✓ · 2 – | 53 ✅ · 3 ☑️ · 29 ✓ · 7 – | 60 ✅ · 5 ☑️ · 20 ✓ · 7 – | 67 ✅ · 3 ☑️ · 19 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 98 | 49 ✅ · 4 ☑️ · 37 ✓ · 8 – | 51 ✅ · 3 ☑️ · 38 ✓ · 4 – | 73 ✅ · 5 ☑️ · 13 ✓ · 6 – | 59 ✅ · 3 ☑️ · 27 ✓ · 9 – | 61 ✅ · 3 ☑️ · 24 ✓ · 10 – | 66 ✅ · 2 ☑️ · 21 ✓ · 9 – |
| [SearchField](SearchField.md) | 111 | 61 ✅ · 5 ☑️ · 36 ✓ · 6 – | 68 ✅ · 3 ☑️ · 38 ✓ · 2 – | 89 ✅ · 6 ☑️ · 12 ✓ · 2 – | 69 ✅ · 7 ☑️ · 27 ✓ · 8 – | 70 ✅ · 6 ☑️ · 28 ✓ · 7 – | 85 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Separator](Separator.md) | 81 | 40 ✅ · 3 ☑️ · 36 ✓ · 2 – | 40 ✅ · 3 ☑️ · 36 ✓ · 2 – | 63 ✅ · 5 ☑️ · 10 ✓ · 2 – | 43 ✅ · 3 ☑️ · 28 ✓ · 6 – | 48 ✅ · 4 ☑️ · 22 ✓ · 7 – | 55 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Slider](Slider.md) | 93 | 49 ✅ · 3 ☑️ · 36 ✓ · 3 – | 45 ✅ · 3 ☑️ · 40 ✓ · 5 – | 69 ✅ · 5 ☑️ · 12 ✓ · 6 – | 55 ✅ · 3 ☑️ · 27 ✓ · 6 – | 55 ✅ · 4 ☑️ · 25 ✓ · 9 – | 67 ✅ · 1 ☑️ · 21 ✓ · 4 – |
| [Space](Space.md) | 84 | 45 ✅ · 2 ☑️ · 36 ✓ · 1 – | 44 ✅ · 3 ☑️ · 36 ✓ · 1 – | 67 ✅ · 5 ☑️ · 10 ✓ · 2 – | 48 ✅ · 3 ☑️ · 29 ✓ · 4 – | 52 ✅ · 3 ☑️ · 22 ✓ · 7 – | 58 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Spinner](Spinner.md) | 83 | 40 ✅ · 3 ☑️ · 37 ✓ · 3 – | 42 ✅ · 3 ☑️ · 36 ✓ · 2 – | 65 ✅ · 5 ☑️ · 10 ✓ · 2 – | 44 ✅ · 3 ☑️ · 28 ✓ · 7 – | 50 ✅ · 4 ☑️ · 22 ✓ · 7 – | 57 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Stepper](Stepper.md) | 91 | 50 ✅ · 3 ☑️ · 36 ✓ · 2 – | 45 ✅ · 3 ☑️ · 38 ✓ · 5 – | 67 ✅ · 5 ☑️ · 12 ✓ · 6 – | 54 ✅ · 4 ☑️ · 27 ✓ · 6 – | 56 ✅ · 4 ☑️ · 24 ✓ · 7 – | 65 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Switch](Switch.md) | 92 | 50 ✅ · 3 ☑️ · 36 ✓ · 3 – | 46 ✅ · 3 ☑️ · 38 ✓ · 5 – | 68 ✅ · 6 ☑️ · 12 ✓ · 4 – | 56 ✅ · 3 ☑️ · 27 ✓ · 6 – | 56 ✅ · 3 ☑️ · 25 ✓ · 8 – | 66 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Text](Text.md) | 99 | 57 ✅ · 4 ☑️ · 36 ✓ · 1 – | 59 ✅ · 2 ☑️ · 36 ✓ · 1 – | 80 ✅ · 6 ☑️ · 10 ✓ · 1 – | 62 ✅ · 3 ☑️ · 28 ✓ · 6 – | 65 ✅ · 5 ☑️ · 23 ✓ · 6 – | 73 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 110 | 67 ✅ · 4 ☑️ · 36 ✓ · 3 – | 67 ✅ · 3 ☑️ · 38 ✓ · 2 – | 88 ✅ · 6 ☑️ · 12 ✓ · 2 – | 73 ✅ · 4 ☑️ · 27 ✓ · 6 – | 69 ✅ · 6 ☑️ · 28 ✓ · 7 – | 84 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [TextField](TextField.md) | 113 | 65 ✅ · 5 ☑️ · 36 ✓ · 4 – | 70 ✅ · 3 ☑️ · 38 ✓ · 2 – | 90 ✅ · 6 ☑️ · 12 ✓ · 3 – | 73 ✅ · 6 ☑️ · 27 ✓ · 6 – | 71 ✅ · 6 ☑️ · 28 ✓ · 8 – | 86 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [TimePicker](TimePicker.md) | 99 | 51 ✅ · 3 ☑️ · 37 ✓ · 8 – | 45 ✅ · 2 ☑️ · 38 ✓ · 10 – | 74 ✅ · 6 ☑️ · 13 ✓ · 4 – | 58 ✅ · 4 ☑️ · 27 ✓ · 6 – | 62 ✅ · 4 ☑️ · 25 ✓ · 7 – | 68 ✅ · 2 ☑️ · 21 ✓ · 7 – |
| [VStack](VStack.md) | 92 | 52 ✅ · 2 ☑️ · 36 ✓ · 1 – | 50 ✅ · 3 ☑️ · 37 ✓ · 1 – | 74 ✅ · 5 ☑️ · 11 ✓ · 2 – | 56 ✅ · 3 ☑️ · 27 ✓ · 5 – | 58 ✅ · 3 ☑️ · 23 ✓ · 8 – | 66 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [WebView](WebView.md) | 97 | 55 ✅ · 3 ☑️ · 37 ✓ · 2 – | 53 ✅ · 3 ☑️ · 39 ✓ · 2 – | 74 ✅ · 5 ☑️ · 12 ✓ · 5 – | 56 ✅ · 13 ✓ · 26 – | 62 ✅ · 4 ☑️ · 24 ✓ · 7 – | 65 ✅ · 2 ☑️ · 21 ✓ · 6 – |
| [ZStack](ZStack.md) | 91 | 51 ✅ · 2 ☑️ · 36 ✓ · 1 – | 48 ✅ · 3 ☑️ · 38 ✓ · 1 – | 72 ✅ · 5 ☑️ · 12 ✓ · 2 – | 55 ✅ · 3 ☑️ · 27 ✓ · 5 – | 56 ✅ · 3 ☑️ · 24 ✓ · 8 – | 65 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| ✅ |  | 1899 | 1841 | 2547 | 2016 | 2097 | 2390 |
| ✓ |  | 1343 | 1386 | 398 | 984 | 853 | 755 |
| – |  | 93 | 106 | 193 | 248 | 273 | 144 |
| **Met** | 3469 | **3335** | **3333** | **3138** | **3248** | **3223** | **3289** |
| 🧩 |  | 0 | 0 | 89 | 89 | 89 | 89 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Anchor](Anchor.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](Application.md) | 23 | 11 ✅ · 11 ✓ · 1 – | 13 ✅ · 10 ✓ | 10 ✅ · 1 ☑️ · 11 ✓ · 1 – | 18 ✅ · 4 ✓ · 1 – | 15 ✅ · 6 ✓ · 1 – | 16 ✅ · 1 ☑️ · 6 ✓ |
| [BottomBar](BottomBar.md) | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ☑️ | 1 ✅ |
| [ButtonMenu](ButtonMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](ContextMenu.md) | 0 | ◐ | ◐ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 4 ✅ · 3 – | 7 ✅ |
| [MenuSeparator](MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuToggle](MenuToggle.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 5 ✅ · 2 – | 7 ✅ |
| [NavigationStack](NavigationStack.md) | 11 | 3 ✅ · 3 ☑️ · 2 ✓ · 2 – | 8 ✅ · 1 ✓ · 2 – | 6 ✅ · 2 ☑️ · 1 ✓ · 2 – | 6 ✅ · 1 ☑️ · 2 ✓ · 2 – | 3 ✅ · 2 ☑️ · 1 ✓ · 4 – | 9 ✅ · 1 ☑️ · 1 ✓ |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 14 | 10 ✅ · 1 ✓ | 13 ✅ · 1 ✓ | 12 ✅ · 1 ✓ · 1 – | 12 ✅ · 1 ✓ · 1 – | 11 ✅ · 1 ✓ · 2 – | 12 ✅ · 1 ✓ |
| [Popover](Popover.md) | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [Sheet](Sheet.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [SplitView](SplitView.md) | 14 | 7 ✅ · 3 ☑️ · 1 ✓ · 3 – | 9 ✅ · 3 ✓ · 2 – | 4 ✅ · 4 ☑️ · 4 ✓ · 2 – | 7 ✅ · 3 ☑️ · 2 ✓ · 2 – | 5 ✅ · 4 ☑️ · 1 ✓ · 3 – | 10 ✅ · 3 ☑️ · 1 ✓ |
| [TabView](TabView.md) | 12 | 4 ✅ · 3 ☑️ · 2 ✓ · 2 – | 9 ✅ · 1 ✓ · 2 – | 7 ✅ · 2 ☑️ · 1 ✓ · 2 – | 8 ✅ · 1 ☑️ · 1 ✓ · 2 – | 4 ✅ · 2 ☑️ · 1 ✓ · 4 – | 10 ✅ · 1 ☑️ · 1 ✓ |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](ToolbarButton.md) | 27 | 5 ✅ · 2 ✓ · 18 – | 6 ✅ · 1 ☑️ · 1 ✓ · 19 – | 6 ✅ · 1 ☑️ · 19 – | 8 ✅ · 2 ✓ · 17 – | 8 ✅ · 1 ✓ · 18 – | 27 ✅ |
| [ToolbarGroup](ToolbarGroup.md) | 16 | 6 ✅ · 10 – | 6 ✅ · 10 – | 5 ✅ · 1 ☑️ · 10 – | 7 ✅ · 9 – | 6 ✅ · 10 – | 15 ✅ · 1 – |
| [ToolbarLabel](ToolbarLabel.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ToolbarToggle](ToolbarToggle.md) | 26 | 7 ✅ · 18 – | 8 ✅ · 18 – | 6 ✅ · 1 ☑️ · 18 – | 7 ✅ · 2 ✓ · 17 – | 8 ✅ · 18 – | 26 ✅ |
| [Window](Window.md) | 22 | 14 ✅ · 2 ☑️ · 5 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 2 ✅ · 2 ☑️ · 4 ✓ · 12 – | 16 ✅ · 1 ☑️ · 5 ✓ | 8 ✅ · 3 ☑️ · 4 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 108 | 113 | 90 | 127 | 101 | 167 |
| ✓ |  | 26 | 25 | 23 | 20 | 16 | 14 |
| – |  | 55 | 61 | 72 | 52 | 72 | 16 |
| **Met** | 211 | **189** | **199** | **185** | **199** | **189** | **197** |
| 🧩 |  | 0 | 0 | 6 | 6 | 6 | 6 |
<!-- structure:end -->

## Tiers

Members many elements share, declared once.

<!-- tiers:begin -->
- [AutomationElement](tiers/AutomationElement.md) - What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an arrangement of pages: the name automation finds it by.
- [VisualElement](tiers/VisualElement.md) - What every drawn element has: its size and its bounds, how it is shown and turned, whether it answers input and holds the keyboard focus, the visual states it enters, and what a screen reader says about it.
- [View](tiers/View.md) - What every view a layout positions has: where it sits in its layout, the space kept around it, and the gestures, drags and frame reports it answers.
- [Layout](tiers/Layout.md) - What every layout has: the edges it runs under what stands over its page on, whether its children are clipped or let input through, and how its children come onto the places it gives them.
- [Stack](tiers/Stack.md) - What both stacks have: the space between their children.
- [TextInput](tiers/TextInput.md) - What every field a user types into has: the text's limits and caret, the keyboard it asks for, and the placeholder shown while it is empty.
- [Shape](tiers/Shape.md) - What every drawn shape has: the line along it, how it fits its room, and a transform of its own drawing.
- [FilledShape](tiers/FilledShape.md) - A shape enclosing an area its fill paints - every shape but a line.
- [CorneredShape](tiers/CorneredShape.md) - A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path; neither a line nor an ellipse.
- [TextualElement](tiers/TextualElement.md) - What every element drawing its words itself has: the case they are drawn in, their color, and the words.
- [PointsShape](tiers/PointsShape.md) - What a shape drawn through a list of points has: the points, and which parts of a self-crossing outline count as inside it - a polygon's, joined last back to first, and a polyline's, left open.
- [LineBreakElement](tiers/LineBreakElement.md) - What happens to words too long for their room: they wrap, or they are cut and say so - a text's, a button's caption.
- [PlaceholderElement](tiers/PlaceholderElement.md) - The words an element shows while it holds nothing: a field while it is empty, a picker while nothing is chosen.
- [StyledElement](tiers/StyledElement.md) - The keyed style an element wears from the application's style sheet: a view's, a bar item's.
- [TextElement](tiers/TextElement.md) - The words an element shows: a control's caption, a text's or a field's words, a menu's caption and its items', a bar's label.
- [ShortcutElement](tiers/ShortcutElement.md) - The keys that choose an element from the keyboard while its window is in front: a button, a menu's or a toolbar's item.
- [IconElement](tiers/IconElement.md) - The picture an element shows beside or for its words: a button's, a toolbar label's, a menu entry's, a page's.
- [BackgroundElement](tiers/BackgroundElement.md) - What an element is painted on: a view's, a page's, a window's, a bar item's and a run of text's background.
- [EnabledElement](tiers/EnabledElement.md) - Whether the user's hand reaches an element: a view, a menu, an entry in one, a toolbar's group.
- [ClickElement](tiers/ClickElement.md) - What a control the user chooses reports: a button, a link, a menu's entry, a toolbar's button.
- [RangeElement](tiers/RangeElement.md) - What a control choosing a number in a range holds and reports: a slider, a stepper.
- [SubmitElement](tiers/SubmitElement.md) - What a field the user submits holds and reports: the word its key shows, and the submission.
- [SessionElement](tiers/SessionElement.md) - What a scene and a window report of the user's attention: coming to the front, leaving it, going out of sight.
- [HoverElement](tiers/HoverElement.md) - What an element the pointer comes over and leaves reports: a view, an item on a bar.
- [PressElement](tiers/PressElement.md) - What a control held down and let go of reports: a button, a slider, a bar's button.
- [PresentedElement](tiers/PresentedElement.md) - What a page shown over the one beneath it holds and reports: a sheet, a popover.
- [PopupElement](tiers/PopupElement.md) - What a control whose choices open in a list of their own holds and reports: a picker, a date's and a time's.
- [ToggleElement](tiers/ToggleElement.md) - What a control turned on and off holds and reports: a check box, a switch, a menu's and a toolbar's toggle.
- [TextColorElement](tiers/TextColorElement.md) - The color of text, wherever it is drawn.
- [FontElement](tiers/FontElement.md) - The font text is drawn in: its step of the platform's type ramp, its family, its size, its weight and slant, and whether it follows the user's text-size setting.
- [TextAlignmentElement](tiers/TextAlignmentElement.md) - Where text sits across the space its own element was given.
- [LineHeightElement](tiers/LineHeightElement.md) - How far apart the lines of text are.
- [TrackingElement](tiers/TrackingElement.md) - The space between the letters of words an element draws as written - a text, a button's caption, a run.
- [DecorableTextElement](tiers/DecorableTextElement.md) - The lines drawn through or under text.
- [PaddingElement](tiers/PaddingElement.md) - The space kept inside an element, around what it holds.
- [BorderElement](tiers/BorderElement.md) - What an element draws of its own box: the shape its background, its outline and its cut follow, and the outline.
- [ContentModeElement](tiers/ContentModeElement.md) - How what an element draws fills the room it was given: a picture, a shape.
- [TintElement](tiers/TintElement.md) - A control's one accent color.
- [LanguageElement](tiers/LanguageElement.md) - The language a branch of the interface is written in: the one a screen reader speaks its words in, and whose rules set them - where they break, how they hyphenate.
- [KeyboardElement](tiers/KeyboardElement.md) - An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.
- [FocusElement](tiers/FocusElement.md) - An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.
- [RefreshElement](tiers/RefreshElement.md) - An element the user pulls to refresh what it shows - a scroller, a list.
- [BarElement](tiers/BarElement.md) - What an arrangement declares of the bar while it stands on the visible path: its look.
- [ActionElement](tiers/ActionElement.md) - What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks it.
- [ButtonMenuElement](tiers/ButtonMenuElement.md) - What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow saying so shows.
- [TextAndIconElement](tiers/TextAndIconElement.md) - What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.
- [PageElement](tiers/PageElement.md) - What a page shows about itself - a title and a picture where another container presents it as an item, and what it stands on - and the links its window is given.
- [OpenedLinkElement](tiers/OpenedLinkElement.md) - What hears the links its window is given: a link opened into the application - one chosen elsewhere, its scheme the application's - goes to the window it names, else the one the user came to last, and every page and arrangement there that hears links takes it.
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
