// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One view's drags, as GTK's own controllers: a drag source carrying the view's words as UTF-8 text, and a drop
/// target taking a string - and a list of files where the view takes files - each telling the host layer what it
/// heard (`HeardInput`) by the view's number.
/// Design: docs/design/platforms/gtk/input.md#a-drag-between-views
@MainActor
final class GTKDragAndDrop {
    private let widget: GTKWidget
    private let number: Int64
    private var source: OpaquePointer?
    private var target: OpaquePointer?

    /// What a drag of the view carries and what it takes, as it stands.
    private(set) var offered = DragAndDrop.none

    /// What hears what the view heard of a drag.
    var heard: ((HeardInput) -> Void)?

    init(widget: GTKWidget, number: Int64) {
        self.widget = widget
        self.number = number
    }

    /// Puts on the view the controllers `offered` asks for, and takes away those it no longer does.
    func offer(_ offered: DragAndDrop) {
        let before = self.offered
        self.offered = offered
        if (offered.words != nil) != (source != nil) {
            if let source {
                gtk_widget_remove_controller(widget, source)
                self.source = nil
            } else {
                source = makeSource()
            }
        }
        guard offered.takesWords != before.takesWords || offered.takesFiles != before.takesFiles else { return }
        if let target {
            gtk_widget_remove_controller(widget, target)
            self.target = nil
        }
        if offered.takesWords || offered.takesFiles { target = makeTarget(offered) }
    }

    func detach() {
        offer(.none)
    }

    /// The drag source: what it carries asked as it prepares, its start and its end told.
    private func makeSource() -> OpaquePointer {
        let source = gtk_drag_source_new()!
        gtk_drag_source_set_actions(source, GDK_ACTION_COPY)
        let prepare: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> UnsafeMutablePointer<GdkContentProvider>? = {
            _, _, _, data in
            let words = MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.offered.words }
            guard let words else { return nil }
            let bytes = Array(words.utf8).withUnsafeBytes { g_bytes_new($0.baseAddress, gsize($0.count)) }
            defer { g_bytes_unref(bytes) }
            return gdk_content_provider_new_for_bytes("text/plain;charset=utf-8", bytes)
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "prepare", unsafeBitCast(prepare, to: GCallback.self),
            UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(rawValue: 0))
        connectSignal(UnsafeMutableRawPointer(source), "drag-begin", number: number) {
            (_: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, data) in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.heard?(.dragStarted) }
        }
        let ended: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, gpointer?) -> Void = {
            _, _, _, data in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.heard?(.dragEnded) }
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "drag-end", unsafeBitCast(ended, to: GCallback.self),
            UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(widget, source)
        return source
    }

    /// The drop target: a string where the view takes words, a list of files where it takes files.
    private func makeTarget(_ offered: DragAndDrop) -> OpaquePointer {
        let target = gtk_drop_target_new(0, GDK_ACTION_COPY)!
        var types: [GType] = []
        if offered.takesWords { types.append(g_type_from_name("gchararray")) }
        if offered.takesFiles { types.append(gdk_file_list_get_type()) }
        gtk_drop_target_set_gtypes(target, &types, gsize(types.count))
        let over: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> GdkDragAction = { _, _, _, data in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.heard?(.dragOver) }
            return GDK_ACTION_COPY
        }
        for signal in ["enter", "motion"] {
            g_signal_connect_data(
                UnsafeMutableRawPointer(target), signal, unsafeBitCast(over, to: GCallback.self),
                UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(rawValue: 0))
        }
        connectSignal(UnsafeMutableRawPointer(target), "leave", number: number) { (_: UnsafeMutableRawPointer?, data) in
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.heard?(.dragLeft) }
        }
        let drop: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = {
            _, value, _, _, data in
            guard let value, let heard = GTKDragAndDrop.heard(in: value) else { return 0 }
            MainActor.assumeIsolated { GTKView.find(viewNumber(data))?.dragAndDrop?.heard?(heard) }
            return 1
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(target), "drop", unsafeBitCast(drop, to: GCallback.self),
            UnsafeMutableRawPointer(bitPattern: Int(number)), nil, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(widget, target)
        return target
    }

    /// What a drop's value says: its words, or the files of a list - each by its path and name.
    nonisolated private static func heard(in value: UnsafePointer<GValue>) -> HeardInput? {
        if value.pointee.g_type == gdk_file_list_get_type() {
            guard let list = g_value_get_boxed(value) else { return nil }
            var files: [ChosenFile] = []
            var node = gdk_file_list_get_files(OpaquePointer(list))
            let first = node
            while let each = node {
                if let path = g_file_get_path(OpaquePointer(each.pointee.data)) {
                    let name = g_path_get_basename(path)
                    files.append(ChosenFile(address: String(cString: path), name: name.map { String(cString: $0) } ?? ""))
                    g_free(name)
                    g_free(path)
                }
                node = each.pointee.next
            }
            g_slist_free(first)
            return .filesDropped(files)
        }
        guard let words = g_value_get_string(value) else { return nil }
        return .dropped(String(cString: words))
    }
}
