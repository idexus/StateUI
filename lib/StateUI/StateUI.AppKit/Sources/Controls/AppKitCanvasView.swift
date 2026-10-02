// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Canvas: its drawing replayed in order - the instructions and the pen the host layer reads
/// (`CanvasInstruction`, `CanvasPen`), its arcs the host layer's curves - within its own frame.
@MainActor
final class AppKitCanvasView: AppKitHitTestView {
    var onPressed: ((NSPoint) -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var onReleased: ((NSPoint) -> Void)?

    private var instructions: [CanvasInstruction] = []

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { .zero }

    /// The drawing, as its contract declares it; none draws nothing.
    func apply(_ drawing: [DrawCommand]?) {
        instructions = CanvasInstruction.instructions(drawing)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current else { return }

        // A canvas draws inside its own frame, as it does on every other
        // platform. A view is not clipped to its bounds, so an instruction
        // reaching past the edge would paint over the views beside it.
        bounds.clip()

        var pen = CanvasPen()
        var saved = 0
        for instruction in instructions {
            if pen.take(instruction) {
                if instruction == .saveState {
                    NSGraphicsContext.saveGraphicsState()
                    saved += 1
                } else if instruction == .restoreState, saved > 0 {
                    NSGraphicsContext.restoreGraphicsState()
                    saved -= 1
                }
                continue
            }
            draw(instruction, pen: pen, in: context.cgContext)
        }
        while saved > 0 {
            NSGraphicsContext.restoreGraphicsState()
            saved -= 1
        }
    }

    private func draw(_ instruction: CanvasInstruction, pen: CanvasPen, in context: CGContext) {
        switch instruction {
        case .strokeLine(let from, let to):
            let path = NSBezierPath()
            path.move(to: NSPoint(x: from.x, y: from.y))
            path.line(to: NSPoint(x: to.x, y: to.y))
            stroke(path, pen)
        case .strokeRectangle(let room): stroke(NSBezierPath(rect: Self.rect(room)), pen)
        case .strokeRoundedRectangle(let room, let radius): stroke(Self.rounded(room, radius), pen)
        case .strokeEllipse(let room): stroke(NSBezierPath(ovalIn: Self.rect(room)), pen)
        case .strokeArc(let room, let start, let end, let clockwise, let closed):
            stroke(Self.path(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false)), pen)
        case .strokePath(let curves): stroke(Self.path(curves), pen)
        case .fillRectangle(let room): fill(NSBezierPath(rect: Self.rect(room)), pen)
        case .fillRoundedRectangle(let room, let radius): fill(Self.rounded(room, radius), pen)
        case .fillEllipse(let room): fill(NSBezierPath(ovalIn: Self.rect(room)), pen)
        case .fillArc(let room, let start, let end, let clockwise):
            fill(Self.path(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: true, wedge: true)), pen)
        case .fillPath(let curves):
            let path = Self.path(curves)
            path.windingRule = .nonZero
            fill(path, pen)
        case .text(let text, let room, let across, let down):
            draw(text: text, in: Self.rect(room), horizontal: across, vertical: down, pen: pen)
        case .translate(let x, let y): context.translateBy(x: x, y: y)
        case .rotate(let degrees): context.rotate(by: degrees * .pi / 180)
        case .scale(let x, let y): context.scaleBy(x: x, y: y)
        default: break
        }
    }

    override func mouseDown(with event: NSEvent) {
        onPressed?(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        onDragged?(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        onReleased?(convert(event.locationInWindow, from: nil))
    }

    var instructionsForTesting: [CanvasInstruction] { instructions }
    func pressForTesting(at point: NSPoint) { onPressed?(point) }
    func dragForTesting(at point: NSPoint) { onDragged?(point) }
    func releaseForTesting(at point: NSPoint) { onReleased?(point) }

    private static func rect(_ room: Rect) -> NSRect {
        NSRect(x: room.x, y: room.y, width: room.width, height: room.height)
    }

    private static func rounded(_ room: Rect, _ radius: Double) -> NSBezierPath {
        let radius = max(0, radius)
        return NSBezierPath(roundedRect: rect(room), xRadius: radius, yRadius: radius)
    }

    /// The path the host layer's curves draw.
    private static func path(_ curves: [HostCurveCommand]) -> NSBezierPath {
        let path = NSBezierPath()
        func point(_ point: Point) -> NSPoint { NSPoint(x: point.x, y: point.y) }
        for curve in curves {
            switch curve {
            case .move(let to): path.move(to: point(to))
            case .line(let to): path.line(to: point(to))
            case .cubic(let first, let second, let end):
                path.curve(to: point(end), controlPoint1: point(first), controlPoint2: point(second))
            case .quadratic(let control, let end):
                let from = path.isEmpty ? point(control) : path.currentPoint
                let first = NSPoint(x: from.x + 2 / 3 * (control.x - from.x), y: from.y + 2 / 3 * (control.y - from.y))
                let second = NSPoint(x: end.x + 2 / 3 * (control.x - end.x), y: end.y + 2 / 3 * (control.y - end.y))
                path.curve(to: point(end), controlPoint1: first, controlPoint2: second)
            case .close: path.close()
            }
        }
        return path
    }

    private static func color(_ value: HostValue, _ pen: CanvasPen) -> NSColor? {
        nsColor(value).map { $0.withAlphaComponent($0.alphaComponent * pen.alpha) }
    }

    private func stroke(_ path: NSBezierPath, _ pen: CanvasPen) {
        guard pen.strokeWidth > 0, let color = Self.color(pen.stroke, pen) else { return }
        color.setStroke()
        path.lineWidth = pen.strokeWidth
        path.stroke()
    }

    private func fill(_ path: NSBezierPath, _ pen: CanvasPen) {
        guard let color = Self.color(pen.fill, pen) else { return }
        color.setFill()
        path.fill()
    }

    private func draw(
        text: String, in rectangle: NSRect, horizontal: TextAlignment, vertical: TextAlignment, pen: CanvasPen
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = switch horizontal {
        case .center: .center
        case .end: .right
        case .start: .left
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: pen.fontSize ?? NSFont.systemFontSize),
            .foregroundColor: Self.color(pen.text, pen) ?? .black,
            .paragraphStyle: paragraph,
        ]
        let measured = (text as NSString).boundingRect(
            with: rectangle.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes)
        let y: CGFloat = switch vertical {
        case .center: rectangle.midY - measured.height / 2
        case .end: rectangle.maxY - measured.height
        case .start: rectangle.minY
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rectangle).addClip()
        (text as NSString).draw(
            in: NSRect(x: rectangle.minX, y: y, width: rectangle.width, height: measured.height),
            withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}

#endif
