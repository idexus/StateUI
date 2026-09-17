// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Native canvas that replays StateUI's closed drawing vocabulary in authored
/// order. The command list is decoded before drawing, so malformed records are
/// skipped outside AppKit's draw pass and every redraw sees one immutable plan.
@MainActor
final class AppKitCanvasView: AppKitHitTestView {
    var onPressed: ((NSPoint) -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var onReleased: ((NSPoint) -> Void)?

    private enum Command {
        case fillColor(NSColor)
        case strokeColor(NSColor)
        case textColor(NSColor)
        case strokeWidth(CGFloat)
        case fontSize(CGFloat)
        case alpha(CGFloat)
        case drawLine([CGFloat])
        case drawRectangle([CGFloat])
        case drawRoundedRectangle([CGFloat])
        case drawEllipse([CGFloat])
        case drawArc([CGFloat], clockwise: Bool, closed: Bool)
        case drawPath(String)
        case fillRectangle([CGFloat])
        case fillRoundedRectangle([CGFloat])
        case fillEllipse([CGFloat])
        case fillArc([CGFloat], clockwise: Bool)
        case fillPath(String)
        case drawText(
            text: String,
            rect: NSRect,
            horizontal: Int32,
            vertical: Int32)
        case translate(CGFloat, CGFloat)
        case rotate(CGFloat)
        case scale(CGFloat, CGFloat)
        case save
        case restore

        var kind: Int32 {
            switch self {
            case .fillColor: 0
            case .strokeColor: 1
            case .textColor: 2
            case .strokeWidth: 3
            case .fontSize: 4
            case .alpha: 5
            case .drawLine: 6
            case .drawRectangle: 7
            case .drawRoundedRectangle: 8
            case .drawEllipse: 9
            case .drawArc: 10
            case .drawPath: 11
            case .fillRectangle: 12
            case .fillRoundedRectangle: 13
            case .fillEllipse: 14
            case .fillArc: 15
            case .fillPath: 16
            case .drawText: 17
            case .translate: 18
            case .rotate: 19
            case .scale: 20
            case .save: 21
            case .restore: 22
            }
        }
    }

    private struct State {
        var fill = NSColor.black
        var stroke = NSColor.black
        var font = NSColor.black
        var strokeWidth: CGFloat = 1
        var fontSize = NSFont.systemFontSize
        var alpha: CGFloat = 1
    }

    private var commands: [Command] = []

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { .zero }

    func apply(_ drawable: HostValue?) {
        commands = decode(drawable)
        needsDisplay = true
    }

    /// The drawing as its contract declares it - one record per instruction,
    /// in the order they were authored.
    ///
    /// A registration hands a view the value its member declares, so this
    /// takes the typed records and reads them through the one decoder above:
    /// `DrawCommand` writes itself as the same record the wire carries, and a
    /// second table of twenty-three instructions would be a second place to
    /// get one wrong.
    ///
    /// - Parameter drawing: the instructions, or none to draw nothing.
    func apply(_ drawing: [DrawCommand]?) {
        apply(drawing.map { PropValue.values($0.map(\.propValue)) })
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current else { return }

        // A canvas draws inside its own frame, as it does on every other
        // platform. A view is not clipped to its bounds, so an instruction
        // reaching past the edge would paint over the views beside it.
        bounds.clip()

        var state = State()
        var states: [State] = []
        var nativeSaveDepth = 0

        for command in commands {
            switch command {
            case .fillColor(let color): state.fill = color
            case .strokeColor(let color): state.stroke = color
            case .textColor(let color): state.font = color
            case .strokeWidth(let size): state.strokeWidth = max(0, size)
            case .fontSize(let size): state.fontSize = max(0, size)
            case .alpha(let alpha): state.alpha = min(max(alpha, 0), 1)

            case .drawLine(let values):
                let path = NSBezierPath()
                path.move(to: NSPoint(x: values[0], y: values[1]))
                path.line(to: NSPoint(x: values[2], y: values[3]))
                stroke(path, state: state)

            case .drawRectangle(let values):
                stroke(NSBezierPath(rect: rect(values)), state: state)

            case .drawRoundedRectangle(let values):
                let rectangle = rect(values)
                let radius = max(0, values[4])
                stroke(
                    NSBezierPath(roundedRect: rectangle, xRadius: radius, yRadius: radius),
                    state: state)

            case .drawEllipse(let values):
                stroke(NSBezierPath(ovalIn: rect(values)), state: state)

            case .drawArc(let values, let clockwise, let closed):
                stroke(AppKitShapeView.ellipseArcPath(
                    in: rect(values),
                    startAngle: values[4],
                    endAngle: values[5],
                    clockwise: clockwise,
                    closed: closed,
                    wedge: false), state: state)

            case .drawPath(let data):
                stroke(AppKitShapeView.svgPath(data), state: state)

            case .fillRectangle(let values):
                fill(NSBezierPath(rect: rect(values)), state: state)

            case .fillRoundedRectangle(let values):
                let rectangle = rect(values)
                let radius = max(0, values[4])
                fill(
                    NSBezierPath(roundedRect: rectangle, xRadius: radius, yRadius: radius),
                    state: state)

            case .fillEllipse(let values):
                fill(NSBezierPath(ovalIn: rect(values)), state: state)

            case .fillArc(let values, let clockwise):
                fill(AppKitShapeView.ellipseArcPath(
                    in: rect(values),
                    startAngle: values[4],
                    endAngle: values[5],
                    clockwise: clockwise,
                    closed: true,
                    wedge: true), state: state)

            case .fillPath(let data):
                let path = AppKitShapeView.svgPath(data)
                path.windingRule = .nonZero
                fill(path, state: state)

            case .drawText(let text, let rectangle, let horizontal, let vertical):
                draw(
                    text: text,
                    in: rectangle,
                    horizontal: horizontal,
                    vertical: vertical,
                    state: state)

            case .translate(let x, let y):
                context.cgContext.translateBy(x: x, y: y)

            case .rotate(let degrees):
                context.cgContext.rotate(by: degrees * .pi / 180)

            case .scale(let x, let y):
                context.cgContext.scaleBy(x: x, y: y)

            case .save:
                states.append(state)
                NSGraphicsContext.saveGraphicsState()
                nativeSaveDepth += 1

            case .restore:
                guard let saved = states.popLast(), nativeSaveDepth > 0 else { continue }
                state = saved
                NSGraphicsContext.restoreGraphicsState()
                nativeSaveDepth -= 1
            }
        }

        while nativeSaveDepth > 0 {
            NSGraphicsContext.restoreGraphicsState()
            nativeSaveDepth -= 1
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

    var commandKindsForTesting: [Int32] { commands.map(\.kind) }
    func pressForTesting(at point: NSPoint) { onPressed?(point) }
    func dragForTesting(at point: NSPoint) { onDragged?(point) }
    func releaseForTesting(at point: NSPoint) { onReleased?(point) }

    private func decode(_ value: HostValue?) -> [Command] {
        guard let records = value?.values else { return [] }
        return records.compactMap { recordValue in
            guard let record = recordValue.values,
                  let kind = record.first?.enumeration
            else { return nil }

            switch kind {
            case 0: return color(record, at: 1).map(Command.fillColor)
            case 1: return color(record, at: 1).map(Command.strokeColor)
            case 2: return color(record, at: 1).map(Command.textColor)
            case 3: return numbers(record, at: 1, count: 1).map { .strokeWidth($0[0]) }
            case 4: return numbers(record, at: 1, count: 1).map { .fontSize($0[0]) }
            case 5: return numbers(record, at: 1, count: 1).map { .alpha($0[0]) }
            case 6: return numbers(record, at: 1, count: 4).map(Command.drawLine)
            case 7: return numbers(record, at: 1, count: 4).map(Command.drawRectangle)
            case 8: return numbers(record, at: 1, count: 5).map(Command.drawRoundedRectangle)
            case 9: return numbers(record, at: 1, count: 4).map(Command.drawEllipse)
            case 10:
                guard let values = numbers(record, at: 1, count: 6),
                      let clockwise = record.value(7)?.bool,
                      let closed = record.value(8)?.bool
                else { return nil }
                return .drawArc(values, clockwise: clockwise, closed: closed)
            case 11:
                return record.value(1)?.string.map(Command.drawPath)
            case 12: return numbers(record, at: 1, count: 4).map(Command.fillRectangle)
            case 13: return numbers(record, at: 1, count: 5).map(Command.fillRoundedRectangle)
            case 14: return numbers(record, at: 1, count: 4).map(Command.fillEllipse)
            case 15:
                guard let values = numbers(record, at: 1, count: 6),
                      let clockwise = record.value(7)?.bool
                else { return nil }
                return .fillArc(values, clockwise: clockwise)
            case 16:
                return record.value(1)?.string.map(Command.fillPath)
            case 17:
                guard let values = numbers(record, at: 1, count: 4),
                      let horizontal = record.value(5)?.enumeration,
                      let vertical = record.value(6)?.enumeration,
                      let text = record.value(7)?.string
                else { return nil }
                return .drawText(
                    text: text,
                    rect: rect(values),
                    horizontal: horizontal,
                    vertical: vertical)
            case 18:
                return numbers(record, at: 1, count: 2).map { .translate($0[0], $0[1]) }
            case 19:
                return numbers(record, at: 1, count: 1).map { .rotate($0[0]) }
            case 20:
                return numbers(record, at: 1, count: 2).map { .scale($0[0], $0[1]) }
            case 21: return .save
            case 22: return .restore
            default: return nil
            }
        }
    }

    private func color(_ record: [HostValue], at index: Int) -> NSColor? {
        record.value(index).flatMap(nsColor)
    }

    private func numbers(
        _ record: [HostValue],
        at start: Int,
        count: Int
    ) -> [CGFloat]? {
        guard start >= 0, count >= 0, start + count <= record.count else { return nil }
        var result: [CGFloat] = []
        result.reserveCapacity(count)
        for index in start..<(start + count) {
            guard let value = record[index].number, value.isFinite else { return nil }
            result.append(CGFloat(value))
        }
        return result
    }

    private func rect(_ values: [CGFloat]) -> NSRect {
        NSRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    private func stroke(_ path: NSBezierPath, state: State) {
        guard state.strokeWidth > 0 else { return }
        state.stroke.withAlphaComponent(state.stroke.alphaComponent * state.alpha).setStroke()
        path.lineWidth = state.strokeWidth
        path.stroke()
    }

    private func fill(_ path: NSBezierPath, state: State) {
        state.fill.withAlphaComponent(state.fill.alphaComponent * state.alpha).setFill()
        path.fill()
    }

    private func draw(
        text: String,
        in rectangle: NSRect,
        horizontal: Int32,
        vertical: Int32,
        state: State
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = switch horizontal {
        case 1: .center
        case 2: .right
        default: .left
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: state.fontSize),
            .foregroundColor: state.font.withAlphaComponent(
                state.font.alphaComponent * state.alpha),
            .paragraphStyle: paragraph,
        ]
        let measured = (text as NSString).boundingRect(
            with: rectangle.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes)
        let y: CGFloat = switch vertical {
        case 1: rectangle.midY - measured.height / 2
        case 2: rectangle.maxY - measured.height
        default: rectangle.minY
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
