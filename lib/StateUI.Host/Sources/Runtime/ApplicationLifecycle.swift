// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where the application, each of its scenes and each of its windows stand as a toolkit tells what each window does,
/// and what each hears as they move, the same on every host.
/// Design: docs/design/host/runtime.md#the-applications-phase
@_spi(Host) @MainActor public final class ApplicationLifecycle {
    /// One event a scene or a window hears.
    public struct Told {
        /// The scene or the window.
        public let element: MountedElement

        /// What it hears.
        public let event: Event
    }

    /// What one settling moved.
    public struct Moves {
        /// The application's phase, where it changed.
        public var phase: ApplicationPhase?

        /// What the scenes and the windows hear, in order.
        public var told: [Told] = []

        /// Whether a window's standing changed: the scene in front, or whether floating windows float.
        public var standing = false
    }

    private struct Report {
        weak var window: MountedElement?
        let minimized: Bool
        let activated: Bool
    }

    private struct Heard {
        weak var element: MountedElement?
        var event: Event
    }

    /// The phase the application stands in; nil before a settling told one.
    public private(set) var phase: ApplicationPhase?

    /// The scene in front: the one whose window was activated last. Only another window's activation moves it.
    public private(set) weak var front: MountedElement?

    /// Whether the toolkit hid the whole application, every window with it.
    public var isHidden = false

    private var reports: [Report] = []
    private var heard: [Heard] = []
    private weak var settledFront: MountedElement?
    private var settledInFront = true

    /// Nothing told yet.
    public init() {}

    /// The toolkit told what `window` does now: whether it is minimized, whether it is activated.
    public func report(_ window: MountedElement, minimized: Bool, activated: Bool) {
        reports.removeAll { $0.window == nil || $0.window === window }
        reports.append(Report(window: window, minimized: minimized, activated: activated))
        if activated { front = window.enclosing(type: .scene) }
    }

    /// Whether `window` stands hidden by its scene: it hides while another scene is in front.
    public func isHiddenByScene(_ window: MountedElement) -> Bool {
        guard window.value(.hidesWhenInactive)?.bool == true, let front else { return false }

        return window.enclosing(type: .scene) !== front
    }

    /// Whether `window` floats over the application's other windows now: it says so, and the application is in front.
    public func floats(_ window: MountedElement) -> Bool {
        window.value(.floatsOnTop)?.bool == true && isInFront
    }

    /// Where everything stands now that the toolkit told it, `windows` the tree's, in order: the application's phase,
    /// then what each scene and window hears where it moved - a window that resumes first, then what leaves, then
    /// what is activated.
    public func settle(windows: [MountedElement]) -> Moves {
        var moves = Moves()
        guard !windows.isEmpty else { return moves }

        reports.removeAll { report in !windows.contains { $0 === report.window } }
        let scenes = Self.scenes(of: windows)
        let phase: ApplicationPhase = isHidden ? .background
            : windows.contains(where: isActivated) ? .active
            : windows.allSatisfy(isStopped) ? .background : .inactive
        if phase != self.phase {
            moves.phase = phase
            self.phase = phase
        }

        var resumed: [Told] = []
        var leaving: [Told] = []
        var activated: [Told] = []
        let events = scenes.map { ($0, sceneEvent($0, windows: windows)) } + windows.map { ($0, windowEvent($0)) }
        heard.removeAll { entry in !events.contains { $0.0 === entry.element } }
        for (element, event) in events {
            let last = heard.firstIndex { $0.element === element }
            guard last.map({ heard[$0].event }) != event else { continue }

            if last.map({ heard[$0].event }) == .stopped, element.type == .window {
                resumed.append(Told(element: element, event: .resumed))
            }
            if event == .activated {
                activated.append(Told(element: element, event: event))
            } else {
                leaving.append(Told(element: element, event: event))
            }
            if let last { heard[last].event = event } else { heard.append(Heard(element: element, event: event)) }
        }
        moves.told = resumed + leaving + activated

        moves.standing = front !== settledFront || isInFront != settledInFront
        settledFront = front
        settledInFront = isInFront
        return moves
    }

    /// What the scenes and the windows hear as the application ends: each scene's windows that they are going, then
    /// the scene.
    public static func ending(windows: [MountedElement]) -> [Told] {
        scenes(of: windows).flatMap { scene in
            windows.filter { $0.enclosing(type: .scene) === scene }.map { Told(element: $0, event: .destroying) }
                + [Told(element: scene, event: .destroying)]
        }
    }

    /// The scenes holding `windows`, each once, in order.
    private static func scenes(of windows: [MountedElement]) -> [MountedElement] {
        windows.compactMap { $0.enclosing(type: .scene) }.reduce(into: []) { scenes, scene in
            if !scenes.contains(where: { $0 === scene }) { scenes.append(scene) }
        }
    }

    /// Whether the application is in front, or not yet told it is not.
    private var isInFront: Bool {
        phase == nil || phase == .active
    }

    /// Whether `window` stands off the screen: the application hidden, the window minimized or hidden by its scene.
    private func isStopped(_ window: MountedElement) -> Bool {
        isHidden || reports.first { $0.window === window }?.minimized == true || isHiddenByScene(window)
    }

    /// Whether `window` is the one the user is in.
    private func isActivated(_ window: MountedElement) -> Bool {
        !isStopped(window) && reports.first { $0.window === window }?.activated == true
    }

    /// What `scene` stands in: stopped with the application hidden, activated while one of its windows is, stopped
    /// while its main window is off the screen, else deactivated.
    private func sceneEvent(_ scene: MountedElement, windows: [MountedElement]) -> Event {
        let own = windows.filter { $0.enclosing(type: .scene) === scene }
        if isHidden { return .stopped }
        if own.contains(where: isActivated) { return .activated }
        if let main = own.first(where: { $0.value(.windowType) == nil }), isStopped(main) { return .stopped }
        return .deactivated
    }

    /// What `window` stands in: stopped while it is off the screen, else activated or deactivated.
    private func windowEvent(_ window: MountedElement) -> Event {
        isStopped(window) ? .stopped : isActivated(window) ? .activated : .deactivated
    }
}
