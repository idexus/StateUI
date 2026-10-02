// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SceneContract` on a host: a scene hears when it comes to the front, goes behind another application and goes out
/// of sight; when its main window closes it ends; a window of its own the user closes is heard; a window the platform
/// restores comes back for its value.
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
            ConformanceCase("aSceneEndsWhenItsMainWindowCloses", proves: [Covered(SceneContract.destroying)]) { s in
                let sessions = Received<ApplicationSession>()
                s.start { ApplicationPage(sessions: sessions) }
                s.settle { !sessions.values.isEmpty }
                s.expect(sessions.values.first?.scenes.count, 1)

                try s.perform(.close, on: s.element(ofType: WindowContract.nodeType))
                s.settle { sessions.values.first?.scenes.isEmpty == true }
                s.expect(sessions.values.first?.scenes.count, 0, "the scene ended")
            },
            ConformanceCase("aWindowOfItsOwnTheUserClosesIsHeard", proves: [
                Covered(SceneContract.windowClosed),
            ], needs: [Covered(WindowContract.windowType)]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("no second window") }

                try s.perform(.close, on: note)
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 1 }
                s.expect(s.elements(ofType: WindowContract.nodeType).count, 1, "the scene let the note's window go")
            },
            ConformanceCase("aWindowThePlatformRestoresComesBackForItsValue", proves: [
                Covered(SceneContract.windowRestored),
            ]) { s in
                try s.start(application: { NotesApplication() })
                try s.perform(.activate, on: s.element("open"))
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }

                try s.start(application: { NotesApplication() })
                s.settle { s.elements(ofType: WindowContract.nodeType).count == 2 }
                guard let note = s.elements(ofType: WindowContract.nodeType).last else { return s.fail("nothing restored") }
                s.expect(try s.held(WindowContract.windowValue, on: note), "7", "the note restored for its number")
            },
        ]
    }
}

/// A page saying each phase its scene goes through.
struct ScenePhasePage: ContentView {
    let log: Received<ScenePhase>

    @Environment private var scene: SceneSession

    var content: some View {
        let (log, scene) = (self.log, self.scene)
        return Text("Scene")
            .onCreated { log.values.append(scene.phase) }
            .onChanged(scene.phase) { log.values.append(scene.phase) }
    }
}

/// A page handing its application's session to the case.
struct ApplicationPage: ContentView {
    let sessions: Received<ApplicationSession>

    @Environment private var application: ApplicationSession

    var content: some View {
        let (sessions, application) = (self.sessions, self.application)
        return Text("Application").onCreated { sessions.values.append(application) }
    }
}
