// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// The input method GTK hands a field the keyboard through, which on Wayland binds as the compositor answers the
/// process's first field: a field gone before that left GTK holding it freed, and the compositor's next word crashed
/// the process. Only the process's first field meets it, so the test proves it run alone.
/// Design: docs/design/platforms/gtk/runtime.md#the-input-method
final class GTKInputMethodTests: XCTestCase {
    /// A field that takes the keyboard and goes in the same turn leaves nothing behind: the window goes on, and the
    /// next field takes the keyboard as the first did.
    func testAFieldThatTakesTheKeyboardAndGoesAtOnceLeavesNothingBehind() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { Text("Fields") } }
            defer { host.finish() }
            let window = try XCTUnwrap(host.windows.first?.window.widget)
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first).widget
            let field = { () -> GTKWidget in
                let field = gtk_text_new()!
                gtk_widget_set_parent(field, stack)
                gtk_widget_grab_focus(field)
                return field
            }

            gtk_widget_unparent(field())
            GTKTestHost.pump(0.5)

            let next = field()
            defer { gtk_widget_unparent(next) }
            XCTAssertEqual(gtk_root_get_focus(window.opaque), next, "the next field takes the keyboard")
        }
    }
}
