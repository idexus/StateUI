// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The platform identity and StateUI ownership needed to restore one window.
///
/// A main window has no owner and keeps its scene values. Every other window
/// names the main window it belongs to, plus its StateUI group and value. The
/// platform identity is intentionally separate from `ElementId`: StateUI ids
/// are deterministic inside one process, while AppKit ids survive relaunch.
struct AppKitRestorationRecord: Equatable, Sendable {
    let windowIdentifier: String
    let ownerIdentifier: String?
    let kind: String?
    let value: String?
    var kept: [String: HostValue]

    init(
        windowIdentifier: String,
        ownerIdentifier: String? = nil,
        kind: String? = nil,
        value: String? = nil,
        kept: [String: HostValue] = [:]
    ) {
        self.windowIdentifier = windowIdentifier
        self.ownerIdentifier = ownerIdentifier
        self.kind = kind
        self.value = value
        self.kept = kept
    }

    init(data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.version == Payload.currentVersion else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "unsupported StateUI AppKit restoration version"))
        }

        windowIdentifier = payload.windowIdentifier
        ownerIdentifier = payload.ownerIdentifier
        kind = payload.kind
        value = payload.value
        kept = payload.kept.mapValues(\.hostValue)
    }

    func data() throws -> Data {
        var stored: [String: StoredValue] = [:]

        for (name, value) in kept {
            guard let value = StoredValue(value) else { continue }
            stored[name] = value
        }

        return try JSONEncoder().encode(Payload(
            version: Payload.currentVersion,
            windowIdentifier: windowIdentifier,
            ownerIdentifier: ownerIdentifier,
            kind: kind,
            value: value,
            kept: stored))
    }

    private struct Payload: Codable {
        static let currentVersion = 1

        let version: Int
        let windowIdentifier: String
        let ownerIdentifier: String?
        let kind: String?
        let value: String?
        let kept: [String: StoredValue]
    }

    private enum StoredValue: Codable {
        case bool(Bool)
        case number(Double)
        case string(String)

        init?(_ value: HostValue) {
            switch value {
            case .bool(let value): self = .bool(value)
            case .number(let value): self = .number(value)
            case .string(let value): self = .string(value)
            default: return nil
            }
        }

        var hostValue: HostValue {
            switch self {
            case .bool(let value): .bool(value)
            case .number(let value): .number(value)
            case .string(let value): .string(value)
            }
        }
    }
}

/// Restored windows waiting for the deterministic StateUI tree to claim them.
/// AppKit makes no ordering promise, so an owned window may arrive first.
final class AppKitRestorationQueue {
    private var records: [AppKitRestorationRecord] = []

    var isEmpty: Bool { records.isEmpty }
    var hasMain: Bool { records.contains { $0.ownerIdentifier == nil } }
    var all: [AppKitRestorationRecord] { records }

    func append(_ record: AppKitRestorationRecord) {
        guard !records.contains(where: { $0.windowIdentifier == record.windowIdentifier }) else {
            return
        }

        records.append(record)
    }

    func takeMain() -> AppKitRestorationRecord? {
        take { $0.ownerIdentifier == nil }
    }

    func takeOwned(by owner: String, kind: String?, value: String?) -> AppKitRestorationRecord? {
        take { record in
            record.ownerIdentifier == owner && record.kind == kind && record.value == value
        }
    }

    func owned(by owner: String) -> [AppKitRestorationRecord] {
        records.filter { $0.ownerIdentifier == owner }
    }

    func remove(windowIdentifier: String) -> AppKitRestorationRecord? {
        take { $0.windowIdentifier == windowIdentifier }
    }

    private func take(
        where matches: (AppKitRestorationRecord) -> Bool
    ) -> AppKitRestorationRecord? {
        guard let index = records.firstIndex(where: matches) else { return nil }
        return records.remove(at: index)
    }
}

@MainActor
struct AppKitRestoredWindow {
    let record: AppKitRestorationRecord
    let window: NSWindow
}

@MainActor
final class AppKitRestorationBroker {
    static let shared = AppKitRestorationBroker()
    weak var host: AppKitRenderer?

    private init() {}

    func restore(_ record: AppKitRestorationRecord) -> NSWindow? {
        host?.acceptRestoredWindow(record)
    }
}

@MainActor
final class AppKitWindowRestorer: NSObject, NSWindowRestoration {
    static let recordKey = "StateUI.RestorationRecord"

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        guard let data = state.decodeObject(of: NSData.self, forKey: recordKey) as Data? else {
            completionHandler(nil, nil)
            return
        }

        do {
            let record = try AppKitRestorationRecord(data: data)
            guard record.windowIdentifier == identifier.rawValue,
                  let window = AppKitRestorationBroker.shared.restore(record)
            else {
                completionHandler(nil, nil)
                return
            }

            completionHandler(window, nil)
        } catch {
            NSLog("StateUI AppKit: ignored an unreadable restoration record: %@", String(describing: error))
            completionHandler(nil, nil)
        }
    }
}

#endif
