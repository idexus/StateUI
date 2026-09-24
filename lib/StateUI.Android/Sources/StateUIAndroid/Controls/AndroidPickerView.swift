// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Picker: the host's `StateUIPicker`, Android's dropdown spinner, whose closed field shows the title
/// while nothing is chosen.
/// Design: docs/design/platforms/android/controls.md#a-picker
@MainActor
final class AndroidPickerView: AndroidView {
    /// What the picker does when the user chooses an option, by its index.
    var onChosen: ((Int) -> Void)?

    /// What the picker does when the user opens its list.
    var onOpened: (() -> Void)?

    /// What the picker does when its list closes.
    var onClosed: (() -> Void)?

    /// The arrow's colour the picker was made with.
    private var madeTint: JavaObject??

    init() {
        super.init { number in
            Java.new(JavaAPI.picker, JavaAPI.newPicker, .object(AndroidRenderer.context), .long(number))
        }
    }

    /// The options, the title shown while nothing is chosen, and the chosen index; -1 for none.
    func setChoices(_ options: [String], title: String, chosen: Int) {
        Java.frame {
            let array = Java.array(of: JavaAPI.string, options.map(Java.string))
            Java.call(
                reference, JavaAPI.setChoices, .object(array), .object(Java.string(title)), .int(Int32(chosen)))
        }
    }

    /// The words' size in points, colour and face, and where they stand across the field; nil for the theme's.
    func setLook(size: Double?, color: HostValue?, family: String?, attributes: FontAttributes?, alignment: TextAlignment) {
        Java.frame {
            let style = (attributes?.rawValue ?? 0) & 3
            let face = Java.callStaticObject(
                JavaAPI.typeface, JavaAPI.createTypeface, .object(family.flatMap(Java.string)), .int(style))
            let across: Int32 = switch alignment {
            case .start: 0x0080_0003
            case .center: 0x01
            case .end: 0x0080_0005
            }
            Java.call(
                reference, JavaAPI.setPickerLook, .float(Float(size.map { $0 * density } ?? 0)),
                .int(color.flatMap(Self.argb) ?? 0), .object(face), .int(across))
        }
    }

    /// Opens the list; the user did not, so no `opened` is reported.
    func openList() {
        Java.call(reference, JavaAPI.openList)
    }

    /// The arrow's colour; nil puts back the platform's.
    func setTint(_ color: HostValue?) {
        if madeTint == nil {
            madeTint = .some(Java.callObject(reference, JavaAPI.getBackgroundTintList).map(JavaObject.init))
        }
        guard let argb = color.flatMap(Self.argb) else {
            return Java.call(reference, JavaAPI.setBackgroundTintList, .object(madeTint??.reference))
        }
        let tint = Java.callStaticObject(JavaAPI.colorStateList, JavaAPI.colorStateListOf, .int(argb))
        Java.call(reference, JavaAPI.setBackgroundTintList, .object(tint))
        Java.release(local: tint)
    }

    override func detach() {
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
