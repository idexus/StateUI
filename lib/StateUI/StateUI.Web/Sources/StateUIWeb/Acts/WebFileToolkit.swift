// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web's part of the files the user opens and saves and of what the browser launches (`HostActs.files`): the
/// browser's file input, its save dialog or a download, a file read as the browser hands it, a window opened. A
/// chosen file's address is the number the relay keeps it under.
/// Design: docs/design/platforms/web/runtime.md#files
@MainActor
final class WebFileToolkit: FileToolkit {
    private unowned let renderer: WebRenderer

    init(renderer: WebRenderer) {
        self.renderer = renderer
    }

    func show(
        _ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void
    ) -> MountedElement? {
        guard let window = renderer.shownWindow else { return nil }
        let listener = WebRelay.once {
            guard WebRelay.fileKept else { return answered(.failure(ActFailure(WebRelay.fileWords))) }
            answered(.success(WebRelay.filesChosen.map { ChosenFile(address: String($0.number), name: $0.name) }))
        }
        switch dialog.kind {
        case .open, .openSeveral:
            WebRelay.openFiles(several: dialog.kind == .openSeveral, extensions: dialog.extensions, listener)
        case .save:
            WebRelay.saveFile(dialog.contents, name: dialog.name, kinds: dialog.types, listener)
        }
        return window
    }

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let listener = WebRelay.once {
            answered(WebRelay.fileKept ? .success(WebRelay.fileBytes) : .failure(ActFailure(WebRelay.fileWords)))
        }
        WebRelay.readFile(Int32(file.address) ?? 0, atMost: maximum, listener)
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        WebRelay.launchFile(Int32(file.address) ?? 0, WebRelay.once { answered(WebRelay.fileKept) })
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        guard Self.launches(address) else {
            Task { @MainActor in answered(false) }
            return
        }
        WebRelay.launchAddress(address, WebRelay.once { answered(WebRelay.fileKept) })
    }

    /// The schemes a launch opens: a page's, mail's, a call's, and the relay's own files.
    private static let launchedSchemes: Set<String> = ["http", "https", "mailto", "tel", "blob"]

    /// Whether a launch opens `address`: its scheme read as the browser reads an address - spaces and controls at
    /// its ends dropped, tabs and line breaks anywhere - one of `launchedSchemes`; never `javascript:` or `data:`,
    /// which would run in the application's origin.
    /// Design: docs/design/platforms/web/runtime.md#files
    static func launches(_ address: String) -> Bool {
        let read = address.unicodeScalars
            .drop { $0.value <= 0x20 }.reversed().drop { $0.value <= 0x20 }.reversed()
            .filter { !["\t", "\n", "\r"].contains($0) }
        guard let colon = read.firstIndex(of: ":") else { return false }
        let scheme = String(String.UnicodeScalarView(read[..<colon])).lowercased()
        return launchedSchemes.contains(scheme)
    }
}
