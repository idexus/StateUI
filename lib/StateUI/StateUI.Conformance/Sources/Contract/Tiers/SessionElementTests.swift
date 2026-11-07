// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SessionElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum SessionElementTests: ConformanceFamily {
    public static let name = "SessionElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Scene.aSceneHearsWhereItStands", proves: [
                Covered(SessionElementContract.activated, on: SceneContract.self), Covered(SessionElementContract.deactivated, on: SceneContract.self), Covered(SessionElementContract.stopped, on: SceneContract.self),
            ]) { s in
                let log = Received<SessionPhase>()
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
            ConformanceCase("Window.anotherApplicationInFrontPutsItBehindAndBack", proves: [
                Covered(SessionElementContract.deactivated, on: WindowContract.self), Covered(SessionElementContract.activated, on: WindowContract.self),
            ]) { s in
                let log = Received<SessionPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .active }

                try s.perform(.switchAway, on: window)
                s.settle { log.values.last == .inactive }
                s.expect(log.values.last, .inactive, "behind another application")
                try s.perform(.switchBack, on: window)
                s.settle { log.values.last == .active }
                s.expect(log.values.last, .active, "in front again")
            },
            ConformanceCase("Window.aWindowPutAwayIsOutOfSightUntilBroughtBack", proves: [
                Covered(SessionElementContract.stopped, on: WindowContract.self),
            ], needs: [Covered(SessionElementContract.activated, on: WindowContract.self)]) { s in
                let log = Received<SessionPhase>()
                s.start { WindowPhasePage(log: log) }
                let window = try s.element(ofType: WindowContract.nodeType)
                s.settle { log.values.last == .active }

                try s.perform(.minimize, on: window)
                s.settle { log.values.last == .background }
                s.expect(log.values.last, .background, "put away")
                try s.perform(.restore, on: window)
                s.settle { log.values.last == .active }
                s.expect(log.values.last, .active, "brought back to the front")
            },
        ]
    }
}
