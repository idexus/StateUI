// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI

extension ControlDictionary {
    /// The example opening each contract's page, under its description: one per element and per tier.
    /// Design: docs/design/contracts/dictionary.md#examples
    static let examples: [(contract: any Contract.Type, code: String)] = [
        // MARK: - Elements

        (ActivityIndicatorContract.self, #"""
            @State var loading = true

            ActivityIndicator(loading)
                .tint(.firebrick)
            """#),

        (ApplicationContract.self, #"""
            struct NotesApp: Application {
                var scene: any Scene { NotesWindow() }
            }

            struct NotesWindow: Window {
                var page: any Page {
                    Button("About")
                        .onClicked { try await Dialogs.alert("Notes", message: "Version 1.0") }
                }
            }
            """#),

        (ButtonContract.self, #"""
            @State var count = 0

            Button("Pressed \(count) times")
                .onClicked { count += 1 }
            """#),

        (CanvasContract.self, #"""
            @State var dot = Point(40, 40)

            Canvas {
                Draw.fillColor(.cornflowerBlue)
                Draw.fillEllipse(x: dot.x - 8, y: dot.y - 8, width: 16, height: 16)
            }
            .height(120)
            .onPressed { point in dot = point }
            """#),

        (CheckBoxContract.self, #"""
            @State var agreed = false

            HStack {
                CheckBox($agreed)
                Text("I agree to the terms")
            }
            .spacing(8)
            """#),

        (ColorBoxContract.self, #"""
            ColorBox(.cornflowerBlue)
                .cornerRadius(8)
                .height(40)
            """#),

        (ContextMenuContract.self, #"""
            @State var title = "Groceries"

            Text(title)
                .contextMenu {
                    MenuItem("Rename").onClicked { title = "Shopping" }
                    MenuItem("Clear")
                        .isDestructive(true)
                        .onClicked { title = "" }
                }
            """#),

        (DatePickerContract.self, #"""
            @State var birthday = CalendarDate(year: 1990, month: 6, day: 1)

            DatePicker($birthday)
                .minimumDate(CalendarDate(year: 1900, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
            """#),

        (EllipseContract.self, #"""
            Ellipse()
                .fill(.tomato)
                .width(48)
                .height(48)
            """#),

        (GridContract.self, #"""
            @State var name = ""

            Grid {
                Text("Name")
                TextField($name)
                    .gridColumn(1)
                Button("Save")
                    .gridRow(1)
                    .gridColumnSpan(2)
            }
            .rows(.auto, .auto)
            .columns(.auto, .fill)
            .columnSpacing(12)
            """#),

        (HStackContract.self, #"""
            HStack {
                Image("home.png")
                Text("Home")
            }
            .spacing(8)
            """#),

        (ImageContract.self, #"""
            Image("avatar.png")
                .contentMode(.fill)
                .width(64)
                .height(64)
            """#),

        (ItemsViewContract.self, #"""
            @State var chosen: String? = nil

            ItemsView(["Apple", "Banana", "Cherry"]) { fruit in
                Text(fruit).padding(14, 10)
            }
            .selection($chosen)
            .onItemActivated { fruit in chosen = fruit }
            """#),

        (TextContract.self, #"""
            Text("A description long enough to wrap onto a second line, and stop there.")
                .maximumLines(2)
                .lineBreak(.tailTruncation)
            """#),

        (LineContract.self, #"""
            Line()
                .x1(0).y1(0)
                .x2(240).y2(0)
                .stroke(.lightGray)
                .lineWidth(1)
            """#),

        (MapContract.self, #"""
            @State var tapped = "nowhere yet"

            Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
                .mapType(.hybrid)
                .onMapClicked { place in tapped = "\(place.latitude), \(place.longitude)" }
            """#),

        (MenuContract.self, #"""
            @State var order = "Name"

            Text("Sorted by \(order)")
                .menuBar {
                    Menu("View") {
                        Menu("Sort by") {
                            MenuItem("Name").onClicked { order = "Name" }
                            MenuItem("Date").onClicked { order = "Date" }
                        }
                    }
                }
            """#),

        (MenuBarContract.self, #"""
            @State var saved = false

            Text(saved ? "Saved" : "Not saved")
                .menuBar {
                    Menu("File") {
                        MenuItem("Save").onClicked { saved = true }
                    }
                    .id(StandardMenu.file)
                }
            """#),

        (MenuItemContract.self, #"""
            @State var archived = false

            Text("Report.pdf")
                .contextMenu {
                    MenuItem(archived ? "Unarchive" : "Archive")
                        .icon("archive.png")
                        .onClicked { archived.toggle() }
                }
            """#),

        (MenuSeparatorContract.self, #"""
            Text("Report.pdf")
                .contextMenu {
                    MenuItem("Open")
                    MenuItem("Rename")
                    MenuSeparator()
                    MenuItem("Delete").isDestructive(true)
                }
            """#),

        (ModalStackContract.self, #"""
            struct MainWindow: Window {
                @State private var sheets: [String] = []

                var page: any Page {
                    ModalStack($sheets) {
                        Button("Settings").onClicked { sheets.append("Settings") }
                    } destination: { sheet in
                        Button("Close \(sheet)").onClicked { sheets.removeLast() }
                    }
                }
            }
            """#),

        (NavigationStackContract.self, #"""
            struct MainWindow: Window {
                @State private var path: [Int] = []

                var page: any Page {
                    NavigationStack($path) {
                        Button("Open note 1").onClicked { path.append(1) }
                    } destination: { note in
                        Text("Note \(note)")
                    }
                }
            }
            """#),

        (OverlayContract.self, #"""
            @State var offline = true

            Switch($offline)
                .overlays {
                    if offline {
                        Text("Working offline")
                            .horizontalAlignment(.center)
                            .verticalAlignment(.start)
                    }
                }
            """#),

        (PageContract.self, #"""
            struct NotePage: View {
                @Environment private var page: PageSession

                var body: some View {
                    Text("Nothing written yet.")
                        .onCreated {
                            page.title = "Note"
                            page.showsBackButton = true
                        }
                }
            }
            """#),

        (PathContract.self, #"""
            Path("M 0,40 L 20,0 L 40,40 Z")
                .fill(.gold)
                .contentMode(.fit)
            """#),

        (PickerContract.self, #"""
            @State var size = 1

            Picker(["Small", "Medium", "Large"])
                .selectedIndex($size)
                .placeholder("Size")
            """#),

        (PinContract.self, #"""
            @State var chosen = ""

            Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
                .pins {
                    Pin("Royal Castle")
                        .address("Plac Zamkowy 4")
                        .location(latitude: 52.2479, longitude: 21.0155)
                        .onPinClicked { chosen = "castle" }
                }
            """#),

        (PolygonContract.self, #"""
            Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
                .fill(.steelBlue)
            """#),

        (PolylineContract.self, #"""
            Polyline([Point(0, 30), Point(20, 5), Point(40, 25), Point(60, 0)])
                .stroke(.cornflowerBlue)
                .lineWidth(2)
            """#),

        (ProgressBarContract.self, #"""
            @State var done = 0.4

            ProgressBar(done)
                .tint(.firebrick)
            """#),

        (RadioButtonContract.self, #"""
            @State var size = "Medium"

            VStack {
                ForEach(["Small", "Medium", "Large"]) { option in
                    RadioButton(option)
                        .groupName("size")
                        .isOn(option == size)
                        .onToggled { checked in
                            if checked { size = option }
                        }
                }
            }
            """#),

        (RectangleContract.self, #"""
            Rectangle()
                .fill(.cornflowerBlue)
                .cornerRadius(8)
                .height(60)
            """#),

        (SceneContract.self, #"""
            extension WindowType {
                static let inspector = WindowType("notes.inspector")
            }

            struct NoteWindow: Window {
                let title: String
                var page: any Page { Text(title) }
            }

            struct NotesScene: Scene {
                var windows: Windows {
                    Windows {
                        WindowGroup(.inspector) { NoteWindow(title: "Inspector") }
                    } main: {
                        NoteWindow(title: "Notes")
                    }
                }
            }
            """#),

        (ScrollViewContract.self, #"""
            @State var offset = Point.zero

            ScrollView {
                VStack {
                    ForEach(1...100) { row in
                        Text("Row \(row)")
                    }
                }
            }
            .scrollOffset($offset)
            """#),

        (SearchFieldContract.self, #"""
            @State var query = ""

            SearchField($query)
                .placeholder("Search notes")
                .onSubmitted {
                    if query.isEmpty { query = "All notes" }
                }
            """#),

        (SliderContract.self, #"""
            @State var volume = 50.0

            Slider($volume)
                .minimum(0)
                .maximum(100)
            """#),

        (SpanContract.self, #"""
            Text()
                .spans {
                    TextSpan("Sold out")
                        .textColor(.firebrick)
                        .background(.yellow)
                    TextSpan(" until Monday")
                }
            """#),

        (SpansContract.self, #"""
            Text()
                .spans {
                    TextSpan("let ").textColor(.purple)
                    TextSpan("count").fontAttributes(.bold)
                    TextSpan(" = 0")
                }
            """#),

        (SplitViewContract.self, #"""
            struct MainWindow: Window {
                @State private var showsFolders = true

                var page: any Page {
                    SplitView($showsFolders) {
                        Text("Folders")
                    } detail: {
                        Text("Notes")
                    }
                }
            }
            """#),

        (StepperContract.self, #"""
            @State var servings = 4.0

            Stepper($servings)
                .minimum(1)
                .maximum(12)
                .step(1)
            """#),

        (SwitchContract.self, #"""
            @State var soundOn = true

            Switch($soundOn)
                .tint(.green)
            """#),

        (TabbedViewContract.self, #"""
            struct Tab: View {
                let name: String
                @Environment private var page: PageSession

                var body: some View {
                    Text("Nothing in \(name)").onCreated { page.title = name }
                }
            }

            @State var shown = "Today"

            TabbedView(["Today", "Archive"]) { name in Tab(name: name) }
                .selection($shown)
            """#),

        (TextEditorContract.self, #"""
            @State var notes = ""

            TextEditor($notes)
                .placeholder("Anything worth remembering")
                .growsWithText(true)
            """#),

        (TextFieldContract.self, #"""
            @State var name = ""
            @State var greeting = ""

            TextField($name)
                .placeholder("Your name")
                .showsClearButton(true)
                .onSubmitted { greeting = "Hello, \(name)" }
            """#),

        (TimePickerContract.self, #"""
            @State var alarm = ClockTime(hour: 7, minute: 0)

            TimePicker($alarm)
                .format("t")
            """#),

        (TitleViewContract.self, #"""
            @State var query = ""

            Text("Results for \(query)")
                .titleView {
                    SearchField($query).placeholder("Search")
                }
            """#),

        (ToolbarItemContract.self, #"""
            @State var count = 0

            Text("\(count) items")
                .toolbar {
                    ToolbarItem("Add")
                        .icon("add.png")
                        .showsText(true)
                        .onClicked { count += 1 }
                    ToolbarItem("Clear")
                        .placement(.overflow)
                        .isDestructive(true)
                        .onClicked { count = 0 }
                }
            """#),

        (ToolbarItemsContract.self, #"""
            @State var edited = false

            TextEditor()
                .onTextChanged { _ in edited = true }
                .toolbar(.leading) {
                    ToolbarItem("New")
                }
                .toolbar {
                    ToolbarItem("Save")
                        .isEnabled(edited)
                        .onClicked { edited = false }
                }
            """#),

        (VStackContract.self, #"""
            VStack {
                Text("One")
                Text("Two")
            }
            .spacing(12)
            .padding(24)
            """#),

        (WebViewContract.self, #"""
            @Aim(WebView.self) var browser
            @State var canGoBack = false

            Grid {
                Button("Back")
                    .isEnabled(canGoBack)
                    .onClicked { try await browser.goBack() }
                WebView("https://example.com")
                    .canGoBack($canGoBack)
                    .aim(browser)
                    .gridRow(1)
            }
            .rows(.auto, .fill)
            """#),

        (WindowContract.self, #"""
            struct MainWindow: Window {
                var page: any Page { MainPage() }
            }

            struct MainPage: View {
                @Environment private var window: WindowSession

                var body: some View {
                    Text("Hello")
                        .onCreated {
                            window.title = "Notes"
                            window.minimumWidth = 480
                        }
                }
            }
            """#),

        (ZStackContract.self, #"""
            ZStack {
                ColorBox(.cornflowerBlue)
                Text("Bottom right")
                    .horizontalAlignment(.end)
                    .verticalAlignment(.end)
            }
            .height(160)
            """#),

        // MARK: - Tiers

        (PropertyContainerContract.self, #"""
            Button("Save")
                .accessibilityIdentifier("editor.save")
            """#),

        (VisualElementContract.self, #"""
            @State var busy = false

            Button("Send")
                .isEnabled(!busy)
                .opacity(busy ? 0.5 : 1)
                .width(120)
                .accessibilityHint("Sends the message")
            """#),

        (ViewContract.self, #"""
            @State var taps = 0

            Text("Tapped \(taps) times")
                .margin(16, 8)
                .horizontalAlignment(.center)
                .onTapped { taps += 1 }
            """#),

        (LayoutContract.self, #"""
            VStack {
                Text("Edge to edge")
            }
            .background(.steelBlue)
            .avoidsSafeArea(.none)
            .clipsContent(true)
            """#),

        (StackBaseContract.self, #"""
            HStack {
                Button("Cancel")
                Button("Save")
            }
            .spacing(8)
            """#),

        (InputViewContract.self, #"""
            @State var email = ""

            TextField($email)
                .placeholder("name@example.com")
                .inputPurpose(.email)
                .maximumLength(80)
            """#),

        (ShapeContract.self, #"""
            Rectangle()
                .fill(.gold)
                .stroke(.black)
                .lineWidth(2)
                .dash([4, 2])
                .height(40)
            """#),

        (TextElementContract.self, #"""
            Button("Continue")
                .textCase(.uppercase)
            """#),

        (TextStyleElementContract.self, #"""
            Text("Overdue")
                .textColor(.firebrick)
                .tracking(1.5)
            """#),

        (FontElementContract.self, #"""
            Text("Total")
                .fontSize(20)
                .fontAttributes(.bold)
            """#),

        (TextAlignmentElementContract.self, #"""
            Text("In the middle")
                .horizontalTextAlignment(.center)
                .verticalTextAlignment(.center)
                .height(80)
            """#),

        (LineHeightElementContract.self, #"""
            Text("A paragraph long enough to wrap onto several lines, read more easily with room between them.")
                .lineHeight(1.4)
            """#),

        (DecorableTextElementContract.self, #"""
            Text("Was 20, now 15")
                .textDecorations(.strikethrough)
            """#),

        (PaddingElementContract.self, #"""
            Button("Save")
                .padding(18, 10)
            """#),

        (BorderElementContract.self, #"""
            VStack {
                Text("Cheese")
                Text("Aged twelve months")
            }
            .padding(14)
            .shape(.roundedRectangle(8))
            .stroke(.lightGray)
            .lineWidth(1)
            """#),

        (ImageElementContract.self, #"""
            Button(icon: "trash.png")
                .contentMode(.fit)
                .accessibilityLabel("Delete")
            """#),

        (TintElementContract.self, #"""
            @State var on = true

            Switch($on)
                .tint(.green)
            """#),

        (BarElementContract.self, #"""
            struct MainWindow: Window {
                @State private var path: [Int] = []

                var page: any Page {
                    NavigationStack($path) {
                        Text("Inbox")
                    } destination: { message in
                        Text("Message \(message)")
                    }
                    .barTitle("Mail")
                    .barBackgroundColor(.cornflowerBlue)
                    .barForegroundColor(.white)
                }
            }
            """#),

        (MenuItemElementContract.self, #"""
            @State var saved = false

            Text(saved ? "Saved" : "Draft")
                .toolbar {
                    ToolbarItem("Save")
                        .icon("save.png")
                        .isEnabled(!saved)
                        .onClicked { saved = true }
                }
            """#),

        (PageElementContract.self, #"""
            @State var path: [String] = []

            NavigationStack($path) {
                Text("General")
            } destination: { section in
                Text(section)
            }
            .title("Settings")
            .icon("settings.png")
            """#),
    ]

    /// What an application registers with a host that does not realize a provider's element, shown under the
    /// element's example: the words saying when, and the host's registration, quoted - it is written against a
    /// host's facade, which no handbook block compiles with.
    /// Design: docs/design/contracts/dictionary.md#examples
    static let registrations: [(contract: any ElementContract.Type, words: String, code: String)] = [
        (MapContract.self,
         "A host with no map of its own shows the one the application registers with it - its control, the provider "
            + "and the key it needs - and draws the pins as the map's children:",
         #"""
            StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
                map.property(MapContract.region) { control, region in … }
                map.children(PinContract.self, members: [PinContract.location, PinContract.pinClicked]) { control, pins in
                    // each pin: its typed values, and its own reports to raise pinClicked on it
                }
            }
            """#),
    ]

    /// The example opening `contract`'s page.
    static func example(of contract: any Contract.Type) -> String? {
        examples.first { ObjectIdentifier($0.contract) == ObjectIdentifier(contract) }?.code
    }
}
