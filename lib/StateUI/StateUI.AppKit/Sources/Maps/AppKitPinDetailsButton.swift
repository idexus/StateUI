// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIApple

/// The button a marker's callout shows for its details: a click on it is heard on the marker.
@MainActor
final class AppKitPinDetailsButton: NSButton {
    weak var pin: MapKitMarker?
}
#endif
