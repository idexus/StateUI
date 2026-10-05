// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a canvas draws with: each setting holds until the next of its kind, `saveState` remembers them all and
/// `restoreState` puts them back - the same on every host drawing in Swift.
/// Design: docs/design/types/drawing.md#settings-hold-until-changed
@_spi(Host) public struct CanvasPen: Equatable, Sendable {
    /// The colour fills are drawn in: black until set.
    public var fill: HostValue = .color(red: 0, green: 0, blue: 0, alpha: 255)

    /// The colour outlines are drawn in: black until set.
    public var stroke: HostValue = .color(red: 0, green: 0, blue: 0, alpha: 255)

    /// The colour text is drawn in: black until set.
    public var text: HostValue = .color(red: 0, green: 0, blue: 0, alpha: 255)

    /// An outline's width, never below nothing: one until set.
    public var lineWidth = 1.0

    /// The text's size in points; the platform's own until set.
    public var fontSize: Double?

    /// How opaque everything is drawn, from nothing to whole: whole until set.
    public var alpha = 1.0

    private var saved: [CanvasPen] = []

    /// A pen drawing black, one wide, whole.
    public init() {}

    /// Takes `instruction` where it is a setting or a state's saving or putting back: whether it was one.
    public mutating func take(_ instruction: CanvasInstruction) -> Bool {
        switch instruction {
        case .fillColor(let color): fill = color
        case .strokeColor(let color): stroke = color
        case .textColor(let color): text = color
        case .lineWidth(let width): lineWidth = max(0, width)
        case .fontSize(let size): fontSize = max(0, size)
        case .opacity(let value): alpha = min(max(value, 0), 1)
        case .saveState: saved.append(self)
        case .restoreState:
            guard let last = saved.popLast() else { return true }
            let stack = saved
            self = last
            saved = stack
        default: return false
        }
        return true
    }

    /// How many states are saved and not yet put back.
    public var savedDepth: Int { saved.count }

    /// Replays `instructions` in order with a pen from its start: each setting taken into it, each state saved told
    /// to `save` and each put back to `restore` - one with none saved does nothing - and every other instruction
    /// drawn by `draw` with the pen as it stands.
    public static func replay(
        _ instructions: [CanvasInstruction], save: () -> Void, restore: () -> Void,
        draw: (CanvasInstruction, CanvasPen) -> Void
    ) {
        var pen = CanvasPen()
        for instruction in instructions {
            let depth = pen.savedDepth
            guard pen.take(instruction) else {
                draw(instruction, pen)
                continue
            }
            if pen.savedDepth > depth { save() } else if pen.savedDepth < depth { restore() }
        }
    }
}
