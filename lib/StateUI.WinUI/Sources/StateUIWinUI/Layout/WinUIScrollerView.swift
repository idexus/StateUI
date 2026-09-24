// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// WinUI's `ScrollViewer`, which a ScrollView stands over its whole room around the document it moves.
/// Design: docs/design/platforms/winui/layout.md#scrolling
@MainActor
final class WinUIScrollerView: WinUIView {
    /// Says where the view stands after it changed, in DIPs.
    var onScrolled: ((Point) -> Void)?

    /// Says the user took hold of the scroller, or let go of it.
    var onHeld: ((Bool) -> Void)?

    init() {
        super.init { number in stateui_winui_scroller_make(number) }
    }

    /// The document it moves, the ways it scrolls, and its bars.
    func set(
        content: WinUIView, orientation: ScrollOrientation, verticalBar: ScrollBarVisibility,
        horizontalBar: ScrollBarVisibility
    ) {
        let way: Int32 = switch orientation {
        case .horizontal: 1
        case .both: 2
        case .neither: 3
        default: 0
        }
        stateui_winui_scroller_set(handle, content.handle, way, Self.bar(verticalBar), Self.bar(horizontalBar))
    }

    private static func bar(_ visibility: ScrollBarVisibility) -> Int32 {
        switch visibility {
        case .always: 1
        case .never: 2
        default: 0
        }
    }

    /// Moves the view to `target` at once; the scroller says where it stands once it has moved.
    func move(to target: Point) {
        stateui_winui_scroller_move(handle, target.x, target.y)
    }

    /// Where the view stands, and the farthest it reaches, in DIPs.
    var standing: (offset: Point, reach: Point) {
        var values = [0.0, 0.0, 0.0, 0.0]
        stateui_winui_scroller_offset(handle, &values)
        return (Point(x: values[0], y: values[1]), Point(x: values[2], y: values[3]))
    }

    override func detach() {
        onScrolled = nil
        onHeld = nil
    }
}
