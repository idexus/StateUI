// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Kept values: read from the preferences before the first render, and saved.
extension AppKitRenderer {
    func hydratePersistentState() {
        var restored: [String: HostValue] = [:]

        for key in core.persistentKeys {
            guard preferences.object(forKey: key.name) != nil else { continue }

            switch key.kind {
            case .boolean:
                restored[key.name] = .bool(preferences.bool(forKey: key.name))
            case .integer, .number:
                restored[key.name] = .number(preferences.double(forKey: key.name))
            case .text:
                if let value = preferences.string(forKey: key.name) {
                    restored[key.name] = .string(value)
                }
            }
        }

        core.restorePersistent(restored)
    }

    func savePersistent(_ call: HostActCall) {
        guard call.arguments.count >= 2,
              let name = call.arguments[0].name,
              let key = core.persistentKeys.first(where: { $0.name == name })
        else { return }

        let value = call.arguments[1]
        switch key.kind {
        case .boolean:
            if let value = value.bool { preferences.set(value, forKey: name) }
        case .integer:
            if let value = value.number { preferences.set(Int64(value), forKey: name) }
        case .number:
            if let value = value.number { preferences.set(value, forKey: name) }
        case .text:
            if let value = value.string { preferences.set(value, forKey: name) }
        }
    }
}
#endif
