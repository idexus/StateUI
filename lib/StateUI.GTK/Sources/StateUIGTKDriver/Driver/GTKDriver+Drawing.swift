// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What the GTK driver reads of what StateUI draws, and does on a canvas as its user does: the colour a view shows at
/// a point, as GTK renders it, and a press, its drag and its release through the canvas's own gesture.
/// Design: docs/design/host/conformance.md#a-colour-drawn
extension GTKDriver {
    /// The colour `element` shows at `point`, in its own coordinates, as GTK renders it; nil where it shows nothing.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? GTKElement)?.view else {
            throw DriverCannot("read the colour of \(element.type.name)")
        }
        renderer?.layOut()
        guard let pixel = view.pixels(at: [(point.x, point.y)]).first, pixel >> 24 != 0 else { return nil }
        let alpha = Int(pixel >> 24)
        let channel = { (shift: UInt32) in min(255, Int((pixel >> shift) & 0xFF) * 255 / alpha) }
        return Color(red: channel(16), green: channel(8), blue: channel(0), alpha: alpha)
    }

    /// A press, its drag and its release on a canvas, as its gesture tells them: a drag and a release by how far
    /// they are from the press.
    func press(_ act: UserAct, on canvas: GTKCanvasView, _ element: MountedElement) throws {
        let from = canvas.pressedAt
        switch act {
        case .pressDown(let at): GTKTestHost.emit(canvas.drag, "drag-begin", [at.x, at.y])
        case .drag(let to): GTKTestHost.emit(canvas.drag, "drag-update", [to.x - from.x, to.y - from.y])
        case .lift(let at): GTKTestHost.emit(canvas.drag, "drag-end", [at.x - from.x, at.y - from.y])
        default: throw DriverCannot(act, on: element)
        }
    }
}
