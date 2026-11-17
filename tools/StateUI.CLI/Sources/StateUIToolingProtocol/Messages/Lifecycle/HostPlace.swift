// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A host this machine builds and runs heads of, and where they run.
public struct HostPlace: Codable, Equatable, Sendable {
    /// Where a host's heads run from this machine.
    public enum Place: String, Codable, Sendable {
        /// On this machine itself, as its own program: AppKit on a Mac, WinUI on Windows, GTK on Linux.
        case machine
        /// On a device, simulator or emulator chosen: UIKit's and Android's.
        case device
        /// In a browser chosen: the Web's.
        case browser
        /// In a virtual machine of this one chosen: GTK's and WinUI's on a Mac.
        case guest
    }

    public var host: HostFamily
    public var place: Place

    /// `host`'s heads, run at `place`.
    public init(host: HostFamily, place: Place) {
        self.host = host
        self.place = place
    }
}
