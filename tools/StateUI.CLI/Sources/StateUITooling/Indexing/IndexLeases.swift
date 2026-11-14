// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Synchronization

/// The host each package is indexed as by the connections of this machine: a connection holds, its life long, a lock
/// the system keeps on a file of the package and the host in the user's state folder. A package holds one language
/// server configuration, so connections share it only as one host.
/// Design: docs/design/tooling/indexing.md#two-windows-on-one-package
public final class IndexLeases: Sendable {
    private let folder: URL
    private let held = Mutex<[(file: URL, lock: Lock)]>([])

    /// The leases kept in `folder`: the user's state folder's `index-leases` unless given.
    public init(folder: URL = BuildPermit.userFolder.appendingPathComponent("index-leases")) {
        self.folder = folder
    }

    deinit {
        drop(held.withLock { held in defer { held = [] }; return held })
    }

    /// Holds `roots` as `host` in place of what this connection held - or answers the first root another living
    /// connection holds as another host, keeping what it held. A lease whose connection ended is taken away.
    public func acquire(_ host: HostFamily?, roots: [URL]) async throws -> IndexLease {
        let name = host?.rawValue ?? "plain"
        var seen = Set<String>()
        let places = roots.map { (root: $0, place: folder.appendingPathComponent(BuildContext.digest(RealPath.of($0).path))) }
            .filter { seen.insert($0.place.path).inserted }
        let guards = try await places.map(\.place).sorted { $0.path < $1.path }.asyncMap(guarded)
        defer { guards.forEach { $0.close() } }
        let own = Set(held.withLock { $0.map(\.file.path) })
        for (root, place) in places {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: place.path)) ?? []
            for file in files.sorted() where file.hasSuffix(".lock") && !own.contains(place.appendingPathComponent(file).path) {
                let other = String(file.prefix { $0 != "-" })
                guard other != name else { continue }
                guard let stale = try Lock(file: place.appendingPathComponent(file)) else {
                    return IndexLease(host: host, rootUris: [], conflict: IndexConflict(rootUri: FileURI.string(root), host: HostFamily(rawValue: other)))
                }
                stale.close()
                try? FileManager.default.removeItem(at: place.appendingPathComponent(file))
            }
        }
        let taken = try places.map { _, place in
            let file = place.appendingPathComponent("\(name)-\(UUID().uuidString).lock")
            guard let lock = try Lock(file: file) else { throw ToolingError(.internalError, "\(file.path) is locked as it is made.") }
            return (file: file, lock: lock)
        }
        drop(held.withLock { held in defer { held = taken }; return held })
        return IndexLease(host: host, rootUris: roots.map(FileURI.string))
    }

    /// The lock of `place`'s guard, waited for: the one connection at a time that reads and writes its leases.
    private func guarded(_ place: URL) async throws -> Lock {
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        while true {
            if let lock = try Lock(file: place.appendingPathExtension("guard")) { return lock }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func drop(_ leases: [(file: URL, lock: Lock)]) {
        for lease in leases {
            lease.lock.close()
            try? FileManager.default.removeItem(at: lease.file)
        }
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var mapped: [T] = []
        for element in self { mapped.append(try await transform(element)) }
        return mapped
    }
}
