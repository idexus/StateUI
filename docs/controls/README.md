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
| [Button](Button.md) | 107 | 50 ✅ · 2 ☑️ · 12 ✓ · 3 – | 48 ✅ · 1 ☑️ · 14 ✓ · 5 – | 51 ✅ · 5 ☑️ · 3 ✓ · 4 – | 61 ✅ · 1 ☑️ · 2 ✓ · 5 – | 46 ✅ · 2 ☑️ · 15 ✓ · 6 – | 55 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Canvas](Canvas.md) | 76 | 26 ✅ · 2 ☑️ · 10 ✓ | 25 ✅ · 2 ☑️ · 10 ✓ · 1 – | 33 ✅ · 4 ☑️ | 28 ✅ · 1 ☑️ · 3 ✓ · 5 – | 20 ✅ · 2 ☑️ · 10 ✓ · 6 – | 24 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Capsule](Capsule.md) | 83 | 33 ✅ · 2 ☑️ · 10 ✓ | 31 ✅ · 3 ☑️ · 10 ✓ · 1 – | 39 ✅ · 5 ☑️ | 35 ✅ · 1 ☑️ · 3 ✓ · 6 – | 26 ✅ · 3 ☑️ · 10 ✓ · 6 – | 30 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [CheckBox](CheckBox.md) | 86 | 35 ✅ · 2 ☑️ · 10 ✓ · 1 – | 28 ✅ · 2 ☑️ · 13 ✓ · 5 – | 38 ✅ · 4 ☑️ · 2 ✓ · 3 – | 40 ✅ · 1 ☑️ · 2 ✓ · 5 – | 27 ✅ · 2 ☑️ · 13 ✓ · 6 – | 34 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [ColorPicker](ColorPicker.md) | 83 | 32 ✅ · 2 ☑️ · 10 ✓ · 1 – | 26 ✅ · 2 ☑️ · 12 ✓ · 5 – | 45 – | 37 ✅ · 1 ☑️ · 2 ✓ · 5 – | 25 ✅ · 2 ☑️ · 12 ✓ · 6 – | 30 ✅ · 1 ☑️ · 10 ✓ · 4 – |
| [DatePicker](DatePicker.md) | 95 | 37 ✅ · 2 ☑️ · 11 ✓ · 7 – | 27 ✅ · 1 ☑️ · 12 ✓ · 13 – | 43 ✅ · 4 ☑️ · 5 ✓ · 3 – | 47 ✅ · 3 ☑️ · 2 ✓ · 5 – | 34 ✅ · 5 ☑️ · 12 ✓ · 6 – | 38 ✅ · 1 ☑️ · 10 ✓ · 7 – |
| [Ellipse](Ellipse.md) | 83 | 33 ✅ · 2 ☑️ · 10 ✓ | 31 ✅ · 3 ☑️ · 10 ✓ · 1 – | 39 ✅ · 5 ☑️ | 35 ✅ · 1 ☑️ · 3 ✓ · 6 – | 26 ✅ · 3 ☑️ · 10 ✓ · 6 – | 30 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Fill](Fill.md) | 78 | 29 ✅ · 1 ☑️ · 10 ✓ | 27 ✅ · 2 ☑️ · 10 ✓ · 1 – | 36 ✅ · 4 ☑️ | 33 ✅ · 1 ☑️ · 3 ✓ · 3 – | 23 ✅ · 1 ☑️ · 10 ✓ · 6 – | 26 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Grid](Grid.md) | 88 | 38 ✅ · 1 ☑️ · 10 ✓ | 33 ✅ · 3 ☑️ · 12 ✓ · 1 – | 44 ✅ · 4 ☑️ · 2 ✓ | 42 ✅ · 1 ☑️ · 2 ✓ · 4 – | 30 ✅ · 1 ☑️ · 12 ✓ · 7 – | 36 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [HStack](HStack.md) | 88 | 38 ✅ · 1 ☑️ · 10 ✓ | 33 ✅ · 3 ☑️ · 12 ✓ · 1 – | 44 ✅ · 4 ☑️ · 2 ✓ | 42 ✅ · 1 ☑️ · 2 ✓ · 4 – | 30 ✅ · 1 ☑️ · 12 ✓ · 7 – | 36 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Image](Image.md) | 78 | 27 ✅ · 2 ☑️ · 10 ✓ | 26 ✅ · 2 ☑️ · 10 ✓ · 1 – | 33 ✅ · 4 ☑️ | 30 ✅ · 3 ✓ · 6 – | 21 ✅ · 2 ☑️ · 10 ✓ · 6 – | 25 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [ItemsView](ItemsView.md) | 93 | 35 ✅ · 2 ☑️ · 14 ✓ · 4 – | 32 ✅ · 2 ☑️ · 16 ✓ · 5 – | 47 ✅ · 4 ☑️ · 3 ✓ | 44 ✅ · 1 ☑️ · 2 ✓ · 8 – | 32 ✅ · 1 ☑️ · 12 ✓ · 9 – | 37 ✅ · 1 ☑️ · 11 ✓ · 6 – |
| [Line](Line.md) | 84 | 34 ✅ · 2 ☑️ · 10 ✓ | 33 ✅ · 2 ☑️ · 10 ✓ · 1 – | 41 ✅ · 4 ☑️ | 37 ✅ · 3 ✓ · 6 – | 28 ✅ · 2 ☑️ · 10 ✓ · 6 – | 32 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Link](Link.md) | 85 | 33 ✅ · 2 ☑️ · 11 ✓ · 1 – | 27 ✅ · 2 ☑️ · 13 ✓ · 5 – | 36 ✅ · 4 ☑️ · 3 ✓ · 3 – | 38 ✅ · 1 ☑️ · 3 ✓ · 5 – | 26 ✅ · 2 ☑️ · 13 ✓ · 6 – | 32 ✅ · 1 ☑️ · 11 ✓ · 3 – |
| [Map](Map.md) | 83 | 31 ✅ · 2 ☑️ · 11 ✓ · 1 – | 30 ✅ · 2 ☑️ · 11 ✓ · 2 – | 45 🧩 | 45 🧩 | 45 🧩 | 45 🧩 |
| [MotionLayout](MotionLayout.md) | 95 | 32 ✅ · 1 ☑️ · 19 ✓ · 1 – | 29 ✅ · 3 ☑️ · 21 ✓ · 2 – | 43 ✅ · 4 ☑️ · 6 ✓ · 1 – | 37 ✅ · 1 ☑️ · 10 ✓ · 8 – | 25 ✅ · 1 ☑️ · 19 ✓ · 8 – | 37 ✅ · 2 ☑️ · 14 ✓ · 4 – |
| [Path](Path.md) | 86 | 36 ✅ · 2 ☑️ · 10 ✓ | 34 ✅ · 3 ☑️ · 10 ✓ · 1 – | 42 ✅ · 5 ☑️ | 38 ✅ · 1 ☑️ · 3 ✓ · 6 – | 29 ✅ · 3 ☑️ · 10 ✓ · 6 – | 33 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Picker](Picker.md) | 97 | 41 ✅ · 2 ☑️ · 11 ✓ · 2 – | 33 ✅ · 3 ☑️ · 15 ✓ · 5 – | 43 ✅ · 5 ☑️ · 3 ✓ · 3 – | 51 ✅ · 1 ☑️ · 2 ✓ · 5 – | 33 ✅ · 2 ☑️ · 12 ✓ · 12 – | 40 ✅ · 1 ☑️ · 10 ✓ · 6 – |
| [Polygon](Polygon.md) | 87 | 37 ✅ · 2 ☑️ · 10 ✓ | 35 ✅ · 3 ☑️ · 10 ✓ · 1 – | 43 ✅ · 5 ☑️ | 39 ✅ · 1 ☑️ · 3 ✓ · 6 – | 30 ✅ · 3 ☑️ · 10 ✓ · 6 – | 34 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [Polyline](Polyline.md) | 87 | 37 ✅ · 2 ☑️ · 10 ✓ | 35 ✅ · 3 ☑️ · 10 ✓ · 1 – | 43 ✅ · 5 ☑️ | 39 ✅ · 1 ☑️ · 3 ✓ · 6 – | 30 ✅ · 3 ☑️ · 10 ✓ · 6 – | 34 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [ProgressBar](ProgressBar.md) | 77 | 25 ✅ · 2 ☑️ · 10 ✓ · 2 – | 25 ✅ · 2 ☑️ · 10 ✓ · 2 – | 34 ✅ · 4 ☑️ | 31 ✅ · 2 ✓ · 6 – | 20 ✅ · 2 ☑️ · 11 ✓ · 6 – | 25 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Rectangle](Rectangle.md) | 86 | 36 ✅ · 2 ☑️ · 10 ✓ | 34 ✅ · 3 ☑️ · 10 ✓ · 1 – | 42 ✅ · 5 ☑️ | 38 ✅ · 1 ☑️ · 3 ✓ · 6 – | 29 ✅ · 3 ☑️ · 10 ✓ · 6 – | 33 ✅ · 2 ☑️ · 10 ✓ · 3 – |
| [ScrollView](ScrollView.md) | 92 | 33 ✅ · 3 ☑️ · 11 ✓ · 7 – | 34 ✅ · 2 ☑️ · 12 ✓ · 4 – | 43 ✅ · 4 ☑️ · 3 ✓ · 3 – | 43 ✅ · 1 ☑️ · 2 ✓ · 8 – | 32 ✅ · 1 ☑️ · 12 ✓ · 9 – | 34 ✅ · 1 ☑️ · 10 ✓ · 9 – |
| [SearchField](SearchField.md) | 105 | 45 ✅ · 4 ☑️ · 10 ✓ · 5 – | 51 ✅ · 2 ☑️ · 12 ✓ · 2 – | 58 ✅ · 4 ☑️ · 2 ✓ · 1 – | 53 ✅ · 5 ☑️ · 2 ✓ · 7 – | 41 ✅ · 4 ☑️ · 16 ✓ · 6 – | 53 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Separator](Separator.md) | 75 | 24 ✅ · 2 ☑️ · 10 ✓ · 1 – | 23 ✅ · 2 ☑️ · 10 ✓ · 2 – | 32 ✅ · 4 ☑️ | 27 ✅ · 1 ☑️ · 3 ✓ · 5 – | 19 ✅ · 2 ☑️ · 10 ✓ · 6 – | 23 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Slider](Slider.md) | 87 | 33 ✅ · 2 ☑️ · 10 ✓ · 2 – | 28 ✅ · 2 ☑️ · 14 ✓ · 5 – | 39 ✅ · 4 ☑️ · 2 ✓ · 3 – | 39 ✅ · 1 ☑️ · 2 ✓ · 5 – | 26 ✅ · 2 ☑️ · 13 ✓ · 8 – | 35 ✅ · 10 ✓ · 4 – |
| [Space](Space.md) | 78 | 29 ✅ · 1 ☑️ · 10 ✓ | 27 ✅ · 2 ☑️ · 10 ✓ · 1 – | 36 ✅ · 4 ☑️ | 33 ✅ · 1 ☑️ · 3 ✓ · 3 – | 23 ✅ · 1 ☑️ · 10 ✓ · 6 – | 26 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Spinner](Spinner.md) | 77 | 24 ✅ · 2 ☑️ · 11 ✓ · 2 – | 25 ✅ · 2 ☑️ · 10 ✓ · 2 – | 34 ✅ · 4 ☑️ | 28 ✅ · 1 ☑️ · 3 ✓ · 6 – | 21 ✅ · 2 ☑️ · 10 ✓ · 6 – | 25 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Stepper](Stepper.md) | 85 | 34 ✅ · 2 ☑️ · 10 ✓ · 1 – | 28 ✅ · 2 ☑️ · 12 ✓ · 5 – | 37 ✅ · 4 ☑️ · 2 ✓ · 3 – | 38 ✅ · 2 ☑️ · 2 ✓ · 5 – | 27 ✅ · 2 ☑️ · 12 ✓ · 6 – | 33 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Switch](Switch.md) | 86 | 34 ✅ · 2 ☑️ · 10 ✓ · 2 – | 29 ✅ · 2 ☑️ · 12 ✓ · 5 – | 37 ✅ · 4 ☑️ · 2 ✓ · 3 – | 40 ✅ · 1 ☑️ · 2 ✓ · 5 – | 27 ✅ · 1 ☑️ · 13 ✓ · 7 – | 34 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [Text](Text.md) | 93 | 41 ✅ · 2 ☑️ · 10 ✓ · 1 – | 42 ✅ · 1 ☑️ · 10 ✓ · 1 – | 49 ✅ · 4 ☑️ | 47 ✅ · 1 ☑️ · 2 ✓ · 5 – | 36 ✅ · 2 ☑️ · 11 ✓ · 6 – | 41 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TextEditor](TextEditor.md) | 104 | 51 ✅ · 3 ☑️ · 10 ✓ · 2 – | 50 ✅ · 2 ☑️ · 12 ✓ · 2 – | 57 ✅ · 4 ☑️ · 2 ✓ · 1 – | 57 ✅ · 2 ☑️ · 2 ✓ · 5 – | 40 ✅ · 4 ☑️ · 16 ✓ · 6 – | 52 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TextField](TextField.md) | 107 | 49 ✅ · 4 ☑️ · 10 ✓ · 3 – | 53 ✅ · 2 ☑️ · 12 ✓ · 2 – | 59 ✅ · 4 ☑️ · 2 ✓ · 2 – | 57 ✅ · 4 ☑️ · 2 ✓ · 5 – | 42 ✅ · 4 ☑️ · 16 ✓ · 7 – | 54 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [TimePicker](TimePicker.md) | 93 | 35 ✅ · 2 ☑️ · 11 ✓ · 7 – | 28 ✅ · 1 ☑️ · 12 ✓ · 10 – | 43 ✅ · 4 ☑️ · 3 ✓ · 3 – | 42 ✅ · 2 ☑️ · 2 ✓ · 5 – | 33 ✅ · 2 ☑️ · 13 ✓ · 6 – | 36 ✅ · 1 ☑️ · 10 ✓ · 7 – |
| [VStack](VStack.md) | 85 | 35 ✅ · 1 ☑️ · 10 ✓ | 31 ✅ · 3 ☑️ · 11 ✓ · 1 – | 42 ✅ · 4 ☑️ · 1 ✓ | 39 ✅ · 1 ☑️ · 2 ✓ · 4 – | 28 ✅ · 1 ☑️ · 11 ✓ · 7 – | 33 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| [WebView](WebView.md) | 91 | 39 ✅ · 2 ☑️ · 11 ✓ · 1 – | 36 ✅ · 2 ☑️ · 13 ✓ · 2 – | 43 ✅ · 4 ☑️ · 2 ✓ · 3 – | 40 ✅ · 3 ✓ · 9 – | 33 ✅ · 2 ☑️ · 12 ✓ · 6 – | 33 ✅ · 1 ☑️ · 10 ✓ · 6 – |
| [ZStack](ZStack.md) | 84 | 34 ✅ · 1 ☑️ · 10 ✓ | 29 ✅ · 3 ☑️ · 12 ✓ · 1 – | 40 ✅ · 4 ☑️ · 2 ✓ | 38 ✅ · 1 ☑️ · 2 ✓ · 4 – | 26 ✅ · 1 ☑️ · 12 ✓ · 7 – | 32 ✅ · 1 ☑️ · 10 ✓ · 3 – |
| ✅ |  | 1295 | 1196 | 1463 | 1443 | 1044 | 1245 |
| ✓ |  | 393 | 435 | 52 | 95 | 430 | 366 |
| – |  | 57 | 106 | 84 | 197 | 238 | 134 |
| **Met** | 3247 | **1745** | **1737** | **1599** | **1735** | **1712** | **1745** |
| 🧩 |  | 0 | 0 | 45 | 45 | 45 | 45 |
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
| [MenuToggle](MenuToggle.md) | 7 | 6 ✅ · 1 ☑️ | 6 ✅ · 1 ☑️ | 5 ✅ · 2 – | 7 ✅ | 5 ✅ · 2 – | 7 ✅ |
| [NavigationStack](NavigationStack.md) | 11 | 3 ✅ · 3 ☑️ · 2 ✓ · 2 – | 8 ✅ · 1 ✓ · 2 – | 6 ✅ · 2 ☑️ · 1 ✓ · 2 – | 7 ✅ · 1 ☑️ · 1 ✓ · 2 – | 3 ✅ · 2 ☑️ · 1 ✓ · 4 – | 9 ✅ · 1 ☑️ · 1 ✓ |
| [Overlay](Overlay.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [Page](Page.md) | 15 | 11 ✅ · 1 ✓ | 14 ✅ · 1 ✓ | 13 ✅ · 1 ✓ · 1 – | 13 ✅ · 1 ✓ · 1 – | 11 ✅ · 1 ✓ · 2 – | 13 ✅ · 1 ✓ |
| [Popover](Popover.md) | 2 | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 1 ✅ · 1 ✓ | 2 ✅ |
| [Scene](Scene.md) | 4 | 4 ✅ | 3 ✅ | 3 ✅ | 4 ✅ | 4 ✅ | 3 ✅ · 1 – |
| [Sheet](Sheet.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [SplitView](SplitView.md) | 16 | 8 ✅ · 3 ☑️ · 1 ✓ · 3 – | 11 ✅ · 3 ✓ · 2 – | 6 ✅ · 4 ☑️ · 4 ✓ · 2 – | 10 ✅ · 3 ☑️ · 1 ✓ · 2 – | 6 ✅ · 4 ☑️ · 1 ✓ · 4 – | 12 ✅ · 3 ☑️ · 1 ✓ |
| [TabView](TabView.md) | 12 | 4 ✅ · 3 ☑️ · 2 ✓ · 2 – | 9 ✅ · 1 ✓ · 2 – | 7 ✅ · 2 ☑️ · 1 ✓ · 2 – | 8 ✅ · 1 ☑️ · 1 ✓ · 2 – | 4 ✅ · 2 ☑️ · 1 ✓ · 4 – | 10 ✅ · 1 ☑️ · 1 ✓ |
| [TextSpan](TextSpan.md) | 12 | 11 ✅ · 1 – | 12 ✅ | 10 ✅ · 1 – | 11 ✅ · 1 – | 12 ✅ | 12 ✅ |
| [TextSpans](TextSpans.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [TitleView](TitleView.md) | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| [ToolbarButton](ToolbarButton.md) | 27 | 5 ✅ · 2 ✓ · 18 – | 6 ✅ · 1 ☑️ · 1 ✓ · 19 – | 6 ✅ · 1 ☑️ · 19 – | 10 ✅ · 17 – | 8 ✅ · 1 ✓ · 18 – | 27 ✅ |
| [ToolbarGroup](ToolbarGroup.md) | 16 | 6 ✅ · 10 – | 6 ✅ · 10 – | 5 ✅ · 1 ☑️ · 10 – | 7 ✅ · 9 – | 6 ✅ · 10 – | 15 ✅ · 1 – |
| [ToolbarLabel](ToolbarLabel.md) | 2 | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ | 2 ✅ |
| [ToolbarToggle](ToolbarToggle.md) | 26 | 7 ✅ · 18 – | 8 ✅ · 18 – | 6 ✅ · 1 ☑️ · 18 – | 9 ✅ · 17 – | 8 ✅ · 18 – | 26 ✅ |
| [Window](Window.md) | 21 | 14 ✅ · 1 ☑️ · 5 ✓ | 3 ✅ · 1 ☑️ · 3 ✓ · 8 – | 3 ✅ · 1 ☑️ · 3 ✓ · 12 – | 20 ✅ · 1 ☑️ | 8 ✅ · 2 ☑️ · 4 ✓ · 7 – | 3 ✅ · 1 ☑️ · 3 ✓ · 14 – |
| ✅ |  | 110 | 116 | 94 | 140 | 102 | 170 |
| ✓ |  | 26 | 24 | 22 | 9 | 16 | 13 |
| – |  | 55 | 61 | 72 | 52 | 73 | 16 |
| **Met** | 213 | **191** | **201** | **188** | **201** | **191** | **199** |
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
