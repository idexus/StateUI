// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A host as the conformance suite drives it: what a user does to its native controls, and what they hold. Each
/// host's test target implements one over its toolkit, and names no widget to a case.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
@_spi(Host) public protocol HostDriver: AnyObject {
    /// The host's column in the control dictionary.
    var host: String { get }

    /// What the host realizes, member by member: whether a case runs on it.
    var marks: HostMarks { get }

    /// What this driver cannot do on its host yet, each with why: a case needing it is not run, and says so.
    var cannot: [String: String] { get }

    /// Shows `page` in a window of its own on a new host, its display frames at `clock`'s time where one is
    /// given; the tree it mounted.
    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree

    /// One bounded step of the host: its toolkit's loop a moment, the jobs, a turn of the pump, and a display
    /// frame while one is asked for.
    func step()

    /// One turn of the pump alone: what a user's change raised lands, and nothing is waited for.
    func turn()

    /// One display frame at the clock's time, and the layout in it.
    func frame()

    /// Does `act` to `element` as the user does, through its toolkit's own path.
    /// - Throws: `DriverCannot` where this driver has no such path for the element.
    func perform(_ act: UserAct, on element: MountedElement) throws

    /// What the native control of `element` holds of `property`, as the contract writes it.
    /// - Throws: `DriverCannot` where this driver cannot read it - never a nil standing for "unknown".
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue?
}
