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

    /// What the host realizes, member by member: whether a case runs on it, and what its verdict says.
    var register: HostRegister { get }

    /// What this driver cannot do on its host yet, each with why: a case needing it is not run, and says so.
    var cannot: [String: String] { get }

    /// Why this driver cannot do `ability` - what `cannot` says of it, unless the driver says more; nil where it says
    /// nothing, and the case needing it fails.
    func reason(cannot ability: String) -> String?

    /// Shows `page` in a window of its own on a new host, its display frames at `clock`'s time where one is
    /// given; the tree it mounted.
    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree

    /// Runs `application` on a new host, its display frames at `clock`'s time where one is given; the tree it
    /// mounted.
    /// - Throws: `DriverCannot` where this driver runs one page alone.
    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree

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

    /// The menu `element` offers as the user meets it - a view's context menu, a window's menu bar: each item by
    /// its caption, "!" before one that cannot be chosen, "-" a separator, a submenu's entries in brackets after its
    /// caption, ";" between; empty for none.
    func menu(of element: MountedElement) throws -> String

    /// Whether `element` holds the keyboard.
    func focused(_ element: MountedElement) throws -> Bool

    /// Whether a press at `point`, in the element's own coordinates, reaches `element` or what stands in it, through
    /// everything its window shows over it.
    func reaches(_ element: MountedElement, at point: Point) throws -> Bool

    /// The question the window of `element` shows now; nil where it shows none.
    func question(over element: MountedElement) throws -> Question?

    /// What the platform's screen reader was told to say, in order, since the host started.
    func announced() throws -> [String]

    /// The colour `element` shows at `point`, in its own coordinates; nil where it shows nothing there. Asked only of
    /// what StateUI draws itself - a canvas, a shape, a box's fill - never of a native control's look.
    func color(of element: MountedElement, at point: Point) throws -> Color?

    /// What the host wrote to its log, a line a message, since it started.
    func logged() throws -> [String]

    /// What the host's store keeps under `key` - one every scene shares, or one of the scene the case's page is
    /// in - as the next launch reads it; nil where it keeps nothing.
    func kept(_ key: String, inScene: Bool) throws -> HostValue?
}

extension HostDriver {
    public func reason(cannot ability: String) -> String? {
        cannot[ability]
    }

    public func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        throw DriverCannot("start an application")
    }

    public func menu(of element: MountedElement) throws -> String {
        throw DriverCannot("read the menu of \(element.type.name)")
    }

    public func focused(_ element: MountedElement) throws -> Bool {
        throw DriverCannot("read the focus of \(element.type.name)")
    }

    public func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        throw DriverCannot("read what reaches \(element.type.name)")
    }

    public func question(over element: MountedElement) throws -> Question? {
        throw DriverCannot("read a question")
    }

    public func announced() throws -> [String] {
        throw DriverCannot("read what the screen reader said")
    }

    public func color(of element: MountedElement, at point: Point) throws -> Color? {
        throw DriverCannot("read the colour of \(element.type.name)")
    }

    public func logged() throws -> [String] {
        throw DriverCannot("read the log")
    }

    public func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        throw DriverCannot("read what is kept")
    }
}

/// A question a window shows the user: its words, and its buttons' captions.
public struct Question: Equatable, Sendable {
    /// Its title.
    public var title: String

    /// Its message; empty for none.
    public var message: String

    /// Its buttons' captions, sorted: their order is the platform's.
    public var buttons: [String]

    /// The words its field holds; nil for a question with no field.
    public var field: String?

    /// A question titled `title`, saying `message`, answered by `buttons`, its field holding `field`.
    public init(title: String, message: String, buttons: [String], field: String? = nil) {
        self.title = title
        self.message = message
        self.buttons = buttons.sorted()
        self.field = field
    }
}
