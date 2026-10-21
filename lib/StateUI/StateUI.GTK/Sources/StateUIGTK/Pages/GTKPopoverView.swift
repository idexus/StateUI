// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A popover's view: what it holds, standing in GTK's `GtkPopover` on its anchor's widget while it shows; `onClosed`
/// hears the user take it away - a click beside it, Escape.
/// Design: docs/design/platforms/gtk/pages.md#a-popover
@MainActor
final class GTKPopoverView: GTKSingleChildView {
    var onClosed: (() -> Void)?

    /// The popover holding the view, once it was first shown.
    private(set) var popover: GTKWidget?

    /// Whether the program wants the popover shown: a closing while it does is the user's.
    private var wanted = false

    /// The anchor's widget waited on to be mapped - GTK pops a popover up only by a mapped widget - and the
    /// handler hearing it.
    private var waitingOn: (widget: GTKWidget, handler: gulong)?

    /// Whether the popover shows.
    var popoverShows: Bool {
        popover.map { gtk_widget_get_visible($0) != 0 } ?? false
    }

    /// Shows the popover on `anchor`'s widget.
    func show(by anchor: GTKView) {
        wanted = true
        let popover = self.popover ?? made()
        if gtk_widget_get_parent(popover) != anchor.widget {
            if gtk_widget_get_parent(popover) != nil { gtk_widget_unparent(popover) }
            gtk_widget_set_parent(popover, anchor.widget)
        }
        guard !popoverShows else { return }
        guard gtk_widget_get_mapped(anchor.widget) != 0 else { return waitForMap(of: anchor.widget) }
        gtk_popover_popup(popover.of(GtkPopover.self))
    }

    func close() {
        wanted = false
        stopWaiting()
        popover.map { gtk_popover_popdown($0.of(GtkPopover.self)) }
    }

    /// Pops the popover up once `widget` is mapped, after the frame that maps it is laid out - where it points at
    /// the anchor's place.
    private func waitForMap(of widget: GTKWidget) {
        guard waitingOn?.widget != widget else { return }
        stopWaiting()
        let handler = connectSignal(UnsafeMutableRawPointer(widget), "map", number: number) { _, data in
            g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, { data in
                MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKPopoverView)?.anchorMapped() }
                return 0
            }, data, nil)
        }
        waitingOn = (widget, handler)
    }

    private func anchorMapped() {
        stopWaiting()
        guard wanted, let popover, !popoverShows else { return }
        gtk_popover_popup(popover.of(GtkPopover.self))
    }

    private func stopWaiting() {
        guard let waiting = waitingOn else { return }
        g_signal_handler_disconnect(UnsafeMutableRawPointer(waiting.widget), waiting.handler)
        waitingOn = nil
    }

    private func made() -> GTKWidget {
        let popover = gtk_popover_new()!
        g_object_ref_sink(popover)
        gtk_popover_set_child(popover.of(GtkPopover.self), widget)
        connectSignal(UnsafeMutableRawPointer(popover), "closed", number: number) { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKPopoverView)?.closedByGTK() }
        }
        self.popover = popover
        return popover
    }

    private func closedByGTK() {
        guard wanted else { return }
        wanted = false
        onClosed?()
    }

    override func detach() {
        close()
        onClosed = nil
        if let popover {
            gtk_popover_set_child(popover.of(GtkPopover.self), nil)
            if gtk_widget_get_parent(popover) != nil { gtk_widget_unparent(popover) }
            g_object_unref(popover)
        }
        popover = nil
        super.detach()
    }
}
