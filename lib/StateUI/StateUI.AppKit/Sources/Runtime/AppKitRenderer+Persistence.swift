// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Kept values in the preferences: read before the first render, each written as it changes, as the words every
/// host keeps a value by.
/// Design: docs/design/host/runtime.md#kept-values
extension AppKitRenderer {
    func hydratePersistentState() {
        let keys = runtime.core.persistentKeys
        let words = Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            preferences.string(forKey: key.name).map { (key.name, $0) }
        })
        runtime.core.restorePersistent(KeptWord.restored(words, for: keys))
    }

    func savePersistent(_ call: HostActCall) {
        guard let kept = KeptWord.kept(call.arguments, keys: runtime.core.persistentKeys) else { return }
        preferences.set(kept.word, forKey: kept.name)
    }
}
#endif
