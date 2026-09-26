// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Slider: an `android.widget.SeekBar` over the range, in `steps` whole steps.
/// Design: docs/design/platforms/android/controls.md#a-slider-in-steps
@MainActor
final class AndroidSliderView: AndroidView {
    /// The SeekBar's whole steps across the range.
    static let steps: Int32 = 10_000

    /// What the slider does when the user moves its thumb, handed the value it stands at.
    var onValueChanged: ((Double) -> Void)?

    /// What the slider does when the user takes its thumb, and lets it go.
    var onDragStarted: (() -> Void)?
    var onDragCompleted: (() -> Void)?

    /// The range's ends, the lower first.
    private(set) var minimum = 0.0
    private(set) var maximum = 1.0

    private var madeTints: (progress: JavaObject?, thumb: JavaObject?)?

    init() {
        super.init { _ in Java.new(JavaAPI.seekBar, JavaAPI.newSeekBar, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setMax, .int(Self.steps))
        listen(JavaAPI.setOnSeekBarChangeListener)
    }

    /// The value the thumb stands at.
    var value: Double { value(at: Java.callInt(reference, JavaAPI.getProgress)) }

    /// The value of the step `progress`.
    func value(at progress: Int32) -> Double {
        minimum + Double(progress) / Double(Self.steps) * (maximum - minimum)
    }

    /// The range, then the value: `value` where `writeValue`, else the one the thumb stands at, kept inside the range.
    func apply(value: Double?, writeValue: Bool, minimum: Double, maximum: Double) {
        let kept = writeValue ? value ?? self.value : self.value
        self.minimum = Swift.min(minimum, maximum)
        self.maximum = Swift.max(minimum, maximum)

        let span = self.maximum - self.minimum
        let clamped = Swift.min(Swift.max(kept, self.minimum), self.maximum)
        let progress = span > 0 ? Int32(((clamped - self.minimum) / span * Double(Self.steps)).rounded()) : 0
        if progress != Java.callInt(reference, JavaAPI.getProgress) {
            Java.call(reference, JavaAPI.setProgress, .int(progress))
        }
    }

    /// The colour of the track's filled part and the thumb; nil puts back the platform's.
    func setTint(_ color: HostValue?) {
        let made = madeTints ?? (
            Java.callObject(reference, JavaAPI.getProgressTintList).map(JavaObject.init),
            Java.callObject(reference, JavaAPI.getThumbTintList).map(JavaObject.init))
        madeTints = made

        guard let argb = color.flatMap(Self.argb) else {
            Java.call(reference, JavaAPI.setProgressTintList, .object(made.progress?.reference))
            Java.call(reference, JavaAPI.setThumbTintList, .object(made.thumb?.reference))
            return
        }

        let tint = Java.callStaticObject(JavaAPI.colorStateList, JavaAPI.colorStateListOf, .int(argb))
        Java.call(reference, JavaAPI.setProgressTintList, .object(tint))
        Java.call(reference, JavaAPI.setThumbTintList, .object(tint))
        Java.release(local: tint)
    }

    override func detach() {
        super.detach()
        onValueChanged = nil
        onDragStarted = nil
        onDragCompleted = nil
    }
}
