// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A ProgressBar: a `GtkProgressBar` over the range 0 to 1, a fraction past either end standing at that end.
/// Design: docs/design/platforms/gtk/controls.md#what-shows-work
@MainActor
final class GTKProgressBarView: GTKView {
    private var tintClass: String?

    init() {
        super.init { _ in gtk_progress_bar_new() }
    }

    /// How far the work went, as GTK stands it.
    var progress: Double { gtk_progress_bar_get_fraction(widget.opaque) }

    func setProgress(_ progress: Double) {
        gtk_progress_bar_set_fraction(widget.opaque, progress.isFinite ? min(max(progress, 0), 1) : 0)
    }

    /// The colour the done part is drawn in; nil for the platform's accent.
    func setTint(_ tint: HostValue?) {
        swapClass(&tintClass, to: tint.flatMap(GTKBrush.rgba).map { GTKStyleSheet.tint($0, of: "trough > progress") })
    }
}

/// An ActivityIndicator: a `GtkSpinner`, turning while its work runs and drawing nothing while it does not.
/// Design: docs/design/platforms/gtk/controls.md#what-shows-work
@MainActor
final class GTKActivityIndicatorView: GTKView {
    private var tintClass: String?

    init() {
        super.init { _ in gtk_spinner_new() }
    }

    /// Whether the spinner turns, as GTK stands it.
    var isRunning: Bool { gtk_spinner_get_spinning(widget.opaque) != 0 }

    func setRunning(_ running: Bool) {
        gtk_spinner_set_spinning(widget.opaque, running ? 1 : 0)
    }

    /// The colour the spinner turns in; nil for the platform's.
    func setTint(_ tint: HostValue?) {
        swapClass(&tintClass, to: tint.flatMap(GTKBrush.rgba).map { GTKStyleSheet.tint($0, of: nil) })
    }
}
