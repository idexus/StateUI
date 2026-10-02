// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads and does of a date field: the day or time in the words it shows, whether its dialog
/// shows, and the user's hand on that dialog - a tap opening it, Back closing it, a day or time set and its OK.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    static func dateFieldHolds(_ property: Prop, _ field: AndroidDateFieldView) throws -> HostValue?? {
        switch property {
        case .date:
            guard let day = shown(field, Self.fieldDay) else { throw DriverCannot("read a day in a form of its own") }
            return .some(CalendarDate(year: Int(day[0]), month: Int(day[1]), day: Int(day[2])).propValue)
        case .time:
            guard let time = shown(field, Self.fieldTime) else { throw DriverCannot("read a time in a form of its own") }
            return .some(ClockTime(hour: Int(time[0]), minute: Int(time[1])).propValue)
        case .minimumDate: return .some(bound(Self.earliest, of: field))
        case .maximumDate: return .some(bound(Self.latest, of: field))
        case .format:
            let format = Java.frame { objectField(field, Self.format).map { Java.text($0) } ?? "" }
            return .some(format.isEmpty ? nil : format.propValue)
        case .isOpen:
            let showing = Java.frame { objectField(field, Self.dialog).map { Java.callBool($0, Self.isShowing) } }
            return .some((showing ?? false).propValue)
        default: return nil
        }
    }

    func performOnDateField(_ act: UserAct, _ field: AndroidDateFieldView) throws -> Bool {
        switch act {
        case .open: _ = Java.callBool(field.reference, JavaAPI.performClick)
        case .close:
            // Back cancels a dialog.
            Java.frame { Self.objectField(field, Self.dialog).map { Java.call($0, Self.cancel) } }
        case .pickDate(let day):
            try onOpenDialog(of: field) { dialog in
                Java.callStatic(
                    Self.testDateField, Self.pickDay, .object(dialog), .int(Int32(day.year)), .int(Int32(day.month)),
                    .int(Int32(day.day)))
            }
        case .pickTime(let time):
            try onOpenDialog(of: field) { dialog in
                Java.callStatic(
                    Self.testDateField, Self.pickTime, .object(dialog), .int(Int32(time.hour)), .int(Int32(time.minute)))
            }
        default: return false
        }
        return true
    }

    /// Opens the field's dialog by its tap where none shows, and hands it to `act`.
    private func onOpenDialog(of field: AndroidDateFieldView, _ act: (jobject) -> Void) throws {
        if Java.frame({ Self.objectField(field, Self.dialog) == nil }) {
            _ = Java.callBool(field.reference, JavaAPI.performClick)
        }
        let opened = Java.frame {
            guard let dialog = Self.objectField(field, Self.dialog) else { return false }
            act(dialog)
            return true
        }
        guard opened else { throw DriverCannot("open a date field's dialog") }
    }

    /// The object `field` of the field's relay holds; a local reference, let go with the frame around it.
    private static func objectField(_ field: AndroidDateFieldView, _ which: jfieldID) -> jobject? {
        Java.jni.GetObjectField(Java.env, field.reference, which)
    }

    /// The numbers the field shows, as `reader` reads its words.
    private static func shown(_ field: AndroidDateFieldView, _ reader: jmethodID) -> [Int32]? {
        Java.frame { Java.callStaticObject(Self.testDateField, reader, .object(field.reference)).map(Java.intsOf) }
    }

    /// A bound the relay hands the calendar as it opens.
    private static func bound(_ which: jfieldID, of field: AndroidDateFieldView) -> HostValue? {
        let day = Java.frame { objectField(field, which).map(Java.intsOf) } ?? []
        return day.count == 3 ? CalendarDate(year: Int(day[0]), month: Int(day[1]), day: Int(day[2])).propValue : nil
    }

    static let testDateField = Java.findClass("stateui/android/test/TestDateField")
    static let fieldDay = Java.staticMethod(testDateField, "day", "(Landroid/widget/TextView;)[I")
    static let fieldTime = Java.staticMethod(testDateField, "time", "(Landroid/widget/TextView;)[I")
    static let pickDay = Java.staticMethod(testDateField, "pickDay", "(Landroid/app/Dialog;III)V")
    static let pickTime = Java.staticMethod(testDateField, "pickTime", "(Landroid/app/Dialog;II)V")
    static let dialog = Java.field(JavaAPI.dateField, "dialog", "Landroid/app/Dialog;")
    static let earliest = Java.field(JavaAPI.dateField, "earliest", "[I")
    static let latest = Java.field(JavaAPI.dateField, "latest", "[I")
    static let format = Java.field(JavaAPI.dateField, "format", "Ljava/lang/String;")
    static let isShowing = Java.method(Java.findClass("android/app/Dialog"), "isShowing", "()Z")
    static let cancel = Java.method(Java.findClass("android/app/Dialog"), "cancel", "()V")
}
