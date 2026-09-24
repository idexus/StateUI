// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A WinUI element Swift holds, and the number the relay calls back with.
/// Design: docs/design/platforms/winui/relay.md#a-view-and-its-number
@MainActor
class WinUIView {
    /// The element, held until this is released.
    let handle: StateUIObjectRef

    /// The number the relay's callbacks name this view by.
    let number: Int64

    private static var nextNumber: Int64 = 0
    private static var live: [Int64: Weak] = [:]

    /// Takes the next number and holds the element `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> StateUIObjectRef?) {
        Self.nextNumber += 1
        number = Self.nextNumber
        guard let handle = make(number) else { fatalError("the relay made no element - its log says why") }
        self.handle = handle
        Self.live[number] = Weak(self)
    }

    isolated deinit {
        Self.live[number] = nil
        stateui_winui_release(handle)
    }

    /// The live view a callback names; nil once it has left.
    static func find(_ number: Int64) -> WinUIView? {
        live[number]?.view
    }

    /// How many views Swift holds - what a test counts to see every one let go.
    static var liveCount: Int { live.count }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        stateui_winui_set_shown(handle, shown)
    }

    func setOpacity(_ opacity: Double) {
        stateui_winui_set_opacity(handle, opacity)
    }

    /// Asks WinUI to measure this element again, and every panel above it.
    func invalidateMeasure() {
        stateui_winui_invalidate_measure(handle)
    }

    /// The element's size for the room offered, in DIPs; nil offers any.
    /// Design: docs/design/platforms/winui/layout.md#measured-every-pass
    func measure(width: Double?, height: Double?) -> LayoutSize {
        var size = [0.0, 0.0]
        stateui_winui_measure(handle, width ?? .infinity, height ?? .infinity, &size)
        return LayoutSize(width: size[0], height: size[1])
    }

    /// Places the element at `place`, in DIPs of its parent - only inside the parent's arrangement.
    /// Design: docs/design/platforms/winui/layout.md#a-layout-is-a-panel
    func layout(_ place: Rect) {
        stateui_winui_arrange(handle, place.x, place.y, place.width, place.height)
    }

    /// Where WinUI laid the element out in its parent, in DIPs.
    var laidOutFrame: Rect {
        var frame = [0.0, 0.0, 0.0, 0.0]
        stateui_winui_frame(handle, &frame)
        return Rect(x: frame[0], y: frame[1], width: frame[2], height: frame[3])
    }

    /// The user clicked the view.
    func clicked() {}

    /// The element left the tree: the view lets go of everything that would call back into it.
    func detach() {}

    private struct Weak {
        weak var view: WinUIView?

        init(_ view: WinUIView) { self.view = view }
    }
}
