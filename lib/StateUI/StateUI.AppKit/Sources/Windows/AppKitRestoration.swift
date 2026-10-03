// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Hands each window AppKit restores to the renderer that stands - the system restores before the application
/// finishes launching, through a class.
/// Design: docs/design/platforms/appkit/runtime.md#restored-windows
@MainActor
final class AppKitRestorationBroker {
    static let shared = AppKitRestorationBroker()
    weak var host: AppKitRenderer?

    private init() {}

    func restore(_ record: WindowRecord) -> NSWindow? {
        host?.acceptRestoredWindow(record)
    }
}

/// Restores a window AppKit kept: its record, read from the text the window wrote, handed to the renderer.
@MainActor
final class AppKitWindowRestorer: NSObject, NSWindowRestoration {
    static let recordKey = "StateUI.RestorationRecord"

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        guard let text = state.decodeObject(of: NSString.self, forKey: recordKey) as String?,
              let record = WindowRecord(text),
              record.identifier == identifier.rawValue,
              let window = AppKitRestorationBroker.shared.restore(record)
        else {
            completionHandler(nil, nil)
            return
        }

        completionHandler(window, nil)
    }
}

#endif
