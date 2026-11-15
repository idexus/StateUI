// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGTKTesting
import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// A hidden button presenting a popover while `shown` says - the first one's or the other's view as `flipped` says.
@MainActor @ViewBuilder
private func anchor(flipped: Bool) -> some View {
    if flipped { Button("Other").isVisible(false) } else { Button("First").isVisible(false) }
}

@MainActor
private func anchored(flipped: Bool, shown: Binding<Bool>) -> some View {
    anchor(flipped: flipped).popover(isPresented: shown) { Text("Inside") }
}

@MainActor
final class GTKPopoverViewTests: XCTestCase {
    /// GLib's and GTK's criticals said while a test ran - a call on a widget gone among them.
    nonisolated(unsafe) private static var criticals = 0
    /// Whether the first view's widget went, and the widget the popover stood by as it went.
    nonisolated(unsafe) private static var firstWent = false
    nonisolated(unsafe) private static var standingAsTheFirstWent: UnsafeMutableRawPointer?

    /// A popover waiting for its hidden anchor to be shown holds the anchor's widget while it waits: the anchor's
    /// view made anew - its branch flipped - the old view's widget goes only as the popover moves to the new one,
    /// and nothing touches it gone.
    func testAPopoverWaitingOnAnAnchorMadeAnewTouchesNothingGone() {
        (Self.criticals, Self.firstWent, Self.standingAsTheFirstWent) = (0, false, nil)
        let domains: [String] = ["Gtk", "GLib-GObject"]
        let heard = domains.map { domain in
            (domain, g_log_set_handler(
                domain, GLogLevelFlags(rawValue: 1 << 3), { _, _, _, _ in GTKPopoverViewTests.criticals += 1 }, nil))
        }
        defer { for (domain, handler) in heard { g_log_remove_handler(domain, handler) } }
        onUIThread {
            let (flipped, shown) = (State(wrappedValue: false), State(wrappedValue: true))
            let host = GTKRenderer.running {
                VStack { anchored(flipped: flipped.wrappedValue, shown: shown.projectedValue) }
            }
            // No reference kept between the reads: one would hold the first view's widget.
            @MainActor func standsByTheButton() -> Bool {
                guard let popover = host.views(GTKPopoverView.self).first?.popover,
                      let button = host.views(GTKButtonView.self).first?.widget
                else { return false }
                return gtk_widget_get_parent(popover) == button
            }
            host.settle { standsByTheButton() }
            XCTAssertFalse(host.views(GTKPopoverView.self).first?.popoverShows ?? true, "it waits, the anchor hidden")
            if let popover = host.views(GTKPopoverView.self).first?.popover,
               let first = host.views(GTKButtonView.self).first?.widget {
                g_object_weak_ref(first.of(GObject.self), { popover, _ in
                    GTKPopoverViewTests.firstWent = true
                    GTKPopoverViewTests.standingAsTheFirstWent = UnsafeMutableRawPointer(
                        gtk_widget_get_parent(popover?.assumingMemoryBound(to: GtkWidget.self)))
                }, UnsafeMutableRawPointer(popover))
            }

            flipped.wrappedValue = true
            host.settle { standsByTheButton() && Self.firstWent }

            XCTAssertTrue(standsByTheButton(), "it stands by the new view")
            XCTAssertTrue(Self.firstWent, "the first view's widget went")
            XCTAssertEqual(Self.standingAsTheFirstWent, host.views(GTKButtonView.self).first.map {
                UnsafeMutableRawPointer($0.widget) }, "the first view's widget went while the popover waited on it")
            XCTAssertEqual(Self.criticals, 0, "the popover touched the old view's widget, gone")
        }
    }
}
