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

    func setOpacity(_ opacity: Double) {
        ownOpacity = opacity
        Java.call(reference, JavaAPI.setAlpha, .float(Float(ownOpacity * placedOpacity)))
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

        Java.call(reference, JavaAPI.setTranslationX, .float(Float(drawn.translationX * density)))
        Java.call(reference, JavaAPI.setTranslationY, .float(Float(drawn.translationY * density)))
        Java.call(reference, JavaAPI.setRotation, .float(Float(drawn.rotation)))
        Java.call(reference, JavaAPI.setRotationX, .float(Float(drawn.rotationX)))
        Java.call(reference, JavaAPI.setRotationY, .float(Float(drawn.rotationY)))
        Java.call(reference, JavaAPI.setScaleX, .float(Float(drawn.scaleX)))
        Java.call(reference, JavaAPI.setScaleY, .float(Float(drawn.scaleY)))
        pivot = placed == nil ? (drawn.pivotX, drawn.pivotY) : (0.5, 0.5)
        applyPivot()
    }

    /// Puts the pivot at its fractions of the view's size; at the centre Android keeps it there itself.
    private func applyPivot() {
        guard pivot != (0.5, 0.5) else {
            Java.call(reference, JavaAPI.resetPivot)
            return
        }

        let width = Double(Java.callInt(reference, JavaAPI.getWidth))
        let height = Double(Java.callInt(reference, JavaAPI.getHeight))
        Java.call(reference, JavaAPI.setPivotX, .float(Float(pivot.x * width)))
        Java.call(reference, JavaAPI.setPivotY, .float(Float(pivot.y * height)))
    }

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
        if pivot != (0.5, 0.5) { applyPivot() }
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
    /// Where the view stands in its parent, in points; set, it is measured and placed there.
    var placedFrame: Rect {
        get {
            Rect(
                x: Double(Java.callInt(reference, JavaAPI.getLeft)) / density,
                y: Double(Java.callInt(reference, JavaAPI.getTop)) / density,
                width: Double(Java.callInt(reference, JavaAPI.getWidth)) / density,
                height: Double(Java.callInt(reference, JavaAPI.getHeight)) / density)
        }
        set { layout(newValue) }
    }
}
