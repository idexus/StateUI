// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) extension HostStateValue {
    /// The value a state takes from what a control reported: words as text, a flag, a number, numbers or a
    /// choice as lanes; nil for what no state carries.
    public init?(carrying value: HostValue) {
        switch value {
        case .string(let text): self = .text(text)
        case .name(let name): self = .text(name)
        case .bool(let flag): self = .lanes([flag ? 1 : 0])
        case .number(let number): self = .lanes([number])
        case .numbers(let numbers): self = .lanes(numbers)
        case .enumeration(let choice): self = .lanes([Double(choice)])
        default: return nil
        }
    }
}

/// What the user does to an element's native control, carried into the runtime alike on every host.
/// Design: docs/design/host/runtime.md#a-users-change
extension MountedElement {
    /// An event the control raised, with what it carries, to the handler the tree listens with.
    public func send(_ event: Event, _ values: [HostValue], in runtime: HostRuntime) {
        guard let handler = handler(event) else { return }
        runtime.dispatch(handler, payload: values)
    }

    /// A value the user changed: onto the state carrying it, then the event with it. A radio button checked takes
    /// its set's other checks away first - `turnOff` writing each off as the program - each reporting that it is
    /// off, in one transaction. What the program writes reports nothing.
    public func reportUserChange(
        _ property: Prop, _ event: Event, _ value: HostValue, in runtime: HostRuntime,
        turningOff turnOff: (MountedElement) -> Void
    ) {
        guard !ProgramWrite.isWriting else { return }
        guard type == .radioButton, property == .isOn, value == .bool(true) else {
            return carry(property, event, value, in: runtime)
        }
        runtime.performUserTransaction {
            for peer in radioPeers where peer.value(.isOn)?.bool == true {
                ProgramWrite.perform { turnOff(peer) }
                peer.carry(.isOn, event, .bool(false), in: runtime)
            }
            carry(property, event, value, in: runtime)
        }
    }

    /// The user moved the scroller from `old` to `new`, as the display's frame saw it: onto its state first, then
    /// the events, as one user's transaction.
    public func reportScrolled(from old: Point, to new: Point, in runtime: HostRuntime) {
        runtime.performUserTransaction {
            if old != new, let binding = driven[.scrollOffset] {
                runtime.take([new.x, new.y], through: binding)
            }
            if old.x != new.x, let handler = handler(.scrollXChanged) {
                runtime.dispatch(handler, payload: [.number(new.x)])
            }
            if old.y != new.y, let handler = handler(.scrollYChanged) {
                runtime.dispatch(handler, payload: [.number(new.y)])
            }
        }
    }

    /// One value onto the state that carries it - a journey the host carries, else a report - then the event with
    /// it; with no handler, a turn renders what the state changed.
    private func carry(_ property: Prop, _ event: Event, _ value: HostValue, in runtime: HostRuntime) {
        var reported = false
        if let carried = HostStateValue(carrying: value), let binding = driven[property] {
            if case .lanes(let lanes) = carried, binding.kind == .property {
                reported = runtime.take(lanes, through: binding)
            } else {
                reported = runtime.report(carried, through: binding)
            }
        }

        if let handler = handler(event) {
            runtime.dispatch(handler, payload: [value])
        } else if reported {
            runtime.pump.turn()
        }
    }
}
