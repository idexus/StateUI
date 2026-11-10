// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI

extension ControlDictionary {
    /// The example opening each contract's page, under its description: one per element and per tier.
    /// Design: docs/design/contracts/dictionary.md#examples
    static let examples: [(contract: any Contract.Type, code: String)] = [
        // MARK: - Elements

        (SpinnerContract.self, #"""
            @State var loading = true

            Spinner(loading)
                .tint(.firebrick)
            """#),

        (AnchorContract.self, #"""
            @State var signedIn = false
            @State var showsHelp = false

            Group {
                if signedIn {
                    Text("Welcome")
                } else {
                    Button("Sign in").onClicked { signedIn = true }
                }
            }
            .sheet(isPresented: $showsHelp) {
                Text("Help")
            }
            """#),

        (ApplicationContract.self, #"""
            struct NotesApp: Application {
                var body: some Scene { WindowGroup { NotesPage() } }
            }

            struct NotesPage: View {
                @Environment(\.window) private var window

                var body: some View {
                    Button("About")
                        .onClicked(policy: .ignoreWhileRunning) { try await window.alert("Notes", message: "Version 1.0") }
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
            .onPointerPressed { point in dot = point }
            """#),

        (CheckBoxContract.self, #"""
            @State var agreed = false

            CheckBox("I agree to the terms", isOn: $agreed)
            """#),

        (ButtonMenuContract.self, #"""
            @State var sent = ""

            Button("Share").menu {
                MenuItem("Mail").onClicked { sent = "mail" }
                MenuItem("Message").onClicked { sent = "message" }
            }
            """#),

        (PopoverContract.self, #"""
            @State var filtering = false

            Button("Filters")
                .onClicked { filtering = true }
                .popover(isPresented: $filtering) {
                    Text("Unread only").padding(12)
                }
            """#),

        (ContextMenuContract.self, #"""
            @State var title = "Groceries"

            Text(title)
                .contextMenu {
                    MenuItem("Rename").onClicked { title = "Shopping" }
                    MenuItem("Clear")
                        .role(.destructive)
                        .onClicked { title = "" }
                }
            """#),

        (DatePickerContract.self, #"""
            @State var birthday = CalendarDate(year: 1990, month: 6, day: 1)

            DatePicker($birthday)
                .minimum(CalendarDate(year: 1900, month: 1, day: 1))
                .maximum(CalendarDate(year: 2026, month: 12, day: 31))
            """#),

        (EllipseContract.self, #"""
            Ellipse()
                .fill(.tomato)
                .width(48)
                .height(48)
            """#),

        (CapsuleContract.self, #"""
            Capsule()
                .fill(.teal)
                .width(120)
                .height(32)
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
            .rows(.automatic, .automatic)
            .columns(.automatic, .fill)
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
                Text(fruit).padding(horizontal: 14, vertical: 10)
            }
            .selection($chosen)
            .onItemActivated { fruit in chosen = fruit }
            """#),

        (TextContract.self, #"""
            Text("A description long enough to wrap onto a second line, and stop there.")
                .maximumLines(2)
                .lineBreak(.tailTruncation)
                .verticalTextAlignment(.center)
                .height(80)
            """#),

        (LineContract.self, #"""
            Line(from: Point(0, 0), to: Point(240, 0))
                .stroke(.lightGray)
                .lineWidth(1)
            """#),

        (MapContract.self, #"""
            @State var tapped = "nowhere yet"

            Map(region: MapRegion(center: Location(latitude: 52.2297, longitude: 21.0122), radiusMeters: 3000))
                .kind(.hybrid)
                .onLocationTapped { place in tapped = "\(place.latitude), \(place.longitude)" }
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
                    .joins(.file)
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

        (ToolbarToggleContract.self, #"""
            @State var showsInspector = false

            Text("Draft")
                .toolbar {
                    ToolbarToggle("Inspector", isOn: $showsInspector)
                        .icon("sidebar.png", on: "sidebar_filled.png")
                }
            """#),

        (ToolbarLabelContract.self, #"""
            @State var unread = 3

            Text("Inbox")
                .toolbar(.bottom) {
                    ToolbarLabel("\(unread) unread")
                        .icon("envelope.png")
                }
            """#),

        (MenuToggleContract.self, #"""
            @State var showsRuler = false

            Text("Draft")
                .contextMenu {
                    MenuToggle("Show Ruler", isOn: $showsRuler)
                        .keyboardShortcut("r")
                }
            """#),

        (SeparatorContract.self, #"""
            VStack {
                Text("Inbox")
                Separator()
                Text("Archive")
            }
            """#),

        (MenuSeparatorContract.self, #"""
            Text("Report.pdf")
                .contextMenu {
                    MenuItem("Open")
                    MenuItem("Rename")
                    MenuSeparator()
                    MenuItem("Delete").role(.destructive)
                }
            """#),

        (SheetContract.self, #"""
            @State var editing = false

            Button("Edit")
                .onClicked { editing = true }
                .sheet(isPresented: $editing) {
                    Button("Done").onClicked { editing = false }
                }
            """#),

        (NavigationStackContract.self, #"""
            struct MainPage: View {
                @State private var path: [Int] = []

                var body: some View {
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
                var body: some View {
                    Text("Nothing written yet.")
                        .pageTitle("Note")
                        .showsBackButton(true)
                }
            }
            """#),

        (PathContract.self, #"""
            Path("M 0,40 L 20,0 L 40,40 Z")
                .fill(.gold)
                .contentMode(.fit)
            """#),

        (PickerContract.self, #"""
            @State var size: String? = "Medium"

            Picker(["Small", "Medium", "Large"], selection: $size)
                .placeholder("Size")
                .presentation(.segmented)
            """#),

        (MarkerContract.self, #"""
            @State var chosen = ""

            Map(region: MapRegion(center: Location(latitude: 52.2479, longitude: 21.0155), radiusMeters: 1500))
                .markers {
                    Marker(at: Location(latitude: 52.2479, longitude: 21.0155))
                        .title("Royal Castle")
                        .subtitle("Plac Zamkowy 4")
                        .onSelected { chosen = "castle" }
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

        (RectangleContract.self, #"""
            Rectangle()
                .fill(.cornflowerBlue)
                .cornerRadius(8)
                .height(60)
            """#),

        (SceneContract.self, #"""
            extension WindowKind where Value == Void {
                static let inspector = WindowKind("notes.inspector")
            }

            struct NotePage: View {
                let title: String
                var body: some View { Text(title) }
            }

            struct NotesScene: Scene {
                var body: some Scene {
                    WindowGroup { NotePage(title: "Notes") }
                    Window(.inspector) { NotePage(title: "Inspector") }
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

        (SpaceContract.self, #"""
            HStack {
                Text("Draft")
                Space()
                Button("Send")
            }
            """#),

        (FillContract.self, #"""
            ZStack {
                Fill(.blur(.regular))
                    .shape(.roundedRectangle(16))

                Text("Over the blur")
            }
            .height(120)
            """#),

        (SliderContract.self, #"""
            @State var volume = 50.0

            Slider($volume)
                .minimum(0)
                .maximum(100)
            """#),

        (TextSpanContract.self, #"""
            Text()
                .spans {
                    TextSpan("Sold out")
                        .textColor(.firebrick)
                        .background(.yellow)
                    TextSpan(" until Monday")
                }
            """#),

        (TextSpansContract.self, #"""
            Text()
                .spans {
                    TextSpan("let ").textColor(.purple)
                    TextSpan("count").fontWeight(.bold)
                    TextSpan(" = 0")
                }
            """#),

        (SplitViewContract.self, #"""
            struct MainPage: View {
                @State private var showsFolders = true

                var body: some View {
                    SplitView {
                        Text("Folders")
                    } detail: {
                        Text("Notes")
                    }
                    .showsSidebar($showsFolders)
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

            Switch("Sound", isOn: $soundOn)
                .tint(.green)
            """#),

        (TabViewContract.self, #"""
            struct Tab: View {
                let name: String

                var body: some View {
                    Text("Nothing in \(name)").pageTitle(name)
                }
            }

            @State var shown = "Today"

            TabView(["Today", "Archive"]) { name in Tab(name: name) }.selection($shown)
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
                .format(.short)
            """#),

        (BottomBarContract.self, #"""
            @State var draft = ""

            Text("Messages")
                .bottomBar {
                    TextEditor($draft).growsWithText(true)
                }
            """#),

        (TitleViewContract.self, #"""
            @State var query = ""

            Text("Results for \(query)")
                .titleView {
                    SearchField($query).placeholder("Search")
                }
            """#),

        (ToolbarButtonContract.self, #"""
            @State var count = 0

            Text("\(count) items")
                .toolbar {
                    ToolbarButton("Add")
                        .icon("add.png")
                        .showsText(true)
                        .onClicked { count += 1 }
                    ToolbarButton("Clear")
                        .placement(at: .overflow)
                        .role(.destructive)
                        .onClicked { count = 0 }
                }
            """#),

        (ToolbarGroupContract.self, #"""
            @State var notes = ""
            @State var edited = false

            TextEditor($notes)
                .onTextChanged { _ in edited = true }
                .toolbar {
                    ToolbarButton("New").placement(at: .start)
                    ToolbarGroup {
                        ToolbarButton("Save")
                            .isEnabled(edited)
                            .onClicked { edited = false }
                        ToolbarButton("Revert")
                            .isEnabled(edited)
                            .onClicked { edited = false }
                    }
                    .placement(order: 1)
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
                    .onClicked(policy: .ignoreWhileRunning) { try await browser.goBack() }
                WebView("https://example.com")
                    .canGoBack(into: $canGoBack)
                    .aim(browser)
                    .gridRow(1)
            }
            .rows(.automatic, .fill)
            """#),

        (WindowContract.self, #"""
            struct NotesApp: Application {
                var body: some Scene { WindowGroup { MainPage() } }
            }

            struct MainPage: View {
                @Environment(\.window) private var window

                var body: some View {
                    Text("Hello")
                        .onCreated {
                            window.title = "Notes"
                            window.minimumWidth = 480
                        }
                }
            }
            """#),

        (MotionLayoutContract.self, #"""
            @State var turn = 0.0

            MotionLayout(["Mural", "Nebula", "Ridge"], parameters: $turn) { name in
                Text(name)
            } placements: { room, phase in
                (0..<3).map { index in
                    Placement(Rect((Double(index) - phase) * 120 + room.width / 2 - 50, 0, 100, room.height))
                }
            }
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .height(160)
            """#),

        (ZStackContract.self, #"""
            ZStack {
                Rectangle()
                    .fill(.cornflowerBlue)
                Text("Bottom right")
                    .horizontalAlignment(.end)
                    .verticalAlignment(.end)
            }
            .height(160)
            """#),

        // MARK: - Tiers

        (AutomationElementContract.self, #"""
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
                .margin(horizontal: 16, vertical: 8)
                .horizontalAlignment(.center)
                .onTapped { taps += 1 }
            """#),

        (LayoutContract.self, #"""
            VStack {
                Text("Edge to edge")
            }
            .background(.steelBlue)
            .ignoresSafeArea(.all)
            .clipsContent(true)
            """#),

        (StackContract.self, #"""
            HStack {
                Button("Cancel")
                Button("Save")
            }
            .spacing(8)
            """#),

        (TextInputContract.self, #"""
            @State var email = ""

            TextField($email)
                .placeholder("name@example.com")
                .inputPurpose(.email)
                .maximumLength(80)
            """#),

        (ShapeContract.self, #"""
            Line(from: Point(0, 0), to: Point(120, 0))
                .stroke(.black)
                .lineWidth(2)
                .dash([4, 2])
                .lineCap(.round)
            """#),

        (FilledShapeContract.self, #"""
            Ellipse()
                .fill(.gold)
                .stroke(.black)
                .width(40)
                .height(40)
            """#),

        (CorneredShapeContract.self, #"""
            Polygon([Point(0, 40), Point(20, 0), Point(40, 40)])
                .stroke(.black)
                .lineWidth(6)
                .lineJoin(.round)
            """#),

        (TextualElementContract.self, #"""
            Button("Continue")
                .textCase(.uppercase)
            """#),

        (TextColorElementContract.self, #"""
            Text("Overdue")
                .textColor(.firebrick)
            """#),

        (TrackingElementContract.self, #"""
            Button("Continue")
                .tracking(1.5)
            """#),

        (FontElementContract.self, #"""
            Text("Total")
                .fontSize(20)
                .fontWeight(.bold)
            """#),

        (TextAlignmentElementContract.self, #"""
            @State var amount = ""

            TextField($amount)
                .horizontalTextAlignment(.end)
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
                .padding(horizontal: 18, vertical: 10)
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

        (ContentModeElementContract.self, #"""
            Button("Delete")
                .icon("trash.png")
                .showsText(false)
                .contentMode(.fit)
            """#),

        (LanguageElementContract.self, #"""
            enum Language: LocaleTag, CaseIterable {
                case english = "en"
                case polish = "pl"
            }

            enum Catalog: LocalizationCatalog {
                static let defaultLanguage = Language.english
            }

            struct LetterPage: View {
                @State private var localization = Localization(Catalog.self, language: .polish)

                var body: some View {
                    Text("Dzień dobry")
                        .environment(localization)
                }
            }
            """#),

        (TintElementContract.self, #"""
            @State var on = true

            Switch($on)
                .tint(.green)
            """#),

        (ToggleElementContract.self, #"""
            @State var wifi = true

            Switch("Wi-Fi", isOn: $wifi)
                .onToggled { on in print("Wi-Fi \(on)") }
            """#),

        (PopupElementContract.self, #"""
            @State var due = CalendarDate(year: 2026, month: 11, day: 7)
            @State var choosing = false

            DatePicker($due)
                .isOpen($choosing)
                .onClosed { print("chosen") }
            """#),

        (PresentedElementContract.self, #"""
            @State var editing = false

            Button("Edit")
                .onClicked { editing = true }
                .sheet(isPresented: $editing) {
                    Text("Editing").padding(16)
                }
            """#),

        (HoverElementContract.self, #"""
            @State var over = false

            Rectangle()
                .fill(over ? .steelBlue : .lightGray)
                .onPointerEntered { over = true }
                .onPointerExited { over = false }
            """#),

        (SessionElementContract.self, #"""
            struct StatusPage: View {
                @Environment(\.window) private var window

                var body: some View {
                    Text(window.phase == .active ? "In front" : "Behind")
                }
            }
            """#),

        (SubmitElementContract.self, #"""
            @State var city = ""

            TextField($city)
                .submitLabel(.done)
                .onSubmitted { print("saved") }
            """#),

        (RangeElementContract.self, #"""
            @State var volume = 5.0

            Slider($volume)
                .minimum(0)
                .maximum(11)
                .onValueChanged { print($0) }
            """#),

        (ClickElementContract.self, #"""
            @State var saved = false

            Button(saved ? "Saved" : "Save")
                .onClicked { saved = true }
            """#),

        (TextElementContract.self, #"""
            @State var count = 0

            Button("Clicked \(count) times")
                .onClicked { count += 1 }
            """#),

        (PlaceholderElementContract.self, #"""
            @State var city = ""

            TextField($city)
                .placeholder("City")
            """#),

        (LineBreakElementContract.self, #"""
            Text("Words enough to take several lines of a narrow label")
                .lineBreak(.tailTruncation)
                .width(120)
            """#),

        (PointsShapeContract.self, #"""
            Polygon([Point(20, 0), Point(40, 40), Point(0, 15), Point(40, 15), Point(0, 40)])
                .fillRule(.evenOdd)
                .fill(.gold)
            """#),

        (ShortcutElementContract.self, #"""
            Button("Save")
                .keyboardShortcut("s")
                .onClicked { print("saved") }
            """#),

        (EnabledElementContract.self, #"""
            @State var name = ""

            Button("Send")
                .isEnabled(!name.isEmpty)
            """#),

        (BackgroundElementContract.self, #"""
            Text("On a colored ground")
                .padding(12)
                .background(.cornflowerBlue)
            """#),

        (IconElementContract.self, #"""
            Button("Share")
                .icon("square.and.arrow.up")
            """#),

        (FocusElementContract.self, #"""
            @State var editing = false

            TextField("Name")
                .isFocused(into: $editing)
            """#),

        (RefreshElementContract.self, #"""
            @State var refreshing = false
            @State var rows = ["First"]

            ItemsView(rows) { Text($0) }
                .isRefreshing($refreshing)
                .onRefreshRequested {
                    rows.insert("Fresh", at: 0)
                    refreshing = false
                }
            """#),

        (KeyboardElementContract.self, #"""
            @State var row = 0

            VStack {
                Text("Row \(row)")
            }
            .onKeyPressed([.upArrow, .downArrow]) { press in
                row += press.key == .upArrow ? -1 : 1
            }
            """#),

        (BarElementContract.self, #"""
            struct MainPage: View {
                @State private var path: [Int] = []

                var body: some View {
                    NavigationStack($path) {
                        Text("Inbox")
                    } destination: { message in
                        Text("Message \(message)")
                    }
                    .barBackground(.cornflowerBlue)
                    .barForegroundColor(.white)
                }
            }
            """#),

        (StyledElementContract.self, #"""
            Button("Save")
                .style(.platform)
            """#),

        (PressElementContract.self, #"""
            Text("Inbox")
                .toolbar {
                    ToolbarButton("Sign out")
                        .shape(.roundedRectangle(12))
                        .visualState(.pressed) { $0.background(.lightGray) }
                }
            """#),

        (ActionElementContract.self, #"""
            @State var deleted = false

            Text(deleted ? "Deleted" : "Report.pdf")
                .contextMenu {
                    MenuItem("Delete")
                        .role(.destructive)
                        .onClicked { deleted = true }
                }
            """#),

        (ColorPickerContract.self, #"""
            @State var tint = Color.steelBlue

            ColorPicker($tint)
            """#),

        (LinkContract.self, #"""
            Link("Terms of use", address: "https://stateui.dev/terms")
            """#),

        (ButtonMenuElementContract.self, #"""
            @State var sorted = "By name"

            Text(sorted)
                .toolbar {
                    ToolbarButton("Sort")
                        .icon("sort.png")
                        .menu {
                            MenuItem("By name").onClicked { sorted = "By name" }
                            MenuItem("By date").onClicked { sorted = "By date" }
                        }
                }
            """#),

        (TextAndIconElementContract.self, #"""
            @State var wordsShown = false

            Button("Delete")
                .icon("trash.png")
                .showsText($wordsShown)
            """#),

        (PageElementContract.self, #"""
            @State var path: [String] = []

            NavigationStack($path) {
                Text("General")
            } destination: { section in
                Text(section)
            }
            .pageTitle("Settings")
            .pageIcon("settings.png")
            """#),
    ]

    /// What an application registers with a host that does not realize a provider's element, shown under the
    /// element's example: the words saying when, and where the hosts' pages show the Gallery's registration, cut from
    /// its heads.
    /// Design: docs/design/contracts/dictionary.md#examples
    static let registrations: [(contract: any ElementContract.Type, words: String)] = [
        (MapContract.self,
         "A host with no map of its own shows the one the application registers with it - its control, the provider "
            + "and the key it needs - and draws the pins as the map's children, as the Gallery's "
            + "[Android](../hosts/android.md#children-a-control-draws) and "
            + "[Web](../hosts/web.md#children-a-control-draws) heads register Google's."),
    ]

    /// The example opening `contract`'s page.
    static func example(of contract: any Contract.Type) -> String? {
        examples.first { ObjectIdentifier($0.contract) == ObjectIdentifier(contract) }?.code
    }
}
