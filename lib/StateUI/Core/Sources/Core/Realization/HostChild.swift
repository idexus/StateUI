// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One child element a registered view draws itself - a map's marker: what it is read and reported through. The host
/// keeps one for as long as the child lives, so a child is the same object every time its parent's view is handed it.
@MainActor
@_spi(Host) public final class HostChild {
    /// The child's current value for a key, as the host presents it.
    let read: @MainActor (Prop) -> HostValue?

    /// Given each event the child raises, and what it carries.
    let send: @MainActor (Event, [HostValue]) -> Void

    /// Given each value the user changed on the child: the property, the event to raise for it, and the value.
    let carry: @MainActor (Prop, Event, HostValue) -> Void

    /// A child, read and reported through the functions given.
    ///
    /// - Parameters:
    ///   - read: the child's current value for a key.
    ///   - send: given each event the child raises.
    ///   - carry: given each value the user changed on the child.
    public init(
        reading read: @escaping @MainActor (Prop) -> HostValue?,
        sending send: @escaping @MainActor (Event, [HostValue]) -> Void,
        reporting carry: @escaping @MainActor (Prop, Event, HostValue) -> Void
    ) {
        self.read = read
        self.send = send
        self.carry = carry
    }
}
