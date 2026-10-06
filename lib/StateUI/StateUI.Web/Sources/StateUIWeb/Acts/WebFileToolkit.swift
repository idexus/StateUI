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
    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
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
        return true
    }

    func read(_ file: ChosenFile, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let listener = WebRelay.once {
            answered(WebRelay.fileKept ? .success(WebRelay.fileBytes) : .failure(ActFailure(WebRelay.fileWords)))
        }
        WebRelay.readFile(Int32(file.address) ?? 0, listener)
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        WebRelay.launchFile(Int32(file.address) ?? 0, WebRelay.once { answered(WebRelay.fileKept) })
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        WebRelay.launchAddress(address, WebRelay.once { answered(WebRelay.fileKept) })
    }
}
