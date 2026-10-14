// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web's icons: a browser ships none, so StateUI draws its own - one stroke on a 24-point square for each
/// `Icon`, worn as a mask over the colour of the words around it.
/// Design: docs/design/platforms/web/controls.md#icons
enum WebIcons {
    /// The icon's drawing as an SVG document, black on nothing - a mask takes its shape alone.
    static func svg(_ icon: Icon) -> String {
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' "
            + "stroke-linecap='round' stroke-linejoin='round'>" + drawing(icon) + "</svg>"
    }

    /// A drawing of nothing, 24 points square: what an icon's picture stands at.
    static let room = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24'/%3E"

    /// The icon's drawing as a URL CSS reads.
    static func url(_ icon: Icon) -> String {
        "url(\"data:image/svg+xml," + svg(icon).replacing("<", with: "%3C").replacing(">", with: "%3E") + "\")"
    }

    private static func drawing(_ icon: Icon) -> String {
        switch icon {
        case .add: "<path d='M12 5v14M5 12h14'/>"
        case .remove: "<path d='M5 12h14'/>"
        case .close: "<path d='M6 6l12 12M18 6L6 18'/>"
        case .checkmark: "<path d='M5 12.5l4.5 4.5L19 7.5'/>"
        case .search: "<circle cx='10.5' cy='10.5' r='6'/><path d='M15 15l5 5'/>"
        case .share: "<path d='M12 3v12M8 7l4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7'/>"
        case .edit: "<path d='M4 20h4L19 9l-4-4L4 16zM13 7l4 4'/>"
        case .delete: "<path d='M4 7h16M10 3h4M6 7l1 13h10l1-13M10 11v6M14 11v6'/>"
        case .settings:
            "<circle cx='12' cy='12' r='3'/><path d='M19.3 10L21.9 10.4V13.6L19.3 14L18.6 15.8L20.1 17.9L17.9 20.1"
                + "L15.8 18.6L14 19.3L13.6 21.9H10.4L10 19.3L8.2 18.6L6.1 20.1L3.9 17.9L5.4 15.8L4.7 14L2.1 13.6V10.4"
                + "L4.7 10L5.4 8.2L3.9 6.1L6.1 3.9L8.2 5.4L10 4.7L10.4 2.1H13.6L14 4.7L15.8 5.4L17.9 3.9L20.1 6.1"
                + "L18.6 8.2Z'/>"
        case .info: "<circle cx='12' cy='12' r='9'/><path d='M12 11v6M12 7.5v.5'/>"
        case .warning: "<path d='M12 3L2 20h20zM12 10v4M12 17v.5'/>"
        case .home: "<path d='M3 11l9-8 9 8M5 9.5V20h5v-6h4v6h5V9.5'/>"
        case .back: "<path d='M15 5l-7 7 7 7'/>"
        case .forward: "<path d='M9 5l7 7-7 7'/>"
        case .up: "<path d='M5 15l7-7 7 7'/>"
        case .down: "<path d='M5 9l7 7 7-7'/>"
        case .menu: "<path d='M4 6h16M4 12h16M4 18h16'/>"
        case .more: "<path d='M5 12h.01M12 12h.01M19 12h.01' stroke-width='3.5'/>"
        case .refresh: "<path d='M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5'/>"
        case .download: "<path d='M12 4v11M7 10l5 5 5-5M5 20h14'/>"
        case .upload: "<path d='M12 16V5M7 10l5-5 5 5M5 20h14'/>"
        case .copy:
            "<rect x='8' y='8' width='12' height='12' rx='2'/>"
                + "<path d='M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2'/>"
        case .star: "<path d='M12 3l2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9z'/>"
        case .heart: "<path d='M12 20s-7-4.4-9-9a4.8 4.8 0 0 1 9-3 4.8 4.8 0 0 1 9 3c-2 4.6-9 9-9 9z'/>"
        case .person: "<circle cx='12' cy='8' r='4'/><path d='M4 21a8 8 0 0 1 16 0'/>"
        case .mail: "<rect x='3' y='5' width='18' height='14' rx='2'/><path d='M3 7l9 6 9-6'/>"
        case .calendar: "<rect x='3' y='5' width='18' height='16' rx='2'/><path d='M3 10h18M8 3v4M16 3v4'/>"
        case .clock: "<circle cx='12' cy='12' r='9'/><path d='M12 7v5l3 3'/>"
        case .lock: "<rect x='5' y='11' width='14' height='10' rx='2'/><path d='M8 11V7a4 4 0 0 1 8 0v4'/>"
        case .play: "<path d='M8 5v14l11-7z' fill='black'/>"
        case .pause: "<path d='M8 5v14M16 5v14' stroke-width='3'/>"
        case .link:
            "<path d='M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3"
                + "a4 4 0 0 0 5.7 5.7l1-1'/>"
        }
    }
}
