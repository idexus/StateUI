// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The control dictionary - docs/controls - as the library's contracts and the
// hosts' declarations say it is. A page per element contract and per tier,
// rendered whole: the contract's doc, what it wears, and a row per member with
// its kind, its value, its layer and a mark for every host. The index and the
// platform contract are written by hand around the tables rendered here, which
// stand between `<!-- name:begin -->` and `<!-- name:end -->`.
//
// A host's column comes from its RUNTIME wherever it can: each host's suite
// writes what its registrations realize to `exports/<host>.txt`, read here and
// joined with the contracts, so each member is named under the contract
// declaring it and no owner is typed by hand. What a registry cannot know stays
// written - every judgement: what a realization is missing, what a host
// realizes none of, and what it presents with no view of its own.
//
// The rest is read as text: `AppKitRealization` and `AndroidRealization`; the
// doc comments over the contracts and over `ElementLayer`'s cases; the platform
// contract's "Native control mapping", the one hand-written input; and, from
// the sources declaring them, the `on…` modifiers events are heard through.

import Foundation
@_spi(Host) @testable import StateUI

/// What an event carries, read off its declaration.
fileprivate protocol EventShape {
    var payloadType: Any.Type { get }
}

extension ElementEvent: EventShape {
    fileprivate var payloadType: Any.Type { Payload.self }
}

/// What an act takes and what it answers, read off its declaration.
fileprivate protocol ActShape {
    var argumentsType: Any.Type { get }
    var answerType: Any.Type { get }
}

extension ElementAct: ActShape {
    fileprivate var argumentsType: Any.Type { Arguments.self }
    fileprivate var answerType: Any.Type { Answer.self }
}

/// docs/controls as the contracts and the hosts' declarations say it is.
struct ControlDictionary {
    /// Every host the matrix has a column for, in the columns' order.
    static let platforms = ["AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"]

    /// What a mark means.
    static let legend = "✅ realized by that host and covered by its tests · ☑️ realized and tested, but "
        + "incomplete - the note says what is missing · – not planned for that host's family, which meets the "
        + "contract there - the note says why · empty: absent, partial and unverified, or not looked at yet"

    /// The line over every page: that it is rendered, and how it is rendered again.
    static let rendered = "<!-- Rendered by ControlDictionaryTests from the contracts, each host's export of what "
        + "its runtime realizes, and what is still declared by hand: STATEUI_UPDATE_DOCS=1 swift test --filter "
        + "ControlDictionaryTests writes it again. -->"

    /// The sources outside Views/ that declare an element's `on…` modifiers.
    static let modifierSources: Set<String> = [
        "SceneElement.swift", "ApplicationSession.swift", "SceneSession.swift", "WindowSession.swift", "PageSession.swift",
    ]

    /// A document the dictionary needs and cannot read as it expects.
    struct Unreadable: Error, CustomStringConvertible {
        let description: String
    }

    /// One host's declaration of what it realizes, read out of its source: its marks, by the host layer's rule.
    struct Declaration {
        typealias Record = HostRecord
        typealias Judgement = HostRecord.Judgement

        /// The host, as its column is headed.
        let host: String

        /// Where the declaration is written, under the repository.
        let source: String

        /// What the host realizes, member by member.
        let marks: HostMarks

        var records: [Record] { marks.records }
        var unrealized: Set<String> { marks.unrealized }
        var viewless: Set<String> { marks.viewless }
        var notPlanned: Set<String> { marks.notPlanned }

        init(
            host: String, source: String, records: [Record], unrealized: Set<String>, viewless: Set<String>,
            notPlanned: Set<String> = []
        ) {
            self.init(host: host, source: source, marks: HostMarks(
                records: records, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned))
        }

        init(host: String, source: String, marks: HostMarks) {
            self.host = host
            self.source = source
            self.marks = marks
        }

        /// The same declaration with a host's own export behind it: what is written wins (`HostMarks.and`).
        func and(_ runtime: [Record]) -> Declaration {
            Declaration(host: host, source: source, marks: marks.and(runtime))
        }

        /// The mark and the note one member of `element` has on this host (`HostMarks.mark`).
        func mark(of member: String, on element: String, from tier: String?) -> (mark: String, note: String) {
            switch marks.mark(of: member, on: element, from: tier) {
            case .complete: ("✅", "")
            case .partial(let missing): ("☑️", missing)
            case .notPlanned(let reason): ("–", reason)
            case .absent: ("", "")
            }
        }
    }

    /// What one element's page says, and what its marks add up to.
    struct Page {
        /// The page.
        let text: String

        /// How many members it lists, its own and its tiers'.
        let members: Int

        /// Each host's count of members realized in full, in part, and not planned.
        let marks: [String: Marks]
    }

    /// One host's count of an element's members, by mark.
    struct Marks {
        var done = 0
        var partial = 0
        var notPlanned = 0

        /// The members the host meets the contract on: realized in full, or not planned for its family.
        var met: Int { done + notPlanned }
    }

    /// Every element contract, by name.
    let elements: [any ElementContract.Type]

    /// Every tier, in the dictionary's order.
    let tiers: [any Contract.Type]

    /// The hosts that declare what they realize.
    let declarations: [Declaration]

    /// The `on…` spellings each event is heard through.
    let spellings: [String: Set<String>]

    /// Each surface's native counterpart on each host.
    let mapping: [String: [String: String]]

    /// Each layer, and what it means.
    let layers: [(name: String, meaning: String)]

    /// Each contract's doc, by the contract.
    private let documentation: [ObjectIdentifier: String]

    /// Where each contract is declared, under lib/StateUI/Sources, by the contract.
    private let declared: [ObjectIdentifier: String]

    /// The dictionary as everything it is rendered from stands now.
    init() throws {
        elements = LibraryContracts.elements.sorted { $0.name < $1.name }
        tiers = LibraryContracts.tiers
        declarations = try Self.declarations()
        spellings = try Self.handlerSpellings()
        mapping = try Self.nativeMapping()
        layers = try Self.layers()

        var documentation: [ObjectIdentifier: String] = [:]
        var declared: [ObjectIdentifier: String] = [:]
        for contract in LibraryContracts.all {
            documentation[ObjectIdentifier(contract)] = try Self.documentation(of: contract)
            declared[ObjectIdentifier(contract)] = try Self.path(of: contract)
        }
        self.documentation = documentation
        self.declared = declared
    }

    // MARK: - The pages

    /// Every page, by its path under docs/controls.
    func pages() -> [String: String] {
        var pages: [String: String] = [:]

        for element in elements {
            pages["\(element.name).md"] = page(of: element).text
        }

        for tier in tiers {
            pages["tiers/\(tier.name).md"] = page(ofTier: tier)
        }

        return pages
    }

    /// One element's page: its doc, what it wears, its own members, then each
    /// tier's, every member with a mark for each host.
    func page(of element: any ElementContract.Type) -> Page {
        let name = element.name
        let worn = tiers.filter { tier in element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) } }
        var members = 0
        var marks: [String: Marks] = [:]

        func table(of contract: any Contract.Type, tier: String?) -> [String] {
            var lines = [
                "| Member | Kind | Value | Layer | " + Self.platforms.joined(separator: " | ") + " | Notes |",
                "| --- | --- | --- | --- | " + Self.platforms.map { _ in ":---:" }.joined(separator: " | ") + " | --- |",
            ]

            for member in contract.members {
                var cells = describe(member)
                var notes: [String: String] = [:]

                for platform in Self.platforms {
                    guard let declaration = declarations.first(where: { $0.host == platform }) else {
                        cells.append("")
                        continue
                    }

                    let (mark, note) = declaration.mark(of: member.name, on: name, from: tier)
                    cells.append(mark)
                    notes[platform] = note

                    if mark == "✅" { marks[platform, default: Marks()].done += 1 }
                    if mark == "☑️" { marks[platform, default: Marks()].partial += 1 }
                    if mark == "–" { marks[platform, default: Marks()].notPlanned += 1 }
                }

                lines.append("| " + (cells + [Self.notes(notes)]).joined(separator: " | ") + " |")
                members += 1
            }

            return lines
        }

        var body = [
            Self.rendered, "",
            "# \(name)", "",
            doc(of: element), "",
            "Layer: `\(element.layer)`. " + meaning(of: element.layer), "",
            worn.isEmpty
                ? "Inherits nothing: every member below is its own."
                : "Inherits: " + worn.map { "[\($0.name)](tiers/\($0.name).md)" }.joined(separator: " · "),
            "",
            "Marks: \(Self.legend). See [the dictionary](README.md).", "",
            "Declared in `lib/StateUI/Sources/\(declared[ObjectIdentifier(element)] ?? "")`.", "",
            "## \(name)'s own members", "",
        ]

        if element.members.isEmpty {
            body.append("\(name) declares no members of its own.")
        } else {
            body += table(of: element, tier: nil)
        }

        body += ["", "Realization:", ""] + Self.platforms.map { realization(of: name, on: $0) } + [""]

        for tier in worn {
            body += ["## From [\(tier.name)](tiers/\(tier.name).md)", "", Self.firstSentence(doc(of: tier)), ""]
            body += table(of: tier, tier: tier.name) + [""]
        }

        return Page(text: Self.ending(body), members: members, marks: marks)
    }

    /// One tier's page: its doc, what it wears, who wears it, and its members.
    func page(ofTier tier: any Contract.Type) -> String {
        let wearers = elements.filter { element in
            element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(tier) }
        }
        var body = [Self.rendered, "", "# \(tier.name)", "", doc(of: tier), ""]

        if !tier.tiers.isEmpty {
            body += ["Wears: " + tier.tiers.map { "[\($0.name)](\($0.name).md)" }.joined(separator: " · "), ""]
        }

        body += [
            "Worn by: " + wearers.map { "[\($0.name)](../\($0.name).md)" }.joined(separator: " · "), "",
            "Declared in `lib/StateUI/Sources/\(declared[ObjectIdentifier(tier)] ?? "")`.", "",
            "How each of them realizes these members is on its own page.", "",
            "| Member | Kind | Value | Layer |",
            "| --- | --- | --- | --- |",
        ]
        body += tier.members.map { "| " + describe($0).joined(separator: " | ") + " |" }

        return Self.ending(body)
    }

    /// A member's first four cells: its name - with the `on…` modifier an event
    /// is heard through - its kind, its value and its layer.
    func describe(_ member: any ContractMember) -> [String] {
        let facts = (member as? any DeclaredMember)?.facts
        var name = "`\(member.name)`"

        if facts?.kind == .event, let heard = spellings[member.name], heard.count == 1, let spelling = heard.first {
            name = "`\(spelling)` (`\(member.name)`)"
        }

        let value = Self.value(of: member)

        return [
            name,
            facts.map { "\($0.kind)" } ?? "",
            value.isEmpty ? "" : "`\(value)`",
            facts?.layer.map { "\($0)" } ?? "",
        ]
    }

    /// The line naming what an element is on one host, from the platform
    /// contract's mapping.
    func realization(of element: String, on platform: String) -> String {
        switch mapping[element]?[platform] {
        case "—"?:
            return "- **\(platform)**: no honest native counterpart."
        case let native? where !native.isEmpty:
            return "- **\(platform)**: \(native)"
        default:
            return "- **\(platform)**: no native counterpart is named yet."
        }
    }

    /// A contract's doc.
    func doc(of contract: any Contract.Type) -> String {
        documentation[ObjectIdentifier(contract)] ?? ""
    }

    /// What a layer means.
    func meaning(of layer: ElementLayer) -> String {
        layers.first { $0.name == "\(layer)" }?.meaning ?? ""
    }

    // MARK: - The tables

    /// The elements the index lists as controls - those that wear View - and
    /// the rest, the parts of an application's structure.
    var split: (controls: [any ElementContract.Type], structure: [any ElementContract.Type]) {
        let view = ObjectIdentifier(ViewContract.self)
        let wearsView = { (element: any ElementContract.Type) in element.worn.contains { ObjectIdentifier($0) == view } }

        return (elements.filter(wearsView), elements.filter { !wearsView($0) })
    }

    /// The index's tables, by the block each stands in.
    func indexBlocks() -> [String: String] {
        [
            "controls": summary(of: split.controls, heading: "Control", linking: ""),
            "structure": summary(of: split.structure, heading: "Part", linking: ""),
            "tiers": tiers.map { "- [\($0.name)](tiers/\($0.name).md) - " + Self.firstSentence(doc(of: $0)) }
                .joined(separator: "\n"),
            "layers": layers.map { "- `\($0.name)` - \($0.meaning)" }.joined(separator: "\n"),
        ]
    }

    /// The platform contract's rendered tables, by the block each stands in.
    func contractBlocks() -> [String: String] {
        [
            // Two tables in one block, so each is titled where it is
            // rendered: the index puts its own under headings of its own, and
            // a reader meeting the second table here has nothing else to tell
            // them it counts the parts rather than the controls.
            "dictionary": "### Controls\n\n"
                + summary(of: split.controls, heading: "Control", linking: "controls/")
                + "\n\n### Application structure\n\n"
                + summary(of: split.structure, heading: "Part", linking: "controls/"),
            "creation": creationTable(),
            "members": memberTable(),
            "shared": sharedTable(),
            "acts": actTable(),
            "vocabulary": vocabulary(),
        ]
    }

    /// A row per element: the layer that realizes it, and a ✅ for each host
    /// that creates or interprets it.
    func creationTable() -> String {
        var lines = [Self.header("Element", "Layer"), Self.rule(leading: 2)]

        for element in elements {
            let marks = Self.platforms.map { platform -> String in
                guard let declaration = declaration(of: platform) else { return "" }

                if declaration.notPlanned.contains(element.name) { return "–" }
                return declaration.unrealized.contains(element.name) ? "" : "✅"
            }

            lines.append(Self.row(["`\(element.name)`", "\(element.layer)"] + marks))
        }

        return lines.joined(separator: "\n")
    }

    /// A row per contract with properties or events - the tiers, then the
    /// elements - naming them, marked by the rule for a row naming several.
    /// Its acts are the act table's.
    func memberTable() -> String {
        var lines = [Self.header("Contract", "Members"), Self.rule(leading: 2)]

        for contract in contracts {
            let described = Self.described(by: contract)

            guard !described.isEmpty else { continue }

            let marks = Self.platforms.map { platform in
                Self.grouped(described.map { mark(of: $0, declaredIn: contract, on: platform) })
            }

            lines.append(Self.row(
                ["[\(contract.name)](\(Self.page(of: contract)))",
                 described.map { describe($0)[0] }.joined(separator: ", ")] + marks))
        }

        return lines.joined(separator: "\n")
    }

    /// A row per property and event of the three tiers every view wears,
    /// marked across the views.
    func sharedTable() -> String {
        var lines = [Self.header("Member", "Tier", "Kind"), Self.rule(leading: 3)]
        let everyView: [any Contract.Type] = [
            PropertyContainerContract.self, VisualElementContract.self, ViewContract.self,
        ]

        for tier in everyView {
            for member in Self.described(by: tier) {
                let cells = describe(member)

                lines.append(Self.row(
                    [cells[0], "[\(tier.name)](\(Self.page(of: tier)))", cells[1]]
                        + Self.platforms.map { mark(of: member, declaredIn: tier, on: $0, amongViews: true) }))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// A row per act of every contract.
    func actTable() -> String {
        var lines = [Self.header("Act", "Contract"), Self.rule(leading: 2)]

        for contract in contracts {
            for member in contract.members where (member as? any DeclaredMember)?.facts.kind == .act {
                lines.append(Self.row(
                    ["`\(member.name)`", "[\(contract.name)](\(Self.page(of: contract)))"]
                        + Self.platforms.map { mark(of: member, declaredIn: contract, on: $0) }))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Every name the contracts declare, as the platform contract lists them:
    /// the node types, then the names of the properties, the events and the
    /// acts.
    func vocabulary() -> String {
        func names(of kind: MemberFacts.Kind) -> [String] {
            Set(contracts.flatMap { contract in
                contract.members.filter { ($0 as? any DeclaredMember)?.facts.kind == kind }.map { $0.name }
            }).sorted(by: Self.inReadingOrder)
        }

        let lists: [(heading: String, names: [String])] = [
            ("Controls and structural nodes", elements.map { $0.name }.sorted(by: Self.inReadingOrder)),
            ("Properties", names(of: .property)),
            ("Events", names(of: .event)),
            ("Acts", names(of: .act)),
        ]

        return lists
            .map { "### \($0.heading)\n\n" + Self.wrapped($0.names.map { "`\($0)`" }) }
            .joined(separator: "\n\n")
    }

    /// Every contract, the tiers first.
    var contracts: [any Contract.Type] {
        tiers + elements.map { $0 as any Contract.Type }
    }

    /// The declaration of one host, where it has one.
    func declaration(of platform: String) -> Declaration? {
        declarations.first { $0.host == platform }
    }

    /// One member's mark on one host: on the element declaring it, or - for a
    /// tier's member - across the elements wearing the tier that the host
    /// realizes with a view of their own, and only the views among them
    /// `amongViews`.
    func mark(
        of member: any ContractMember, declaredIn contract: any Contract.Type, on platform: String,
        amongViews: Bool = false
    ) -> String {
        guard let declaration = declaration(of: platform) else { return "" }

        if let element = contract as? any ElementContract.Type {
            return declaration.mark(of: member.name, on: element.name, from: nil).mark
        }

        let view = ObjectIdentifier(ViewContract.self)
        let wearers = elements.filter { element in
            element.worn.contains { ObjectIdentifier($0) == ObjectIdentifier(contract) }
                && (!amongViews || element.worn.contains { ObjectIdentifier($0) == view })
                && !declaration.unrealized.contains(element.name)
                && !declaration.viewless.contains(element.name)
        }

        return Self.grouped(wearers.map { declaration.mark(of: member.name, on: $0.name, from: contract.name).mark })
    }

    /// The mark of a row naming several members, or of one member across
    /// several elements: – when none is planned, ✅ when every one is realized
    /// in full or not planned, ☑️ when every one is judged and some are
    /// realized only in part, and nothing otherwise - or where there is nothing
    /// to count.
    static func grouped(_ marks: [String]) -> String {
        guard !marks.isEmpty, marks.allSatisfy({ $0 == "✅" || $0 == "☑️" || $0 == "–" }) else { return "" }

        if marks.allSatisfy({ $0 == "–" }) { return "–" }
        return marks.contains("☑️") ? "☑️" : "✅"
    }

    /// A contract's properties and events: every member but its acts.
    static func described(by contract: any Contract.Type) -> [any ContractMember] {
        contract.members.filter { ($0 as? any DeclaredMember)?.facts.kind != .act }
    }

    /// A contract's page, as the platform contract links it.
    static func page(of contract: any Contract.Type) -> String {
        (contract as? any ElementContract.Type) == nil
            ? "controls/tiers/\(contract.name).md" : "controls/\(contract.name).md"
    }

    /// A table's header: its own columns, then one per host.
    static func header(_ leading: String...) -> String {
        row(leading + platforms)
    }

    /// The rule under a header: its own columns left, the hosts' centred.
    static func rule(leading count: Int) -> String {
        row(Array(repeating: "---", count: count) + platforms.map { _ in ":---:" })
    }

    /// One table row.
    static func row(_ cells: [String]) -> String {
        "| " + cells.joined(separator: " | ") + " |"
    }

    /// Names in the order a reader looks them up: by their letters, case
    /// aside.
    static func inReadingOrder(_ first: String, _ second: String) -> Bool {
        let (a, b) = (first.lowercased(), second.lowercased())

        return a == b ? first < second : a < b
    }

    /// A list written as prose - a comma after each name, a full stop after
    /// the last - wrapped at eighty columns.
    static func wrapped(_ items: [String]) -> String {
        var lines: [String] = []
        var line = ""

        for (index, item) in items.enumerated() {
            let word = item + (index == items.count - 1 ? "." : ",")

            if line.isEmpty {
                line = word
            } else if line.count + 1 + word.count <= 80 {
                line += " " + word
            } else {
                lines.append(line)
                line = word
            }
        }

        if !line.isEmpty { lines.append(line) }

        return lines.joined(separator: "\n")
    }

    /// One table of counts: a row per element, how many members its page
    /// lists, and how many each host realizes.
    func summary(of elements: [any ElementContract.Type], heading: String, linking prefix: String) -> String {
        var lines = [
            "| \(heading) | Members | " + Self.platforms.joined(separator: " | ") + " |",
            "| --- | ---: | " + Self.platforms.map { _ in ":---:" }.joined(separator: " | ") + " |",
        ]

        var total = 0
        var totals: [String: Marks] = [:]
        for element in elements {
            let page = page(of: element)
            total += page.members
            let cells = Self.platforms.map { platform -> String in
                let marks = page.marks[platform] ?? Marks()
                totals[platform, default: Marks()].done += marks.done
                totals[platform, default: Marks()].partial += marks.partial
                totals[platform, default: Marks()].notPlanned += marks.notPlanned
                return Self.counted(marks)
            }

            lines.append("| [\(element.name)](\(prefix)\(element.name).md) | \(page.members) | "
                + cells.joined(separator: " | ") + " |")
        }

        let met = Self.platforms.map { platform -> String in
            let marks = totals[platform] ?? Marks()
            return marks.met + marks.partial == 0 ? "" : "\(marks.met) of \(total) met"
        }
        lines.append("| **Met** - ✅ and – | \(total) | " + met.joined(separator: " | ") + " |")

        return lines.joined(separator: "\n")
    }

    /// One host's marks on one element, counted: each kind it has, in the legend's order.
    static func counted(_ marks: Marks) -> String {
        [(marks.done, "✅"), (marks.partial, "☑️"), (marks.notPlanned, "–")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: " · ")
    }

    /// `text` with the block `name` holding `content`, between its markers.
    static func replacing(block name: String, in text: String, with content: String) throws -> String {
        let begin = "<!-- \(name):begin -->"
        let end = "<!-- \(name):end -->"

        guard let opening = text.range(of: begin),
              let closing = text.range(of: end, range: opening.upperBound..<text.endIndex)
        else { throw Unreadable(description: "no \(begin) … \(end) to put the rendered table between") }

        return String(text[..<opening.upperBound]) + "\n" + content + "\n" + String(text[closing.lowerBound...])
    }

    // MARK: - What the pages are rendered from

    /// What AppKit, Android Views, WinUI 3 and GTK 4 declare they realize.
    ///
    /// Each is read twice over: what its RUNTIME wrote to its export - every
    /// element it registers, with the owner of each member worked out against
    /// the contracts - and then what is still said by hand, the notes saying
    /// what a realization is missing. A registry knows presence and nothing
    /// else, so a judgement stays written.
    static func declarations() throws -> [Declaration] {
        let appKit = try Declaration(
            host: "AppKit", reading: "lib/StateUI.AppKit/Sources/Registration/AppKitRealization.swift",
            records: #"\.(complete|partial|notPlanned)"#,
            unrealized: #"static let unrealized: Set<String> = \[([^\]]*)\]"#,
            viewless: #"static let viewless: Set<String> = \[([^\]]*)\]"#,
            notPlanned: #"static let notPlanned: Set<String> = \[([^\]]*)\]"#)

        let android = try Declaration(
            host: "Android Views",
            reading: "lib/StateUI.Android/Sources/StateUIAndroid/Registration/AndroidRealization.swift",
            records: #"\.(complete|partial|notPlanned)"#,
            unrealized: #"static let unrealized: Set<String> = \[([^\]]*)\]"#,
            viewless: #"static let viewless: Set<String> = \[([^\]]*)\]"#,
            notPlanned: #"static let notPlanned: Set<String> = \[([^\]]*)\]"#)

        let winUI = try Declaration(
            host: "WinUI 3",
            reading: "lib/StateUI.WinUI/Sources/StateUIWinUI/Registration/WinUIRealization.swift",
            records: #"\.(complete|partial|notPlanned)"#,
            unrealized: #"static let unrealized: Set<String> = \[([^\]]*)\]"#,
            viewless: #"static let viewless: Set<String> = \[([^\]]*)\]"#,
            notPlanned: #"static let notPlanned: Set<String> = \[([^\]]*)\]"#)

        let gtk = try Declaration(
            host: "GTK 4",
            reading: "lib/StateUI.GTK/Sources/StateUIGTK/Registration/GTKRealization.swift",
            records: #"\.(complete|partial|notPlanned)"#,
            unrealized: #"static let unrealized: Set<String> = \[([^\]]*)\]"#,
            viewless: #"static let viewless: Set<String> = \[([^\]]*)\]"#,
            notPlanned: #"static let notPlanned: Set<String> = \[([^\]]*)\]"#)

        return [
            try appKit.and(exported(exports["AppKit"]!)),
            try android.and(exported(exports["Android Views"]!)),
            try winUI.and(exported(exports["WinUI 3"]!)),
            try gtk.and(exported(exports["GTK 4"]!)),
        ]
    }

    /// Where each host's suite writes what its runtime realizes, by the host's name.
    static let exports = [
        "AppKit": "exports/appkit.txt", "Android Views": "exports/android.txt", "WinUI 3": "exports/winui.txt",
        "GTK 4": "exports/gtk.txt",
    ]

    /// The records a host's own export carries: its declaration joined with
    /// the contracts, so each member is named under the contract DECLARING it.
    ///
    /// A tier's member reaches every element wearing it, and the dictionary
    /// asks about a tier once - so the join's members are reduced to the pairs
    /// they are made of, which is also what keeps each record written once.
    static func exported(_ path: String) throws -> [Declaration.Record] {
        HostMarks.records(of: try export(path))
    }

    /// The declaration a host's export holds.
    static func export(_ path: String) throws -> HostDeclaration {
        let url = SourceTree.repository.appendingPathComponent(path)

        guard let declaration = HostDeclaration(text: try String(contentsOf: url, encoding: .utf8)) else {
            throw Unreadable(description: "\(path) did not read as a host declaration. Write it again "
                + "with STATEUI_UPDATE_EXPORTS=1, through the suite of the host that writes it - "
                + "`swift test --package-path lib/StateUI.AppKit` or `.scripts/Android/test-android.sh`.")
        }
        return declaration
    }

    /// The `on…` modifier each event is heard through, read from the sources
    /// declaring the elements' modifiers: `onClicked` hears `clicked`. A
    /// modifier hears the first event its body registers - by its token or by
    /// its member - its body running to the next function declared.
    static func handlerSpellings() throws -> [String: Set<String>] {
        let kinds = memberKinds()
        let declared = try NSRegularExpression(pattern: #"public func (on\w+)\("#)
        let boundary = try NSRegularExpression(pattern: #"\bfunc\b"#)
        let token = try NSRegularExpression(pattern: #"addHandler\(\.(\w+)"#)
        let member = try NSRegularExpression(pattern: #"\b(?:addHandler|onEvent)\(\s*(\w+)\.(\w+)"#)
        var spellings: [String: Set<String>] = [:]

        for source in try SourceTree.allSources()
        where source.path.hasPrefix("Views/") || modifierSources.contains(SourceTree.name(of: source.path)) {
            let text = uncommented(source.text)
            let nsText = text as NSString
            let whole = NSRange(location: 0, length: nsText.length)
            let starts = boundary.matches(in: text, range: whole).map { $0.range.location }

            for function in declared.matches(in: text, range: whole) {
                let end = starts.first { $0 >= NSMaxRange(function.range) } ?? nsText.length
                let body = NSRange(location: function.range.location, length: end - function.range.location)
                var heard: [(at: Int, event: String)] = []

                for match in token.matches(in: text, range: body) {
                    heard.append((match.range.location, nsText.substring(with: match.range(at: 1))))
                }

                for match in member.matches(in: text, range: body) {
                    let contract = nsText.substring(with: match.range(at: 1))
                    let name = nsText.substring(with: match.range(at: 2))

                    if kinds[contract]?[name] == .event { heard.append((match.range.location, name)) }
                }

                if let first = heard.min(by: { $0.at < $1.at }) {
                    spellings[first.event, default: []].insert(nsText.substring(with: function.range(at: 1)))
                }
            }
        }

        return spellings
    }

    /// Each surface's native counterpart on each host, from the platform
    /// contract's "Native control mapping", read by its header:
    /// `mapping["Button"]?["AppKit"] == "`NSButton`"`.
    static func nativeMapping() throws -> [String: [String: String]] {
        let lines = try String(
            contentsOf: SourceTree.repository.appendingPathComponent("docs/platform-contract.md"), encoding: .utf8
        ).components(separatedBy: "\n")

        guard let start = lines.firstIndex(of: "## Native control mapping") else {
            throw Unreadable(description: "docs/platform-contract.md has no \"## Native control mapping\"")
        }

        var header: [String] = []
        var mapping: [String: [String: String]] = [:]

        for line in lines[(start + 1)...] {
            if line.hasPrefix("## ") { break }
            guard line.hasPrefix("|") else { continue }

            let cells = Self.cells(of: line)

            if header.isEmpty {
                header = cells
                continue
            }

            guard cells.first?.hasPrefix("`") == true else { continue }

            var named: [String: String] = [:]
            for (platform, cell) in zip(header.dropFirst(), cells.dropFirst()) {
                named[platform] = cell
            }

            for name in backticked(cells[0]) {
                mapping[name] = named
            }
        }

        return mapping
    }

    /// `ElementLayer`'s cases with what each means, read off their doc
    /// comments in ElementLayer.swift.
    static func layers() throws -> [(name: String, meaning: String)] {
        let lines = try source("ElementLayer.swift").components(separatedBy: "\n")

        guard let start = lines.firstIndex(where: { $0.hasPrefix("public enum ElementLayer") }) else {
            throw Unreadable(description: "ElementLayer.swift declares no ElementLayer")
        }

        var layers: [(name: String, meaning: String)] = []
        var doc: [String] = []

        for line in lines[(start + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "}" { break }

            if trimmed.hasPrefix("///") {
                doc.append(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("case ") {
                layers.append((String(trimmed.dropFirst(5)), doc.joined(separator: " ")))
                doc = []
            }
        }

        return layers
    }

    /// The first paragraph of the doc comment over a contract's declaration,
    /// as one line.
    static func documentation(of contract: any Contract.Type) throws -> String {
        let type = String(describing: contract)
        let lines = try source(try path(of: contract)).components(separatedBy: "\n")

        guard let declaration = lines.firstIndex(where: { $0.hasPrefix("public enum \(type):") }) else {
            throw Unreadable(description: "\(type).swift does not declare \(type)")
        }

        var start = declaration
        while start > 0, lines[start - 1].hasPrefix("///") {
            start -= 1
        }

        return lines[start..<declaration]
            .map { $0.dropFirst(3).trimmingCharacters(in: .whitespaces) }
            .prefix { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Where a contract is declared, under lib/StateUI/Sources: the one file named for it.
    static func path(of contract: any Contract.Type) throws -> String {
        let name = "\(String(describing: contract)).swift"
        let found = try sourcePaths.get()[name] ?? []

        guard found.count == 1, let path = found.first else {
            throw Unreadable(description: "\(name) is \(found.count) files under lib/StateUI/Sources")
        }

        return path
    }

    /// Every source's path under lib/StateUI/Sources, by its file name, read once.
    private static let sourcePaths = Result {
        Dictionary(grouping: try SourceTree.allSources().map(\.path), by: SourceTree.name(of:))
    }

    /// A member's value as Swift spells it: a property's type, an event's
    /// payload - nothing for one that carries none - and an act's arguments
    /// and answer.
    static func value(of member: any ContractMember) -> String {
        if let property = member as? any PropertyMember {
            return spelling(of: property.valueType)
        }

        if let event = member as? any EventShape {
            return ObjectIdentifier(event.payloadType) == ObjectIdentifier(Void.self) ? "" : spelling(of: event.payloadType)
        }

        if let act = member as? any ActShape {
            let arguments = spelling(of: act.argumentsType)
            let answer = ObjectIdentifier(act.answerType) == ObjectIdentifier(Void.self) ? "Void" : spelling(of: act.answerType)

            return (arguments.hasPrefix("(") ? arguments : "(\(arguments))") + " -> " + answer
        }

        return ""
    }

    /// A type as Swift writes it where it is used: `Optional<Array<String>>`
    /// is `[String]?`.
    static func spelling(of type: Any.Type) -> String {
        var text = Substring(String(describing: type))

        return spell(&text)
    }

    private static func spell(_ text: inout Substring) -> String {
        if text.hasPrefix("(") {
            text.removeFirst()
            return "(" + list(&text, closing: ")").joined(separator: ", ") + ")"
        }

        let name = text.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }

        guard !name.isEmpty else { return text.popFirst().map { String($0) } ?? "" }

        text.removeFirst(name.count)

        // A tuple element's label.
        if text.hasPrefix(": ") {
            text.removeFirst(2)
            return "\(name): " + spell(&text)
        }

        guard text.hasPrefix("<") else { return String(name) }

        text.removeFirst()
        let arguments = list(&text, closing: ">")

        switch name {
        case "Optional": return arguments[0] + "?"
        case "Array": return "[\(arguments[0])]"
        case "Dictionary": return "[\(arguments[0]): \(arguments[1])]"
        default: return "\(name)<\(arguments.joined(separator: ", "))>"
        }
    }

    private static func list(_ text: inout Substring, closing: Character) -> [String] {
        var items: [String] = []

        while let first = text.first, first != closing {
            items.append(spell(&text))
            if text.hasPrefix(", ") { text.removeFirst(2) }
        }

        if !text.isEmpty { text.removeFirst() }

        return items
    }

    /// A row's one Notes cell: AppKit's note as written, then each other
    /// host's as "<host>: <note>", in the columns' order, joined by "; ".
    static func notes(_ notes: [String: String]) -> String {
        (["AppKit"] + platforms.filter { $0 != "AppKit" })
            .compactMap { host in
                guard let note = notes[host], !note.isEmpty else { return nil }
                return host == "AppKit" ? note : "\(host): \(note)"
            }
            .joined(separator: "; ")
    }

    /// A text up to the end of its first sentence.
    static func firstSentence(_ text: String) -> String {
        let characters = Array(text)

        for index in characters.indices
        where ".!?".contains(characters[index]) && (index + 1 == characters.count || characters[index + 1] == " ") {
            return String(characters[...index])
        }

        return text
    }

    /// Every library member's kind, by its contract type's name and its own.
    static func memberKinds() -> [String: [String: MemberFacts.Kind]] {
        var kinds: [String: [String: MemberFacts.Kind]] = [:]

        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members {
                kinds[String(describing: contract), default: [:]][member.name] = member.facts.kind
            }
        }

        return kinds
    }

    /// Every match of `pattern` in `text`, as its groups - nil for one that
    /// took no part.
    static func matches(_ pattern: String, in text: String) throws -> [[String?]] {
        let regex = try NSRegularExpression(pattern: pattern)

        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
    }

    /// A table row's cells, its outer pipes left out.
    static func cells(of line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }

        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// The names a text writes between backticks.
    static func backticked(_ text: String) -> [String] {
        text.components(separatedBy: "`").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
    }

    /// A text with every line that is only a comment left out.
    static func uncommented(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// One of the library's sources, by its name or its path under lib/StateUI/Sources.
    static func source(_ path: String) throws -> String {
        try SourceTree.text(in: path)
    }

    /// Lines as a file holds them: one newline at the end, none after it.
    static func ending(_ lines: [String]) -> String {
        var text = lines.joined(separator: "\n")

        while text.hasSuffix("\n") {
            text.removeLast()
        }

        return text + "\n"
    }
}

extension ControlDictionary.Declaration {
    /// A record's owner, member, and what is missing or why it is not planned, written on one line after its
    /// opening.
    private static let record = #"\("(\w+)", "(\w+)"(?:, (?:missing|reason): "((?:[^"\\]|\\.)*)")?\)"#

    /// A host's declaration, read from its source: `records` opens each record, which then reads as `record`;
    /// one opened that does not read throws, so no record is lost to how it is written.
    init(
        host: String, reading source: String, records opening: String, unrealized: String, viewless: String?,
        notPlanned: String? = nil
    ) throws {
        let text = ControlDictionary.uncommented(
            try String(contentsOf: SourceTree.repository.appendingPathComponent(source), encoding: .utf8))

        func names(_ pattern: String?) throws -> Set<String> {
            guard let pattern, let list = try ControlDictionary.matches(pattern, in: text).first?[1] else { return [] }

            return Set(try ControlDictionary.matches(#""(\w+)""#, in: list).compactMap { $0[1] })
        }

        let found = try ControlDictionary.matches(opening + Self.record, in: text).map { groups in
            let said = (groups[4] ?? "").replacingOccurrences(of: #"\""#, with: "\"")
            let judgement: Judgement = switch groups[1] {
            case "partial": .partial(missing: said)
            case "notPlanned": .notPlanned(reason: said)
            default: .complete
            }
            return Record(owner: groups[2] ?? "", member: groups[3] ?? "", judgement: judgement)
        }
        let opened = try ControlDictionary.matches(opening + #"\(\s*""#, in: text).count
        guard opened == found.count else {
            throw ControlDictionary.Unreadable(description: "\(source): \(opened - found.count) of its \(opened) records do not read. "
                + "Write each on one line - (\"Owner\", \"member\"), with its missing: or reason: \"...\" where it has one.")
        }
        let unrealizedNames = try names(unrealized)
        let viewlessNames = try names(viewless)
        let notPlannedNames = try names(notPlanned)

        self.init(
            host: host, source: source, records: found, unrealized: unrealizedNames, viewless: viewlessNames,
            notPlanned: notPlannedNames)
    }
}
