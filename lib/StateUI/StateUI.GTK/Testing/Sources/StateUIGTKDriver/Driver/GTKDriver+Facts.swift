// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import Glibc
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// The facts the GTK driver reads besides a member - an application started, the keyboard's focus, where a view
/// stands, the question showing, what the screen reader was told, the log, what is kept - and a window's life as
/// its desktop would tell it.
/// Design: docs/design/host/conformance.md#the-driver
extension GTKDriver {
    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        written.listen()
        let renderer = GTKRenderer.running(clock: clock, keeping: true, application: application)
        self.renderer = renderer
        Self.holdFiles(of: renderer)
        return renderer.runtime.tree
    }

    /// The folder the files a test opens and saves stand in, the process's own.
    static let files = String(cString: g_get_tmp_dir()) + "/stateui-conformance-files-\(getpid())"

    /// Empties the files folder, so no case reads a file another saved, and holds `renderer`'s dialogs and launches
    /// back.
    static func holdFiles(of renderer: GTKRenderer) {
        g_mkdir_with_parents(files, 0o700)
        if let folder = g_dir_open(files, 0, nil) {
            while let name = g_dir_read_name(folder) { unlink(files + "/" + String(cString: name)) }
            g_dir_close(folder)
        }
        renderer.fileToolkit.holdsForTesting = true
    }

    /// The file dialog the host holds: one that opens or one that saves.
    func fileDialog(over element: MountedElement) throws -> FileDialog? {
        renderer?.fileToolkit.held.map { $0.dialog.kind == .save ? .save : .open }
    }

    /// What the host handed the desktop to launch, in order: an address as written, a file by its name.
    func launched() throws -> [String] {
        (renderer?.fileToolkit.launchedForTesting ?? []).map { target in
            target.contains("://") ? target : String(target.split(separator: "/").last ?? Substring(target))
        }
    }

    func forgetWhatIsKept() {
        GTKKeptValues.folder = GTKTestHost.keptFolder
        unlink(GTKKeptValues.file(for: ""))
        unlink(GTKKeptValues.scenesFile(for: ""))
    }

    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? GTKElement)?.view else { throw DriverCannot("read the focus of \(element.type.name)") }
        guard let root = gtk_widget_get_root(view.widget), let focus = gtk_root_get_focus(root) else { return false }
        return focus == view.widget || gtk_widget_is_ancestor(focus, view.widget) != 0
    }

    func place(of element: MountedElement) throws -> Rect {
        guard let view = (element.native as? GTKElement)?.view, let root = gtk_widget_get_root(view.widget) else {
            throw DriverCannot("read where \(element.type.name) stands")
        }
        renderer?.layOut()
        var bounds = graphene_rect_t()
        let window = UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWidget.self)
        guard gtk_widget_compute_bounds(view.widget, window, &bounds) != 0 else {
            throw DriverCannot("read where \(element.type.name) stands")
        }
        return Rect(
            x: Double(bounds.origin.x), y: Double(bounds.origin.y), width: Double(bounds.size.width),
            height: Double(bounds.size.height))
    }

    func question(over element: MountedElement) throws -> Question? {
        let window = try? self.window(of: element)
        guard let dialog = renderer?.visibleDialog(over: window),
              GTKTestHost.holds(dialog, adw_alert_dialog_get_type())
        else { return nil }
        let alert = dialog.of(AdwAlertDialog.self)
        let widgets = GTKTestHost.descendants(of: dialog)
        let buttons = widgets.filter { GTKTestHost.holds($0, gtk_button_get_type()) }
            .compactMap { gtk_button_get_label($0.of(GtkButton.self)).map { String(cString: $0) } }
        let field = widgets.first { GTKTestHost.holds($0, gtk_entry_get_type()) }
            .map { String(cString: gtk_editable_get_text($0.opaque)) }
        return Question(
            title: adw_alert_dialog_get_heading(alert).map { String(cString: $0) } ?? "",
            message: adw_alert_dialog_get_body(alert).map { String(cString: $0) } ?? "",
            buttons: buttons, field: field)
    }

    func announced() throws -> [String] {
        GTKActToolkit.announced
    }

    func logged() throws -> [String] {
        written.lines
    }

    var liveViews: Int? {
        GTKView.liveCount
    }

    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        if inScene { return GTKKeptValues.readScenes(applicationID: "").scenes.first?.values[key] }
        let kept = GTKKeptValues.read(GTKKeptValues.file(for: ""))
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Int.self),
            PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { kept.restored(for: [$0])[key] }.first
    }

    /// Performs a window's act: its question answered, or its life as the desktop would tell it - the driver tells
    /// what GTK's notices would, since a desktop moves no window a test shows; false for an act it is not.
    func windowAct(_ act: UserAct, on element: MountedElement) throws -> Bool {
        // The driver stands for the desktop: what GTK itself tells of the windows the driver moves is let go of, so
        // a test window's own focus says nothing over it.
        for controller in renderer?.windows ?? [] { Self.quiet(controller.window) }
        let tell = { (window: MountedElement, minimized: Bool, activated: Bool) in
            self.renderer?.runtime.windowStateChanged(window, minimized: minimized, activated: activated)
        }
        switch act {
        case .answer(let caption, let words):
            try renderer?.answer(caption, typing: words, over: try? window(of: element))
        case .switchAway:
            for window in renderer?.windows.compactMap(\.element) ?? [] { tell(window, false, false) }
        case .switchBack, .restore: tell(element, false, true)
        case .minimize: tell(element, true, false)
        case .bringToFront:
            for window in renderer?.windows.compactMap(\.element) ?? [] where window !== element { tell(window, false, false) }
            tell(element, false, true)
        default: return false
        }
        step()
        return true
    }
}

extension GTKDriver {
    /// Stops the window's own notices of its activity and its state reaching the host; its close still does.
    fileprivate static func quiet(_ window: GTKWindow) {
        let data = UnsafeMutableRawPointer(bitPattern: Int(window.number))
        for instance in [UnsafeMutableRawPointer(window.widget), gtk_native_get_surface(window.widget.opaque).map {
            UnsafeMutableRawPointer($0)
        }].compactMap({ $0 }) {
            g_signal_handlers_block_matched(
                instance, GSignalMatchType(rawValue: STATEUI_SIGNAL_MATCH_ID.rawValue | STATEUI_SIGNAL_MATCH_DATA.rawValue),
                g_signal_lookup("notify", g_object_get_type()), 0, nil, nil, data)
        }
    }
}

/// What the GTK host wrote to its log while a driver listened, each line also printed.
final class GTKLogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        GTKRenderer.log = HostLog(host: "GTK") { [self] line in
            lines.append(line)
            print(line, terminator: "")
        }
    }
}

extension GTKSplitView {
    /// The overlay split view GTK shows the panes in.
    private var overlay: GTKWidget? {
        GTKTestHost.descendants(of: widget).first { GTKTestHost.holds($0, adw_overlay_split_view_get_type()) }
    }

    /// Whether GTK shows the sidebar.
    var showsSidebar: Bool {
        overlay.map { adw_overlay_split_view_get_show_sidebar($0.opaque) != 0 } ?? false
    }

    /// Shows or hides the sidebar as the header's toggle does: through the split's own `show-sidebar`.
    func toggleAsUser() {
        guard let overlay else { return }
        adw_overlay_split_view_set_show_sidebar(overlay.opaque, showsSidebar ? 0 : 1)
    }
}

extension GTKTabView {
    /// Shows the tab at `place` as its switcher does: the stack's visible child.
    func choose(_ place: Int, on element: MountedElement) throws {
        guard element.children.indices.contains(place) else { throw DriverCannot(.choose(place), on: element) }
        selectByUser(place)
    }
}
