// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import UniformTypeIdentifiers
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A save's words, exported under a name, and the name the file was saved as.
private struct Saving: View {
    @State private var answer = "-"

    var body: some View {
        VStack {
            Button("Save").onClicked {
                let text = FileType("Text", extensions: ["txt"])
                answer = try await Dialogs.saveFile(Array("Kept".utf8), name: "Note", types: [text])?.name ?? "nothing"
            }
            Text(answer)
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

/// A file dialog is UIKit's own document picker, presented over the window: one that opens offers the files of every
/// kind, several where asked; one that saves exports a file of the act's name holding its contents.
@MainActor
final class UIKitFileDialogTests: XCTestCase {
    @MainActor
    func testAPickerThatSavesExportsAFileOfItsNameHoldingItsContents() throws {
        let host = UIKitRenderer.running { Saving() }
        defer { host.finish() }
        host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
        host.settle { host.fileToolkit.showing?.picker?.presentingViewController != nil }
        let exported = try XCTUnwrap(host.fileToolkit.showing?.exported)

        XCTAssertEqual(exported.lastPathComponent, "Note.txt")
        XCTAssertEqual(try String(contentsOf: exported, encoding: .utf8), "Kept")

        let place = FileManager.default.temporaryDirectory.appendingPathComponent("UIKitFileDialogTests.txt")
        defer { try? FileManager.default.removeItem(at: place) }
        host.fileToolkit.showing?.chooseForTesting([place])
        host.settle { host.views(UIKitTextView.self).last?.attributedText?.string != "-" }

        XCTAssertEqual(host.views(UIKitTextView.self).last?.attributedText?.string, "UIKitFileDialogTests.txt")
        XCTAssertEqual(try String(contentsOf: place, encoding: .utf8), "Kept")
        XCTAssertFalse(FileManager.default.fileExists(atPath: exported.path), "the file exported goes once saved")
    }

    @MainActor
    func testAPickerThatOpensOffersEveryKindsFilesSeveralWhereAsked() throws {
        let host = UIKitRenderer.running { Opening() }
        defer { host.finish() }
        host.views(UIKitButtonView.self).first?.sendActions(for: .primaryActionTriggered)
        host.settle { host.fileToolkit.showing?.picker?.presentingViewController != nil }
        let picker = try XCTUnwrap(host.fileToolkit.showing?.picker)

        XCTAssertTrue(picker.allowsMultipleSelection)
        host.fileToolkit.showing?.chooseForTesting([])
        host.settle { host.fileToolkit.showing == nil }
        XCTAssertNil(host.fileToolkit.showing, "a cancelled picker answers and goes")
    }
}
