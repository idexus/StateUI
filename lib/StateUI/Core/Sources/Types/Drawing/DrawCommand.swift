// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a Canvas draws: one record per canvas operation, in order, which the
// host replays against its toolkit's own canvas.
// Design: docs/design/types/drawing.md#a-drawing-is-a-list-of-records

/// One instruction for the canvas. Written with `Draw`, never by hand.
public struct DrawCommand: Equatable, Sendable {
    /// The canvas operation an instruction calls, as the number it crosses as.
    /// The host switches on the same numbers: add a case at the end only.
    /// Design: docs/design/types/drawing.md#the-kinds-are-the-contract
    enum Kind: Int32, Sendable {
        // What the canvas draws with.
        case fillColor = 0
        case strokeColor = 1
        case textColor = 2
        case lineWidth = 3
        case fontSize = 4
        case opacity = 5

        // Outlines.
        case strokeLine = 6
        case strokeRectangle = 7
        case strokeRoundedRectangle = 8
        case strokeEllipse = 9
        case strokeArc = 10
        case strokePath = 11

        // Solid shapes.
        case fillRectangle = 12
        case fillRoundedRectangle = 13
        case fillEllipse = 14
        case fillArc = 15
        case fillPath = 16

        // Text.
        case text = 17

        // Where the canvas draws.
        case translate = 18
        case rotate = 19
        case scale = 20
        case saveState = 21
        case restoreState = 22
    }

    /// Which canvas call this instruction is.
    let kind: Kind

    /// Its arguments, in the order the host reads them, each as the value it is.
    let arguments: [PropValue]

    init(_ kind: Kind, _ arguments: [PropValue] = []) {
        self.kind = kind
        self.arguments = arguments
    }

}

extension DrawCommand: HostRepresentable {
    /// The kind, then its arguments.
    public var propValue: PropValue {
        .values([.enumeration(kind.rawValue)] + arguments)
    }

    /// The instruction a record names: its kind, then its arguments as they
    /// are - nil where the first value is no kind this library draws.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, case .enumeration(let number)? = parts.first,
              let kind = Kind(rawValue: number)
        else { return nil }

        self.init(kind, Array(parts.dropFirst()))
    }
}
