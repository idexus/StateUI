// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host's toolkit does for the acts every host performs (`HostActPerformer`): the time and the zones, a
/// question shown, a word to a screen reader, the focus and the on-screen keyboard, a value kept.
/// Design: docs/design/host/runtime.md#acts
@_spi(Host) @MainActor public protocol ActToolkit: AnyObject {
    /// The host's name, as a failure names it.
    var host: String { get }

    /// The local time of day.
    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int)

    /// The name of the local time zone.
    func localZone() -> String

    /// How far `zone` - the local one where nil - is from UTC at `day`'s noon - now where nil - in minutes; nil for a
    /// zone the platform does not know.
    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int?

    /// Shows `question` to the user in the window they are looking at, and calls `answered` - whether they
    /// accepted, and the words they gave - when they answer; false where there is no window to ask in.
    func show(_ question: HostQuestion, answered: @escaping (_ accepted: Bool, _ words: String?) -> Void) -> Bool

    /// Tells the screen reader `words`, now.
    func announce(_ words: String)

    /// Shows the whole application in `theme`: light, dark, or the system's again.
    func useColorScheme(_ theme: ColorScheme)

    /// Takes the on-screen keyboard down; whether one was up.
    func hideOnScreenKeyboard() -> Bool

    /// Puts the focus on `element`'s view, or the first view in it that takes it: whether it took it; nil where the
    /// element shows no view.
    func focus(_ element: MountedElement) -> Bool?

    /// Takes the focus off `element`'s view, where it holds it; false where the element shows no view.
    func unfocus(_ element: MountedElement) -> Bool

    /// Keeps the value `call` - `persistValue` or `persistSceneValue` - writes; whether this host keeps it.
    func keep(_ call: HostActCall) -> Bool

    /// Performs an act this host's own controls answer, as a web view goes back; whether it did.
    func performOwn(_ call: HostActCall) -> Bool

    /// Performs an act the application registered (`InteropActs`); whether it did.
    func performRegistered(_ call: HostActCall) -> Bool

    /// Writes `message` to the host's log.
    func log(_ message: String)
}

/// Where a host's answers to acts go: the core, which hands each to the caller waiting on it.
@_spi(Host) @MainActor public protocol ActAnswering {
    /// Answers `call` with `values`, where a caller waits on it.
    func reply(_ call: HostActCall, _ values: [HostValue])

    /// Fails `call` with `reason`: a caller waiting on it throws the reason; one nobody waits on is told to `log`.
    func fail(_ call: HostActCall, _ reason: String, log: (String) -> Void)
}

extension CoreLink: ActAnswering {}
