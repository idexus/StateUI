// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What AppKit keeps of one scene for the system's window restoration: the identifier its windows are restored by -
/// its main window's - the values it keeps for its next start, and its main window, where the system restored it
/// before the scene came.
/// Design: docs/design/platforms/appkit/runtime.md#restored-windows
@MainActor
final class AppKitSceneSession {
    /// The identifier the scene's windows are restored by: its main window's, once it has one.
    private(set) var identifier: String?

    /// The values the scene keeps for its next start.
    private(set) var kept: [String: HostValue]

    private var restoredMain: AppKitRestoredWindow?

    init(restoredMain: AppKitRestoredWindow?) {
        self.restoredMain = restoredMain
        identifier = restoredMain?.record.windowIdentifier
        kept = restoredMain?.record.kept ?? [:]
    }

    /// The window `element` of this scene comes: the one the system restored for it where there is one, and the
    /// record it is kept by. The main window names the scene.
    func arrival(
        of element: MountedElement, restoredOwned: (_ owner: String) -> AppKitRestoredWindow?
    ) -> (record: AppKitRestorationRecord, window: NSWindow?) {
        let isMain = element.isMainWindow
        let restored: AppKitRestoredWindow?
        if isMain {
            restored = restoredMain
            restoredMain = nil
        } else {
            restored = identifier.flatMap(restoredOwned)
        }

        let windowIdentifier = restored?.record.windowIdentifier ?? UUID().uuidString
        if isMain { identifier = windowIdentifier }
        let record = restored?.record ?? AppKitRestorationRecord(
            windowIdentifier: windowIdentifier,
            ownerIdentifier: isMain ? nil : identifier,
            kind: element.name(.windowType),
            value: element.string(.windowValue),
            kept: isMain ? kept : [:])
        return (record, restored?.window)
    }

    /// The scene keeps `value` under `name` for its next start.
    func keep(name: String, value: HostValue) {
        kept[name] = value
    }
}

#endif
