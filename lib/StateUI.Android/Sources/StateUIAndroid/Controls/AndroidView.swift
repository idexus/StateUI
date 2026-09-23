// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// An `android.view.View` Swift holds, and the number Java calls back with.
/// Design: docs/design/platforms/android/jni.md#a-view-and-its-number
@MainActor
class AndroidView {
    /// The view, held globally until this is released.
    let object: JavaObject

    /// The number the view's Java listeners and layout call back with.
    let number: Int64

    /// Pixels per point, the display's density.
    var density: Double { AndroidRenderer.density }

    private static var nextNumber: Int64 = 0
    private static var live: [Int64: Weak] = [:]

    /// Takes the next number and holds the view `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> JavaObject) {
        Self.nextNumber += 1
        number = Self.nextNumber
        object = make(number)
        Self.live[number] = Weak(self)
    }

    isolated deinit {
        Self.live[number] = nil
    }

    /// The live view a Java callback names; nil once it has left.
    static func find(_ number: Int64) -> AndroidView? {
        live[number]?.view
    }

    /// How many views Swift holds - what a test counts to see every one let go.
    static var liveCount: Int { live.count }

    var reference: jobject { object.reference }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        Java.call(reference, JavaAPI.setVisibility, .int(shown ? ViewConstants.visible : ViewConstants.gone))
    }

    func setOpacity(_ opacity: Double) {
        Java.call(reference, JavaAPI.setAlpha, .float(Float(opacity)))
    }

    func setEnabled(_ enabled: Bool) {
        Java.call(reference, JavaAPI.setEnabled, .bool(enabled))
    }

    /// The view's background: a colour, or none; any other brush draws none yet.
    func setBackground(_ value: HostValue?) {
        Java.call(reference, JavaAPI.setBackgroundColor, .int(value.flatMap(Self.argb) ?? 0))
    }

    /// The element left the tree: the view lets go of everything that would call back into it.
    func detach() {}

    /// Asks Android to measure and place this view and its ancestors again.
    func requestLayout() {
        Java.call(reference, JavaAPI.requestLayout)
    }

    /// Measures the view for the specs given; its size in pixels.
    func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        Java.call(reference, JavaAPI.measure, .int(width), .int(height))
        return (
            Java.callInt(reference, JavaAPI.getMeasuredWidth),
            Java.callInt(reference, JavaAPI.getMeasuredHeight))
    }

    /// Places the view at `place`, in points of its parent.
    func layout(_ place: Rect) {
        let left = pixels(place.x)
        let top = pixels(place.y)
        let right = pixels(place.x + place.width)
        let bottom = pixels(place.y + place.height)
        _ = measure(
            width: ViewConstants.spec(ViewConstants.exactly, right - left),
            height: ViewConstants.spec(ViewConstants.exactly, bottom - top))
        Java.call(reference, JavaAPI.layout, .int(left), .int(top), .int(right), .int(bottom))
    }

    /// `points` in whole pixels.
    func pixels(_ points: Double) -> Int32 {
        Int32((points * density).rounded())
    }

    /// A colour as Android's packed ARGB; nil for a value that is no colour.
    static func argb(_ value: HostValue) -> Int32? {
        guard let channels = value.color else { return nil }

        let value = UInt32(channels.alpha) << 24 | UInt32(channels.red) << 16
            | UInt32(channels.green) << 8 | UInt32(channels.blue)
        return Int32(bitPattern: value)
    }

    private struct Weak {
        weak var view: AndroidView?

        init(_ view: AndroidView) { self.view = view }
    }
}
