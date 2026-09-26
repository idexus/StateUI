// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// An ActivityIndicator: Android's turning `ProgressBar`, drawn while it runs and keeping its room while it
/// does not.
/// Design: docs/design/platforms/android/controls.md#work-under-way
@MainActor
final class AndroidActivityIndicatorView: AndroidView {
    private(set) var isRunning = false
    private var shown = true
    private var madeTint: JavaObject??

    init() {
        super.init { _ in Java.new(JavaAPI.progressBar, JavaAPI.newProgressBar, .object(AndroidRenderer.context)) }
        showWhetherRunning()
    }

    /// Whether the work is under way: the indicator turns, or stands invisible in its room.
    func setRunning(_ running: Bool) {
        isRunning = running
        showWhetherRunning()
    }

    override func setShown(_ shown: Bool) {
        self.shown = shown
        showWhetherRunning()
    }

    override var isShown: Bool { shown }

    private func showWhetherRunning() {
        let visibility = !shown ? ViewConstants.gone : isRunning ? ViewConstants.visible : ViewConstants.invisible
        Java.call(reference, JavaAPI.setVisibility, .int(visibility))
    }

    /// The indicator's colour; nil puts back the platform's.
    func setTint(_ color: HostValue?) {
        if madeTint == nil {
            madeTint = .some(Java.callObject(reference, JavaAPI.getIndeterminateTintList).map(JavaObject.init))
        }
        guard let argb = color.flatMap(Self.argb) else {
            return Java.call(reference, JavaAPI.setIndeterminateTintList, .object(madeTint??.reference))
        }
        let tint = Java.callStaticObject(JavaAPI.colorStateList, JavaAPI.colorStateListOf, .int(argb))
        Java.call(reference, JavaAPI.setIndeterminateTintList, .object(tint))
        Java.release(local: tint)
    }
}
