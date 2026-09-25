// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// `StateUIPanel`, a `GtkWidget` subclass registered from Swift: it measures, allocates and draws by asking the
/// panel view whose number it carries, offers assistive technology a press while it listens for taps, and lets its
/// children go when it is disposed.
/// Design: docs/design/platforms/gtk/c-api.md#a-subclass-from-swift
enum GTKPanel {
    /// Where a panel keeps its view's number.
    static let numberKey = "stateui-view"

    /// The action assistive technology presses a panel by, which answers as one tap.
    /// Design: docs/design/platforms/gtk/input.md#pressed-by-assistive-technology
    static let pressAction = "panel.click"

    /// Widget's own dispose, which a panel's calls after letting its children go, and its own test of a point.
    nonisolated(unsafe) private static var widgetDispose: (@convention(c) (UnsafeMutablePointer<GObject>?) -> Void)?
    nonisolated(unsafe) private static var widgetContains: (@convention(c) (GTKWidget?, Double, Double) -> gboolean)?

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
                MainActor.assumeIsolated {
                    GTKPanel.view(number)?.allocate(width: Double(width), height: Double(height))
                    GTKRenderer.shared?.runtime.frames.laidOut()
                }
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
            gtk_widget_class_install_action(widgetClass, GTKPanel.pressAction, nil) { widget, _, _ in
                let number = GTKPanel.number(of: widget)
                MainActor.assumeIsolated {
                    guard let view = GTKView.find(number), view.hearing.contains(.taps) else { return }
                    view.heard(.tap(run: 0))
                }
            }
            // GTK tries a widget's children before the widget: a panel passing beside them holds no point itself.
            GTKPanel.widgetContains = g_type_class_peek(gtk_widget_get_type())!
                .assumingMemoryBound(to: GtkWidgetClass.self).pointee.contains
            widgetClass.pointee.contains = { widget, x, y in
                let number = GTKPanel.number(of: widget)
                let passes = MainActor.assumeIsolated { GTKPanel.view(number)?.passesBeside == true }
                return passes ? 0 : GTKPanel.widgetContains?(widget, x, y) ?? 0
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
        setPressable(panel.of(GtkWidget.self), false)
        return panel.of(GtkWidget.self)
    }

    /// Whether assistive technology can press `panel`.
    static func setPressable(_ panel: GTKWidget, _ pressable: Bool) {
        gtk_widget_action_set_enabled(panel, pressAction, pressable ? 1 : 0)
    }

    /// Whether `widget` is a panel.
    static func holds(_ widget: GTKWidget) -> Bool {
        g_type_check_instance_is_a(UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GTypeInstance.self), type) != 0
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
