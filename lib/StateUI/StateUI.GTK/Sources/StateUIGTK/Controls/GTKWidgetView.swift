// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A widget of GTK's own that the host makes for an arrangement - a navigation view, a split view - held as a view
/// so a StateUI panel places it.
@MainActor
final class GTKWidgetView: GTKView {
    init(_ make: () -> GTKWidget?) {
        super.init { _ in make() }
    }
}
