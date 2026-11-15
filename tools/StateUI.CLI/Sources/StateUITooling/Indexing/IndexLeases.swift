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
        let places = places(of: roots)
        let guards = try await places.map(\.place).sorted { $0.path < $1.path }.asyncMap(guarded)
        defer { guards.forEach { $0.close() } }
        let own = Set(held.withLock { $0.map(\.file.path) })
        for (root, place) in places {
            if let other = try holder(in: place, besides: own, sharing: name) {
                return IndexLease(host: host, rootUris: [], conflict: IndexConflict(rootUri: FileURI.string(root), host: HostFamily(rawValue: other)))
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

    /// Runs `clean` on the roots of `roots` no other living connection holds, as any host - what this connection
    /// holds is its own - and answers what it removed with the roots left, each with the host it is held as. A root
    /// is its package by whatever path names it, and each package's guard is held until `clean` returns: no
    /// connection takes one as it is cleaned. A lease whose connection ended is taken away.
    public func cleaning(
        _ roots: [URL], _ clean: ([URL]) -> [URL]
    ) async throws -> (removed: [URL], conflicts: [IndexConflict]) {
        let guards = try await places(of: roots).map(\.place).sorted { $0.path < $1.path }.asyncMap(guarded)
        defer { guards.forEach { $0.close() } }
        let own = Set(held.withLock { $0.map(\.file.path) })
        var free: [URL] = []
        var conflicts: [IndexConflict] = []
        for root in roots {
            if let other = try holder(in: place(of: root), besides: own, sharing: nil) {
                conflicts.append(IndexConflict(rootUri: FileURI.string(root), host: HostFamily(rawValue: other)))
            } else {
                free.append(root)
            }
        }
        return (clean(free), conflicts)
    }

    /// Each package of `roots` once, with the folder of its leases.
    private func places(of roots: [URL]) -> [(root: URL, place: URL)] {
        var seen = Set<String>()
        return roots.map { (root: $0, place: place(of: $0)) }.filter { seen.insert($0.place.path).inserted }
    }

    /// The folder of the leases of `root`'s package: one for every path that names it.
    private func place(of root: URL) -> URL {
        folder.appendingPathComponent(BuildContext.digest(RealPath.of(root).path))
    }

    /// The host of a lease in `place` another living connection holds - not `own`, and not one as `sharing` - each
    /// lease whose connection ended taken away; the guard of `place` held.
    private func holder(in place: URL, besides own: Set<String>, sharing name: String?) throws -> String? {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: place.path)) ?? []
        for file in files.sorted() where file.hasSuffix(".lock") && !own.contains(place.appendingPathComponent(file).path) {
            let other = String(file.prefix { $0 != "-" })
            guard other != name else { continue }
            guard let stale = try Lock(file: place.appendingPathComponent(file)) else { return other }
            stale.close()
            try? FileManager.default.removeItem(at: place.appendingPathComponent(file))
        }
        return nil
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
