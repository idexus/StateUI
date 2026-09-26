// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The application's phase as a toolkit's lifecycle moves it, and what its scene and its window hear of each move,
/// the same on every host.
/// Design: docs/design/host/runtime.md#the-applications-phase
@_spi(Host) public struct ApplicationLifecycle: Sendable {
    /// One event an element of the application hears.
    public struct Told: Equatable, Sendable {
        /// The element: the scene or the window.
        public let element: NodeType

        /// What it hears.
        public let event: Event
    }

    /// The phase the application stands in; nil before a toolkit told one.
    public private(set) var phase: ApplicationPhase?

    /// Whether the window stands stopped.
    private var stopped = false

    /// An application no toolkit told a phase yet.
    public init() {}

    /// The phase a window's state puts the application in: seen nowhere where it is minimized, else in use where it
    /// is activated, else behind another.
    public static func phase(minimized: Bool, activated: Bool) -> ApplicationPhase {
        minimized ? .background : activated ? .active : .inactive
    }

    /// What the application's scene and window hear as it enters `phase`, in order; nil where it stands in that
    /// phase already. A window shown again after it stopped hears first that it resumed; then the scene and the
    /// window hear that they were activated, deactivated or stopped.
    public mutating func enter(_ phase: ApplicationPhase) -> [Told]? {
        guard phase != self.phase else { return nil }
        self.phase = phase

        let resumes = stopped && phase != .background
        stopped = phase == .background
        let event: Event = switch phase {
        case .active: .activated
        case .inactive: .deactivated
        case .background: .stopped
        }
        return (resumes ? [Told(element: .window, event: .resumed)] : [])
            + [Told(element: .scene, event: event), Told(element: .window, event: event)]
    }

    /// What they hear as the application ends: the window that it is going, then the scene.
    public static let ending = [Told(element: .window, event: .destroying), Told(element: .scene, event: .destroying)]
}
