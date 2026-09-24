// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A CheckBox: an `android.widget.CheckBox` with no words of its own - the words beside it are a Label.
@MainActor
final class AndroidCheckBoxView: AndroidToggleView {
    private var madeTint: JavaObject??

    init() {
        super.init { _ in Java.new(JavaAPI.checkBox, JavaAPI.newCheckBox, .object(AndroidRenderer.context)) }
    }

    /// The box's colour; nil puts back the platform's.
    func setTint(_ color: HostValue?) {
        if madeTint == nil {
            madeTint = .some(Java.callObject(reference, JavaAPI.getButtonTintList).map(JavaObject.init))
        }
        guard let argb = color.flatMap(Self.argb) else {
            return Java.call(reference, JavaAPI.setButtonTintList, .object(madeTint??.reference))
        }
        let tint = Java.callStaticObject(JavaAPI.colorStateList, JavaAPI.colorStateListOf, .int(argb))
        Java.call(reference, JavaAPI.setButtonTintList, .object(tint))
        Java.release(local: tint)
    }
}
