// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// GTK's part of the acts every host performs (`HostActPerformer`): the clock and the zones as GLib has them, a
/// question in libadwaita's alert dialog over the window the user is in, a word to the screen reader, the focus, a
/// value kept, a list scrolled to an item, and the application's own acts.
/// Design: docs/design/host/runtime.md#acts
@MainActor
final class GTKActToolkit: ActToolkit {
    private unowned let renderer: GTKRenderer

    init(renderer: GTKRenderer) {
        Self.announced = []
        self.renderer = renderer
    }

    let host = "GTK"

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) {
        let now = g_date_time_new_now_local()!
        defer { g_date_time_unref(now) }
        return (
            Int(g_date_time_get_hour(now)), Int(g_date_time_get_minute(now)), Int(g_date_time_get_second(now)),
            Int(g_date_time_get_microsecond(now) / 1000))
    }

    func localZone() -> String {
        let zone = g_time_zone_new_local()!
        defer { g_time_zone_unref(zone) }
        return String(cString: g_time_zone_get_identifier(zone))
    }

    /// Taken at the day's noon; nil for a zone GLib does not know, or no such day.
    func utcOffset(of name: String?, on day: CalendarDate?) -> Int? {
        guard let zone = name.map({ g_time_zone_new_identifier($0) }) ?? g_time_zone_new_local() else { return nil }
        defer { g_time_zone_unref(zone) }

        let today = g_date_time_new_now(zone)!
        let noon = g_date_time_new(
            zone, Int32(day?.year ?? Int(g_date_time_get_year(today))),
            Int32(day?.month ?? Int(g_date_time_get_month(today))),
            Int32(day?.day ?? Int(g_date_time_get_day_of_month(today))), 12, 0, 0)
        g_date_time_unref(today)
        guard let noon else { return nil }
        defer { g_date_time_unref(noon) }
        return Int(g_date_time_get_utc_offset(noon) / 60_000_000)
    }

    /// Design: docs/design/platforms/gtk/runtime.md#questions-for-the-user
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        guard let window = renderer.userWindow else { return false }
        GTKQuestion(question, answered: answered).show(over: window)
        return true
    }

    func announce(_ words: String) {
        Self.announced.append(words)
        guard let window = renderer.userWindow, Self.reachesAScreenReader(window.widget) else { return }
        gtk_accessible_announce(window.widget.opaque, words, GTK_ACCESSIBLE_ANNOUNCEMENT_PRIORITY_MEDIUM)
    }

    /// The keyboard GNOME shows on a touch screen stands for the field holding the focus: the field lets the focus
    /// go, and the keyboard goes down. Whether a field held it.
    func hideOnScreenKeyboard() -> Bool {
        guard let window = renderer.userWindow, let root = gtk_widget_get_root(window.widget),
              let held = gtk_root_get_focus(root),
              [gtk_text_get_type(), gtk_text_view_get_type()].contains(where: {
                  g_type_check_instance_is_a(held.of(GTypeInstance.self), $0) != 0
              })
        else { return false }
        gtk_root_set_focus(root, nil)
        return true
    }

    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? GTKElement)?.view else { return nil }
        return gtk_widget_grab_focus(view.widget) != 0
    }

    /// GTK leaves the focus nowhere.
    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? GTKElement)?.view else { return false }
        if let root = gtk_widget_get_root(view.widget), let focus = gtk_root_get_focus(root),
           focus == view.widget || gtk_widget_is_ancestor(focus, view.widget) != 0 {
            gtk_root_set_focus(root, nil)
        }
        return true
    }

    func keep(_ call: HostActCall) -> Bool {
        switch call.act {
        case .persistValue:
            GTKKeptValues.keep(call, core: renderer.runtime.core, applicationID: renderer.applicationID)
        case .persistSceneValue:
            let scenes = renderer.scenes
            if scenes.keep(call.arguments), let text = scenes.changed(root: renderer.runtime.tree.root) {
                GTKKeptValues.writeScenes(text, applicationID: renderer.applicationID)
            }
        default:
            return false
        }
        return true
    }

    /// An ItemsView's scroll to an item.
    func performOwn(_ call: HostActCall) -> Bool {
        guard call.act == .scrollTo else { return false }
        let core = renderer.runtime.core
        do {
            let element = try renderer.runtime.tree.aimed(call)
            guard let items = (element.native as? GTKElement)?.view as? GTKItemsView else {
                core.fail(call, "scrollTo is an act of an ItemsView", log: log)
                return true
            }
            items.scroll(
                to: call.arguments.value(1)?.string ?? "",
                anchor: call.arguments.value(2).flatMap(ScrollAnchor.init(propValue:)) ?? .nearest)
            core.reply(call, [])
        } catch {
            core.fail(call, error.reason, log: log)
        }
        return true
    }

    /// An act the application registered: its own, or one aimed at its own element.
    func performRegistered(_ call: HostActCall) -> Bool {
        GTKInterop.acts.perform(
            call, in: renderer.runtime.tree, core: renderer.runtime.core, view: { ($0.native as? GTKElement)?.view },
            log: log)
    }

    func log(_ message: String) {
        GTKRenderer.log.error(message)
    }
}

extension GTKActToolkit {
    /// Whether what `widget` announces reaches a screen reader: through GTK's AT-SPI context alone. Without the
    /// accessibility bus GTK stands a context of no assistive technology, which GTK 4.14 announces through a call it
    /// lacks - a crash.
    /// Design: docs/design/platforms/gtk/controls.md#what-assistive-technology-meets
    /// What the host asked GTK to announce, in order, since it started.
    private(set) static var announced: [String] = []

    static func reachesAScreenReader(_ widget: GTKWidget) -> Bool {
        let atSpi = g_type_from_name("GtkAtSpiContext")
        guard atSpi != 0, let context = gtk_accessible_get_at_context(widget.opaque) else { return false }
        defer { g_object_unref(UnsafeMutableRawPointer(context)) }
        return g_type_check_instance_is_a(UnsafeMutablePointer<GTypeInstance>(context), atSpi) != 0
    }
}
