// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What a finger, a mouse and a trackpad do to a view, through the controllers it listens with: each act the
/// signals GTK's own controller emits as it recognizes it.
/// Design: docs/design/platforms/gtk/input.md#taps
extension GTKDriver {
    /// Performs `act` through `view`'s controllers; false where the view hears no such input.
    func input(_ act: UserAct, on view: GTKView) -> Bool {
        if let button = view as? GTKButtonView, case .pressDown = act { pressButton(button, act) }
        if let button = view as? GTKButtonView, case .lift = act { pressButton(button, act) }
        guard let listening = view.listening else { return view is GTKButtonView && ["pressDown", "lift"].contains(act.description) }
        let controllers = { (kind: Hearing) in listening.controllers[kind] ?? [] }
        renderer?.layOut()
        switch act {
        case .tap, .activate:
            guard let click = controllers(.taps).first else { return false }
            let (x, y) = Self.middle(of: view)
            for run in 1...Self.taps(in: act) {
                GTKTestHost.emit(click, "pressed", [Double(run), x, y])
                GTKTestHost.emit(click, "released", [Double(run), x, y])
            }
        case .pan(let offset):
            guard let drag = controllers(.drags).first else { return false }
            GTKTestHost.emit(drag, "drag-begin", [0, 0])
            GTKTestHost.emit(drag, "drag-update", [offset.x / 2, offset.y / 2])
            GTKTestHost.emit(drag, "drag-update", [offset.x, offset.y])
            GTKTestHost.emit(drag, "drag-end", [offset.x, offset.y])
        // GTK takes no touch a driver could put down, so the fingers' place reaches the host's recognizer as GTK's
        // zoom would hand it - ✓.
        case .pinch(let scale, let at):
            guard view.hearing.contains(.pinches) else { return false }
            view.heard(.pinch(.started, scale: 1, at: at))
            view.heard(.pinch(.running, scale: scale, at: at))
            view.heard(.pinch(.completed, scale: 1, at: at))
        case .hover(let point):
            guard let motion = controllers(.pointer).first else { return false }
            GTKTestHost.emit(motion, "enter", [point.x, point.y])
            GTKTestHost.emit(motion, "motion", [point.x, point.y])
        case .leave:
            guard let motion = controllers(.pointer).first else { return false }
            GTKTestHost.emit(motion, "leave")
        case .pressDown(let point):
            guard let press = controllers(.pointer).last else { return view is GTKButtonView }
            pressed.at = point
            GTKTestHost.emit(press, "drag-begin", [point.x, point.y])
        case .drag(let point):
            guard let motion = controllers(.pointer).first else { return false }
            GTKTestHost.emit(motion, "motion", [point.x, point.y])
        case .lift(let point):
            guard let press = controllers(.pointer).last else { return view is GTKButtonView }
            GTKTestHost.emit(press, "drag-end", [point.x - pressed.at.x, point.y - pressed.at.y])
        default: return false
        }
        return true
    }

    /// A press going down on a button or let go, as the button's own gesture takes it.
    private func pressButton(_ button: GTKButtonView, _ act: UserAct) {
        if case .pressDown = act { GTKTestHost.emit(button.press, "drag-begin", [0, 0]) }
        if case .lift = act { GTKTestHost.emit(button.press, "drag-end", [0, 0]) }
    }

    /// How many taps an act is: a tap's count, one for activating a view that hears taps.
    private static func taps(in act: UserAct) -> Int {
        if case .tap(let count) = act { return max(count, 1) }
        return 1
    }

    /// The middle of the view, where a tap lands.
    private static func middle(of view: GTKView) -> (Double, Double) {
        (Double(gtk_widget_get_width(view.widget)) / 2, Double(gtk_widget_get_height(view.widget)) / 2)
    }
}

/// Where the pointer's press went down, which its release is measured from.
final class GTKPress {
    var at = Point(x: 0, y: 0)
}
