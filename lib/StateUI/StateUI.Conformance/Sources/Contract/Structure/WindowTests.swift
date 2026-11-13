// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `WindowContract` on a host: a window hears each phase of its life - made and brought to the front, put behind
/// another application and back, put away and brought back, closed; it stands with the title, the size, the place,
/// the bounds and the chrome its session asks for; a window opened by its kind is of that kind, for its value,
/// floating or hiding as its group says, and the platform keeps it for its value.
@_spi(Host) public enum WindowTests: ConformanceFamily {
    public static let name = "Window"

    public static var cases: [ConformanceCase] { written.proving(WindowContract.self) }

    /// Every case written for the contract: its own members, and a tier's its family takes up.
    @MainActor static var written: [ConformanceCase] {
        [
            ConformanceCase("aWindowIsMadeAndComesToTheFront", proves: [
                Covered(WindowContract.self), Covered(WindowContract.created),
            ]) { s in
                let log = Received<SessionPhase>()
                s.start { WindowPhasePage(log: log) }

                s.settle { log.values.last == .active }
                // Made, it stands showing and not yet in use; before the platform made it, out of sight.
                s.expect(log.values.firstIndex(of: .inactive).map { $0 < log.values.count - 1 }, true, "made first")
                s.expect(log.values.last, .active, "then in front")
            },
            ConformanceCase("aClosedWindowHearsItIsGoing", proves: [Covered(WindowContract.destroying)]) { s in
                let log = Received<SessionPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .active }

                try s.perform(.close, on: window)
                s.settle { log.values.last == .background }
                s.expect(log.values.last, .background, "going away: out of sight, the place to save")
            },
            holds(WindowContract.title, "Notes", then: "Drafts") { $0.title = $1 },
            holds(WindowContract.width, 640, then: 800) { $0.width = $1 },
            holds(WindowContract.height, 480, then: 600) { $0.height = $1 },
            holds(WindowContract.x, 40, then: 120) { $0.x = $1 },
            holds(WindowContract.y, 30, then: 90) { $0.y = $1 },
            holds(WindowContract.minimumWidth, 300, then: 400) { $0.minimumWidth = $1 },
            holds(WindowContract.minimumHeight, 200, then: 300) { $0.minimumHeight = $1 },
            holds(WindowContract.maximumWidth, 1200, then: 1000) { $0.maximumWidth = $1 },
            holds(WindowContract.maximumHeight, 900, then: 800) { $0.maximumHeight = $1 },
            holds(WindowContract.isMaximizable, false, then: true) { $0.isMaximizable = $1 },
            holds(WindowContract.isMinimizable, false, then: true) { $0.isMinimizable = $1 },
            holds(
                BackgroundElementContract.background, .color(Color(hex: 0x512BD4, opacity: 0.15)),
                then: .color(Color(hex: 0x0F766E))
            ) {
                $0.background = $1
            },
            blurred,
            groundsItsSheets,
            ConformanceCase("aWindowAScenesGroupOpensIsOfItsKindForItsValue", proves: [
                Covered(WindowContract.windowKind), Covered(WindowContract.windowValue),
            ]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }

                try s.settle { try s.held(WindowContract.windowValue, on: note) == "7" }
                s.expect(try s.held(WindowContract.windowKind, on: note), Name(NotesApplication.note.name))
                s.expect(try s.held(WindowContract.windowValue, on: note), "7")
            },
            ConformanceCase("aWindowOfAKindIsAskedOverItself", proves: [
                Covered(WindowContract.windowKind),
            ], needs: [
                Covered(ApplicationContract.confirm),
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
            ]) { s in
                let said = Received<Bool>()
                try s.start(application: { AskingApplication(said: said) })
                let first = try s.element(ofType: WindowContract.nodeType)
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let draft = s.elements(ofType: WindowContract.nodeType).first(where: { $0 !== first }) else {
                    return s.fail("no second window")
                }

                s.expect(try s.element("ask again").enclosing(type: .window) === draft, true, "its button in the draft's window")
                try s.perform(.activate, on: s.element("ask again"))
                try s.settle { try s.question(over: draft) != nil }
                s.expect(try s.question(over: draft)?.title, "Close draft?", "over the draft's window, which asked")
                s.expect(try s.question(over: first)?.title, nil, "none over the first")
                try s.perform(.answer(.accept), on: draft)
                s.settle { !said.values.isEmpty }
                s.expect(said.values, [true], "the draft's window answered")
            },
            ConformanceCase("aWindowOfAKindShowsItsOwnPagesTitle", proves: [
                Covered(WindowContract.windowKind),
            ], needs: [
                Covered(PageContract.showsTitle), Covered(SplitViewContract.self),
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
            ]) { s in
                try s.start(application: { TitledWindowsApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                let page = { (id: String) throws -> MountedElement in
                    guard let page = try s.element(id).enclosing(type: .page) else { throw DriverCannot("find \(id)'s page") }
                    return page
                }

                try s.settle { try s.held(PageContract.showsTitle, on: page("untitled")) == false }
                s.expect(try s.held(PageContract.showsTitle, on: page("titled")), true, "the first window's page shows its title")
                s.expect(try s.held(PageContract.showsTitle, on: page("untitled")), false, "the second's shows none")
            },
            ConformanceCase("aWindowThePlatformKeepsComesBackForItsValue", proves: [
                Covered(WindowContract.windowValue),
            ]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }

                try s.start(application: { NotesApplication() })
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("nothing kept") }
                s.expect(try s.held(WindowContract.windowValue, on: note), "7", "the note kept for its number")
            },
            ConformanceCase("aWindowOfTheGroupFloatsWhileTheApplicationIsInFront", proves: [
                Covered(WindowContract.floatsOnTop),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                let windows = s.elements(ofType: WindowContract.nodeType)
                guard let notes = windows.first, let note = windows.last else { return s.fail("no second window") }

                try s.perform(.bringToFront, on: note)
                try s.settle { try s.held(WindowContract.floatsOnTop, on: note) == true }
                s.expect(try s.held(WindowContract.floatsOnTop, on: note), true, "over the application's windows")
                try s.perform(.switchAway, on: notes)
                try s.settle { try s.held(WindowContract.floatsOnTop, on: note) == false }
                s.expect(try s.held(WindowContract.floatsOnTop, on: note), false, "not over another application")
                try s.perform(.switchBack, on: notes)
                try s.settle { try s.held(WindowContract.floatsOnTop, on: note) == true }
                s.expect(try s.held(WindowContract.floatsOnTop, on: note), true, "with the application in front again")
            },
            ConformanceCase("aWindowOfTheGroupHidesWhileAnotherSceneIsInFront", proves: [
                Covered(WindowContract.hidesWhenInactive),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }
                let first = try s.element(ofType: WindowContract.nodeType)
                try s.perform(.bringToFront, on: first)
                try s.settle { try s.held(VisualElementContract.isVisible, on: note) == true }

                try s.perform(.activate, on: s.element("another"))
                s.settle { s.elements(ofType: SceneContract.nodeType).count == 2 }
                guard let second = s.elements(ofType: WindowContract.nodeType)
                    .first(where: { $0.enclosing(type: .scene) !== note.enclosing(type: .scene) })
                else { return s.fail("no second scene") }
                try s.perform(.bringToFront, on: second)
                try s.settle { try s.held(VisualElementContract.isVisible, on: note) == false }
                s.expect(try s.held(VisualElementContract.isVisible, on: note), false, "another scene in front")

                try s.perform(.bringToFront, on: first)
                try s.settle { try s.held(VisualElementContract.isVisible, on: note) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: note), true, "its scene in front again")
            },
            ConformanceCase("aWindowThatStopsHidingShowsWithItsSceneBehind", proves: [
                Covered(WindowContract.hidesWhenInactive),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let hides = HidingApplication.hides
                hides.wrappedValue = true
                try s.start(application: { HidingApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }
                try s.perform(.activate, on: s.element("another"))
                s.settle { s.elements(ofType: SceneContract.nodeType).count == 2 }
                guard let other = s.elements(ofType: WindowContract.nodeType)
                    .first(where: { $0.enclosing(type: .scene) !== note.enclosing(type: .scene) })
                else { return s.fail("no second scene") }
                try s.perform(.bringToFront, on: other)
                try s.settle { try s.held(VisualElementContract.isVisible, on: note) == false }
                s.expect(try s.held(VisualElementContract.isVisible, on: note), false, "hidden: another scene in front")

                hides.wrappedValue = false
                try s.settle { try s.held(VisualElementContract.isVisible, on: note) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: note), true, "shown once it no longer hides")
            },
        ]
    }

    /// The window is made of the blur its session writes and then of the one the tree changes it to - or of the
    /// color a host whose windows show nothing behind them paints for each.
    @MainActor
    static var blurred: ConformanceCase {
        ConformanceCase("Window.background.showsABlurOrWhatStandsInForIt", proves: [
            Covered(BackgroundElementContract.background, on: WindowContract.self),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let value = State(wrappedValue: Material.blur(.thick))
            let changed = Material.blur(.ultraThin)
            s.start {
                WindowSessionPage(beside: [Button("Change").onClicked { value.wrappedValue = changed }.id("change")],
                                  key: "\(value.wrappedValue)") { window in window.background = value.wrappedValue }
            }
            let window = try s.element(ofType: WindowContract.nodeType)
            try s.settle { try s.held(BackgroundElementContract.background, on: window) == .blur(.thick) }
            s.expect(try s.held(BackgroundElementContract.background, on: window), .blur(.thick), "the blur its session wrote")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(BackgroundElementContract.background, on: window) == changed }
            s.expect(try s.held(BackgroundElementContract.background, on: window), changed, "the blur the tree changed it to")
        }
    }

    /// A sheet over the window's page stands on the window's background - its color laid over the platform's own
    /// sheet - and follows it as the tree changes it.
    @MainActor
    static var groundsItsSheets: ConformanceCase {
        ConformanceCase("Window.background.groundsTheSheetsOverItsPage", proves: [
            Covered(BackgroundElementContract.background, on: WindowContract.self),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self), Covered(PresentedElementContract.isPresented, on: SheetContract.self)]) { s in
            let (first, changed) = (Material.color(Color(hex: 0x2A2154)), Material.color(Color(hex: 0x0F766E)))
            let value = State(wrappedValue: first)
            s.start {
                // The change is pressed on the sheet: what stands beneath a sheet takes no press.
                WindowSessionPage(beside: [
                    Text("Beneath").sheet(isPresented: State(wrappedValue: true).projectedValue) {
                        VStack { Button("Change").onClicked { value.wrappedValue = changed }.id("change") }
                    },
                ], key: "\(value.wrappedValue)") { window in window.background = value.wrappedValue }
            }
            let sheet = try s.element(ofType: SheetContract.nodeType)
            try s.settle { try s.ground(of: sheet) == first }
            s.expect(try s.ground(of: sheet), first, "the window's background under the sheet")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.ground(of: sheet) == changed }
            s.expect(try s.ground(of: sheet), changed, "the background the tree changed it to")
        }
    }

    /// `member` of the window holds what its session writes, and what the tree changes it to.
    @MainActor
    static func holds<Owner: WornContract, Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<Owner, Value>, _ first: Value, then second: Value,
        _ write: @escaping @MainActor (WindowSession, Value) -> Void
    ) -> ConformanceCase {
        ConformanceCase("Window.\(member.name).holdsWhatItsSessionWritesAndChanges", proves: [
            Covered(member, on: "Window"),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let value = State(wrappedValue: first)
            s.start {
                WindowSessionPage(beside: [Button("Change").onClicked { value.wrappedValue = second }.id("change")],
                                  key: "\(value.wrappedValue)") { window in write(window, value.wrappedValue) }
            }
            let window = try s.element(ofType: WindowContract.nodeType)
            try s.settle { try s.held(member, on: window) == first }
            s.expect(try s.held(member, on: window), first, "what its session wrote")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: window) == second }
            s.expect(try s.held(member, on: window), second, "what the tree changed it to")
        }
    }
}

/// A page saying each phase its window goes through.
struct WindowPhasePage: View {
    let log: Received<SessionPhase>

    @Environment(\.window) private var window

    var body: some View {
        let (log, window) = (self.log, self.window)
        return Text("Window")
            .onCreated { log.values.append(window.phase) }
            .onChanged(window.phase) { log.values.append(window.phase) }
    }
}

/// An application of two scenes: its notes - the page launch opens, and a window per note, of the note's kind, for
/// the note's number, floating over the others and hiding while another scene is in front - and another, a window
/// alone.
struct NotesApplication: Application {
    /// The kind of a note's window.
    static let note = WindowKind<Int>("conformance.note")

    /// The kind of the other scene's window.
    static let other = WindowKind<Void>("conformance.other")

    var body: some Scene {
        NotesScene()
        Window(NotesApplication.other) { Text("Another scene") }
    }
}

/// The notes scene of `NotesApplication`.
struct NotesScene: Scene {
    var body: some Scene {
        WindowGroup { NotesPage() }
        WindowGroup(NotesApplication.note) { number in Text("Note \(number.wrappedValue)") }
            .floatsOnTop(true)
            .hidesWhenInactive(true)
    }
}

/// `NotesApplication` whose notes hide while another scene is in front as long as `hides` says so.
struct HidingApplication: Application {
    /// Whether the notes hide, which the case writes.
    @MainActor static let hides = State(wrappedValue: true)

    var body: some Scene {
        HidingScene()
        Window(NotesApplication.other) { Text("Another scene") }
    }
}

/// `NotesScene` whose notes hide as `HidingApplication.hides` says.
struct HidingScene: Scene {
    var body: some Scene {
        WindowGroup { NotesPage() }
        WindowGroup(NotesApplication.note) { number in Text("Note \(number.wrappedValue)") }
            .hidesWhenInactive(HidingApplication.hides.wrappedValue)
    }
}

/// The page launch opens in `NotesApplication`, with the buttons that open note 7 and the other scene's window.
struct NotesPage: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Button("Open").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow(NotesApplication.note, value: 7) }.id("open")
            Button("Another").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow(NotesApplication.other) }.id("another")
        }
    }
}

/// Two windows: the first a split view, its detail a page showing its title and a button opening the second, whose
/// page shows none.
struct TitledWindowsApplication: Application {
    /// The kind of the second window.
    static let untitled = WindowKind<Void>("conformance.untitled")

    var body: some Scene {
        TitledWindowsScene()
    }
}

/// The scene of `TitledWindowsApplication`.
struct TitledWindowsScene: Scene {
    var body: some Scene {
        WindowGroup {
            SplitView {
                Text("Sidebar").pageTitle("Places")
            } detail: {
                TitledPage()
            }
        }
        WindowGroup(TitledWindowsApplication.untitled) {
            NavigationStack(State(wrappedValue: [1]).projectedValue) {
                Text("Root")
            } destination: { _ in
                Text("Draft").id("untitled").pageTitle("Draft").showsTitle(false)
            }
        }
    }
}

/// The detail of the first window: a page showing its title, with a button opening the second window.
struct TitledPage: View {
    @Environment(\.application) private var application

    var body: some View {
        let application = self.application
        return VStack {
            Text("Notes").id("titled")
            Button("Open").onClicked(policy: .ignoreWhileRunning) {
                try await application.openWindow(TitledWindowsApplication.untitled)
            }.id("open")
        }
        .pageTitle("Notes")
    }
}
