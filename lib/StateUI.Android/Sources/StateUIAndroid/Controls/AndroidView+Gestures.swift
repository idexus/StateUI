// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The gestures a view's element listens for, told apart by the view's one listener, `StateUIGestures`, and
/// reported back through one native.
/// Design: docs/design/platforms/android/controls.md#gestures
extension AndroidView {
    /// Which gestures the element listens for: how many taps make one - below two a click is the tap - how
    /// many fingers a pan takes, a swipe's directions and the distance past which it is one, a pinch, and the
    /// pointer; none of any is zero or false.
    struct Gestures: Equatable {
        var taps = 0
        var panFingers = 0
        var swipeDirections: Int32 = 0
        var swipeThreshold = 40.0
        var pinch = false
        var pointer = false

        static let none = Gestures()
    }

    /// One gesture, in points.
    enum Gesture: Equatable {
        case tapped
        /// A pan's phase and how far it has come.
        case panned(phase: Int32, x: Double, y: Double)
        case swiped(direction: Int32)
        /// A pinch's phase, its scale since the last report, and where it is centred, as fractions of the view.
        case pinched(phase: Int32, scale: Double, originX: Double, originY: Double)
        /// The pointer entering, leaving, moving, pressing or releasing, and where, where it says.
        case pointer(Event, x: Double?, y: Double?)

        /// The gesture `StateUIGestures` reports by its kind; nil for a kind it does not name.
        init?(kind: Int32, phase: Int32, x: Double, y: Double, z: Double) {
            switch kind {
            case 0: self = .tapped
            case 1: self = .panned(phase: phase, x: x, y: y)
            case 2: self = .swiped(direction: phase)
            case 3: self = .pinched(phase: phase, scale: x, originX: y, originY: z)
            case 4: self = .pointer(.pointerEntered, x: nil, y: nil)
            case 5: self = .pointer(.pointerExited, x: nil, y: nil)
            case 6: self = .pointer(.pointerMoved, x: x, y: y)
            case 7: self = .pointer(.pointerPressed, x: x, y: y)
            case 8: self = .pointer(.pointerReleased, x: x, y: y)
            default: return nil
            }
        }
    }

    /// Tells the view's listener which gestures to tell apart, taking the view's touches and its hovering
    /// pointer the first time any is wanted.
    func setGestures(_ wanted: Gestures) {
        guard wanted != gestures else { return }
        if gestures == .none { listen(JavaAPI.setOnTouchListener, JavaAPI.setOnHoverListener) }
        gestures = wanted
        Java.call(
            listener.reference, JavaAPI.setGestures, .object(reference), .float(Float(density)),
            .int(Int32(wanted.taps)), .int(Int32(wanted.panFingers)), .int(wanted.swipeDirections),
            .float(Float(wanted.swipeThreshold)), .bool(wanted.pinch), .bool(wanted.pointer))
    }
}
