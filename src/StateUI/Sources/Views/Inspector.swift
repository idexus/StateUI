// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT EVERY RENDER COSTS AND WHAT IT BUILDS, shown inside the application.
//
// The record is Core/Inspection.swift's; this is what shows it, and the two
// sentences an application writes to offer it: `ToolbarItem.inspector(scene)`,
// the button on a page, and - for a scene that may show it in a window of its
// own - `WindowGroup(.debugInspector) { DebugInspector() }`.
//
// EVERY SCENE HAS ITS OWN, showing that scene's history: the renders that
// reached it, and what each cost there. It opens along the bottom of the
// scene's main window, folded to its last render, and goes from there - opened
// out, down the side, or into the scene's `DebugInspector` window where the
// scene declares one and the platform opens windows: a window of the scene
// like any other, closed with it, hidden with it where its group says so, off
// the Window menu, and back with it when the system restores the
// application's windows. See Views/Scene.swift.
//
// IT IS A TREE LIKE ANY OTHER, described by this library and applied by the
// host, and so it is careful about its own cost: its views are muted in the
// record, a render its own state caused is not kept, and it is built again at
// most every `Inspector.pace` milliseconds however fast the application renders.

/// What each render costs and what it builds, shown inside the application.
/// This library's own.
///
///     @Environment private var scene: SceneSession
///     @Environment private var page: PageSession
///
///     VStack { … }
///         .onCreated { page.toolbarItems = [.inspector(scene)] }
///
/// A render is listed as it happens: what caused it, which road it took, how
/// long describing it took in Swift and applying it took in C#, in
/// microseconds, and how many composed views it built and carried. Chosen, a
/// render shows its TREE - every composed view it reached, built with the
/// reason it could not be carried, carried whole, or walked past on the way to
/// one below it - with each one's time, its own and with what is under it.
///
/// EACH SCENE HAS ITS OWN, and shows the renders that reached that scene: the
/// ⓘ is handed the scene it opens, the session its page holds. It opens along
/// the bottom of the scene's main window FOLDED TO ONE LINE - the last render
/// that reached its scene - which leaves the page all but uncovered while it
/// is watched, with two buttons at the end of the line: open it out, and close
/// it. Opened out, the same two fold it again and close it. From its head it
/// docks down the side on a desktop or a tablet, and shows in the scene's own
/// window where the scene declares one:
///
///     WindowGroup(.debugInspector) { DebugInspector() }
///
/// Nothing is recorded while every inspector is closed or paused, so an
/// application that offers it costs nothing until somebody looks.
public enum Inspector {
    /// Where an inspector shows.
    public enum Place: Sendable, Equatable {
        /// Along the bottom of its scene's main window, the page going on
        /// above it - where the ⓘ opens it, folded to one line, the last
        /// render. It opens out again, and folds again.
        case bottom

        /// Down the trailing side of the main window, under the bar.
        case side

        /// In the scene's `DebugInspector` window - where the scene declares
        /// one and the platform opens windows, and docked everywhere else.
        case window
    }

    /// Whether a scene's inspector shows.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func isOpen(in scene: SceneSession) -> Bool {
        scene.record.map(showing(in:)) ?? false
    }

    /// Shows a scene's inspector, and records from now on.
    ///
    ///     @Environment private var scene: SceneSession
    ///
    ///     Button("Inspect").onClicked { Inspector.open(.side, in: scene) }
    ///
    /// - Parameters:
    ///   - place: where it shows, whole - or, left out, along the bottom and
    ///     folded to its last render, which is what the ⓘ does.
    ///   - scene: the scene - the session a view in it holds.
    public static func open(_ place: Place? = nil, in scene: SceneSession) {
        guard let record = scene.record else { return }

        show(in: record, place ?? .bottom, folded: place == nil)
    }

    /// Hides a scene's inspector.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func close(in scene: SceneSession) {
        guard let record = scene.record else { return }

        hide(in: record)
    }

    /// Hides a scene's inspector where it shows, and shows it otherwise.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func toggle(in scene: SceneSession) {
        isOpen(in: scene) ? close(in: scene) : open(in: scene)
    }

    /// How often, at most, an inspector is built again while renders land, in
    /// milliseconds.
    static var pace: Int { 150 }

    /// Whether it may dock down the side: a third of a desktop's or a tablet's
    /// window, where it would be all of a phone's.
    static var offersSide: Bool {
        let idiom = StandardEnvironment.device.idiom
        return idiom == .desktop || idiom == .tablet
    }

    /// Whether a scene's inspector may show in a window of its own: the scene
    /// declares one, and the platform opens windows.
    static func windowed(_ record: SceneRecord) -> Bool {
        record.declared[.debugInspector] != nil && Scenes.opensWindows
    }

    /// Whether a scene's inspector shows, docked or in its window.
    static func showing(in record: SceneRecord) -> Bool {
        InspectorModel.shared.places[record.id] != nil
            || record.windows.contains { $0.type == .debugInspector }
    }

    /// Shows a scene's inspector at a place - docked, where it cannot show in
    /// a window - and records from now on.
    ///
    /// - Parameters:
    ///   - record: the scene.
    ///   - place: where it shows.
    ///   - folded: whether it shows folded to its last render, which a panel
    ///     along the bottom alone can - the ⓘ's way of opening it. Anywhere
    ///     else, and asked for a place, it is shown whole.
    static func show(in record: SceneRecord, _ place: Place, folded: Bool = false) {
        let model = InspectorModel.shared

        if place == .window, windowed(record) {
            model.places[record.id] = nil
            try? record.open(.debugInspector)
        } else {
            if windowed(record) {
                try? record.close(.debugInspector)
            }

            model.places[record.id] = place == .window ? (offersSide ? .side : .bottom) : place
        }

        if folded, model.places[record.id] == .bottom {
            model.fold(record.id)
        } else {
            model.expand(record.id)
        }

        model.record()
    }

    /// Hides a scene's inspector, wherever it shows.
    static func hide(in record: SceneRecord) {
        let model = InspectorModel.shared

        if windowed(record) {
            try? record.close(.debugInspector)
        }

        model.places[record.id] = nil
        model.expand(record.id)
        model.settle()
    }

    /// Forgets the inspector of a scene that has ended: docked, it went with
    /// the scene's main window, and the record stops once no inspector shows.
    static func ended(_ record: SceneRecord) {
        let model = InspectorModel.shared

        guard model.places[record.id] != nil else { return }

        model.places[record.id] = nil
        model.expand(record.id)
        model.settle()
    }

    /// The panel over a scene's main window, if its inspector docks there.
    ///
    /// Asked INSIDE the main window's build, so the window is the reader of
    /// where its inspector docks and is built again when that moves.
    static func panel(in record: SceneRecord) -> Node? {
        guard let place = InspectorModel.shared.places[record.id] else { return nil }

        return .overlay(InspectorPanel(scene: record.id, place: place))
    }
}

extension ToolbarItem {
    /// The button that shows a scene's inspector and hides it again - for a
    /// page's `toolbarItems`. See `Inspector`.
    ///
    ///     @Environment private var scene: SceneSession
    ///     @Environment private var page: PageSession
    ///
    ///     VStack { … }
    ///         .onCreated { page.toolbarItems = [.inspector(scene)] }
    ///
    /// - Parameter scene: the scene whose inspector it shows - the page's own.
    public static func inspector(_ scene: SceneSession) -> ToolbarItem {
        ToolbarItem("ⓘ")
            .id("stateui.inspector")
            .automationId("stateui.inspector")
            .onClicked { Inspector.toggle(in: scene) }
    }
}

/// The button that shows its scene's inspector and hides it again, for
/// anywhere a view goes - a window's title bar, or a page of its own. See
/// `Inspector`.
///
///     TitleBar().trailingContent { InspectorButton() }
public struct InspectorButton: ContentView {
    /// The scene the button is in, whose inspector it shows.
    @Environment private var scene: SceneSession

    /// The button.
    public init() {}

    /// The button, as a view.
    public var content: any View {
        Button("ⓘ")
            .fontSize(16)
            .textColor(Look.subtle)
            .backgroundColor(.transparent)
            .padding(10, 2)
            .automationId("stateui.inspector")
            .semanticDescription("Inspector")
            .onClicked { Inspector.toggle(in: scene) }
    }
}

/// The inspector in a window of its own, beside its scene's main window.
/// This library's own.
///
///     WindowGroup(.debugInspector) { DebugInspector() }
///
/// A window of the scene that declares it, showing the renders that reached
/// that scene - opened by the ⓘ of any of the scene's pages, or by
/// `scene.openWindow(.debugInspector)`. Where a scene declares none, or the
/// platform opens no second window, the inspector docks in the main window
/// instead.
public struct DebugInspector: Window {
    /// The scene it inspects - the one it is a window of.
    @Environment private var scene: SceneSession

    /// The inspector's window.
    public init() {}

    /// The inspector, for its scene.
    public var page: any Page { InspectorPage(scene: scene.id) }
}

// MARK: - What it remembers

/// Everything the inspectors hold, and the only state they have.
///
/// ONE PLACE, because a render caused by nothing but these is an inspector
/// drawing itself: their storages are what `Inspection.ownStates` holds, and a
/// pass whose causes are all among them is not kept.
final class InspectorModel: @unchecked Sendable {
    /// The one there is.
    static let shared = InspectorModel()

    /// Where each scene's inspector docks, by the scene's number - nothing
    /// for a scene whose inspector is not docked.
    @State var places: [String: Inspector.Place] = [:]

    /// The scenes whose inspector, docked along the bottom, is folded to its
    /// last render.
    @State var collapsed: Set<String> = []

    /// Whether recording is held while they show.
    @State var paused = false

    /// Moves whenever there is something new to show - which is what the views
    /// that show it read.
    @State var revision = 0

    /// The render chosen, by its number.
    @State var selected: Int? = nil

    /// How many inspector windows the platform has up - counted by the
    /// inspector's page, as the tree creates and destroys it.
    var windows = 0

    /// Whether a rebuild is already asked for.
    private var asking = false

    private init() {}

    /// Whether any inspector shows, docked or in a window.
    var showing: Bool { !places.isEmpty || windows > 0 }

    /// Holds recording, or takes it up again.
    func pause() {
        paused.toggle()
        Inspection.recording = !paused && showing
    }

    /// Forgets every render.
    func clear() {
        selected = nil
        Inspection.clear()
    }

    /// Opens a scene's inspector out again where it is folded, and writes
    /// nothing where it is not.
    func expand(_ scene: String) {
        if collapsed.contains(scene) {
            collapsed.remove(scene)
        }
    }

    /// Folds a scene's inspector to its last render, and writes nothing where
    /// it already is.
    func fold(_ scene: String) {
        if !collapsed.contains(scene) {
            collapsed.insert(scene)
        }
    }

    /// Records from now on, telling the record what is the inspectors' own -
    /// and starting it afresh where nothing was recording.
    func record() {
        Inspection.ownViews = [
            String(reflecting: InspectorPanel.self),
            String(reflecting: InspectorPage.self),
        ]
        Inspection.ownStates = Set([
            $places.described.map { ObjectIdentifier($0) },
            $collapsed.described.map { ObjectIdentifier($0) },
            $paused.described.map { ObjectIdentifier($0) },
            $revision.described.map { ObjectIdentifier($0) },
            $selected.described.map { ObjectIdentifier($0) },
        ].compactMap { $0 })
        Inspection.landed = { [unowned self] in self.landed() }

        if !Inspection.recording && !paused {
            Inspection.start()
        }
    }

    /// Stops recording once no inspector shows any more.
    func settle() {
        guard !showing else { return }

        selected = nil
        Inspection.stop()
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

/// An inspector docked in its scene's main window, and nothing over the rest
/// of it.
///
/// THE LAYOUT IT STANDS IN TAKES NO TOUCHES OF ITS OWN, and the host lays it
/// over the whole window: a touch anywhere the panel is not goes through to
/// the page under it, which is what lets an application be used while it is
/// being watched.
struct InspectorPanel: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    /// Where it docks.
    let place: Inspector.Place

    @Environment private var device: DeviceInfo

    var content: any View {
        // Read here, so a panel folding or opening out is the one view built
        // again - the window under it standing as it was.
        let collapsed = place == .bottom && InspectorModel.shared.collapsed.contains(scene)
        let wide = place == .bottom && device.idiom != .phone && device.idiom != .unknown

        let panel = Border {
            if collapsed {
                InspectorStrip(scene: scene)
            } else {
                InspectorView(scene: scene, place: place, wide: wide)
            }
        }
        .backgroundColor(Look.ground)
        .stroke(Look.edge)
        .strokeThickness(1)
        .strokeShape(.roundRectangle(14))
        .margin(8)

        if place == .side {
            // UNDER THE BAR, which keeps the page's own buttons - its ⓘ among
            // them - where the reader left them.
            return Grid { panel.gridRow(1).gridColumn(1) }
                .rowDefinitions(.absolute(Look.bar), .star)
                .columnDefinitions(.star, .absolute(Look.side))
                .inputTransparent(true)
                .cascadeInputTransparent(false)
        }

        if collapsed {
            // One line along the bottom, as tall as what it says.
            return Grid { panel.gridRow(1) }
                .rowDefinitions(.star, .auto)
                .inputTransparent(true)
                .cascadeInputTransparent(false)
        }

        return Grid { panel.gridRow(1) }
            .rowDefinitions(.star(wide ? 1.25 : 1), .star(1))
            .inputTransparent(true)
            .cascadeInputTransparent(false)
    }
}

/// The page of an inspector's own window.
struct InspectorPage: ContentPage {
    /// The scene it looks at, by its number.
    let scene: String

    /// The window it is the page of.
    @Environment private var window: WindowSession

    /// The page itself.
    @Environment private var page: PageSession

    var content: any View {
        InspectorView(scene: scene, place: .window, wide: true)
            .onCreated {
                page.backgroundColor = Look.ground
                window.title = "Inspector"
                window.width = 900           // the renders and the one chosen, side by side
                window.height = 760          // a tree of some depth
                window.minimumWidth = 560    // below this the two halves no longer read
                window.minimumHeight = 420   // below this the tree has no room

                // One more place the inspector shows.
                InspectorModel.shared.windows += 1
                InspectorModel.shared.record()
            }
            .onDestroying {
                // Recording stops once nothing shows.
                InspectorModel.shared.windows -= 1
                InspectorModel.shared.settle()
            }
    }
}

// MARK: - What it shows

/// An inspector itself: what it can do, its scene's renders, and the one
/// chosen.
struct InspectorView: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    /// Where it shows.
    let place: Inspector.Place

    /// Whether there is room for the renders and the chosen one side by side.
    let wide: Bool

    var content: any View {
        let model = InspectorModel.shared

        // WHAT MAKES THIS THE VIEW BUILT AGAIN when a pass lands. The record
        // itself is plain data, read below without asking anybody.
        _ = model.revision

        // Shown means recording, however it came to be shown - the ⓘ, or a
        // scene opening its inspector's window by itself.
        model.record()

        let element = ElementId.manual(scene)
        let index = Scenes.shared.index(of: scene)
        let all = Array(Inspection.passes.reversed())
        let passes = InspectorView.history(of: element, in: all)
        let chosen = model.selected.flatMap { number in passes.first { $0.number == number } }

        // Each part in a cell of its own, which is what a part answered as a
        // plain view is placed by.
        return Grid {
            Grid { head(model) }
                .gridRow(0)

            Label(summary(passes, all: all.count, at: index))
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreakMode(.tailTruncation)
                .gridRow(1)

            if wide {
                Grid {
                    Grid { list(passes, scene: element, at: index) }
                        .gridColumn(0)

                    Grid { detail(chosen, scene: element, at: index) }
                        .gridColumn(1)
                }
                .columnDefinitions(.star(1), .star(1.5))
                .columnSpacing(10)
                .gridRow(2)
            } else if let chosen {
                Grid { detail(chosen, scene: element, at: index) }
                    .gridRow(2)
            } else {
                Grid { list(passes, scene: element, at: index) }
                    .gridRow(2)
            }
        }
        .rowDefinitions(.auto, .auto, .star)
        .rowSpacing(6)
        .padding(10, 8)
    }

    /// A scene's history: the renders that reached it, in the order given.
    ///
    /// - Parameters:
    ///   - scene: the scene's element.
    ///   - passes: the renders.
    static func history(of scene: ElementId, in passes: [InspectedPass]) -> [InspectedPass] {
        passes.filter { pass in pass.entries.contains { $0.scene == scene } }
    }

    /// What an inspector says while no render has reached its scene.
    ///
    /// - Parameter all: how many renders there are, in every scene.
    static func waiting(_ all: Int) -> String {
        if !Inspection.recording {
            return "Paused - nothing is being recorded."
        }

        return all == 0
            ? "Waiting for a render. Use the application; every render lands here."
            : "Nothing has reached this scene yet - \(all) renders elsewhere."
    }

    /// What it can do - hold the record, forget it, move, go.
    ///
    /// A ROW THAT WRAPS: a panel down a window's side, or a phone held upright,
    /// has no room for all of it on one line - and a stack draws what does not
    /// fit clipped away, with nothing said.
    private func head(_ model: InspectorModel) -> Element {
        let record = Scenes.shared.record(id: scene)
        let windowed = record.map(Inspector.windowed) ?? false
        let close: () -> Void = {
            if let record {
                Inspector.hide(in: record)
            }
        }

        let actions = FlexLayout {
            Label("Inspector")
                .fontSize(15)
                .fontAttributes(.bold)
                .textColor(Look.ink)
                .margin(0, 0, 10, 4)

            Look.action(model.paused ? "Record" : "Pause") { model.pause() }
            Look.action("Clear") { model.clear() }

            if place == .window {
                Look.action("Dock in the window") {
                    if let record {
                        Inspector.show(in: record, Inspector.offersSide ? .side : .bottom)
                    }
                }
            } else {
                if Inspector.offersSide {
                    Look.action(place == .side ? "Dock at the bottom" : "Dock at the side") {
                        if let record {
                            Inspector.show(in: record, place == .side ? .bottom : .side)
                        }
                    }
                }

                if windowed {
                    Look.action("Open in a window") {
                        if let record {
                            Inspector.show(in: record, .window)
                        }
                    }
                }
            }

            if place != .bottom {
                Look.action("Close", close)
            }
        }
        .wrap(.wrap)
        .alignItems(.center)

        guard place == .bottom else { return actions }

        // ALONG THE BOTTOM THE LAST TWO ARE PICTURES AT THE END OF THE ROW -
        // the same two the folded line ends with, this one folding it where
        // that one opens it out.
        return Grid {
            actions.gridColumn(0)

            HStack {
                Look.icon(Look.folding, "Collapse") { model.fold(scene) }
                Look.icon(Look.closing, "Close", close)
            }
            .verticalOptions(.start)
            .gridColumn(1)
        }
        .columnDefinitions(.star, .auto)
    }

    /// One line about the scene's renders.
    private func summary(_ passes: [InspectedPass], all: Int, at index: Int?) -> String {
        guard let last = passes.first else { return InspectorView.waiting(all) }

        let paused = Inspection.recording ? "" : "paused · "
        let renders = passes.count == 1 ? "1 render" : "\(passes.count) renders"
        let others = all > passes.count ? " (\(all) in all)" : ""
        let swift = Look.micros(last.describe + last.encode)
        let host = last.host.map { Look.micros($0.read + $0.apply) } ?? "…"

        return "\(paused)\(renders) here\(others) · the last: Swift \(swift) + C# \(host)"
    }

    /// The scene's renders, newest first.
    private func list(_ passes: [InspectedPass], scene: ElementId, at index: Int?) -> Element {
        let model = InspectorModel.shared

        return LazyList(passes, id: \.number) { pass in
            Row(pass: pass, scene: scene, index: index, chosen: model.selected == pass.number)
        }
        .itemSize(46)
        .selection(model.$selected)
    }

    /// The render chosen: its numbers, then its tree in this scene.
    private func detail(_ chosen: InspectedPass?, scene: ElementId, at index: Int?) -> Element {
        guard let pass = chosen else {
            return Label("Choose a render to see what it built.")
                .fontSize(12)
                .textColor(Look.subtle)
                .verticalOptions(.start)
        }

        let entries = pass.entries.filter { $0.scene == scene }
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

                Look.line(pass.causes.isEmpty
                    ? "caused by nothing named"
                    : "for " + pass.causes.joined(separator: ", "))
                Look.line(
                    "at \(Look.seconds(pass.at)) · generation \(pass.generation) · "
                        + "\(pass.bytes) bytes")
                Look.line(
                    "Swift  describe \(Look.micros(pass.describe)) · encode \(Look.micros(pass.encode))"
                        + (pass.own > 0 ? " · the inspector's own \(Look.micros(pass.own)), left out" : ""))
                Look.line(host(pass.host))
                Look.line(
                    "this scene  Swift \(whole.map { Look.micros($0.micros) } ?? "nothing built")"
                        + (Look.scene(pass.host, at: index).map { " · C# \(Look.micros($0))" } ?? ""))

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

/// An inspector folded to one line: the last render that reached its scene,
/// said the way the list says it, and the button that opens it out again.
struct InspectorStrip: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    var content: any View {
        let model = InspectorModel.shared

        // Built again as renders land, the way the whole inspector is.
        _ = model.revision

        let element = ElementId.manual(scene)
        let all = Inspection.passes
        let last = all.last { pass in pass.entries.contains { $0.scene == element } }

        return Grid {
            Grid {
                if let last {
                    Row(pass: last, scene: element, index: Scenes.shared.index(of: scene), chosen: false)
                } else {
                    Label(InspectorView.waiting(all.count))
                        .fontSize(12)
                        .textColor(Look.subtle)
                        .lineBreakMode(.tailTruncation)
                        .margin(8, 4)
                }
            }
            .verticalOptions(.center)
            .gridColumn(0)

            HStack {
                Look.icon(Look.expanding, "Expand") { model.expand(scene) }
                Look.icon(Look.closing, "Close") {
                    if let record = Scenes.shared.record(id: scene) {
                        Inspector.hide(in: record)
                    }
                }
            }
            .verticalOptions(.center)
            .gridColumn(1)
        }
        .columnDefinitions(.star, .auto)
        .padding(2, 4)
    }
}

/// One render in the list.
private struct Row: ContentView {
    let pass: InspectedPass
    let scene: ElementId
    let index: Int?
    let chosen: Bool

    var content: any View {
        let mine = pass.entries.filter { $0.scene == scene }
        let built = mine.filter { if case .built = $0.outcome { return true } else { return false } }.count
        let carried = mine.filter { $0.outcome == .carried }.count
        let swift = Look.micros(mine.first { $0.depth == 0 }?.micros ?? pass.describe + pass.encode)
        let host = pass.host.map { host in
            Look.micros(Look.scene(host, at: index) ?? host.read + host.apply)
        } ?? "…"

        return VStack {
            Label("#\(pass.number)  \(Look.road(pass.road))  "
                + (pass.causes.isEmpty ? "" : "for " + pass.causes.joined(separator: ", ")))
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(Look.ink)
                .lineBreakMode(.tailTruncation)

            Label("Swift \(swift) · C# \(host) · \(built) built · \(carried) carried")
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

    var content: any View {
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

/// The inspector's colours, measures, words and the one kind of button it has.
enum Look {
    static let ground = Color(light: Color("#F7F6FB"), dark: Color("#1C1A24"))
    static let edge = Color(light: Color("#D6D2E2"), dark: Color("#3A3647"))
    static let ink = Color(light: Color("#1B1A22"), dark: Color("#ECEAF4"))
    static let subtle = Color(light: Color("#6B6878"), dark: Color("#A29FB0"))
    static let built = Color(light: Color("#B4400A"), dark: Color("#FB923C"))
    static let carried = Color(light: Color("#15803D"), dark: Color("#4ADE80"))
    static let chosen = Color(light: Color("#E7E3F3"), dark: Color("#2E2A3B"))

    /// How wide a panel docked at the side stands.
    static let side = 460.0

    /// How far below a window's top a panel at the side begins - the height
    /// of a page's bar, which keeps its buttons clear.
    static let bar = 56.0

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

    /// One of the two pictures at the end of a panel's line along the bottom:
    /// a drawing in a twelve-unit box, the tap, and the word a screen reader
    /// and a script know it by.
    ///
    /// DRAWN RATHER THAN TYPED: a glyph is whatever the platform's font makes
    /// of it, and a font without one draws an empty box in its place.
    ///
    /// - Parameters:
    ///   - picture: the drawing - `expanding`, `folding` or `closing`.
    ///   - words: what it does, in a word.
    ///   - run: what a tap does.
    static func icon(_ picture: String, _ words: String, _ run: @escaping () -> Void) -> Element {
        Grid {
            Path(picture)
                .stroke(ink)
                .strokeThickness(1.5)
                .strokeLineCap(.round)
                .widthRequest(12)
                .heightRequest(12)
                .horizontalOptions(.center)
                .verticalOptions(.center)
                .inputTransparent(true)
        }
        .widthRequest(28)
        .heightRequest(24)
        .backgroundColor(.transparent)
        .semanticDescription(words)
        .automationId("stateui.inspector.\(words.lowercased())")
        .onTapped { run() }
    }

    /// Opening a folded panel out: the square a window is enlarged with.
    static let expanding = "M1.5 1.5 H10.5 V10.5 H1.5 Z"

    /// Folding it to one line: the bar a window is made small with.
    static let folding = "M1.5 9 H10.5"

    /// Closing it: a cross.
    static let closing = "M2 2 L10 10 M10 2 L2 10"

    /// One line of the chosen render's numbers.
    static func line(_ text: String) -> Element {
        Label(text)
            .fontSize(11)
            .textColor(subtle)
            .lineBreakMode(.tailTruncation)
    }

    /// How long one scene's part of the host's apply took, where it said.
    static func scene(_ host: InspectedHost?, at index: Int?) -> Double? {
        guard let host, let index, index < host.scenes.count else { return nil }

        return host.scenes[index]
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
