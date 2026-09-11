// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT EVERY RENDER COSTS AND WHAT IT BUILDS, shown while the application runs.
//
// The record is Core/Inspection.swift's; this is what shows it - a panel over
// the window being looked at, or a window of its own - and the one sentence an
// application writes to offer it, `ToolbarItem.inspector`.
//
// IT IS A TREE LIKE ANY OTHER, described by this library and applied by the
// host, and so it is careful about its own cost: its views are muted in the
// record, a render its own state caused is not kept, and it is built again at
// most every `Inspector.pace` milliseconds however fast the application renders
// - a pass landing asks for that, and a burst of them asks once.

/// What each render costs and what it builds, shown while the application
/// runs. This library's own.
///
///     var toolbarItems: [ToolbarItem] { [.inspector] }
///
/// A render is listed as it happens: what caused it, which road it took, how
/// long describing it took in Swift and applying it took in C#, in
/// microseconds, and how many composed views it built and carried. Chosen, a
/// render shows its TREE - every composed view it reached, built with the
/// reason it could not be carried, carried whole, or walked past on the way to
/// one below it - with each one's time, its own and with what is under it.
///
/// It shows as a PANEL over the bottom of the window being looked at, or in a
/// WINDOW of its own where the platform opens windows - a desktop, or a
/// tablet. Nothing is recorded while it is closed or paused, so an application
/// that offers it costs nothing until somebody looks.
public enum Inspector {
    /// Where the inspector shows.
    public enum Presentation: Sendable, Equatable {
        /// Over the bottom of the window being looked at, which goes on
        /// answering every touch above it.
        case panel

        /// In a window of its own - a desktop or a tablet. The application
        /// needs the platform's multi-window support, which a new project has.
        case window
    }

    /// Whether it is showing.
    public static var isOpen: Bool { InspectorModel.shared.presentation != nil }

    /// Shows it, recording from now on.
    ///
    /// - Parameter presentation: where it shows - by default in a window on a
    ///   desktop and as a panel everywhere else.
    public static func open(_ presentation: Presentation? = nil) {
        InspectorModel.shared.open(presentation ?? preferred)
    }

    /// Hides it and stops recording.
    public static func close() {
        InspectorModel.shared.close()
    }

    /// Shows it where it is hidden, and hides it where it shows.
    public static func toggle() {
        isOpen ? close() : open()
    }

    /// How often, at most, the inspector is built again while renders land,
    /// in milliseconds.
    static var pace: Int { 150 }

    /// Where it shows unless told: a desktop has room for a window, and
    /// everything else keeps its screen.
    static var preferred: Presentation {
        offers(.window) && StandardEnvironment.device.idiom == .desktop ? .window : .panel
    }

    /// Whether this platform can show it that way.
    ///
    /// A WINDOW needs the room for one and a platform that opens them - a
    /// desktop or a tablet, and not Android, whose applications have one. A
    /// PANEL needs the host to lay a view over a window, which it does
    /// everywhere but Linux.
    static func offers(_ presentation: Presentation) -> Bool {
        let platform = stateUIPlatform()

        switch presentation {
        case .window:
            let idiom = StandardEnvironment.device.idiom
            return (idiom == .desktop || idiom == .tablet) && !platform.hasPrefix("Android")
        case .panel:
            return !platform.hasPrefix("Linux")
        }
    }

    /// The inspector's own window, while it shows in one - what the renderer
    /// adds after the application's own.
    static var windows: [Node] {
        InspectorModel.shared.presentation == .window ? [InspectorWindow().body] : []
    }

    /// The panel, over the window at `index` in the application's list, if
    /// that is the one being looked at.
    ///
    /// Asked INSIDE the window's build, so the window is the reader of where
    /// the inspector shows and is built again when that moves.
    static func overlay(over index: Int) -> Node? {
        let model = InspectorModel.shared

        guard model.presentation == .panel, model.looking == index else { return nil }

        return .overlay(InspectorPanel())
    }
}

extension ToolbarItem {
    /// The button that shows the inspector and hides it again - for a page's
    /// `toolbarItems`. See `Inspector`.
    ///
    ///     var toolbarItems: [ToolbarItem] { [.inspector] }
    public static var inspector: ToolbarItem {
        ToolbarItem("ⓘ")
            .id("stateui.inspector")
            .automationId("stateui.inspector")
            .onClicked { Inspector.toggle() }
    }
}

/// The button that shows the inspector and hides it again, for anywhere a
/// view goes - a window's title bar, or a page of its own. See `Inspector`.
///
///     TitleBar().trailingContent { InspectorButton() }
public struct InspectorButton: ContentView {
    /// The button.
    public init() {}

    /// The button, as a view.
    public var content: Element {
        Button("ⓘ")
            .fontSize(16)
            .textColor(Look.subtle)
            .backgroundColor(.transparent)
            .padding(10, 2)
            .automationId("stateui.inspector")
            .semanticDescription("Inspector")
            .onClicked { Inspector.toggle() }
    }
}

// MARK: - What it remembers

/// Everything the inspector holds, and the only state it has.
///
/// ONE PLACE, because a render caused by nothing but these is the inspector
/// drawing itself: their storages are what `Inspection.ownStates` holds, and a
/// pass whose causes are all among them is not kept.
final class InspectorModel: @unchecked Sendable {
    /// The one there is.
    static let shared = InspectorModel()

    /// Where it shows, or nothing while it is closed.
    @State var presentation: Inspector.Presentation? = nil

    /// Whether recording is held while it shows.
    @State var paused = false

    /// Moves whenever there is something new to show - which is what the
    /// views that show it read.
    @State var revision = 0

    /// The render chosen, by its number.
    @State var selected: Int? = nil

    /// The window being looked at, by its place in the application's list.
    @State var looking = 0

    /// Whether a rebuild is already asked for.
    private var asking = false

    private init() {}

    /// Shows it, recording from now on if it was closed.
    func open(_ how: Inspector.Presentation) {
        if presentation == nil {
            Inspection.ownViews = [
                String(reflecting: InspectorWindow.self),
                String(reflecting: InspectorPanel.self),
            ]
            Inspection.ownStates = Set([
                $presentation.described.map { ObjectIdentifier($0) },
                $paused.described.map { ObjectIdentifier($0) },
                $revision.described.map { ObjectIdentifier($0) },
                $selected.described.map { ObjectIdentifier($0) },
                $looking.described.map { ObjectIdentifier($0) },
            ].compactMap { $0 })
            Inspection.landed = { [unowned self] in self.landed() }
            Inspection.start()
            paused = false
            selected = nil
        }

        presentation = how
    }

    /// Hides it and stops recording.
    func close() {
        presentation = nil
        Inspection.stop()
    }

    /// Holds recording, or takes it up again.
    func pause() {
        paused.toggle()
        Inspection.recording = !paused && presentation != nil
    }

    /// Forgets every render.
    func clear() {
        selected = nil
        Inspection.clear()
    }

    /// A pass landed, or the host reported on one: asks for the views to be
    /// built again, once for however many arrive in the pace.
    private func landed() {
        guard !asking else { return }

        asking = true

        Task { @MainThread [self] in
            try? await Task.sleep(for: .milliseconds(Inspector.pace))
            asking = false
            revision &+= 1
        }
    }
}

// MARK: - Where it shows

/// The inspector's own window.
struct InspectorWindow: Window {
    var id: AnyHashable? { "stateui.inspector" }

    var title: String? { "Inspector" }

    var width: Double? { 640 }

    var height: Double? { 860 }

    var content: Page { InspectorPage() }

    /// Closed by the reader: the inspector is closed, which is what the state
    /// that opened it says.
    var onDestroying: EventHandler? { { Inspector.close() } }
}

/// The page the inspector's window shows.
///
/// SIDE BY SIDE ON A DESKTOP ALONE: a tablet's window is as likely as not a
/// third of a split screen, where two columns squeeze each other to nothing.
struct InspectorPage: ContentPage {
    @Environment private var device: DeviceInfo

    var title: String? { "Inspector" }

    var backgroundColor: Color? { Look.ground }

    var content: Element { InspectorView(wide: device.idiom == .desktop, windowed: true) }
}

/// The panel: the inspector over the bottom of a window, and nothing over
/// the rest of it.
///
/// THE LAYOUT IT STANDS IN TAKES NO TOUCHES OF ITS OWN, and the host lays it
/// over the whole window: a touch anywhere the panel is not goes through to
/// the page under it, which is what lets an application be used while it is
/// being watched.
struct InspectorPanel: ContentView {
    @Environment private var device: DeviceInfo

    var content: Element {
        let wide = device.idiom != .phone && device.idiom != .unknown

        return Grid {
            Border {
                InspectorView(wide: wide, windowed: false)
            }
            .backgroundColor(Look.ground)
            .stroke(Look.edge)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(14))
            .margin(8)
            .gridRow(1)
        }
        .rowDefinitions(.star(wide ? 1.25 : 1), .star(1))
        .inputTransparent(true)
        .cascadeInputTransparent(false)
    }
}

// MARK: - What it shows

/// The inspector itself: what it can do, the renders, and the one chosen.
struct InspectorView: ContentView {
    /// Whether there is room for the renders and the chosen one side by side.
    let wide: Bool

    /// Whether it is in a window of its own rather than a panel.
    let windowed: Bool

    var content: Element {
        let model = InspectorModel.shared

        // WHAT MAKES THIS THE VIEW BUILT AGAIN when a pass lands. The record
        // itself is plain data, read below without asking anybody.
        _ = model.revision

        let windows = Inspection.windows
        let looking = min(max(model.looking, 0), max(windows.count - 1, 0))
        let window = windows.isEmpty ? nil : windows[looking]
        let passes = Array(Inspection.passes.reversed())
        let chosen = model.selected.flatMap { number in passes.first { $0.number == number } }

        // Each part in a cell of its own, which is what a part answered as a
        // plain view is placed by.
        return Grid {
            Grid { head(model, windows: windows, looking: looking) }
                .gridRow(0)

            Label(summary(passes, window: window?.view, looking: looking))
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreakMode(.tailTruncation)
                .gridRow(1)

            if wide {
                Grid {
                    Grid { list(passes, window: window?.view, looking: looking) }
                        .gridColumn(0)

                    Grid { detail(chosen, window: window?.view, looking: looking) }
                        .gridColumn(1)
                }
                .columnDefinitions(.star(1), .star(1.5))
                .columnSpacing(10)
                .gridRow(2)
            } else if let chosen {
                Grid { detail(chosen, window: window?.view, looking: looking) }
                    .gridRow(2)
            } else {
                Grid { list(passes, window: window?.view, looking: looking) }
                    .gridRow(2)
            }
        }
        .rowDefinitions(.auto, .auto, .star)
        .rowSpacing(6)
        .padding(10, 8)
    }

    /// What it can do: hold the record, forget it, move, and go.
    private func head(
        _ model: InspectorModel,
        windows: [(view: String, title: String)],
        looking: Int
    ) -> Element {
        let moves: Inspector.Presentation = windowed ? .panel : .window

        return VStack {
            // A ROW THAT WRAPS: a window a third of a split screen wide, or a
            // phone held upright, has no room for all of it on one line - and
            // a stack draws what does not fit clipped away, with nothing said.
            FlexLayout {
                Label("Inspector")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(Look.ink)
                    .margin(0, 0, 10, 4)

                Look.action(model.paused ? "Record" : "Pause") { model.pause() }
                Look.action("Clear") { model.clear() }

                if Inspector.offers(moves) {
                    Look.action(windowed ? "As a panel" : "In a window") {
                        Inspector.open(moves)
                    }
                }

                Look.action("Close") { Inspector.close() }
            }
            .wrap(.wrap)
            .alignItems(.center)

            // WHICH WINDOW is looked at, where there is more than one. The
            // panel goes over the one chosen, and the renders are read for it.
            if windows.count > 1 {
                Picker(windows.map(\.title))
                    .selectedIndex(model.$looking)
                    .fontSize(12)
                    .horizontalOptions(.start)
            }
        }
        .spacing(4)
    }

    /// One line about the renders kept, for the window looked at.
    private func summary(_ passes: [InspectedPass], window: String?, looking: Int) -> String {
        guard let last = passes.first else {
            return Inspection.recording
                ? "Waiting for a render. Use the application; every render lands here."
                : "Paused - nothing is being recorded."
        }

        let paused = Inspection.recording ? "" : "paused · "
        let swift = Look.micros(last.describe + last.encode)
        let host = last.host.map { Look.micros($0.read + $0.apply) } ?? "…"

        let renders = passes.count == 1 ? "1 render" : "\(passes.count) renders"

        return "\(paused)\(renders) · the last: Swift \(swift) + C# \(host)"
    }

    /// The renders, newest first.
    private func list(_ passes: [InspectedPass], window: String?, looking: Int) -> Element {
        LazyList(passes, id: \.number) { pass in
            Row(pass: pass, window: window, looking: looking)
        }
        .itemSize(46)
        .selection(InspectorModel.shared.$selected)
    }

    /// The render chosen: its numbers, then its tree.
    private func detail(_ chosen: InspectedPass?, window: String?, looking: Int) -> Element {
        guard let pass = chosen else {
            return Label("Choose a render to see what it built.")
                .fontSize(12)
                .textColor(Look.subtle)
                .verticalOptions(.start)
        }

        let entries = pass.entries.filter { window == nil || $0.window == window }
        let whole = entries.first { $0.depth == 0 }

        return Grid {
            VStack {
                HStack {
                    if !wide {
                        Look.action("‹ Renders") { InspectorModel.shared.selected = nil }
                    }

                    Label("Render #\(pass.number) · \(Look.road(pass.road))")
                        .fontSize(13)
                        .fontAttributes(.bold)
                        .textColor(Look.ink)
                        .verticalOptions(.center)
                }
                .spacing(8)

                Look.line(pass.causes.isEmpty ? "caused by nothing named" : "for " + pass.causes.joined(separator: ", "))
                Look.line(
                    "at \(Look.seconds(pass.at)) · generation \(pass.generation) · "
                        + "\(pass.bytes) bytes")
                Look.line(
                    "Swift  describe \(Look.micros(pass.describe)) · encode \(Look.micros(pass.encode))"
                        + (pass.own > 0 ? " · the inspector's own \(Look.micros(pass.own)), left out" : ""))
                Look.line(host(pass.host))

                if let window {
                    Look.line(
                        "\(window)  Swift \(whole.map { Look.micros($0.micros) } ?? "nothing built")"
                            + (pass.host.map { host in
                                looking < host.windows.count
                                    ? " · C# \(Look.micros(host.windows[looking]))" : ""
                            } ?? ""))
                }

                if pass.truncated {
                    Look.line("only the first \(Inspection.most) views are listed")
                }
            }
            .spacing(2)
            .gridRow(0)

            LazyList(Array(entries.enumerated()), id: \.offset) { item in
                Branch(entry: item.element)
            }
            .itemSize(22)
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(8)
    }

    /// The host's half, in one line.
    private func host(_ host: InspectedHost?) -> String {
        guard let host else { return "C#  not reported yet" }

        return "C#  read \(Look.micros(host.read)) · apply \(Look.micros(host.apply)) · "
            + "\(host.nodes) nodes · \(host.made) made · \(host.kept) kept · \(host.adopted) adopted"
    }
}

/// One render in the list.
private struct Row: ContentView {
    let pass: InspectedPass
    let window: String?
    let looking: Int

    var content: Element {
        let mine = pass.entries.filter { window == nil || $0.window == window }
        let built = mine.filter { if case .built = $0.outcome { return true } else { return false } }.count
        let carried = mine.filter { $0.outcome == .carried }.count
        let swift = Look.micros(pass.describe + pass.encode)
        let host = pass.host.map { Look.micros($0.read + $0.apply) } ?? "…"
        let chosen = InspectorModel.shared.selected == pass.number

        return VStack {
            Label("#\(pass.number)  \(Look.road(pass.road))  "
                + (pass.causes.isEmpty ? "" : "for " + pass.causes.joined(separator: ", ")))
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(mine.isEmpty ? Look.subtle : Look.ink)
                .lineBreakMode(.tailTruncation)

            Label(mine.isEmpty
                ? "Swift \(swift) · C# \(host) · nothing in this window"
                : "Swift \(swift) · C# \(host) · \(built) built · \(carried) carried")
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreakMode(.tailTruncation)
        }
        .spacing(1)
        .padding(8, 4)
        .backgroundColor(chosen ? Look.chosen : .transparent)
    }
}

/// One composed view of the chosen render's tree.
private struct Branch: ContentView {
    let entry: InspectedEntry

    var content: Element {
        let (mark, said, colour): (String, String, Color) = {
            switch entry.outcome {
            case let .built(reason):
                return ("●", "\(reason) · \(Look.micros(entry.micros)) (\(Look.micros(entry.own)) own)",
                    Look.built)
            case .carried:
                return ("○", "carried", Look.carried)
            case .walked:
                return ("·", "walked · \(Look.micros(entry.micros))", Look.subtle)
            }
        }()

        return Label("\(mark) \(entry.view) — \(said)")
            .fontSize(12)
            .textColor(colour)
            .lineBreakMode(.tailTruncation)
            .padding(Double(entry.depth) * 12 + 6, 2)
            .horizontalOptions(.start)
    }
}

// MARK: - How it looks

/// The inspector's colours, words and the one kind of button it has.
enum Look {
    static let ground = Color(light: Color("#F7F6FB"), dark: Color("#1C1A24"))
    static let edge = Color(light: Color("#D6D2E2"), dark: Color("#3A3647"))
    static let ink = Color(light: Color("#1B1A22"), dark: Color("#ECEAF4"))
    static let subtle = Color(light: Color("#6B6878"), dark: Color("#A29FB0"))
    static let built = Color(light: Color("#B4400A"), dark: Color("#FB923C"))
    static let carried = Color(light: Color("#15803D"), dark: Color("#4ADE80"))
    static let chosen = Color(light: Color("#E7E3F3"), dark: Color("#2E2A3B"))

    /// One of the inspector's buttons.
    static func action(_ caption: String, _ run: @escaping () -> Void) -> Element {
        Button(caption)
            .fontSize(12)
            .textColor(ink)
            .backgroundColor(.transparent)
            .borderColor(edge)
            .borderWidth(1)
            .cornerRadius(7)
            .padding(10, 2)
            .margin(0, 0, 6, 4)
            .onClicked { run() }
    }

    /// One line of the chosen render's numbers.
    static func line(_ text: String) -> Element {
        Label(text)
            .fontSize(11)
            .textColor(subtle)
            .lineBreakMode(.tailTruncation)
    }

    /// Microseconds, whole and grouped by thousands.
    static func micros(_ value: Double) -> String {
        let whole = Int(value.rounded())
        var digits = String(whole)
        var grouped = ""

        while digits.count > 3 {
            grouped = " " + digits.suffix(3) + grouped
            digits = String(digits.dropLast(3))
        }

        return digits + grouped + " µs"
    }

    /// Milliseconds as seconds to a tenth.
    static func seconds(_ milliseconds: Double) -> String {
        let tenths = Int((milliseconds / 100).rounded())

        return "\(tenths / 10).\(tenths % 10) s"
    }

    /// A road, in a word.
    static func road(_ road: InspectedPass.Road) -> String {
        switch road {
        case .walk: return "walk"
        case .build: return "build"
        case .complete: return "complete"
        }
    }
}
