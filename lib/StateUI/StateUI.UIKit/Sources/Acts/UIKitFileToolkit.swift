// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import QuickLook
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// UIKit's part of the files the user opens and saves and of what iOS launches (`HostActs.files`): UIKit's document
/// picker over what the user's window shows, a file read beside the UI thread, a file previewed, an address opened.
/// Design: docs/design/platforms/uikit/runtime.md#files
@MainActor
final class UIKitFileToolkit: FileToolkit {
    private unowned let renderer: UIKitRenderer

    /// The dialog showing now, where one is.
    private(set) var showing: UIKitFileDialog?

    /// Whether a launch is only recorded, never handed to iOS: a test's.
    var holdsLaunchesForTesting = false

    /// What the host handed iOS to launch, in order: an address as written, a file by its path.
    private(set) var launchedForTesting: [String] = []

    init(renderer: UIKitRenderer) {
        self.renderer = renderer
    }

    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
        guard let presenter = renderer.userPresenter else { return false }
        let asked = UIKitFileDialog(dialog)
        showing = asked
        asked.ask(over: presenter) { [weak self] chosen in
            self?.showing = nil
            answered(chosen)
        }
        return true
    }

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let path = file.address
        Task { @MainActor in answered(await Self.bytes(at: path, atMost: maximum)) }
    }

    /// The file's bytes, or its first `maximum` of them, read no further.
    @concurrent private static func bytes(at path: String, atMost maximum: Int?) async -> Result<[UInt8], ActFailure> {
        do {
            let url = URL(fileURLWithPath: path)
            guard let maximum else { return .success(Array(try Data(contentsOf: url))) }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return .success(Array(try handle.read(upToCount: maximum) ?? Data()))
        } catch {
            return .failure(ActFailure(error.localizedDescription))
        }
    }

    /// Shows the file in iOS's preview over what the user's window shows; whether it can be previewed.
    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launchedForTesting.append(file.address)
        let url = URL(fileURLWithPath: file.address)
        let holds = holdsLaunchesForTesting
        Task { @MainActor [weak self] in
            if holds { return answered(true) }
            guard QLPreviewController.canPreview(url as NSURL), let presenter = self?.renderer.userPresenter else {
                return answered(false)
            }
            presenter.present(UIKitFilePreview(url), animated: true)
            answered(true)
        }
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        let url = URL(string: address).flatMap { $0.scheme == nil ? nil : $0 }
        if url != nil { launchedForTesting.append(address) }
        let holds = holdsLaunchesForTesting
        Task { @MainActor in
            guard let url else { return answered(false) }
            answered(holds ? true : await UIApplication.shared.open(url))
        }
    }
}

/// iOS's preview of one file, its own data source.
private final class UIKitFilePreview: QLPreviewController, QLPreviewControllerDataSource {
    private let file: URL

    init(_ file: URL) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
        dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("UIKitFilePreview is made in code")
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        file as NSURL
    }
}
#endif
