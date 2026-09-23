// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import Android
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

    /// The background the view was made with, often none, read before the first change.
    private var madeBackground: JavaObject??

    /// How the view's own properties move, turn and scale it.
    private var own = HostDrawingTransform.identity

    /// How a placing layout draws the view over the place it gave; nil for none.
    private var placed: HostDrawingTransform?

    /// How opaque the view's own property and a placing layout draw it.
    private var ownOpacity = 1.0
    private var placedOpacity = 1.0

    /// The point the view turns and scales about, as fractions of its size.
    private var pivot = (x: 0.5, y: 0.5)

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

    /// Hands each of `setters` one listener forwarding what the user does to this view, by its number.
    /// Design: docs/design/platforms/android/jni.md#global-references
    func listen(_ setters: jmethodID...) {
        listen(on: reference, setters)
    }

    /// Hands each of `setters` of `object` - a view this one holds - one listener forwarding to this view.
    func listen(on object: jobject, _ setters: jmethodID...) {
        listen(on: object, setters)
    }

    private func listen(on object: jobject, _ setters: [jmethodID]) {
        let listener = Java.new(JavaAPI.listener, JavaAPI.newListener, .long(number))
        withExtendedLifetime(listener) {
            for setter in setters { Java.call(object, setter, .object(listener.reference)) }
        }
    }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        Java.call(reference, JavaAPI.setVisibility, .int(shown ? ViewConstants.visible : ViewConstants.gone))
    }

    /// Whether the view is shown rather than gone.
    var isShown: Bool {
        Java.callInt(reference, JavaAPI.getVisibility) == ViewConstants.visible
    }

    /// How opaque the view's own property draws it, with a placing layout's opacity over it; written only where
    /// it differs from what was.
    func setOpacity(_ opacity: Double) {
        ownOpacity = opacity
        let alpha = Float(ownOpacity * placedOpacity)
        guard alpha != written.alpha else { return }

        written.alpha = alpha
        Java.call(reference, JavaAPI.setAlpha, .float(alpha))
    }

    /// How opaque the view's own property draws it.
    var opacity: Double { ownOpacity }

    /// Moves, turns and scales the view where its layout put it, in points and degrees.
    /// Design: docs/design/platforms/android/motion.md#moved-turned-and-scaled
    func setTransform(_ transform: HostDrawingTransform) {
        own = transform
        applyTransform()
    }

    /// How a placing layout draws the view over the place it gave, and how opaque; nil and 1 for as the view says.
    /// Design: docs/design/platforms/android/drawing.md#a-placed-child
    func setPlacedDrawing(_ transform: HostDrawingTransform?, opacity: Double) {
        guard transform != placed || opacity != placedOpacity else { return }

        placed = transform
        placedOpacity = opacity
        applyTransform()
        setOpacity(ownOpacity)
    }

    /// Writes the view's own transform, with a placing layout's over it.
    private func applyTransform() {
        var drawn = own
        if let placed {
            let angle = placed.rotation * .pi / 180
            let x = own.translationX * placed.scaleX
            let y = own.translationY * placed.scaleY
            drawn.translationX = placed.translationX + x * cos(angle) - y * sin(angle)
            drawn.translationY = placed.translationY + x * sin(angle) + y * cos(angle)
            drawn.rotation += placed.rotation
            drawn.scaleX *= placed.scaleX
            drawn.scaleY *= placed.scaleY
        }

        pivot = placed == nil ? (drawn.pivotX, drawn.pivotY) : (0.5, 0.5)

        // A pivot off the centre is in pixels of the size the view was last placed at; at the centre, Android's own.
        let size = laidOut.map { (Double($0.right - $0.left), Double($0.bottom - $0.top)) } ?? (0, 0)
        let centred = pivot == (0.5, 0.5)
        let transform = Written.Transform(
            translationX: Float(drawn.translationX * density), translationY: Float(drawn.translationY * density),
            rotation: Float(drawn.rotation), rotationX: Float(drawn.rotationX), rotationY: Float(drawn.rotationY),
            scaleX: Float(drawn.scaleX), scaleY: Float(drawn.scaleY),
            pivotX: centred ? nil : Float(pivot.x * size.0), pivotY: centred ? nil : Float(pivot.y * size.1))
        guard transform != written.transform else { return }

        written.transform = transform
        Java.callStatic(
            JavaAPI.views, JavaAPI.transformView, .object(reference),
            .float(transform.translationX), .float(transform.translationY), .float(transform.rotation),
            .float(transform.rotationX), .float(transform.rotationY), .float(transform.scaleX), .float(transform.scaleY),
            .float(transform.pivotX ?? .nan), .float(transform.pivotY ?? .nan))
    }

    /// What the host last wrote to the view, so a frame writes only what differs and reads nothing back.
    /// Design: docs/design/platforms/android/jni.md#what-a-frame-writes
    private struct Written {
        struct Transform: Equatable {
            var translationX: Float = 0, translationY: Float = 0
            var rotation: Float = 0, rotationX: Float = 0, rotationY: Float = 0
            var scaleX: Float = 1, scaleY: Float = 1
            var pivotX: Float?, pivotY: Float?
        }

        var alpha: Float = 1
        var transform = Transform()
    }

    private var written = Written()

    /// Where the host last laid the view out, in pixels of its parent; nil until it has, or once another
    /// container places it.
    private var laidOut: (left: Int32, top: Int32, right: Int32, bottom: Int32)?

    func setEnabled(_ enabled: Bool) {
        Java.call(reference, JavaAPI.setEnabled, .bool(enabled))
    }

    /// The view's background: a colour, or a brush drawn over its bounds; nil puts back the platform's.
    func setBackground(_ value: HostValue?) {
        if madeBackground == nil {
            madeBackground = .some(Java.callObject(reference, JavaAPI.getBackground).map(JavaObject.init))
        }

        guard let value else {
            return Java.call(reference, JavaAPI.setBackground, .object(madeBackground??.reference))
        }
        if let argb = Self.argb(value) {
            return Java.call(reference, JavaAPI.setBackgroundColor, .int(argb))
        }

        let brush = AndroidShapeDrawable()
        brush.setFill(value)
        withExtendedLifetime(brush) { Java.call(reference, JavaAPI.setBackground, .object(brush.reference)) }
    }

    /// What the view does when the user taps it; nil where it takes no tap.
    private(set) var onTapped: (() -> Void)?

    /// Makes the view answer a tap with `action`, or answer none for nil.
    func setTapped(_ action: (() -> Void)?) {
        let listening = onTapped != nil
        onTapped = action
        guard (action != nil) != listening, !(self is AndroidButtonView) else { return }

        if action != nil {
            listen(JavaAPI.setOnClickListener)
        } else {
            Java.call(reference, JavaAPI.setOnClickListener, .object(nil))
            Java.call(reference, JavaAPI.setClickable, .bool(false))
        }
    }

    /// The user clicked or tapped the view.
    func clicked() {
        onTapped?()
    }

    /// The element left the tree: the view lets go of everything that would call back into it.
    func detach() {
        onTapped = nil
    }

    /// Asks Android to measure and place this view and its ancestors again.
    func requestLayout() {
        Java.call(reference, JavaAPI.requestLayout)
    }

    /// Measures the view for the specs given; its size in pixels.
    func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        let size = Java.callStaticLong(JavaAPI.views, JavaAPI.measureView, .object(reference), .int(width), .int(height))
        return (Int32(truncatingIfNeeded: size >> 32), Int32(truncatingIfNeeded: size))
    }

    /// Places the view at `place`, in points of its parent: measured there exactly and laid out, in one call.
    func layout(_ place: Rect) {
        let frame = (
            left: pixels(place.x), top: pixels(place.y),
            right: pixels(place.x + place.width), bottom: pixels(place.y + place.height))
        let resized = laidOut.map { $0.right - $0.left != frame.right - frame.left || $0.bottom - $0.top != frame.bottom - frame.top }
            ?? true
        laidOut = frame
        Java.callStatic(
            JavaAPI.views, JavaAPI.placeView, .object(reference),
            .int(frame.left), .int(frame.top), .int(frame.right), .int(frame.bottom))
        if resized, pivot != (0.5, 0.5) { applyTransform() }
    }

    /// Hands the view to a container of Android's own, which places it: its place is read from Android from now on.
    func forgetPlace() {
        laidOut = nil
    }

    /// Where the view stands, in points: its frame in its parent, its place in the window, and that place
    /// from `safeArea`, the safe area's top left in the window.
    func frameReport(safeArea: Point) -> [Double] {
        let place = placedFrame
        let window = Java.ints([0, 0])
        Java.call(reference, JavaAPI.getLocationInWindow, .object(window))
        var pixels: [Int32] = [0, 0]
        pixels.withUnsafeMutableBufferPointer { Java.jni.GetIntArrayRegion(Java.env, window, 0, 2, $0.baseAddress) }
        Java.release(local: window)

        let x = Double(pixels[0]) / density
        let y = Double(pixels[1]) / density
        return [place.x, place.y, place.width, place.height, x, y, x - safeArea.x, y - safeArea.y]
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

extension AndroidView: PlacedView {
    /// Where the view stands in its parent, in points - where the host last laid it out, or else where Android
    /// has it; set, it is measured and placed there.
    var placedFrame: Rect {
        get {
            let frame = laidOut ?? (
                left: Java.callInt(reference, JavaAPI.getLeft), top: Java.callInt(reference, JavaAPI.getTop),
                right: Java.callInt(reference, JavaAPI.getRight), bottom: Java.callInt(reference, JavaAPI.getBottom))
            return Rect(
                x: Double(frame.left) / density, y: Double(frame.top) / density,
                width: Double(frame.right - frame.left) / density, height: Double(frame.bottom - frame.top) / density)
        }
        set { layout(newValue) }
    }
}
