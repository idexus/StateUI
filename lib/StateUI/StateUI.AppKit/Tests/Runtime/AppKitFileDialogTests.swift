// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A file dialog is AppKit's own panel, set as the act asks: a save panel offers its kinds under their captions with
/// the name it suggests, an open panel the files of every kind, several where asked.
final class AppKitFileDialogTests: XCTestCase {
    @MainActor
    private func settle(_ renderer: AppKitRenderer, until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.runtime.pump.turn()
        }
    }

    @MainActor
    func testASavePanelOffersEachKindUnderItsCaptionAndWritesWhereTheUserSays() throws {
        let renderer = AppKitRenderer.running { Saving() }
        defer { renderer.closeForTesting() }
        let answer = { renderer.nativeViews(AppKitTextView.self).last?.textForTesting.string }
        try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first).clickForTesting()
        settle(renderer) { renderer.fileToolkit.showing != nil }
        let dialog = try XCTUnwrap(renderer.fileToolkit.showing)
        let html = try XCTUnwrap(UTType(filenameExtension: "html"))
        let text = try XCTUnwrap(UTType(filenameExtension: "txt"))

        XCTAssertFalse(dialog.panel is NSOpenPanel)
        XCTAssertEqual(dialog.panel.allowedContentTypes, [html, text], "each kind once, by its first extension")
        XCTAssertTrue(dialog.panel.showsContentTypes)
        XCTAssertEqual(dialog.panel(dialog.panel, displayNameFor: html), "Web page")
        XCTAssertEqual(dialog.panel.nameFieldStringValue, "Report.html")

        let place = FileManager.default.temporaryDirectory.appendingPathComponent("AppKitFileDialogTests.html")
        defer { try? FileManager.default.removeItem(at: place) }
        dialog.chooseForTesting([place])
        settle(renderer) { answer() != "-" }

        XCTAssertEqual(answer(), "AppKitFileDialogTests.html")
        XCTAssertEqual(try String(contentsOf: place, encoding: .utf8), "<p>Kept</p>")
        XCTAssertNil(renderer.fileToolkit.showing)
    }

    @MainActor
    func testAnOpenPanelOffersEveryKindsFilesSeveralWhereAsked() throws {
        let renderer = AppKitRenderer.running { Opening() }
        defer { renderer.closeForTesting() }
        try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first).clickForTesting()
        settle(renderer) { renderer.fileToolkit.showing != nil }
        let panel = try XCTUnwrap(renderer.fileToolkit.showing?.panel as? NSOpenPanel)

        XCTAssertTrue(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertEqual(
            panel.allowedContentTypes, try ["txt", "md", "html"].map { try XCTUnwrap(UTType(filenameExtension: $0)) })
    }
}

/// A button saving a page under two kinds, and the name it was saved as.
private struct Saving: View {
    @State private var answer = "-"

    var body: some View {
        VStack {
            Button("Save").onClicked {
                let kinds = [FileType("Web page", extensions: ["html", "htm"]), FileType("Text", extensions: ["txt"])]
                let saved = try await Dialogs.saveFile(Array("<p>Kept</p>".utf8), name: "Report", types: kinds)
                answer = saved?.name ?? "nothing"
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
#endif
