// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A spacer: a plain `android.view.View`, empty room which asks for none - the stack's arithmetic gives it what its
/// siblings leave.
/// Design: docs/design/host/layout.md#a-spacer
@MainActor
final class AndroidSpacerView: AndroidView {
    init() {
        super.init { _ in Java.new(JavaAPI.view, JavaAPI.newView, .object(AndroidRenderer.context)) }
    }

    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        super.measure(width: ViewConstants.exactOnly(width), height: ViewConstants.exactOnly(height))
    }
}
