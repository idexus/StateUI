// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Everything an `ItemsView` shows, in order, each named by its identity: the
/// list's header and footer, and each section's header, footer and items. A
/// list with no groups is one section with neither.
///
/// The ItemsView writes it; a host holds each identity in a cell of its own
/// and asks for the subtree of the ones it holds.
/// Design: docs/design/views/items.md#identities-in-order
public struct ItemsEntries: Equatable, Sendable, HostRepresentable {
    /// One group of items, with the header and the footer it has.
    public struct Section: Equatable, Sendable {
        /// The header's identity, where the group has one.
        public let header: String?

        /// The footer's identity, where the group has one.
        public let footer: String?

        /// Its items' identities, in order.
        public let items: [String]

        /// A group of `items`, with a header and a footer where they are named.
        public init(header: String? = nil, footer: String? = nil, items: [String]) {
            self.header = header
            self.footer = footer
            self.items = items
        }
    }

    /// The list's own header's identity, where it has one.
    public let header: String?

    /// The list's own footer's identity, where it has one.
    public let footer: String?

    /// The groups, in order.
    public let sections: [Section]

    /// A list of `sections` under a header and over a footer where they are
    /// named.
    public init(header: String? = nil, footer: String? = nil, sections: [Section]) {
        self.header = header
        self.footer = footer
        self.sections = sections
    }

    /// Whether it holds no item - a header or a footer is none.
    public var isEmpty: Bool {
        sections.allSatisfy { $0.items.isEmpty }
    }

    /// Every identity in the order it shows: the header, each section's header,
    /// items and footer, then the footer.
    public var identities: [String] {
        var all = header.map { [$0] } ?? []
        for section in sections {
            if let header = section.header { all.append(header) }
            all += section.items
            if let footer = section.footer { all.append(footer) }
        }
        if let footer { all.append(footer) }
        return all
    }

    /// The header and footer, each named or nothing, then each section the
    /// same way with its items.
    public var propValue: PropValue {
        .values([
            Self.named(header), Self.named(footer),
            .values(sections.map { .values([Self.named($0.header), Self.named($0.footer), .strings($0.items)]) }),
        ])
    }

    /// The entries the parts name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 3,
              let header = Self.identity(parts[0]), let footer = Self.identity(parts[1]),
              case .values(let written) = parts[2]
        else { return nil }

        var sections: [Section] = []
        for section in written {
            guard case .values(let parts) = section, parts.count == 3,
                  let header = Self.identity(parts[0]), let footer = Self.identity(parts[1]),
                  case .strings(let items) = parts[2]
            else { return nil }
            sections.append(Section(header: header, footer: footer, items: items))
        }
        self.init(header: header, footer: footer, sections: sections)
    }

    /// An identity as it crosses: its text, or nothing.
    private static func named(_ identity: String?) -> PropValue {
        identity.map { .string($0) } ?? .nothing
    }

    /// An identity read back - itself or none - and nil where the part is neither.
    private static func identity(_ part: PropValue) -> String?? {
        switch part {
        case .string(let identity): identity
        case .nothing: .some(nil)
        default: nil
        }
    }
}
