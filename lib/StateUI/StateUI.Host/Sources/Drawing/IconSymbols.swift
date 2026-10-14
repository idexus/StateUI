// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension Icon {
    /// The SF Symbol drawn for the icon - the icons Apple's platforms ship.
    /// Design: docs/design/host/layout.md#an-icon
    public var sfSymbol: String {
        switch self {
        case .add: "plus"
        case .remove: "minus"
        case .close: "xmark"
        case .checkmark: "checkmark"
        case .search: "magnifyingglass"
        case .share: "square.and.arrow.up"
        case .edit: "pencil"
        case .delete: "trash"
        case .settings: "gearshape"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .home: "house"
        case .back: "chevron.backward"
        case .forward: "chevron.forward"
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .menu: "line.3.horizontal"
        case .more: "ellipsis"
        case .refresh: "arrow.clockwise"
        case .download: "arrow.down.circle"
        case .upload: "arrow.up.circle"
        case .copy: "doc.on.doc"
        case .star: "star"
        case .heart: "heart"
        case .person: "person"
        case .mail: "envelope"
        case .calendar: "calendar"
        case .clock: "clock"
        case .lock: "lock"
        case .play: "play.fill"
        case .pause: "pause.fill"
        case .link: "link"
        }
    }
}
