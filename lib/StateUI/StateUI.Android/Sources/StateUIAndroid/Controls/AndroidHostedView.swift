// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An element of the application's own: the Android view its control made, placed and shown as the host's own
/// views are, measured by its own `onMeasure`.
/// Design: docs/design/platforms/android/runtime.md#the-applications-own-controls
@MainActor
final class AndroidHostedView<Control: AndroidControl>: AndroidView {
    /// The application's control.
    let control: Control

    init(_ control: Control) {
        self.control = control
        super.init { _ in control.view }
    }
}
