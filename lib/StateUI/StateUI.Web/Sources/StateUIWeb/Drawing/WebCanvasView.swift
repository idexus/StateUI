// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Canvas: its drawing replayed in order on a `<canvas>` filling the room its layout gives it - the instructions
/// and the pen the host layer reads (`CanvasInstruction`, `CanvasPen`), its arcs the host layer's curves - drawn
/// again as the room or the screen's density changes.
/// Design: docs/design/platforms/web/drawing.md#a-canvas
@MainActor
final class WebCanvasView: WebDOMView {
    private let surface = WebDOMView(tag: "canvas")
    private var instructions: [CanvasInstruction] = []

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-canvas")
        WebRelay.insert(surface.node, into: node, at: 0)
        followSize { [weak self] in self?.redraw() }
        WebRelay.listenToDensity(held(WebRelay.listener { [weak self] in self?.redraw() }))
    }

    /// The drawing, as its contract declares it; none draws nothing.
    func apply(_ drawing: [DrawCommand]?) {
        instructions = CanvasInstruction.instructions(drawing)
        redraw()
    }

    private func redraw() {
        let stroke = WebCanvasStroke(instructions)
        WebRelay.drawCanvas(surface.node, stroke.numbers, words: stroke.words)
    }

    override func release() {
        surface.release()
        super.release()
    }
}
