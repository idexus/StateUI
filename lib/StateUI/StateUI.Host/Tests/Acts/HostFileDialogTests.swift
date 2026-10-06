// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A file dialog as every host reads the act asking it: what it asks for, the kinds it offers, the name a save
/// suggests, and the answer it gives.
final class HostFileDialogTests: XCTestCase {
    private let page = FileType("Page", extensions: ["html", "htm"])
    private let text = FileType("Text", extensions: ["txt", "htm"])

    /// An open takes its kinds and whether it takes several; a save its contents, its name and its kinds; any other
    /// act asks for no dialog.
    func testTheActSaysWhatTheDialogAsksFor() throws {
        let one = try XCTUnwrap(HostFileDialog(HostActCall(
            act: .openFiles, arguments: [[page].propValue, .bool(false)], completion: 1)))
        XCTAssertEqual(one.kind, .open)
        XCTAssertEqual(one.types, [page])
        let several = try XCTUnwrap(HostFileDialog(HostActCall(
            act: .openFiles, arguments: [[FileType]().propValue, .bool(true)], completion: 1)))
        XCTAssertEqual(several.kind, .openSeveral)
        XCTAssertEqual(several.types, [], "none for any file")

        let save = try XCTUnwrap(HostFileDialog(HostActCall(
            act: .saveFile, arguments: [[UInt8]([1, 2, 255]).propValue, .string("Report"), [page].propValue],
            completion: 1)))
        XCTAssertEqual(save.kind, .save)
        XCTAssertEqual(save.contents, [1, 2, 255])
        XCTAssertEqual(save.name, "Report.html")
        XCTAssertNil(HostFileDialog(HostActCall(act: .confirm, arguments: [], completion: 1)))
    }

    /// A save's name gains the first kind's first extension where it ends in none of the kinds' - in any case of
    /// letters - and stays as it is when empty or offered no kind.
    func testASaveSuggestsItsNameEndingInAnExtensionOfItsKinds() {
        XCTAssertEqual(HostFileDialog.name("Report", types: [page, text]), "Report.html")
        XCTAssertEqual(HostFileDialog.name("Report.HTM", types: [page]), "Report.HTM")
        XCTAssertEqual(HostFileDialog.name("notes.txt", types: [page, text]), "notes.txt")
        XCTAssertEqual(HostFileDialog.name("notes.txt", types: [page]), "notes.txt.html")
        XCTAssertEqual(HostFileDialog.name("", types: [page]), "")
        XCTAssertEqual(HostFileDialog.name("Report", types: []), "Report")
    }

    /// A dialog filtering by extension alone shows every kind's, in order, each once.
    func testEveryKindsExtensionsStandOnce() throws {
        let dialog = try XCTUnwrap(HostFileDialog(HostActCall(
            act: .openFiles, arguments: [[page, text].propValue, .bool(false)], completion: 1)))
        XCTAssertEqual(dialog.extensions, ["html", "htm", "txt"])
    }

    /// An open answers the files chosen, none for a cancel; a save the file it wrote, nothing for a cancel.
    func testTheAnswerIsTheFilesChosenOrTheFileSaved() throws {
        let file = ChosenFile(address: "C:\\Reports\\Report.html", name: "Report.html")
        let open = try XCTUnwrap(HostFileDialog(HostActCall(act: .openFiles, arguments: [], completion: 1)))
        XCTAssertEqual(open.answer([file]), [[file].propValue])
        XCTAssertEqual(open.answer([]), [[ChosenFile]().propValue])
        let save = try XCTUnwrap(HostFileDialog(HostActCall(act: .saveFile, arguments: [], completion: 1)))
        XCTAssertEqual(save.answer([file]), [file.propValue])
        XCTAssertEqual(save.answer([]), [.nothing])
    }
}
