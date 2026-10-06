// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One file dialog in AppKit's own panel - an open panel for one file or several, a save panel offering its kinds
/// under their captions - shown as a sheet on the window it is asked in, and answered once: the files chosen, none
/// where the user cancelled, a save's once its contents stand written.
/// Design: docs/design/platforms/appkit/runtime.md#files
@MainActor
final class AppKitFileDialog: NSObject, NSOpenSavePanelDelegate {
    /// The dialog as the host layer reads it.
    let dialog: HostFileDialog

    /// The window it is asked in.
    weak var window: NSWindow?

    let panel: NSSavePanel
    private var captions: [UTType: String] = [:]
    private var answer: ((Result<[ChosenFile], ActFailure>) -> Void)?

    init(_ dialog: HostFileDialog, in window: NSWindow) {
        self.dialog = dialog
        self.window = window
        switch dialog.kind {
        case .open, .openSeveral:
            let open = NSOpenPanel()
            open.canChooseFiles = true
            open.canChooseDirectories = false
            open.allowsMultipleSelection = dialog.kind == .openSeveral
            open.allowedContentTypes = Self.unique(dialog.extensions.map(Self.type))
            panel = open
        case .save:
            panel = NSSavePanel()
            for kind in dialog.types {
                guard let first = kind.extensions.first, captions[Self.type(first)] == nil else { continue }
                captions[Self.type(first)] = kind.caption
                panel.allowedContentTypes.append(Self.type(first))
            }
            panel.showsContentTypes = panel.allowedContentTypes.count > 1
            panel.nameFieldStringValue = dialog.name
        }
        super.init()
        panel.delegate = self
    }

    /// The type of the files ending in `extension`.
    private static func type(_ extension: String) -> UTType {
        UTType(filenameExtension: `extension`, conformingTo: .data) ?? .data
    }

    private static func unique(_ types: [UTType]) -> [UTType] {
        types.reduce(into: []) { kept, next in if !kept.contains(next) { kept.append(next) } }
    }

    /// The caption a save panel shows a kind under in its menu of kinds.
    func panel(_ sender: Any, displayNameFor type: UTType) -> String? {
        captions[type]
    }

    /// Shows the panel as a sheet on its window where `presents`, else holds it unshown; `answer` hears what the user
    /// chose once.
    func ask(presenting presents: Bool, answer: @escaping (Result<[ChosenFile], ActFailure>) -> Void) {
        self.answer = answer
        guard presents, let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            chose(response == .OK ? (panel as? NSOpenPanel)?.urls ?? panel.url.map { [$0] } ?? [] : [])
        }
    }

    /// The user chose `urls` - none cancels: an open answers them, a save writes its contents to the first beside the
    /// UI thread, then answers it.
    private func chose(_ urls: [URL]) {
        guard dialog.kind == .save, let url = urls.first else { return finish(.success(urls.map(ChosenFile.init))) }
        let contents = dialog.contents
        Task { @MainActor [weak self] in
            let written = await Self.write(contents, to: url)
            self?.finish(written.map { [ChosenFile(url)] })
        }
    }

    @concurrent private static func write(_ contents: [UInt8], to url: URL) async -> Result<Void, ActFailure> {
        do {
            // In place: a sandbox lets the application write the file the user chose, not a neighbour to swap in.
            try Data(contents).write(to: url)
            return .success(())
        } catch {
            return .failure(ActFailure(error.localizedDescription))
        }
    }

    private func finish(_ result: Result<[ChosenFile], ActFailure>) {
        guard let answer else { return }
        self.answer = nil
        answer(result)
    }

    /// Answers the dialog as the user does, by the files at `urls` - none cancels it.
    func chooseForTesting(_ urls: [URL]) {
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
