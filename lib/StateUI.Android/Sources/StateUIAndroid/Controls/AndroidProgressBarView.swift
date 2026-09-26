// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A ProgressBar: Android's horizontal `ProgressBar`, the share of the work done across 10 000 steps.
@MainActor
final class AndroidProgressBarView: AndroidView {
    /// The steps the bar is drawn in.
    static let steps: Int32 = 10_000

    /// `android.R.attr.progressBarStyleHorizontal`.
    private static let horizontalStyle: Int32 = 0x0101_0078

    private var madeTint: JavaObject??

    init() {
        super.init { _ in
            Java.new(
                JavaAPI.progressBar, JavaAPI.newStyledProgressBar,
                .object(AndroidRenderer.context), .object(nil), .int(AndroidProgressBarView.horizontalStyle))
        }
        Java.call(reference, JavaAPI.setIndeterminate, .bool(false))
        Java.call(reference, JavaAPI.setMax, .int(Self.steps))
    }

    /// How much of the work is done, from 0 to 1.
    func setProgress(_ progress: Double) {
        let share = progress.isFinite ? min(max(progress, 0), 1) : 0
        Java.call(reference, JavaAPI.setProgress, .int(Int32((share * Double(Self.steps)).rounded())))
    }

    /// How much of the work the bar shows done.
    var progress: Double {
        Double(Java.callInt(reference, JavaAPI.getProgress)) / Double(Self.steps)
    }

    /// The colour of the work done; nil puts back the platform's.
    func setTint(_ color: HostValue?) {
        if madeTint == nil {
            madeTint = .some(Java.callObject(reference, JavaAPI.getProgressTintList).map(JavaObject.init))
        }
        guard let argb = color.flatMap(Self.argb) else {
            return Java.call(reference, JavaAPI.setProgressTintList, .object(madeTint??.reference))
        }
        let tint = Java.callStaticObject(JavaAPI.colorStateList, JavaAPI.colorStateListOf, .int(argb))
        Java.call(reference, JavaAPI.setProgressTintList, .object(tint))
        Java.release(local: tint)
    }
}
