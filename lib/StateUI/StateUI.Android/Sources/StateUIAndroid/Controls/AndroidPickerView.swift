// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    /// Who opened or closed the list - only the user's are heard - and whether it shows.
    private var opening = PickerOpening()
    private var listShows = false

    init() {
        super.init { number in
            Java.new(JavaAPI.picker, JavaAPI.newPicker, .object(AndroidRenderer.context), .long(number))
        }
    }

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    /// The options, the chosen index - written only where `writeChosen` or the options changed, so the user's
    /// choice is never argued with - and the title shown while nothing is chosen.
    func setChoices(_ options: [String], chosen: Int, writeChosen: Bool, title: String) {
        let write = written.write(options, chosen: chosen, choiceChanged: writeChosen)
        Java.frame {
            let array = write.choices.flatMap { Java.array(of: JavaAPI.string, $0.map(Java.string)) }
            Java.call(
                reference, JavaAPI.setChoices, .object(array), .object(Java.string(title)),
                .int(Int32(write.chosen ?? -1)), .bool(write.writesChoice))
        }
    }

    /// How the words look (`TextMembers.look`) - each the theme's where it says nothing - and where they stand across
    /// the field.
    func setLook(_ look: TextLook, alignment: TextAlignment) {
        let (size, color) = (look.size, look.color)
        Java.frame {
            let style = look.attributes.rawValue & 3
            let face = Java.callStaticObject(
                JavaAPI.typeface, JavaAPI.createTypeface, .object(look.family.flatMap(Java.string)), .int(style))
            Java.call(
                reference, JavaAPI.setPickerLook, .float(Float(size ?? 0)),
                .int(color.flatMap(Self.argb) ?? 0), .object(face), .int(ViewConstants.gravity(across: alignment)))
        }
    }

    /// Opens the list for the program, heard by nobody. A spinner's list closes only by the user's hand.
    func openList() {
        guard opening.programAsks(open: true, shown: listShows) else { return }
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

    override func opened() {
        listShows = true
        if opening.heard(open: true) { onOpened?() }
    }

    override func closed() {
        listShows = false
        if opening.heard(open: false) { onClosed?() }
    }

    override func detach() {
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
