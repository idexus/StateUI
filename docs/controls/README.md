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
| [Button](Button.md) | 107 | 61 ✅ · 2 ☑️ · 39 ✓ · 3 – | 59 ✅ · 1 ☑️ · 41 ✓ · 5 – | 77 ✅ · 5 ☑️ · 14 ✓ · 5 – | 85 ✅ · 2 ☑️ · 14 ✓ · 6 – | 71 ✅ · 3 ☑️ · 27 ✓ · 6 – | 82 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Canvas](Canvas.md) | 79 | 37 ✅ · 2 ☑️ · 40 ✓ | 36 ✅ · 2 ☑️ · 40 ✓ · 1 – | 61 ✅ · 5 ☑️ · 10 ✓ · 2 – | 55 ✅ · 1 ☑️ · 16 ✓ · 6 – | 48 ✅ · 2 ☑️ · 23 ✓ · 6 – | 54 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Capsule](Capsule.md) | 83 | 44 ✅ · 2 ☑️ · 37 ✓ | 42 ✅ · 3 ☑️ · 37 ✓ · 1 – | 65 ✅ · 6 ☑️ · 10 ✓ · 1 – | 59 ✅ · 2 ☑️ · 15 ✓ · 7 – | 51 ✅ · 3 ☑️ · 23 ✓ · 6 – | 57 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 86 | 46 ✅ · 2 ☑️ · 37 ✓ · 1 – | 39 ✅ · 2 ☑️ · 40 ✓ · 5 – | 64 ✅ · 5 ☑️ · 12 ✓ · 4 – | 64 ✅ · 2 ☑️ · 14 ✓ · 6 – | 52 ✅ · 2 ☑️ · 26 ✓ · 6 – | 61 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [ColorPicker](ColorPicker.md) | 83 | 43 ✅ · 2 ☑️ · 37 ✓ · 1 – | 37 ✅ · 2 ☑️ · 39 ✓ · 5 – | 83 – | 61 ✅ · 2 ☑️ · 14 ✓ · 6 – | 50 ✅ · 2 ☑️ · 25 ✓ · 6 – | 57 ✅ · 1 ☑️ · 21 ✓ · 4 – |
| [DatePicker](DatePicker.md) | 95 | 48 ✅ · 2 ☑️ · 38 ✓ · 7 – | 38 ✅ · 1 ☑️ · 39 ✓ · 13 – | 69 ✅ · 5 ☑️ · 15 ✓ · 4 – | 71 ✅ · 4 ☑️ · 14 ✓ · 6 – | 59 ✅ · 3 ☑️ · 27 ✓ · 6 – | 65 ✅ · 1 ☑️ · 21 ✓ · 7 – |
| [Ellipse](Ellipse.md) | 83 | 44 ✅ · 2 ☑️ · 37 ✓ | 42 ✅ · 3 ☑️ · 37 ✓ · 1 – | 65 ✅ · 6 ☑️ · 10 ✓ · 1 – | 59 ✅ · 2 ☑️ · 15 ✓ · 7 – | 51 ✅ · 3 ☑️ · 23 ✓ · 6 – | 57 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Fill](Fill.md) | 78 | 40 ✅ · 1 ☑️ · 37 ✓ | 38 ✅ · 2 ☑️ · 37 ✓ · 1 – | 62 ✅ · 5 ☑️ · 10 ✓ · 1 – | 57 ✅ · 2 ☑️ · 15 ✓ · 4 – | 48 ✅ · 2 ☑️ · 22 ✓ · 6 – | 53 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Grid](Grid.md) | 88 | 49 ✅ · 1 ☑️ · 37 ✓ | 44 ✅ · 3 ☑️ · 39 ✓ · 1 – | 70 ✅ · 5 ☑️ · 12 ✓ · 1 – | 66 ✅ · 2 ☑️ · 14 ✓ · 5 – | 55 ✅ · 2 ☑️ · 24 ✓ · 7 – | 63 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [HStack](HStack.md) | 87 | 48 ✅ · 1 ☑️ · 37 ✓ | 43 ✅ · 3 ☑️ · 39 ✓ · 1 – | 69 ✅ · 5 ☑️ · 12 ✓ · 1 – | 65 ✅ · 2 ☑️ · 14 ✓ · 5 – | 54 ✅ · 2 ☑️ · 24 ✓ · 7 – | 62 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Image](Image.md) | 78 | 38 ✅ · 2 ☑️ · 37 ✓ | 37 ✅ · 2 ☑️ · 37 ✓ · 1 – | 59 ✅ · 5 ☑️ · 10 ✓ · 1 – | 54 ✅ · 1 ☑️ · 15 ✓ · 7 – | 46 ✅ · 2 ☑️ · 23 ✓ · 6 – | 52 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 93 | 45 ✅ · 2 ☑️ · 41 ✓ · 4 – | 42 ✅ · 2 ☑️ · 43 ✓ · 5 – | 71 ✅ · 5 ☑️ · 13 ✓ · 2 – | 67 ✅ · 2 ☑️ · 14 ✓ · 9 – | 56 ✅ · 2 ☑️ · 24 ✓ · 9 – | 63 ✅ · 1 ☑️ · 22 ✓ · 6 – |
| [Line](Line.md) | 86 | 47 ✅ · 2 ☑️ · 37 ✓ | 46 ✅ · 2 ☑️ · 37 ✓ · 1 – | 69 ✅ · 5 ☑️ · 10 ✓ · 1 – | 63 ✅ · 1 ☑️ · 15 ✓ · 7 – | 55 ✅ · 2 ☑️ · 23 ✓ · 6 – | 61 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Link](Link.md) | 85 | 44 ✅ · 2 ☑️ · 38 ✓ · 1 – | 38 ✅ · 2 ☑️ · 40 ✓ · 5 – | 62 ✅ · 5 ☑️ · 13 ✓ · 4 – | 62 ✅ · 2 ☑️ · 15 ✓ · 6 – | 51 ✅ · 2 ☑️ · 26 ✓ · 6 – | 59 ✅ · 1 ☑️ · 22 ✓ · 3 – |
| [Map](Map.md) | 83 | 42 ✅ · 2 ☑️ · 38 ✓ · 1 – | 41 ✅ · 2 ☑️ · 38 ✓ · 2 – | 83 🧩 | 83 🧩 | 83 🧩 | 83 🧩 |
| [MotionLayout](MotionLayout.md) | 95 | 42 ✅ · 1 ☑️ · 46 ✓ · 1 – | 39 ✅ · 3 ☑️ · 48 ✓ · 2 – | 68 ✅ · 5 ☑️ · 16 ✓ · 2 – | 55 ✅ · 2 ☑️ · 27 ✓ · 9 – | 49 ✅ · 2 ☑️ · 31 ✓ · 8 – | 63 ✅ · 2 ☑️ · 25 ✓ · 4 – |
| [Path](Path.md) | 86 | 47 ✅ · 2 ☑️ · 37 ✓ | 45 ✅ · 3 ☑️ · 37 ✓ · 1 – | 68 ✅ · 6 ☑️ · 10 ✓ · 1 – | 62 ✅ · 2 ☑️ · 15 ✓ · 7 – | 54 ✅ · 3 ☑️ · 23 ✓ · 6 – | 60 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Picker](Picker.md) | 97 | 52 ✅ · 2 ☑️ · 38 ✓ · 2 – | 44 ✅ · 3 ☑️ · 42 ✓ · 5 – | 69 ✅ · 6 ☑️ · 13 ✓ · 4 – | 75 ✅ · 2 ☑️ · 14 ✓ · 6 – | 58 ✅ · 2 ☑️ · 25 ✓ · 12 – | 67 ✅ · 1 ☑️ · 21 ✓ · 6 – |
| [Polygon](Polygon.md) | 87 | 48 ✅ · 2 ☑️ · 37 ✓ | 46 ✅ · 3 ☑️ · 37 ✓ · 1 – | 69 ✅ · 6 ☑️ · 10 ✓ · 1 – | 63 ✅ · 2 ☑️ · 15 ✓ · 7 – | 55 ✅ · 3 ☑️ · 23 ✓ · 6 – | 61 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [Polyline](Polyline.md) | 87 | 48 ✅ · 2 ☑️ · 37 ✓ | 46 ✅ · 3 ☑️ · 37 ✓ · 1 – | 69 ✅ · 6 ☑️ · 10 ✓ · 1 – | 63 ✅ · 2 ☑️ · 15 ✓ · 7 – | 55 ✅ · 3 ☑️ · 23 ✓ · 6 – | 61 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 77 | 36 ✅ · 2 ☑️ · 37 ✓ · 2 – | 36 ✅ · 2 ☑️ · 37 ✓ · 2 – | 60 ✅ · 5 ☑️ · 10 ✓ · 1 – | 55 ✅ · 1 ☑️ · 14 ✓ · 7 – | 45 ✅ · 2 ☑️ · 24 ✓ · 6 – | 52 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Rectangle](Rectangle.md) | 86 | 47 ✅ · 2 ☑️ · 37 ✓ | 45 ✅ · 3 ☑️ · 37 ✓ · 1 – | 68 ✅ · 6 ☑️ · 10 ✓ · 1 – | 62 ✅ · 2 ☑️ · 15 ✓ · 7 – | 54 ✅ · 3 ☑️ · 23 ✓ · 6 – | 60 ✅ · 2 ☑️ · 21 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 92 | 44 ✅ · 3 ☑️ · 38 ✓ · 7 – | 45 ✅ · 2 ☑️ · 39 ✓ · 4 – | 68 ✅ · 5 ☑️ · 13 ✓ · 5 – | 67 ✅ · 2 ☑️ · 14 ✓ · 9 – | 57 ✅ · 2 ☑️ · 24 ✓ · 9 – | 61 ✅ · 1 ☑️ · 21 ✓ · 9 – |
| [SearchField](SearchField.md) | 102 | 56 ✅ · 4 ☑️ · 37 ✓ · 2 – | 59 ✅ · 2 ☑️ · 39 ✓ · 2 – | 81 ✅ · 5 ☑️ · 12 ✓ · 2 – | 74 ✅ · 6 ☑️ · 14 ✓ · 8 – | 66 ✅ · 4 ☑️ · 26 ✓ · 6 – | 77 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Separator](Separator.md) | 75 | 35 ✅ · 2 ☑️ · 37 ✓ · 1 – | 34 ✅ · 2 ☑️ · 37 ✓ · 2 – | 58 ✅ · 5 ☑️ · 10 ✓ · 1 – | 51 ✅ · 2 ☑️ · 15 ✓ · 6 – | 44 ✅ · 2 ☑️ · 23 ✓ · 6 – | 50 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Slider](Slider.md) | 87 | 44 ✅ · 2 ☑️ · 37 ✓ · 2 – | 39 ✅ · 2 ☑️ · 41 ✓ · 5 – | 64 ✅ · 5 ☑️ · 12 ✓ · 5 – | 63 ✅ · 2 ☑️ · 14 ✓ · 6 – | 51 ✅ · 2 ☑️ · 26 ✓ · 8 – | 62 ✅ · 21 ✓ · 4 – |
| [Space](Space.md) | 78 | 40 ✅ · 1 ☑️ · 37 ✓ | 38 ✅ · 2 ☑️ · 37 ✓ · 1 – | 62 ✅ · 5 ☑️ · 10 ✓ · 1 – | 57 ✅ · 2 ☑️ · 15 ✓ · 4 – | 48 ✅ · 2 ☑️ · 22 ✓ · 6 – | 53 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Spinner](Spinner.md) | 77 | 35 ✅ · 2 ☑️ · 38 ✓ · 2 – | 36 ✅ · 2 ☑️ · 37 ✓ · 2 – | 60 ✅ · 5 ☑️ · 10 ✓ · 1 – | 52 ✅ · 2 ☑️ · 15 ✓ · 7 – | 46 ✅ · 2 ☑️ · 23 ✓ · 6 – | 52 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Stepper](Stepper.md) | 85 | 45 ✅ · 2 ☑️ · 37 ✓ · 1 – | 39 ✅ · 2 ☑️ · 39 ✓ · 5 – | 62 ✅ · 5 ☑️ · 12 ✓ · 5 – | 62 ✅ · 3 ☑️ · 14 ✓ · 6 – | 52 ✅ · 2 ☑️ · 25 ✓ · 6 – | 60 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Switch](Switch.md) | 86 | 45 ✅ · 2 ☑️ · 37 ✓ · 2 – | 40 ✅ · 2 ☑️ · 39 ✓ · 5 – | 63 ✅ · 5 ☑️ · 12 ✓ · 4 – | 64 ✅ · 2 ☑️ · 14 ✓ · 6 – | 52 ✅ · 2 ☑️ · 25 ✓ · 7 – | 61 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [Text](Text.md) | 93 | 52 ✅ · 2 ☑️ · 37 ✓ · 1 – | 53 ✅ · 1 ☑️ · 37 ✓ · 1 – | 75 ✅ · 5 ☑️ · 10 ✓ · 1 – | 71 ✅ · 2 ☑️ · 14 ✓ · 6 – | 61 ✅ · 2 ☑️ · 24 ✓ · 6 – | 68 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 101 | 59 ✅ · 3 ☑️ · 37 ✓ · 2 – | 58 ✅ · 2 ☑️ · 39 ✓ · 2 – | 80 ✅ · 5 ☑️ · 12 ✓ · 2 – | 78 ✅ · 3 ☑️ · 14 ✓ · 6 – | 65 ✅ · 4 ☑️ · 26 ✓ · 6 – | 76 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [TextField](TextField.md) | 104 | 57 ✅ · 4 ☑️ · 37 ✓ · 3 – | 61 ✅ · 2 ☑️ · 39 ✓ · 2 – | 82 ✅ · 5 ☑️ · 12 ✓ · 3 – | 78 ✅ · 5 ☑️ · 14 ✓ · 6 – | 67 ✅ · 4 ☑️ · 26 ✓ · 7 – | 78 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [TimePicker](TimePicker.md) | 93 | 46 ✅ · 2 ☑️ · 38 ✓ · 7 – | 39 ✅ · 1 ☑️ · 39 ✓ · 10 – | 69 ✅ · 5 ☑️ · 13 ✓ · 4 – | 66 ✅ · 3 ☑️ · 14 ✓ · 6 – | 58 ✅ · 2 ☑️ · 26 ✓ · 6 – | 63 ✅ · 1 ☑️ · 21 ✓ · 7 – |
| [VStack](VStack.md) | 85 | 46 ✅ · 1 ☑️ · 37 ✓ | 42 ✅ · 3 ☑️ · 38 ✓ · 1 – | 68 ✅ · 5 ☑️ · 11 ✓ · 1 – | 63 ✅ · 2 ☑️ · 14 ✓ · 5 – | 53 ✅ · 2 ☑️ · 23 ✓ · 7 – | 60 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| [WebView](WebView.md) | 91 | 50 ✅ · 2 ☑️ · 38 ✓ · 1 – | 47 ✅ · 2 ☑️ · 40 ✓ · 2 – | 69 ✅ · 5 ☑️ · 12 ✓ · 4 – | 50 ✅ · 13 ✓ · 27 – | 58 ✅ · 2 ☑️ · 25 ✓ · 6 – | 60 ✅ · 1 ☑️ · 21 ✓ · 6 – |
| [ZStack](ZStack.md) | 84 | 45 ✅ · 1 ☑️ · 37 ✓ | 40 ✅ · 3 ☑️ · 39 ✓ · 1 – | 66 ✅ · 5 ☑️ · 12 ✓ · 1 – | 62 ✅ · 2 ☑️ · 14 ✓ · 5 – | 51 ✅ · 2 ☑️ · 24 ✓ · 7 – | 59 ✅ · 1 ☑️ · 21 ✓ · 3 – |
| ✅ |  | 1695 | 1593 | 2361 | 2281 | 1946 | 2210 |
| ✓ |  | 1395 | 1437 | 403 | 531 | 880 | 762 |
| – |  | 54 | 106 | 162 | 250 | 238 | 134 |
| **Met** | 3242 | **3144** | **3136** | **2926** | **3062** | **3064** | **3106** |
| 🧩 |  | 0 | 0 | 83 | 83 | 83 | 83 |
<!-- controls:end -->

## Application structure

The scene, the window and the page an application is made of, the arrangements a page can be, the entries of its toolbar and menus, and the slots and parts the others hold.

<!-- structure:begin -->
| Part | Members | AppKit | UIKit | Android Views | WinUI 3 | GTK 4 | Web |
| --- | ---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [Anchor](Anchor.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Application](Application.md) | 24 | 12 ✅ · 11 ✓ · 1 – | 14 ✅ · 10 ✓ | 12 ✅ · 11 ✓ · 1 – | 19 ✅ · 4 ✓ · 1 – | 16 ✅ · 6 ✓ · 1 – | 18 ✅ · 6 ✓ |
| [BottomBar](BottomBar.md) | 1 | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ☑️ | 1 ✅ |
| [ButtonMenu](ButtonMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ContextMenu](ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 4 ✅ · 3 – | 7 ✅ |
| [MenuSeparator](MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuToggle](MenuToggle.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 5 ✅ · 2 – | 7 ✅ |
| [NavigationStack](NavigationStack.md) | 10 | 3 ✅ · 2 ☑️ · 2 ✓ · 2 – | 7 ✅ · 1 ✓ · 2 – | 5 ✅ · 2 ☑️ · 1 ✓ · 2 – | 6 ✅ · 1 ☑️ · 1 ✓ · 2 – | 3 ✅ · 2 ✓ · 4 – | 8 ✅ · 1 ☑️ · 1 ✓ |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 15 | 11 ✅ · 1 ✓ | 14 ✅ · 1 ✓ | 13 ✅ · 1 ✓ · 1 – | 13 ✅ · 1 ✓ · 1 – | 11 ✅ · 1 ✓ · 2 – | 13 ✅ · 1 ✓ |
| [Popover](Popover.md) | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [Sheet](Sheet.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [SplitView](SplitView.md) | 15 | 8 ✅ · 2 ☑️ · 1 ✓ · 3 – | 10 ✅ · 3 ✓ · 2 – | 5 ✅ · 3 ☑️ · 5 ✓ · 2 – | 9 ✅ · 3 ☑️ · 1 ✓ · 2 – | 6 ✅ · 1 ☑️ · 3 ✓ · 4 – | 11 ✅ · 3 ☑️ · 1 ✓ |
| [TabView](TabView.md) | 11 | 4 ✅ · 2 ☑️ · 2 ✓ · 2 – | 8 ✅ · 1 ✓ · 2 – | 6 ✅ · 2 ☑️ · 1 ✓ · 2 – | 7 ✅ · 1 ☑️ · 1 ✓ · 2 – | 4 ✅ · 1 ☑️ · 1 ✓ · 4 – | 9 ✅ · 1 ☑️ · 1 ✓ |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](ToolbarButton.md) | 27 | 5 ✅ · 2 ✓ · 18 – | 6 ✅ · 1 ☑️ · 1 ✓ · 19 – | 6 ✅ · 1 ☑️ · 19 – | 10 ✅ · 17 – | 8 ✅ · 1 ✓ · 18 – | 27 ✅ |
| [ToolbarGroup](ToolbarGroup.md) | 16 | 6 ✅ · 10 – | 6 ✅ · 10 – | 5 ✅ · 1 ☑️ · 10 – | 7 ✅ · 9 – | 6 ✅ · 10 – | 15 ✅ · 1 – |
| [ToolbarLabel](ToolbarLabel.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ToolbarToggle](ToolbarToggle.md) | 26 | 7 ✅ · 18 – | 8 ✅ · 18 – | 6 ✅ · 1 ☑️ · 18 – | 9 ✅ · 17 – | 8 ✅ · 18 – | 26 ✅ |
| [Window](Window.md) | 22 | 14 ✅ · 1 ☑️ · 6 ✓ | 3 ✅ · 1 ☑️ · 4 ✓ · 8 – | 3 ✅ · 1 ☑️ · 4 ✓ · 12 – | 21 ✅ · 1 ☑️ | 8 ✅ · 7 ✓ · 7 – | 3 ✅ · 1 ☑️ · 4 ✓ · 14 – |
| ✅ |  | 111 | 114 | 93 | 139 | 103 | 169 |
| ✓ |  | 27 | 25 | 24 | 9 | 22 | 14 |
| – |  | 55 | 61 | 72 | 52 | 73 | 16 |
| **Met** | 212 | **193** | **200** | **189** | **200** | **198** | **199** |
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
- [BarItemElement](tiers/BarItemElement.md) - What an item standing on a bar - a button, a setting or a group of them - shows of its own where its host draws the bar itself: the keyed style it wears, what its surface is made of, and the pointer over it its visual states follow.
- [BarButtonElement](tiers/BarButtonElement.md) - A button on a bar - an action or a setting: the press its visual states follow, beside the pointer over it every item on a bar reports.
- [MenuItemElement](tiers/MenuItemElement.md) - What every item a user chooses from says - a menu's entry, a toolbar's item, an action or a setting: a caption, a picture, whether it can be chosen, and the keys that choose it.
- [ActionElement](tiers/ActionElement.md) - What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks it.
- [ButtonMenuElement](tiers/ButtonMenuElement.md) - What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow saying so shows.
- [TextAndIconElement](tiers/TextAndIconElement.md) - What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its picture.
- [PageElement](tiers/PageElement.md) - What a page shows about itself - a title and a picture where another container presents it as an item, and what it stands on - and the links its window is given.
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
