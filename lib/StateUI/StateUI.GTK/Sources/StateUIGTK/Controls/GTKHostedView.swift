// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A control of the application's own, standing in the tree as a view of this host: its widget placed, sized and
/// shown like any other, the control held for as long as its element lives.
@MainActor
final class GTKHostedView<Control: GTKControl>: GTKView {
    /// The application's control.
    let control: Control

    init(_ control: Control) {
        self.control = control
        super.init { _ in control.widget }
    }
}
