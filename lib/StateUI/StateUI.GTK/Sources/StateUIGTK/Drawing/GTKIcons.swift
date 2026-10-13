// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// Each icon as its symbolic icon of the theme, by the names of the freedesktop icon naming and Adwaita.
/// Design: docs/design/platforms/gtk/drawing.md#icons
extension Icon {
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
