// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's part of the files the user opens and saves and of what macOS launches (`HostActs.files`): AppKit's own
/// panels as a sheet on the window the user is looking at, a file read beside the UI thread, `NSWorkspace`.
/// Design: docs/design/platforms/appkit/runtime.md#files
@MainActor
final class AppKitFileToolkit: FileToolkit {
    private unowned let renderer: AppKitRenderer

    /// The dialog showing now, where one is.
    private(set) var showing: AppKitFileDialog?

    /// Whether a launch is only recorded, never handed to macOS: a test's.
    var holdsLaunchesForTesting = false

    /// What the host handed macOS to launch, in order: an address as written, a file by its path.
    private(set) var launchedForTesting: [String] = []

    init(renderer: AppKitRenderer) {
        self.renderer = renderer
    }

    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
        guard let window = renderer.userWindow else { return false }
        let asked = AppKitFileDialog(dialog, in: window)
        showing = asked
        asked.ask(presenting: renderer.presentsWindows) { [weak self] chosen in
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

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launch(URL(fileURLWithPath: file.address), as: file.address, answered: answered)
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        launch(URL(string: address).flatMap { $0.scheme == nil ? nil : $0 }, as: address, answered: answered)
    }

    /// Hands `url` to macOS, which opens it in the application it gives it; `answered` hears whether one took it -
    /// never in the turn that asked.
    private func launch(_ url: URL?, as written: String, answered: @escaping (Bool) -> Void) {
        if url != nil { launchedForTesting.append(written) }
        let holds = holdsLaunchesForTesting
        Task { @MainActor in
            guard let url else { return answered(false) }
            if holds { return answered(true) }
            answered((try? await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())) != nil)
        }
    }
}
#endif
