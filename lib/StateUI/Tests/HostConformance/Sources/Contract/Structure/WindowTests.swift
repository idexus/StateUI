// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `WindowContract` on a host: a window hears each phase of its life - made and brought to the front, put behind
/// another application and back, put away and brought back, closed - and a modal the user takes away; it stands with
/// the title, the size, the place, the bounds and the chrome its session asks for, and a window a scene opens is of
/// its kind, for its value, floating or hiding as its group says.
@_spi(Host) public enum WindowTests: ConformanceFamily {
    public static let name = "Window"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aWindowIsMadeAndComesToTheFront", covers: [
                Covered(WindowContract.self), Covered(WindowContract.created), Covered(WindowContract.activated),
            ]) { s in
                let log = Received<WindowPhase>()
                s.start { WindowPhasePage(log: log) }

                s.settle { log.values.last == .activated }
                s.expect(log.values.first, .created, "made first")
                s.expect(log.values.last, .activated, "then in front")
            },
            ConformanceCase("anotherApplicationInFrontPutsItBehindAndBack", covers: [
                Covered(WindowContract.deactivated), Covered(WindowContract.activated),
            ]) { s in
                let log = Received<WindowPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .activated }

                try s.perform(.switchAway, on: window)
                s.settle { log.values.last == .deactivated }
                s.expect(log.values.last, .deactivated, "behind another application")
                try s.perform(.switchBack, on: window)
                s.settle { log.values.last == .activated }
                s.expect(log.values.last, .activated, "in front again")
            },
            ConformanceCase("aWindowPutAwayStopsAndResumesWhenBroughtBack", covers: [
                Covered(WindowContract.stopped), Covered(WindowContract.resumed),
            ]) { s in
                let log = Received<WindowPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .activated }

                try s.perform(.minimize, on: window)
                s.settle { log.values.last == .stopped }
                s.expect(log.values.last, .stopped, "put away")
                try s.perform(.restore, on: window)
                s.settle { log.values.contains(.resumed) && log.values.last == .activated }
                s.expect(log.values.suffix(2).map { $0 }, [.resumed, .activated], "brought back on its way to the front")
            },
            ConformanceCase("aClosedWindowHearsItIsGoing", covers: [Covered(WindowContract.destroying)]) { s in
                let log = Received<WindowPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .activated }

                try s.perform(.close, on: window)
                s.settle { log.values.last == .destroying }
                s.expect(log.values.last, .destroying)
            },
            ConformanceCase("aModalTheUserTakesAwayIsHeardByItsWindow", covers: [
                Covered(WindowContract.modalPopped), Covered(ModalStackContract.self),
            ]) { s in
                let sheets = State(wrappedValue: [1])
                s.start { SheetsPage(sheets: sheets, log: Received()) }
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet1")) == true }

                try s.perform(.goBack, on: s.element(ofType: WindowContract.nodeType))
                s.settle { sheets.wrappedValue.isEmpty }
                s.expect(sheets.wrappedValue, [], "the window heard none remain, and the state took it")
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
            holds(WindowContract.isTranslucent, true, then: false) { $0.isTranslucent = $1 },
            ConformanceCase("aWindowAScenesGroupOpensIsOfItsKindForItsValue", covers: [
                Covered(WindowContract.windowType), Covered(WindowContract.windowValue),
                Covered(WindowContract.floatsOnTop), Covered(WindowContract.hidesWhenInactive),
            ]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                try s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }

                s.expect(try s.held(WindowContract.windowType, on: note), NotesApplication.note)
                s.expect(try s.held(WindowContract.windowValue, on: note), "7")
                s.expect(try s.held(WindowContract.floatsOnTop, on: note), true)
                s.expect(try s.held(WindowContract.hidesWhenInactive, on: note), true)
            },
        ]
    }

    /// `member` of the window holds what its session writes, and what the tree changes it to.
    static func holds<Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<WindowContract, Value>, _ first: Value, then second: Value,
        _ write: @escaping @Sendable (WindowSession, Value) -> Void
    ) -> ConformanceCase {
        ConformanceCase("Window.\(member.name).holdsWhatItsSessionWritesAndChanges", covers: [
            Covered(member), Covered(ButtonContract.clicked),
        ]) { s in
            let value = State(wrappedValue: first)
            s.start {
                SessionPage(beside: [Button("Change").onClicked { value.wrappedValue = second }.id("change")],
                            key: "\(value.wrappedValue)") { _, window in write(window, value.wrappedValue) }
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
struct WindowPhasePage: ContentView {
    let log: Received<WindowPhase>

    @Environment private var window: WindowSession

    var content: any View {
        let (log, window) = (self.log, self.window)
        return Label("Window")
            .onCreated { log.values.append(window.phase) }
            .onChanged(window.phase) { log.values.append(window.phase) }
    }
}

/// An application whose scene opens a note's window beside its main one: of the note's kind, for the note's number,
/// floating over the others and hiding while another application is in front.
struct NotesApplication: Application {
    /// The kind of a note's window.
    static let note = WindowType("conformance.note")

    var scene: any Scene { NotesScene() }
}

/// The scene of `NotesApplication`.
struct NotesScene: Scene {
    var windows: Windows {
        Windows({
            WindowGroup(NotesApplication.note, for: Int.self) { number in NoteWindow(number: number.wrappedValue) }
                .floatsOnTop(true)
                .hidesWhenInactive(true)
        }, main: { MainNotesWindow() })
    }
}

/// The main window of `NotesApplication`, with the button that opens note 7.
struct MainNotesWindow: Window {
    var page: any Page { NotesPage() }
}

/// The page of the main window.
struct NotesPage: ContentView {
    @Environment private var scene: SceneSession

    var content: any View {
        let scene = self.scene
        return VStack {
            Button("Open").onClicked { try await scene.openWindow(NotesApplication.note, value: 7) }.id("open")
        }
    }
}

/// A note's window.
struct NoteWindow: Window {
    let number: Int
    var page: any Page { Label("Note \(number)") }
}
