// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// `StateUIPanel`, a `GtkWidget` subclass registered from Swift: it measures, allocates and draws by asking the
/// panel view whose number it carries, and lets its children go when it is disposed.
/// Design: docs/design/platforms/gtk/c-api.md#a-subclass-from-swift
enum GTKPanel {
    /// Where a panel keeps its view's number.
    static let numberKey = "stateui-view"

    /// Widget's own dispose, which a panel's calls after letting its children go.
    nonisolated(unsafe) private static var widgetDispose: (@convention(c) (UnsafeMutablePointer<GObject>?) -> Void)?

    static let type: GType = g_type_register_static_simple(
        gtk_widget_get_type(), "StateUIPanel",
        guint(MemoryLayout<GtkWidgetClass>.size),
        { theClass, _ in
            let widgetClass = theClass!.assumingMemoryBound(to: GtkWidgetClass.self)
            widgetClass.pointee.get_request_mode = { _ in GTK_SIZE_REQUEST_HEIGHT_FOR_WIDTH }
            widgetClass.pointee.measure = { widget, orientation, forSize, least, natural, leastBaseline, naturalBaseline in
                let number = GTKPanel.number(of: widget)
                let size = MainActor.assumeIsolated {
                    GTKPanel.view(number)?.measure(across: orientation == GTK_ORIENTATION_HORIZONTAL, forSize: forSize) ?? 0
                }
                least?.pointee = 0
                natural?.pointee = Int32(size.rounded(.up))
                leastBaseline?.pointee = -1
                naturalBaseline?.pointee = -1
            }
            widgetClass.pointee.size_allocate = { widget, width, height, _ in
                let number = GTKPanel.number(of: widget)
                MainActor.assumeIsolated { GTKPanel.view(number)?.allocate(width: Double(width), height: Double(height)) }
            }
            widgetClass.pointee.snapshot = { widget, snapshot in
                let number = GTKPanel.number(of: widget)
                nonisolated(unsafe) let snapshot = snapshot
                MainActor.assumeIsolated {
                    guard let snapshot, let view = GTKPanel.view(number) else { return }
                    view.draw(snapshot, width: Double(gtk_widget_get_width(view.widget)),
                              height: Double(gtk_widget_get_height(view.widget)))
                }
            }
            let objectClass = theClass!.assumingMemoryBound(to: GObjectClass.self)
            GTKPanel.widgetDispose = g_type_class_peek(gtk_widget_get_type())!
                .assumingMemoryBound(to: GObjectClass.self).pointee.dispose
            objectClass.pointee.dispose = { object in
                let widget = object!.of(GtkWidget.self)
                while let child = gtk_widget_get_first_child(widget) { gtk_widget_unparent(child) }
                GTKPanel.widgetDispose?(object)
            }
        },
        guint(MemoryLayout<GtkWidget>.size), nil, GTypeFlags(0))

    /// A new panel carrying `number`.
    static func make(number: Int64) -> GTKWidget {
        let panel = g_object_new_with_properties(type, 0, nil, nil)!
        g_object_set_data(panel, numberKey, UnsafeMutableRawPointer(bitPattern: Int(number)))
        return panel.of(GtkWidget.self)
    }

    /// The number of the view a panel answers for.
    static func number(of widget: GTKWidget?) -> Int64 {
        guard let widget else { return 0 }
        return viewNumber(g_object_get_data(widget.of(GObject.self), numberKey))
    }

    @MainActor private static func view(_ number: Int64) -> GTKPanelView? {
        GTKView.find(number) as? GTKPanelView
    }
}
