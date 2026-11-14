// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which families a conformance run takes, whole - written `{"changed": true}`, `{"families": [...]}` or
/// `{"all": true}`.
public enum ConformanceSelection: Codable, Equatable, Sendable {
    /// The families whose recorded verdicts stand at another revision, or at none.
    case changed
    case families([String])
    case all

    private enum Key: String, CodingKey {
        case changed, families, all
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        if let families = try container.decodeIfPresent([String].self, forKey: .families) {
            self = .families(families)
        } else if try container.decodeIfPresent(Bool.self, forKey: .all) == true {
            self = .all
        } else if try container.decodeIfPresent(Bool.self, forKey: .changed) == true {
            self = .changed
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath, debugDescription: "A selection is changed, families or all."))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .changed: try container.encode(true, forKey: .changed)
        case .families(let names): try container.encode(names, forKey: .families)
        case .all: try container.encode(true, forKey: .all)
        }
    }
}

/// A host's conformance families run, held or recorded: `repository/conformance`'s parameters.
public struct ConformanceRequest: Codable, Equatable, Sendable {
    public var host: HostFamily
    public var selection: ConformanceSelection
    /// Whether the verdicts are written and the documents rendered, instead of held.
    public var record: Bool
    /// UIKit's simulator, or Android's device or emulator, by name or id.
    public var device: String?

    /// `host`'s families `selection` takes, recorded where `record`, on `device`.
    public init(host: HostFamily, selection: ConformanceSelection, record: Bool, device: String? = nil) {
        self.host = host
        self.selection = selection
        self.record = record
        self.device = device
    }
}
