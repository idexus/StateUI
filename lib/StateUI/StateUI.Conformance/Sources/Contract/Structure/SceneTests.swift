// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SceneContract` on a host: a scene hears when it comes to the front, goes behind another application and goes out
/// of sight; a window of it the user closes is heard, takes what it asked the user with it, and the last one ends it.
@_spi(Host) public enum SceneTests: ConformanceFamily {
    public static let name = "Scene"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSceneHoldsItsWindow", proves: [Covered(SceneContract.self)]) { s in
                s.start { VStack { Text("In a scene").id("label") } }

                _ = try s.element(ofType: SceneContract.nodeType)
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("label")), true)
            },
            ConformanceCase("aSceneHearsWhereItStands", proves: [
                Covered(SceneContract.activated), Covered(SceneContract.deactivated), Covered(SceneContract.stopped),
            ]) { s in
                let log = Received<ScenePhase>()
                s.start { ScenePhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .active }

                try s.perform(.switchAway, on: window)
                s.settle { log.values.last == .inactive }
                s.expect(log.values.last, .inactive, "behind another application")
                try s.perform(.switchBack, on: window)
                s.settle { log.values.last == .active }
                s.expect(log.values.last, .active, "in front again")
                try s.perform(.minimize, on: window)
                s.settle { log.values.last == .background }
                s.expect(log.values.last, .background, "out of sight")
                try s.perform(.restore, on: window)
                s.settle { log.values.last == .active }
            },
            ConformanceCase("aWindowTheUserClosesIsHeardAndTheLastEndsItsScene", proves: [
                Covered(SceneContract.windowClosed),
            ], needs: [Covered(WindowContract.windowType)]) { s in
                let sessions = Received<ApplicationSession>()
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }

                try s.perform(.close, on: note)
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 1 }
                s.expect(s.elements(ofType: WindowContract.nodeType).count, 1, "the scene let the note's window go")

                s.start { ApplicationPage(sessions: sessions) }
                s.settle { !sessions.values.isEmpty }
                try s.perform(.close, on: s.element(ofType: WindowContract.nodeType))
                s.settle { sessions.values.first?.scenes.isEmpty == true }
                s.expect(sessions.values.first?.scenes.count, 0, "its last window gone, the scene ended")
            },
            ConformanceCase("aWindowTheUserClosesTakesWhatItAskedWithIt", proves: [
                Covered(SceneContract.windowClosed),
            ], needs: [
                Covered(WindowContract.windowType), Covered(ApplicationContract.confirm), Covered(ButtonContract.clicked),
            ]) { s in
                let said = Received<Bool>()
                try s.start(application: { AskingApplication(said: said) })
                let first = try s.element(ofType: WindowContract.nodeType)
                try s.perform(.activate, on: s.element("ask"))
                try s.settle { try s.question() != nil }
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }

                try s.perform(.close, on: first)
                // A desktop whose dialog closes before its window takes the question with one close, the window with
                // the next.
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 1 || (try? s.question()) == nil }
                if s.elements(ofType: WindowContract.nodeType).count == 2 { try s.perform(.close, on: first) }
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 1 }
                try s.perform(.activate, on: s.element("ask again"))
                try s.settle { try s.question()?.title == "Close draft?" }
                s.expect(try s.question()?.title, "Close draft?", "the question over the window gone is in no way")
                try s.perform(.answer(.accept), on: s.element(ofType: WindowContract.nodeType))
                s.settle { said.values.last == true }
                s.expect(said.values.filter { $0 }, [true], "the one over the window gone, where heard at all, not accepted")
            },
        ]
    }
}

/// A page saying each phase its scene goes through.
struct ScenePhasePage: View {
    let log: Received<ScenePhase>

    @Environment(\.scene) private var scene

    var body: some View {
        let (log, scene) = (self.log, self.scene)
        return Text("Scene")
            .onCreated { log.values.append(scene.phase) }
            .onChanged(scene.phase) { log.values.append(scene.phase) }
    }
}

/// A page handing its application's session to the case.
struct ApplicationPage: View {
    let sessions: Received<ApplicationSession>

    @Environment(\.application) private var application

    var body: some View {
        let (sessions, application) = (self.sessions, self.application)
        return Text("Application").onCreated { sessions.values.append(application) }
    }
}

/// An application whose launch page asks a question and opens a draft, whose window asks another; each answer goes to
/// `said`.
struct AskingApplication: Application {
    /// The kind of the draft's window.
    static let draft = WindowType<Void>("conformance.draft")

    let said: Received<Bool>

    var body: some Scene {
        AskingScene(said: said)
    }
}

/// The scene of `AskingApplication`: the page launch opens, and the draft's window.
struct AskingScene: Scene {
    let said: Received<Bool>

    var body: some Scene {
        WindowGroup { AskingPage(said: said) }
        WindowGroup(AskingApplication.draft) { DraftPage(said: said) }
    }
}

/// The page launch opens in `AskingApplication`: a button asking whether to delete the draft, one opening it.
struct AskingPage: View {
    @Environment(\.application) private var application
    @Environment(\.window) private var window
    let said: Received<Bool>

    var body: some View {
        let (application, window, said) = (self.application, self.window, self.said)
        return VStack {
            Button("Ask").onClicked(gate: .ignoreWhileRunning) {
                said.values.append(try await window.confirm(
                    "Delete draft?", message: "It goes for good", accept: "Delete", cancel: "Keep"))
            }.id("ask")
            Button("Open").onClicked(gate: .ignoreWhileRunning) {
                try await application.openWindow(AskingApplication.draft)
            }.id("open")
        }
    }
}

/// The draft's page in `AskingApplication`: a button asking whether to close it.
struct DraftPage: View {
    @Environment(\.window) private var window
    let said: Received<Bool>

    var body: some View {
        let (window, said) = (self.window, self.said)
        return VStack {
            Button("Ask again").onClicked(gate: .ignoreWhileRunning) {
                said.values.append(try await window.confirm(
                    "Close draft?", message: "It is kept", accept: "Close", cancel: "Stay"))
            }.id("ask again")
        }
    }
}
