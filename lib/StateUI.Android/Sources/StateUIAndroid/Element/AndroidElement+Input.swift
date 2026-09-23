// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to the element's view, reported to the core.
extension AndroidElement {
    /// An event the view raised, with what it carries, to the handler the tree listens with.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let handler = element.handler(event) else { return }

        host?.dispatch(handler, payload: values)
    }

    /// A value the user changed in the view: onto its state first, then the event with it.
    /// Design: docs/design/host/patches.md#program-write
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host, !ProgramWrite.isWriting else { return }

        let carried: HostStateValue? = switch value {
        case .string(let text): .text(text)
        case .name(let name): .text(name)
        case .bool(let flag): .lanes([flag ? 1 : 0])
        case .number(let number): .lanes([number])
        case .numbers(let numbers): .lanes(numbers)
        case .enumeration(let choice): .lanes([Double(choice)])
        default: nil
        }

        var reported = false
        if let carried, let binding = element.driven[property] {
            if case .lanes(let lanes) = carried, binding.kind == .property {
                reported = host.take(lanes, through: binding)
            } else {
                reported = host.report(carried, through: binding)
            }
        }

        if let handler = element.handler(event) {
            host.dispatch(handler, payload: [value])
        } else if reported {
            host.pump()
        }
    }

    /// The user moved a scroller: onto its offset state first, then an event for each axis that moved.
    /// Design: docs/design/host/runtime.md#a-scrollers-movement
    func scrolled(from old: Point, to new: Point) {
        guard let host else { return }

        host.performUserTransaction {
            if old != new, let binding = element.driven[.scrollOffset] {
                host.take([new.x, new.y], through: binding)
            }
            if old.x != new.x, let handler = element.handler(.scrollXChanged) {
                host.dispatch(handler, payload: [.number(new.x)])
            }
            if old.y != new.y, let handler = element.handler(.scrollYChanged) {
                host.dispatch(handler, payload: [.number(new.y)])
            }
        }
    }

    /// Whether the tree reads where this element stands: a state its frame drives, or a handler for its changes.
    var readsFrame: Bool {
        view != nil && (element.driven[.frame] != nil || element.handler(.frameChanged) != nil)
    }

    /// Says where the element stands, where that changed: onto the state its frame drives, and to its handler.
    /// Design: docs/design/platforms/android/layout.md#where-a-view-stands
    func reportFrame() {
        guard let host, let view, readsFrame else { return }

        let report = view.frameReport(safeArea: host.safeAreaOrigin)
        guard report != lastFrameReport else { return }
        lastFrameReport = report

        host.performUserTransaction {
            if let binding = element.driven[.frame] {
                host.report(.lanes(Array(report.prefix(4))), through: binding)
            }
            if let handler = element.handler(.frameChanged) {
                host.dispatch(handler, payload: [.numbers(report)])
            }
        }
    }
}
