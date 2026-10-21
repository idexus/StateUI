// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
import CStateUIGTK

/// Each icon as its symbolic icon of the theme, by the names of the freedesktop icon naming and Adwaita - or, where
/// the theme holds none, the host's own.
/// Design: docs/design/platforms/gtk/drawing.md#icons
extension Icon {
    /// The name `theme` draws the icon by: its own symbolic icon, else the host's, put where the theme finds it.
    @MainActor
    func name(in theme: OpaquePointer?) -> String {
        guard let theme, gtk_icon_theme_has_icon(theme, themeName) == 0, let own = GTKOwnIcons.drawn[self] else {
            return themeName
        }
        GTKOwnIcons.offer(to: theme)
        return own.name
    }

    /// The theme's symbolic icon's name.
    var themeName: String {
        let name = switch self {
        case .add: "list-add"
        case .remove: "list-remove"
        case .close: "window-close"
        case .checkmark: "object-select"
        case .search: "system-search"
        case .share: "send-to"
        case .edit: "document-edit"
        case .delete: "user-trash"
        case .settings: "emblem-system"
        case .info: "dialog-information"
        case .warning: "dialog-warning"
        case .home: "go-home"
        case .back: "go-previous"
        case .forward: "go-next"
        case .up: "go-up"
        case .down: "go-down"
        case .menu: "open-menu"
        case .more: "view-more"
        case .refresh: "view-refresh"
        case .download: "folder-download"
        case .upload: "document-send"
        case .copy: "edit-copy"
        case .star: "starred"
        case .heart: "emblem-favorite"
        case .person: "avatar-default"
        case .mail: "mail-unread"
        case .calendar: "x-office-calendar"
        case .clock: "preferences-system-time"
        case .lock: "changes-prevent"
        case .play: "media-playback-start"
        case .pause: "media-playback-pause"
        case .link: "insert-link"
        }
        return name + "-symbolic"
    }
}

/// The icons the host brings where a theme holds none of its own - a heart, which Adwaita no longer draws - as GNOME's
/// applications bring theirs: each a symbolic SVG, filled in the color GTK draws it in.
/// Design: docs/design/platforms/gtk/drawing.md#icons
@MainActor
enum GTKOwnIcons {
    /// Each icon the host draws, by its name and its drawing - StateUI's own, as the Web's.
    static let drawn: [Icon: (name: String, svg: String)] = [
        .heart: ("stateui-heart-symbolic", """
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">\
            <path fill="#2e3436" d="M12 20s-7-4.4-9-9a4.8 4.8 0 0 1 9-3 4.8 4.8 0 0 1 9 3c-2 4.6-9 9-9 9z"/></svg>
            """),
    ]

    /// The themes the icons were put where they find them.
    private static var offered: Set<OpaquePointer> = []

    /// Writes the host's icons to a folder of the user's runtime directory, once, and puts it on `theme`'s path.
    static func offer(to theme: OpaquePointer) {
        guard offered.insert(theme).inserted else { return }
        g_mkdir_with_parents(folder, 0o700)
        for (name, svg) in drawn.values {
            g_file_set_contents(folder + "/" + name + ".svg", svg, -1, nil)
        }
        gtk_icon_theme_add_search_path(theme, folder)
    }

    /// Where the icons are written.
    private static let folder = String(cString: g_get_user_runtime_dir()) + "/stateui-icons"
}
