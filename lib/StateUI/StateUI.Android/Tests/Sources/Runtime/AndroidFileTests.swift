// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

/// A file dialog is the system's document picker, asked by the intent the act says: one that saves suggests its name
/// and its type, one that opens asks for every kind's type, several where asked.
final class AndroidFileTests: XCTestCase {
    static var allTests: [(String, (AndroidFileTests) -> () throws -> Void)] {
        [
            ("testASavePickerSuggestsItsNameAndType", testASavePickerSuggestsItsNameAndType),
            ("testAnOpenPickerAsksForEveryKindsTypeSeveralWhereAsked", testAnOpenPickerAsksForEveryKindsTypeSeveralWhereAsked),
        ]
    }

    func testASavePickerSuggestsItsNameAndType() throws {
        try onMainActor {
            Java.callStatic(Self.files, Self.holdForTesting)
            let host = AndroidRenderer.running { Saving() }
            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { Self.held() != nil }
            let intent = try XCTUnwrap(Self.held())

            XCTAssertEqual(intent.action, "android.intent.action.CREATE_DOCUMENT")
            XCTAssertEqual(intent.title, "Note.txt")
            XCTAssertEqual(intent.type, "text/plain")
        }
    }

    func testAnOpenPickerAsksForEveryKindsTypeSeveralWhereAsked() throws {
        try onMainActor {
            Java.callStatic(Self.files, Self.holdForTesting)
            let host = AndroidRenderer.running { Opening() }
            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { Self.held() != nil }
            let intent = try XCTUnwrap(Self.held())

            XCTAssertEqual(intent.action, "android.intent.action.OPEN_DOCUMENT")
            XCTAssertTrue(intent.several)
            XCTAssertEqual(intent.types.first, "text/plain")
            XCTAssertTrue(intent.types.contains("text/html"), "\(intent.types)")
        }
    }

    /// The intent of the picker the relay holds: its action, type, suggested name, several, and types asked.
    @MainActor
    private static func held() -> (action: String, type: String, title: String, several: Bool, types: [String])? {
        Java.frame {
            guard let intent = Java.callStaticObject(files, heldIntent) else { return nil }
            let extra = { (name: String) in Java.string("android.intent.extra." + name) }
            return (
                Java.text(Java.callObject(intent, getAction)), Java.text(Java.callObject(intent, getType)),
                Java.text(Java.callObject(intent, getStringExtra, .object(extra("TITLE")))),
                Java.callBool(intent, getBooleanExtra, .object(extra("ALLOW_MULTIPLE")), .bool(false)),
                Java.texts(Java.callObject(intent, getStringArrayExtra, .object(extra("MIME_TYPES")))))
        }
    }

    @MainActor private static let files = Java.findClass("stateui/android/StateUIFiles")
    @MainActor private static let holdForTesting = Java.staticMethod(files, "holdForTesting", "()V")
    @MainActor private static let heldIntent = Java.staticMethod(
        files, "heldIntentForTesting", "()Landroid/content/Intent;")
    @MainActor private static let intentClass = Java.findClass("android/content/Intent")
    @MainActor private static let getAction = Java.method(intentClass, "getAction", "()Ljava/lang/String;")
    @MainActor private static let getType = Java.method(intentClass, "getType", "()Ljava/lang/String;")
    @MainActor private static let getStringExtra = Java.method(
        intentClass, "getStringExtra", "(Ljava/lang/String;)Ljava/lang/String;")
    @MainActor private static let getBooleanExtra = Java.method(intentClass, "getBooleanExtra", "(Ljava/lang/String;Z)Z")
    @MainActor private static let getStringArrayExtra = Java.method(
        intentClass, "getStringArrayExtra", "(Ljava/lang/String;)[Ljava/lang/String;")
}

/// A button saving words under a name of the text kind.
private struct Saving: View {
    var body: some View {
        Button("Save").onClicked {
            _ = try await Dialogs.saveFile(Array("Kept".utf8), name: "Note", types: [FileType("Text", extensions: ["txt"])])
        }
    }
}

/// A button opening files of two kinds.
private struct Opening: View {
    var body: some View {
        Button("Open").onClicked {
            _ = try await Dialogs.openFiles(types: [
                FileType("Text", extensions: ["txt", "md"]), FileType("Web page", extensions: ["html"]),
            ])
        }
    }
}
