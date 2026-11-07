// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Semantic menu keys are shared across parents; the nodes, never this cache, own their authored values.
// Design: docs/design/core/identity-and-diffing.md#menu-identities
@MainActor
final class MenuKeys {
    final class Key {
        let identity: ElementIdentity
        let host: HostMenuKey

        init(identity: ElementIdentity, host: HostMenuKey) {
            self.identity = identity
            self.host = host
        }
    }

    private struct Weak {
        weak var key: Key?
    }

    private var buckets: [Int: [Weak]] = [:]
    private var next = 1

    func key(for identity: ElementIdentity) -> Key {
        var bucket = buckets[identity.number, default: []].filter { $0.key != nil }
        if let existing = bucket.compactMap(\.key).first(where: { $0.identity == identity }) { return existing }

        let host: HostMenuKey
        if let name = identity.value.base as? String {
            host = .name(name)
        } else if let platform = identity.value.base as? PlatformMenu {
            host = .standard(platform.menu)
        } else {
            host = .value(next)
            next += 1
        }
        let made = Key(identity: identity, host: host)
        bucket.append(Weak(key: made))
        buckets[identity.number] = bucket
        return made
    }

    func prune() {
        guard !buckets.isEmpty else { return }
        buckets = buckets.compactMapValues { bucket in
            let live = bucket.filter { $0.key != nil }
            return live.isEmpty ? nil : live
        }
    }
}
