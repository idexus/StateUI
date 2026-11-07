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
| [Button](Button.md) | 106 | 60 ✅ · 3 ☑️ · 38 ✓ · 3 – | 40 ✅ · 1 ☑️ · 12 ✓ · 5 – | 46 ✅ · 4 ☑️ · 2 ✓ · 4 – | 51 ✅ · 1 ☑️ · 2 ✓ · 5 – | 36 ✅ · 3 ☑️ · 14 ✓ · 6 – | 45 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Canvas](Canvas.md) | 75 | 36 ✅ · 3 ☑️ · 36 ✓ | 24 ✅ · 2 ☑️ · 10 ✓ · 1 – | 32 ✅ · 4 ☑️ | 27 ✅ · 1 ☑️ · 3 ✓ · 5 – | 18 ✅ · 3 ☑️ · 10 ✓ · 6 – | 23 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Capsule](Capsule.md) | 82 | 43 ✅ · 3 ☑️ · 36 ✓ | 30 ✅ · 3 ☑️ · 10 ✓ · 1 – | 38 ✅ · 5 ☑️ | 34 ✅ · 1 ☑️ · 3 ✓ · 6 – | 24 ✅ · 4 ☑️ · 10 ✓ · 6 – | 29 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 85 | 45 ✅ · 3 ☑️ · 36 ✓ · 1 – | 26 ✅ · 2 ☑️ · 12 ✓ · 5 – | 35 ✅ · 4 ☑️ · 2 ✓ · 3 – | 37 ✅ · 1 ☑️ · 2 ✓ · 5 – | 23 ✅ · 3 ☑️ · 13 ✓ · 6 – | 31 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [ColorPicker](ColorPicker.md) | 82 | 42 ✅ · 3 ☑️ · 36 ✓ · 1 – | 25 ✅ · 2 ☑️ · 12 ✓ · 5 – | 44 – | 36 ✅ · 1 ☑️ · 2 ✓ · 5 – | 23 ✅ · 3 ☑️ · 12 ✓ · 6 – | 29 ✅ · 1 ☑️ · 10 ✓ · 4 – |
| [DatePicker](DatePicker.md) | 94 | 47 ✅ · 3 ☑️ · 37 ✓ · 7 – | 22 ✅ · 1 ☑️ · 12 ✓ · 13 – | 37 ✅ · 4 ☑️ · 2 ✓ · 3 – | 39 ✅ · 2 ☑️ · 2 ✓ · 5 – | 27 ✅ · 3 ☑️ · 12 ✓ · 6 – | 33 ✅ · 1 ☑️ · 10 ✓ · 4 – |
| [Ellipse](Ellipse.md) | 82 | 43 ✅ · 3 ☑️ · 36 ✓ | 30 ✅ · 3 ☑️ · 10 ✓ · 1 – | 38 ✅ · 5 ☑️ | 34 ✅ · 1 ☑️ · 3 ✓ · 6 – | 24 ✅ · 4 ☑️ · 10 ✓ · 6 – | 29 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Fill](Fill.md) | 77 | 39 ✅ · 2 ☑️ · 36 ✓ | 26 ✅ · 2 ☑️ · 10 ✓ · 1 – | 35 ✅ · 4 ☑️ | 32 ✅ · 1 ☑️ · 3 ✓ · 3 – | 21 ✅ · 2 ☑️ · 10 ✓ · 6 – | 25 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Grid](Grid.md) | 87 | 48 ✅ · 2 ☑️ · 36 ✓ | 32 ✅ · 3 ☑️ · 12 ✓ · 1 – | 43 ✅ · 4 ☑️ · 2 ✓ | 41 ✅ · 1 ☑️ · 2 ✓ · 4 – | 28 ✅ · 2 ☑️ · 12 ✓ · 7 – | 35 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [HStack](HStack.md) | 87 | 48 ✅ · 2 ☑️ · 36 ✓ | 32 ✅ · 3 ☑️ · 12 ✓ · 1 – | 43 ✅ · 4 ☑️ · 2 ✓ | 41 ✅ · 1 ☑️ · 2 ✓ · 4 – | 28 ✅ · 2 ☑️ · 12 ✓ · 7 – | 35 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Image](Image.md) | 77 | 37 ✅ · 3 ☑️ · 36 ✓ | 25 ✅ · 2 ☑️ · 10 ✓ · 1 – | 32 ✅ · 4 ☑️ | 29 ✅ · 3 ✓ · 6 – | 19 ✅ · 3 ☑️ · 10 ✓ · 6 – | 24 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 92 | 45 ✅ · 3 ☑️ · 40 ✓ · 4 – | 31 ✅ · 2 ☑️ · 16 ✓ · 5 – | 46 ✅ · 4 ☑️ · 3 ✓ | 43 ✅ · 1 ☑️ · 2 ✓ · 8 – | 30 ✅ · 2 ☑️ · 12 ✓ · 9 – | 36 ✅ · 1 ☑️ · 11 ✓ · 6 – |
| [Line](Line.md) | 83 | 44 ✅ · 3 ☑️ · 36 ✓ | 32 ✅ · 2 ☑️ · 10 ✓ · 1 – | 40 ✅ · 4 ☑️ | 36 ✅ · 3 ✓ · 6 – | 26 ✅ · 3 ☑️ · 10 ✓ · 6 – | 31 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Link](Link.md) | 84 | 43 ✅ · 3 ☑️ · 37 ✓ · 1 – | 26 ✅ · 2 ☑️ · 13 ✓ · 5 – | 35 ✅ · 4 ☑️ · 3 ✓ · 3 – | 37 ✅ · 1 ☑️ · 3 ✓ · 5 – | 24 ✅ · 3 ☑️ · 13 ✓ · 6 – | 31 ✅ · 1 ☑️ · 11 ✓ · 3 – |
| [Map](Map.md) | 82 | 41 ✅ · 3 ☑️ · 37 ✓ · 1 – | 29 ✅ · 2 ☑️ · 11 ✓ · 2 – | 44 🧩 | 44 🧩 | 44 🧩 | 44 🧩 |
| [MotionLayout](MotionLayout.md) | 94 | 42 ✅ · 2 ☑️ · 45 ✓ · 1 – | 28 ✅ · 3 ☑️ · 21 ✓ · 2 – | 42 ✅ · 4 ☑️ · 6 ✓ · 1 – | 36 ✅ · 1 ☑️ · 10 ✓ · 8 – | 23 ✅ · 2 ☑️ · 19 ✓ · 8 – | 36 ✅ · 2 ☑️ · 14 ✓ · 4 – |
| [Path](Path.md) | 85 | 46 ✅ · 3 ☑️ · 36 ✓ | 33 ✅ · 3 ☑️ · 10 ✓ · 1 – | 41 ✅ · 5 ☑️ | 37 ✅ · 1 ☑️ · 3 ✓ · 6 – | 27 ✅ · 4 ☑️ · 10 ✓ · 6 – | 32 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Picker](Picker.md) | 96 | 51 ✅ · 3 ☑️ · 37 ✓ · 2 – | 31 ✅ · 2 ☑️ · 12 ✓ · 5 – | 39 ✅ · 4 ☑️ · 2 ✓ · 3 – | 42 ✅ · 1 ☑️ · 2 ✓ · 5 – | 27 ✅ · 3 ☑️ · 12 ✓ · 8 – | 34 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Polygon](Polygon.md) | 86 | 47 ✅ · 3 ☑️ · 36 ✓ | 34 ✅ · 3 ☑️ · 10 ✓ · 1 – | 42 ✅ · 5 ☑️ | 38 ✅ · 1 ☑️ · 3 ✓ · 6 – | 28 ✅ · 4 ☑️ · 10 ✓ · 6 – | 33 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Polyline](Polyline.md) | 86 | 47 ✅ · 3 ☑️ · 36 ✓ | 34 ✅ · 3 ☑️ · 10 ✓ · 1 – | 42 ✅ · 5 ☑️ | 38 ✅ · 1 ☑️ · 3 ✓ · 6 – | 28 ✅ · 4 ☑️ · 10 ✓ · 6 – | 33 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 76 | 35 ✅ · 3 ☑️ · 36 ✓ · 2 – | 24 ✅ · 2 ☑️ · 10 ✓ · 2 – | 33 ✅ · 4 ☑️ | 30 ✅ · 2 ✓ · 6 – | 18 ✅ · 3 ☑️ · 11 ✓ · 6 – | 24 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Rectangle](Rectangle.md) | 85 | 46 ✅ · 3 ☑️ · 36 ✓ | 33 ✅ · 3 ☑️ · 10 ✓ · 1 – | 41 ✅ · 5 ☑️ | 37 ✅ · 1 ☑️ · 3 ✓ · 6 – | 27 ✅ · 4 ☑️ · 10 ✓ · 6 – | 32 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 91 | 43 ✅ · 4 ☑️ · 37 ✓ · 7 – | 33 ✅ · 2 ☑️ · 12 ✓ · 4 – | 42 ✅ · 4 ☑️ · 3 ✓ · 3 – | 42 ✅ · 1 ☑️ · 2 ✓ · 8 – | 30 ✅ · 2 ☑️ · 12 ✓ · 9 – | 33 ✅ · 1 ☑️ · 10 ✓ · 9 – |
| [SearchField](SearchField.md) | 104 | 55 ✅ · 5 ☑️ · 36 ✓ · 5 – | 48 ✅ · 2 ☑️ · 12 ✓ · 2 – | 55 ✅ · 4 ☑️ · 2 ✓ · 1 – | 51 ✅ · 4 ☑️ · 2 ✓ · 7 – | 38 ✅ · 4 ☑️ · 16 ✓ · 6 – | 50 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Separator](Separator.md) | 74 | 34 ✅ · 3 ☑️ · 36 ✓ · 1 – | 22 ✅ · 2 ☑️ · 10 ✓ · 2 – | 31 ✅ · 4 ☑️ | 26 ✅ · 1 ☑️ · 3 ✓ · 5 – | 17 ✅ · 3 ☑️ · 10 ✓ · 6 – | 22 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Slider](Slider.md) | 86 | 43 ✅ · 3 ☑️ · 36 ✓ · 2 – | 23 ✅ · 2 ☑️ · 12 ✓ · 5 – | 32 ✅ · 4 ☑️ · 2 ✓ · 3 – | 34 ✅ · 1 ☑️ · 2 ✓ · 5 – | 20 ✅ · 3 ☑️ · 13 ✓ · 6 – | 28 ✅ · 10 ✓ · 4 – |
| [Space](Space.md) | 77 | 39 ✅ · 2 ☑️ · 36 ✓ | 26 ✅ · 2 ☑️ · 10 ✓ · 1 – | 35 ✅ · 4 ☑️ | 32 ✅ · 1 ☑️ · 3 ✓ · 3 – | 21 ✅ · 2 ☑️ · 10 ✓ · 6 – | 25 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Spinner](Spinner.md) | 76 | 34 ✅ · 3 ☑️ · 37 ✓ · 2 – | 24 ✅ · 2 ☑️ · 10 ✓ · 2 – | 33 ✅ · 4 ☑️ | 27 ✅ · 1 ☑️ · 3 ✓ · 6 – | 19 ✅ · 3 ☑️ · 10 ✓ · 6 – | 24 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Stepper](Stepper.md) | 84 | 44 ✅ · 3 ☑️ · 36 ✓ · 1 – | 27 ✅ · 2 ☑️ · 12 ✓ · 5 – | 36 ✅ · 4 ☑️ · 2 ✓ · 3 – | 37 ✅ · 2 ☑️ · 2 ✓ · 5 – | 25 ✅ · 3 ☑️ · 12 ✓ · 6 – | 32 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Switch](Switch.md) | 85 | 44 ✅ · 3 ☑️ · 36 ✓ · 2 – | 26 ✅ · 2 ☑️ · 12 ✓ · 5 – | 34 ✅ · 4 ☑️ · 2 ✓ · 3 – | 37 ✅ · 1 ☑️ · 2 ✓ · 5 – | 23 ✅ · 2 ☑️ · 13 ✓ · 7 – | 31 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Text](Text.md) | 92 | 51 ✅ · 3 ☑️ · 36 ✓ · 1 – | 41 ✅ · 1 ☑️ · 10 ✓ · 1 – | 48 ✅ · 4 ☑️ | 46 ✅ · 1 ☑️ · 2 ✓ · 5 – | 34 ✅ · 3 ☑️ · 11 ✓ · 6 – | 40 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 103 | 61 ✅ · 4 ☑️ · 36 ✓ · 2 – | 49 ✅ · 2 ☑️ · 12 ✓ · 2 – | 56 ✅ · 4 ☑️ · 2 ✓ · 1 – | 56 ✅ · 2 ☑️ · 2 ✓ · 5 – | 38 ✅ · 5 ☑️ · 16 ✓ · 6 – | 51 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TextField](TextField.md) | 106 | 59 ✅ · 5 ☑️ · 36 ✓ · 3 – | 48 ✅ · 2 ☑️ · 12 ✓ · 2 – | 55 ✅ · 4 ☑️ · 2 ✓ · 1 – | 55 ✅ · 2 ☑️ · 2 ✓ · 5 – | 38 ✅ · 4 ☑️ · 16 ✓ · 6 – | 50 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TimePicker](TimePicker.md) | 92 | 45 ✅ · 3 ☑️ · 37 ✓ · 7 – | 25 ✅ · 1 ☑️ · 12 ✓ · 10 – | 37 ✅ · 4 ☑️ · 2 ✓ · 3 – | 39 ✅ · 2 ☑️ · 2 ✓ · 5 – | 27 ✅ · 3 ☑️ · 12 ✓ · 6 – | 33 ✅ · 1 ☑️ · 10 ✓ · 4 – |
| [VStack](VStack.md) | 84 | 45 ✅ · 2 ☑️ · 36 ✓ | 30 ✅ · 3 ☑️ · 11 ✓ · 1 – | 41 ✅ · 4 ☑️ · 1 ✓ | 38 ✅ · 1 ☑️ · 2 ✓ · 4 – | 26 ✅ · 2 ☑️ · 11 ✓ · 7 – | 32 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [WebView](WebView.md) | 90 | 49 ✅ · 3 ☑️ · 37 ✓ · 1 – | 35 ✅ · 2 ☑️ · 13 ✓ · 2 – | 42 ✅ · 4 ☑️ · 2 ✓ · 3 – | 39 ✅ · 3 ✓ · 9 – | 31 ✅ · 3 ☑️ · 12 ✓ · 6 – | 32 ✅ · 1 ☑️ · 10 ✓ · 6 – |
| [ZStack](ZStack.md) | 83 | 44 ✅ · 2 ☑️ · 36 ✓ | 28 ✅ · 3 ☑️ · 12 ✓ · 1 – | 39 ✅ · 4 ☑️ · 2 ✓ | 37 ✅ · 1 ☑️ · 2 ✓ · 4 – | 24 ✅ · 2 ☑️ · 12 ✓ · 7 – | 31 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| ✅ |  | 1665 | 1132 | 1396 | 1371 | 940 | 1174 |
| ✓ |  | 1355 | 427 | 46 | 95 | 428 | 366 |
| – |  | 57 | 106 | 82 | 197 | 231 | 125 |
| **Met** | 3210 | **3077** | **1665** | **1524** | **1663** | **1599** | **1665** |
| 🧩 |  | 0 | 0 | 44 | 44 | 44 | 44 |
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
| [ContextMenu](ContextMenu.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Marker](Marker.md) | 6 | 6 ✅ | 4 ✅ · 2 ✓ | 6 🧩 | 6 🧩 | 6 🧩 | 6 🧩 |
| [Menu](Menu.md) | 2 | 2 ✅ | 1 ✅ · 1 ☑️ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [MenuBar](MenuBar.md) | 1 | 1 ✓ | 1 ✓ | 1 ✅ | 1 ✅ | 1 ✅ | 1 ✅ |
| [MenuItem](MenuItem.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 4 ✅ · 3 – | 7 ✅ |
| [MenuSeparator](MenuSeparator.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [MenuToggle](MenuToggle.md) | 7 | 6 ✅ · 1 ☑️ | 4 ✅ · 1 ☑️ | 3 ✅ · 2 – | 5 ✅ | 3 ✅ · 2 – | 5 ✅ |
| [NavigationStack](NavigationStack.md) | 11 | 3 ✅ · 3 ☑️ · 2 ✓ · 2 – | 8 ✅ · 1 ✓ · 2 – | 6 ✅ · 2 ☑️ · 1 ✓ · 2 – | 7 ✅ · 1 ☑️ · 1 ✓ · 2 – | 3 ✅ · 2 ☑️ · 1 ✓ · 4 – | 9 ✅ · 1 ☑️ · 1 ✓ |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 15 | 11 ✅ · 1 ✓ | 14 ✅ · 1 ✓ | 13 ✅ · 1 ✓ · 1 – | 13 ✅ · 1 ✓ · 1 – | 11 ✅ · 1 ✓ · 2 – | 13 ✅ · 1 ✓ |
| [Popover](Popover.md) | 2 | 1 ✅ · 1 ✓ |  |  |  |  |  |
| [Scene](Scene.md) | 4 | 4 ✅ |  |  |  |  |  |
| [Sheet](Sheet.md) | 2 | 2 ✅ |  |  |  |  |  |
| [SplitView](SplitView.md) | 16 | 8 ✅ · 3 ☑️ · 1 ✓ · 3 – | 11 ✅ · 3 ✓ · 2 – | 6 ✅ · 4 ☑️ · 4 ✓ · 2 – | 10 ✅ · 3 ☑️ · 1 ✓ · 2 – | 6 ✅ · 4 ☑️ · 1 ✓ · 4 – | 12 ✅ · 3 ☑️ · 1 ✓ |
| [TabView](TabView.md) | 12 | 4 ✅ · 3 ☑️ · 2 ✓ · 2 – | 9 ✅ · 1 ✓ · 2 – | 7 ✅ · 2 ☑️ · 1 ✓ · 2 – | 8 ✅ · 1 ☑️ · 1 ✓ · 2 – | 4 ✅ · 2 ☑️ · 1 ✓ · 4 – | 10 ✅ · 1 ☑️ · 1 ✓ |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](ToolbarButton.md) | 27 | 5 ✅ · 2 ✓ · 16 – | 6 ✅ · 1 ☑️ · 1 ✓ · 13 – | 6 ✅ · 1 ☑️ · 13 – | 10 ✅ · 11 – | 8 ✅ · 1 ✓ · 12 – | 21 ✅ |
| [ToolbarGroup](ToolbarGroup.md) | 16 | 6 ✅ · 8 – | 6 ✅ · 6 – | 5 ✅ · 1 ☑️ · 6 – | 7 ✅ · 5 – | 6 ✅ · 6 – | 11 ✅ · 1 – |
| [ToolbarLabel](ToolbarLabel.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ToolbarToggle](ToolbarToggle.md) | 26 | 7 ✅ · 16 – | 5 ✅ · 12 – | 4 ✅ · 12 – | 6 ✅ · 11 – | 5 ✅ · 12 – | 17 ✅ |
| [Window](Window.md) | 21 | 13 ✅ · 1 ☑️ · 6 ✓ |  |  |  |  |  |
| ✅ |  | 109 | 102 | 81 | 108 | 82 | 139 |
| ✓ |  | 27 | 20 | 18 | 8 | 11 | 10 |
| – |  | 49 | 37 | 44 | 36 | 50 | 1 |
| **Met** | 213 | **185** | **159** | **143** | **152** | **143** | **150** |
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
- [ImageElement](tiers/ImageElement.md) - How a picture fills the room it was given.
- [TintElement](tiers/TintElement.md) - A control's one accent color.
- [KeyboardElement](tiers/KeyboardElement.md) - An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and so hear the keys it takes.
- [FocusElement](tiers/FocusElement.md) - An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.
- [RefreshElement](tiers/RefreshElement.md) - An element the user pulls to refresh what it shows - a scroller, a list.
- [BarElement](tiers/BarElement.md) - What an arrangement declares of the bar while it stands on the visible path: its look.
- [BarItemElement](tiers/BarItemElement.md) - What an item standing on a bar - a button, a setting or a group of them - shows of its own where its host draws the bar itself: the keyed style it wears, what its surface is made of, and the pointer over it its visual states follow.
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
