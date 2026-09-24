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

    /// The layout that places this view, which a place written between passes asks to arrange again.
    weak var placingLayout: WinUILayoutView?

    /// How deep the layout passes under way stand: a place written inside one lands at once.
    static var arranging = 0

    /// Where the view was last placed, in DIPs of its parent; nil before its first place.
    private(set) var placed: Rect?

    /// How opaque the view's own property draws it, and whether it shows, as the host last wrote them.
    private(set) var opacity = 1.0
    private(set) var isShown = true

    /// How the view's own properties move, turn and scale it.
    private var transform = HostDrawingTransform.identity

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
        isShown = shown
        stateui_winui_set_shown(handle, shown)
    }

    /// How opaque the view is drawn, written only where it differs from what was.
    func setOpacity(_ opacity: Double) {
        guard opacity != self.opacity else { return }
        self.opacity = opacity
        stateui_winui_set_opacity(handle, opacity)
    }

    /// Moves, turns and scales the view where its layout put it, in DIPs and degrees.
    func setTransform(_ transform: HostDrawingTransform) {
        self.transform = transform
        writeTransform()
    }

    /// Writes the transform, about its pivot in the size the view was last placed at.
    private func writeTransform() {
        let size = placed ?? Rect(x: 0, y: 0, width: 0, height: 0)
        stateui_winui_set_transform(
            handle, transform.translationX, transform.translationY, transform.rotation,
            transform.scaleX, transform.scaleY, transform.pivotX * size.width, transform.pivotY * size.height)
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

    /// Places the element at `place`, in DIPs of its parent: at once inside a pass, and between passes by asking
    /// the layout for one.
    /// Design: docs/design/platforms/winui/layout.md#a-place-between-passes
    func layout(_ place: Rect) {
        let resized = placed.map { $0.width != place.width || $0.height != place.height } ?? true
        placed = place
        if Self.arranging > 0 {
            stateui_winui_arrange(handle, place.x, place.y, place.width, place.height)
        } else {
            placingLayout?.invalidateArrange()
        }
        if resized, transform != .identity { writeTransform() }
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

extension WinUIView: PlacedView {
    /// Where the view stands in its parent, in DIPs - where the host last placed it, or where WinUI has it.
    var placedFrame: Rect {
        get { placed ?? laidOutFrame }
        set { layout(newValue) }
    }
}
