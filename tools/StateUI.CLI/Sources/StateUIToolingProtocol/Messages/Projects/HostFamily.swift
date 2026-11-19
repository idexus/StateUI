// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A native host family: the platform toolkit an application's head runs on.
public enum HostFamily: String, Codable, Sendable, CaseIterable, Comparable {
    /// The Mac.
    case appkit
    /// iPhone and iPad.
    case uikit
    /// Android's views.
    case android
    /// Windows.
    case winui
    /// GTK with libadwaita on Linux.
    case gtk
    /// A browser's page.
    case web

    /// Hosts in the order every host list keeps.
    public static func < (left: HostFamily, right: HostFamily) -> Bool {
        allCases.firstIndex(of: left)! < allCases.firstIndex(of: right)!
    }

    /// The host's name in a head's folder, a compilation condition's root, a product's suffix and the package trait a
    /// build for it enables: `AppKit`.
    public var folder: String {
        switch self {
        case .appkit: "AppKit"
        case .uikit: "UIKit"
        case .android: "Android"
        case .winui: "WinUI"
        case .gtk: "GTK"
        case .web: "Web"
        }
    }
}
