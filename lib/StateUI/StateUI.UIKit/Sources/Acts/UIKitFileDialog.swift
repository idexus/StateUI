// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import UniformTypeIdentifiers
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One file dialog in UIKit's own document picker - one opening files of the kinds asked, one or several, or one
/// exporting a save's contents, written first to a file of its name - presented over what the window shows, and
/// answered once: the files chosen, none where the user cancelled.
/// Design: docs/design/platforms/uikit/runtime.md#files
@MainActor
final class UIKitFileDialog: NSObject, UIDocumentPickerDelegate {
    /// The dialog as the host layer reads it.
    let dialog: HostFileDialog

    /// The picker, once it is presented.
    private(set) var picker: UIDocumentPickerViewController?

    /// The file a save exports, written before its picker is presented.
    private(set) var exported: URL?
    private var answer: ((Result<[ChosenFile], ActFailure>) -> Void)?

    init(_ dialog: HostFileDialog) {
        self.dialog = dialog
    }

    /// Presents the picker over `presenter` - a save's once its file stands written; `answer` hears what the user
    /// chose once, or why the save's file could not be written.
    func ask(over presenter: UIViewController, answer: @escaping (Result<[ChosenFile], ActFailure>) -> Void) {
        self.answer = answer
        guard dialog.kind == .save else {
            let types = dialog.extensions.map { UTType(filenameExtension: $0, conformingTo: .data) ?? .data }
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: types.isEmpty ? [.item] : types, asCopy: false)
            picker.allowsMultipleSelection = dialog.kind == .openSeveral
            return present(picker, over: presenter)
        }
        let (contents, name) = (dialog.contents, dialog.name.isEmpty ? "Untitled" : dialog.name)
        Task { @MainActor [weak self, weak presenter] in
            let written = await Self.write(contents, named: name)
            guard let self, let presenter else { return }
            switch written {
            case .success(let file):
                exported = file
                present(UIDocumentPickerViewController(forExporting: [file], asCopy: true), over: presenter)
            case .failure(let failure):
                finish(.failure(failure))
            }
        }
    }

    private func present(_ picker: UIDocumentPickerViewController, over presenter: UIViewController) {
        picker.delegate = self
        self.picker = picker
        presenter.present(picker, animated: true)
    }

    /// Writes `contents` to a file named `name` in a folder of its own, beside the UI thread.
    @concurrent private static func write(_ contents: [UInt8], named name: String) async -> Result<URL, ActFailure> {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(name)
            try Data(contents).write(to: file)
            return .success(file)
        } catch {
            return .failure(ActFailure(error.localizedDescription))
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        chose(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        chose([])
    }

    /// The user chose `urls` - none cancels: each file stays the application's to read while it runs.
    private func chose(_ urls: [URL]) {
        for url in urls { _ = url.startAccessingSecurityScopedResource() }
        if let exported { try? FileManager.default.removeItem(at: exported.deletingLastPathComponent()) }
        finish(.success(urls.map(ChosenFile.init)))
    }

    private func finish(_ result: Result<[ChosenFile], ActFailure>) {
        guard let answer else { return }
        self.answer = nil
        answer(result)
    }

    /// Answers the picker as the user does, by the files at `urls` - none cancels it: the picker goes, and a save's
    /// file is exported there first, as the picker exports it.
    func chooseForTesting(_ urls: [URL]) {
        if let exported, let place = urls.first {
            try? FileManager.default.removeItem(at: place)
            try? FileManager.default.copyItem(at: exported, to: place)
        }
        picker?.presentingViewController?.dismiss(animated: false)
        chose(urls)
    }
}

extension ChosenFile {
    /// The file at `url`: its path, and its name with its extension.
    init(_ url: URL) {
        self.init(address: url.path, name: url.lastPathComponent)
    }
}
#endif
