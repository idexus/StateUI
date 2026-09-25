// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// The smallest complete application around one page: one scene, one window.
struct OneWindowApplication: Application {
    let page: @Sendable () -> any Page

    var scene: any Scene { OneWindow(content: page) }
}

/// The window of a `OneWindowApplication`, its page built again each time the window is.
struct OneWindow: Window {
    let content: @Sendable () -> any Page

    var page: any Page { content() }
}

/// The test thread as GTK's: libadwaita started once, and an application registered for the windows, with no
/// loop of GLib's running a test.
@MainActor
enum GTKTestHost {
    /// The application every test's windows belong to.
    static let application: UnsafeMutablePointer<GtkApplication> = {
        adw_init()
        let application = adw_application_new("com.stateui.GTKTests", G_APPLICATION_NON_UNIQUE)!
        precondition(
            g_application_register(application.of(GApplication.self), nil, nil) != 0,
            "the test application could not register")
        return application.of(GtkApplication.self)
    }()

    /// Turns GLib's loop for `seconds`: a window's first frame, and the layout GTK does on it.
    static func pump(_ seconds: Double = 0.2) {
        let end = g_get_monotonic_time() + gint64(seconds * 1_000_000)
        repeat {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(2_000)
        } while g_get_monotonic_time() < end
    }
}

extension XCTestCase {
    /// Runs `body` as the main actor's on the test thread, which holds GTK: a drain makes it MainActor's first.
    func onUIThread(_ body: @MainActor () throws -> Void) rethrows {
        _ = CoreLink().runJobs()
        try MainActor.assumeIsolated(body)
    }
}

extension GTKRenderer {
    /// A host showing `page` in a window of its own, laid out; the host before it leaves, and its window closes.
    static func running(_ page: @escaping @Sendable () -> any Page) -> GTKRenderer {
        shared?.tree.root?.leave()
        shared?.window?.close()

        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = GTKRenderer(application: GTKTestHost.application)
        shared = renderer
        renderer.show()
        GTKTestHost.pump()
        return renderer
    }

    /// Every view of `type` in the tree, in order.
    func views<Native: GTKView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: GTKView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? GTKElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension GTKButtonView {
    /// Clicks the button as the pointer's release does - its `clicked` signal - then lets GTK lay out what that
    /// changed.
    func click() {
        var instance = GValue()
        g_value_init(&instance, gtk_button_get_type())
        g_value_set_object(&instance, UnsafeMutableRawPointer(widget))
        g_signal_emitv(&instance, g_signal_lookup("clicked", gtk_button_get_type()), 0, nil)
        g_value_unset(&instance)
        GTKTestHost.pump(0.05)
    }
}
