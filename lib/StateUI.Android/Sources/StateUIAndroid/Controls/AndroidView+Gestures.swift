// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// What of the user's input a view listens for, told by the view's one listener, `StateUIGestures`, and heard in the
/// contract's terms (`HeardInput`): a press dragged by the host layer's rule, the rest as Android tells it.
/// Design: docs/design/platforms/android/controls.md#gestures
extension AndroidView {
    /// What a view's listener is told to listen for.
    struct Listening: Equatable {
        var hearing: Hearing
        var countsTaps: Bool

        static let nothing = Listening(hearing: [], countsTaps: false)
    }

    /// Listens for what `hearing` names, `heard` hearing it - taps counted in runs by the listener where
    /// `countsTaps`, where one tap is no click - taking the view's touches and its hovering pointer the first time
    /// anything is.
    func hear(_ hearing: Hearing, countsTaps: Bool, _ heard: @escaping (HeardInput) -> Void) {
        onHeard = hearing.isEmpty ? nil : heard
        let told = Listening(hearing: hearing, countsTaps: countsTaps)
        guard told != listening else { return }

        if listening == .nothing { watchTouches() }
        listening = told
        if hearing.contains(.drags) { press = DragRecognition(distance: .radius(Self.touchSlop(density: density))) }
        Java.call(
            listener.reference, JavaAPI.setGestures, .object(reference), .float(Float(density)),
            .bool(countsTaps && hearing.contains(.taps)), .bool(hearing.contains(.drags)),
            .bool(hearing.contains(.pinches)), .bool(hearing.contains(.pointer)))
    }

    /// What the listener says the view heard, by the kind `StateUIGestures` numbers: a tap and its place in its run,
    /// a pinch's step and where it is centred in points, the pointer.
    func heard(kind: Int32, phase: Int32, x: Double, y: Double, z: Double) {
        let point = Point(x: x, y: y)
        let input: HeardInput? = switch kind {
        case 0: .tap(run: Int(phase))
        case 3: GesturePhase(rawValue: phase).map { phase in
            let size = standingFrame
            let at = PinchStep.share(of: Point(x: y, y: z), width: size.width, height: size.height)
            return .pinch(phase, scale: x, at: at)
        }
        case 4: .pointer(.pointerEntered, point)
        case 5: .pointer(.pointerExited, point)
        case 6: .pointer(.pointerMoved, point)
        case 7: .pointer(.pointerPressed, point)
        case 8: .pointer(.pointerReleased, point)
        default: nil
        }
        if let input { onHeard?(input) }
    }

    /// A press the listener tells - down, moved, let go or taken away, at `point` of the screen: a drag by the host
    /// layer's rule. Whether it is one now, which takes the rest of the touch.
    /// Design: docs/design/platforms/android/controls.md#gestures
    func heardPress(phase: Int32, at point: Point) -> Bool {
        switch phase {
        case 0: press.pressed(at: point)
        case 1: press.moved(to: point).forEach { onHeard?($0) }
        default: if let end = press.ended(letGo: phase == 2) { onHeard?(end) }
        }
        return press.isDragging
    }

    /// How far a finger moves before it is a drag, as Android measures it, in points at `density`.
    private static func touchSlop(density: Double) -> Double {
        Java.frame {
            guard let configuration = Java.callStaticObject(
                JavaAPI.viewConfiguration, JavaAPI.viewConfigurationOf, .object(AndroidRenderer.context))
            else { return 8 }
            return Double(Java.callInt(configuration, JavaAPI.scaledTouchSlop)) / density
        }
    }
}
