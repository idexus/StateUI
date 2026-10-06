// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host's toolkit does for the files the user opens and saves and for what the system launches
/// (`HostActs.files`), handed to its `HostActPerformer` beside its `ActToolkit`.
/// Design: docs/design/host/runtime.md#files
@_spi(Host) @MainActor public protocol FileToolkit: AnyObject {
    /// Shows `dialog` over the window the user is looking at, and calls `answered` with the files chosen - none where
    /// they cancelled, a save's once its contents stand written - or why it failed; false where there is no window
    /// to show it over.
    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool

    /// Reads `file` whole, and calls `answered` with its bytes or why they could not be read.
    func read(_ file: ChosenFile, answered: @escaping (Result<[UInt8], ActFailure>) -> Void)

    /// Hands `file` to the system to open in the application it gives its kind, and calls `answered` with whether
    /// one took it.
    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void)

    /// Hands `address` to the system to open in the application it gives it, and calls `answered` with whether one
    /// took it.
    func launch(address: String, answered: @escaping (Bool) -> Void)
}
