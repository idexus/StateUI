// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// The event controllers a view puts on its widget and takes off it.
/// Design: docs/design/platforms/gtk/input.md#a-controller-taken-off
@MainActor
enum GTKControllers {
    /// Takes `controller` off `widget` once GTK has ended the event it may be dispatching: both are held until then,
    /// and a controller that left the widget meanwhile is left as it is.
    static func takeOff(_ controller: OpaquePointer, from widget: GTKWidget) {
        g_object_ref(UnsafeMutableRawPointer(widget))
        g_object_ref(UnsafeMutableRawPointer(controller))
        let pair = UnsafeMutablePointer<(widget: GTKWidget, controller: OpaquePointer)>.allocate(capacity: 1)
        pair.initialize(to: (widget, controller))
        g_idle_add_full(G_PRIORITY_HIGH, { data in
            let pair = data!.assumingMemoryBound(to: (widget: GTKWidget, controller: OpaquePointer).self)
            let (widget, controller) = pair.pointee
            if gtk_event_controller_get_widget(controller) == widget { gtk_widget_remove_controller(widget, controller) }
            g_object_unref(UnsafeMutableRawPointer(controller))
            g_object_unref(UnsafeMutableRawPointer(widget))
            pair.deinitialize(count: 1)
            pair.deallocate()
            return 0
        }, UnsafeMutableRawPointer(pair), nil)
    }
}
