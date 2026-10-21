// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Canvas: its drawing replayed in order on Core Graphics - the instructions and the pen the host layer reads
/// (`CanvasInstruction`, `CanvasPen`), its arcs the host layer's curves - within its own bounds; a finger on it is
/// heard as it goes down, moves and lifts.
/// Design: docs/design/platforms/uikit/drawing.md#a-canvas
@MainActor
final class UIKitCanvasView: UIView, UIKitSteppable {
    /// What a reader's step performs, while the element says it is adjustable.
    var stepAction: ((AccessibilityAdjustment) -> Void)?

    override func accessibilityIncrement() { stepAction?(.increment) }

    override func accessibilityDecrement() { stepAction?(.decrement) }

    var onPressed: ((CGPoint) -> Void)?
    var onDragged: ((CGPoint) -> Void)?
    var onReleased: ((CGPoint) -> Void)?

    private var instructions: [CanvasInstruction] = []

    init() {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = nil
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitCanvasView is made in code")
    }

    /// The drawing, as its contract declares it; none draws nothing.
    func apply(_ drawing: [DrawCommand]?) {
        instructions = CanvasInstruction.instructions(drawing)
        setNeedsDisplay()
    }

    /// A canvas asks for no room of its own.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .zero
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clip(to: bounds)
        CanvasPen.replay(
            instructions, save: { context.saveGState() }, restore: { context.restoreGState() },
            draw: { instruction, pen in draw(instruction, pen: pen, in: context) })
    }

    private func draw(_ instruction: CanvasInstruction, pen: CanvasPen, in context: CGContext) {
        switch instruction {
        case .strokeLine(let from, let to):
            let path = CGMutablePath()
            path.move(to: CGPoint(x: from.x, y: from.y))
            path.addLine(to: CGPoint(x: to.x, y: to.y))
            stroke(path, pen, context)
        case .strokeRectangle(let room): stroke(CGPath(rect: Self.rect(room), transform: nil), pen, context)
        case .strokeRoundedRectangle(let room, let radius): stroke(Self.rounded(room, radius), pen, context)
        case .strokeEllipse(let room): stroke(CGPath(ellipseIn: Self.rect(room), transform: nil), pen, context)
        case .strokeArc(let room, let start, let end, let clockwise, let closed):
            stroke(UIKitShapeView.path(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false)), pen, context)
        case .strokePath(let curves): stroke(UIKitShapeView.path(curves), pen, context)
        case .fillRectangle(let room): fill(CGPath(rect: Self.rect(room), transform: nil), pen, context)
        case .fillRoundedRectangle(let room, let radius): fill(Self.rounded(room, radius), pen, context)
        case .fillEllipse(let room): fill(CGPath(ellipseIn: Self.rect(room), transform: nil), pen, context)
        case .fillArc(let room, let start, let end, let clockwise):
            fill(UIKitShapeView.path(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: true, wedge: true)), pen, context)
        case .fillPath(let curves): fill(UIKitShapeView.path(curves), pen, context)
        case .text(let text, let room, let across, let down): write(text, in: room, across, down, pen, context)
        case .translate(let x, let y): context.translateBy(x: x, y: y)
        case .rotate(let degrees): context.rotate(by: degrees * .pi / 180)
        case .scale(let x, let y): context.scaleBy(x: x, y: y)
        default: break
        }
    }

    private func stroke(_ path: CGPath, _ pen: CanvasPen, _ context: CGContext) {
        guard pen.lineWidth > 0, let color = Self.color(pen.stroke, pen) else { return }
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(pen.lineWidth)
        context.strokePath()
    }

    private func fill(_ path: CGPath, _ pen: CanvasPen, _ context: CGContext) {
        guard let color = Self.color(pen.fill, pen) else { return }
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    /// Text in its box: placed by the box's two alignments, and cut to it.
    private func write(
        _ text: String, in room: Rect, _ across: TextAlignment, _ down: TextAlignment, _ pen: CanvasPen,
        _ context: CGContext
    ) {
        let box = Self.rect(room)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = NSTextAlignment(CanvasArithmetic.wordsEdge(across))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: pen.fontSize ?? UIFont.body.pointSize),
            .foregroundColor: Self.color(pen.text, pen) ?? .black,
            .paragraphStyle: paragraph,
        ]
        let measured = (text as NSString).boundingRect(
            with: box.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        let top = CanvasArithmetic.wordsTop(height: measured.height, in: room, down: down)
        context.saveGState()
        context.clip(to: box)
        (text as NSString).draw(
            in: CGRect(x: box.minX, y: top, width: box.width, height: measured.height), withAttributes: attributes)
        context.restoreGState()
    }

    private static func color(_ value: HostValue, _ pen: CanvasPen) -> UIColor? {
        guard let color = UIColor(stateUI: value) else { return nil }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return color.withAlphaComponent(alpha * pen.alpha)
    }

    private static func rect(_ room: Rect) -> CGRect {
        CGRect(x: room.x, y: room.y, width: room.width, height: room.height)
    }

    private static func rounded(_ room: Rect, _ radius: Double) -> CGPath {
        CGPath(roundedRect: rect(room), cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    // MARK: - A finger on it

    func pressed(at point: CGPoint) { onPressed?(point) }
    func dragged(to point: CGPoint) { onDragged?(point) }
    func released(at point: CGPoint) { onReleased?(point) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.first.map { pressed(at: $0.location(in: self)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.first.map { dragged(to: $0.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.first.map { released(at: $0.location(in: self)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.first.map { released(at: $0.location(in: self)) }
    }
}
#endif
