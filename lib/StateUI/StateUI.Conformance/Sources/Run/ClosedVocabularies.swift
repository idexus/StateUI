// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Every case of every closed vocabulary - each member whose value crosses as one of a vocabulary's numbers - written
/// to every element wearing the member, one case after another and then none: the host takes each and goes on, its
/// page standing and its log saying nothing of it. Every host's own suite runs it with its driver; it marks nothing.
/// Design: docs/design/host/conformance.md#every-case-of-a-closed-vocabulary
@MainActor
@_spi(Host) public enum ClosedVocabularies {
    /// What `untaken` walks unless told otherwise: every element wearing a member of a closed vocabulary, in the
    /// library's order.
    public static var walked: [String] {
        LibraryContracts.elements.map { $0.nodeType.name }.filter { !cases(on: $0).isEmpty }
    }

    /// Each case of `elements` `driver`'s host realizes and did not take - what it logged as it took it, or that its
    /// page stopped standing - each named by its element, its member and its case; none where the host took every one.
    /// `part` walks every `count`th of the elements the host realizes, for a host that runs the walk in parts.
    public static func untaken(
        on driver: any HostDriver, _ elements: [String] = walked, part: Conformance.Part = .whole
    ) throws -> [String] {
        let (log, register) = (HostLog(host: driver.host), driver.register)
        let realized = elements.map { element in
            (element, cases(on: element).filter { register.realizes($0.member, on: element, from: $0.owner) })
        }.filter { !$0.1.isEmpty }.enumerated().filter { part.holds($0.offset) }.map(\.element)
        var untaken: [String] = []
        for (place, (element, cases)) in realized.enumerated() {
            log.note("[\(place + 1)/\(realized.count)] \(element): \(cases.count) cases")
            untaken += try written(cases, on: element, by: driver)
        }
        return untaken
    }

    /// Every case of every closed vocabulary among the members `element` wears - read from the contracts once.
    static func cases(on element: String) -> [VocabularyCase] {
        if let known = known[element] { return known }
        let contract = LibraryContracts.elements.first { $0.nodeType.name == element }
        let cases = (contract?.worn ?? []).flatMap { owner in
            owner.members.flatMap { member in (member as? any VocabularyMember)?.everyCase ?? [] }
        }
        known[element] = cases
        return cases
    }

    /// The cases read of each element so far.
    private static var known: [String: [VocabularyCase]] = [:]

    /// `cases` written one after another to `element`'s specimen, then none: each case after which the host logged a
    /// line or the tree held no specimen, and the page that no longer stood.
    private static func written(
        _ cases: [VocabularyCase], on element: String, by driver: any HostDriver
    ) throws -> [String] {
        let step = State(wrappedValue: 0)
        var heard = (try? driver.logged())?.count ?? 0
        let tree = driver.start(clock: nil, reducesMotion: false) {
            page(element, step.wrappedValue < cases.count ? cases[step.wrappedValue] : nil)
        }
        var untaken: [String] = []
        for written in 0...cases.count {
            if written > 0 { step.wrappedValue = written }
            driver.step()
            let said = { written < cases.count ? cases[written].said : "none" }
            if tree.root?.first(id: .manual("specimen")) ?? tree.root?.first(type: NodeType(element)) == nil {
                untaken.append("\(element): \(said()): no specimen stood")
            }
            guard let lines = try? driver.logged(), lines.count > heard else { continue }
            untaken += lines[heard...].map { "\(element): \(said()): \($0)" }
            heard = lines.count
        }
        do {
            guard let after = tree.root?.first(id: .manual("after")) else { throw Session.Missing(id: "after") }
            _ = try driver.place(of: after)
        } catch {
            untaken.append("\(element): the page no longer stands (\(error))")
        }
        return untaken
    }

    /// The page `written` stands on - its element's specimen wearing it, none past the last case - over words standing
    /// after it. An element written only through a modifier of its own stands on a page of its own, which writes the
    /// members it knows and stands no specimen for another.
    private static func page(_ element: String, _ written: VocabularyCase?) -> AnyView {
        let after: [any View] = [Text("After").id("after")]
        let words = VStack { Beside([Text("Page")] + after) }
        let member = written?.member
        func says<Value: HostRepresentable>(_ type: Value.Type) -> Value? {
            written.flatMap { Value(propValue: $0.value) }
        }
        switch element {
        case "BottomBar" where member == nil || member == BottomBarContract.scrollEdge.name:
            return AnyView(words.bottomBar(scrollEdge: says(ScrollEdge.self) ?? .automatic) { Text("Bar") })
        case "Marker" where member == nil || member == MarkerContract.kind.name:
            let marker = Marker(at: Location(latitude: 52.23, longitude: 21.02)).title("Home")
            let map = Map(region: MapRegion(center: Location(latitude: 52.23, longitude: 21.01), radiusMeters: 5_000))
                .markers { says(MarkerKind.self).map { marker.kind($0) } ?? marker }.height(300)
            return AnyView(VStack { Beside([map] + after) })
        case "Page" where member == nil || member == IconElementContract.icon.name:
            let titled = words.pageTitle("Page")
            let icon = says(ImageSource.self)
            return AnyView(TabView([0]) { _ in icon.map { AnyView(titled.pageIcon($0)) } ?? AnyView(titled) })
        case "BottomBar", "Marker", "Page":
            return AnyView(Text("No page writes \(member ?? "")"))
        default:
            return BarElementTests.declaring(element, written.map { [$0.worn] } ?? [], beside: after)
        }
    }
}

/// One case of a member's vocabulary: the words naming it, the contract declaring the member and the member's name, the
/// case as it crosses, and what writes it to a specimen.
struct VocabularyCase: Sendable {
    /// The words naming it, said only where it was not taken: a case's own words take Swift's reflection.
    let says: @MainActor @Sendable () -> String
    let owner: String
    let member: String
    let value: PropValue
    let worn: any Worn

    /// The words naming it.
    @MainActor var said: String { says() }
}

/// A property whose value may cross as one number of a closed vocabulary: each case of it written to a specimen.
protocol VocabularyMember {
    /// Each value of the property that crosses as a number of its vocabulary below 256 - a flag set's none, each of
    /// its first eight bits and those eight - and none where its value crosses otherwise.
    @MainActor var everyCase: [VocabularyCase] { get }
}

extension ElementProperty: VocabularyMember where Owner: WornContract {
    @MainActor var everyCase: [VocabularyCase] {
        guard Value.self != PropValue.self, Value.self != PropValue?.self else { return [] }
        func crossing(_ number: Int32) -> Value? {
            Value(propValue: .enumeration(number)).flatMap { $0.propValue == .enumeration(number) ? $0 : nil }
        }
        let flags = crossing(255) != nil
        let numbers: [Int32] = flags ? [0] + (0..<8).map { 1 << $0 } + [255] : Array(0..<256)
        return numbers.filter { crossing($0) != nil }.map { number in
            VocabularyCase(
                says: { [self] in
                    "\(Owner.name).\(name) " + (Value(propValue: .enumeration(number)).map { "\($0)" } ?? "\(number)")
                },
                owner: Owner.name, member: name, value: .enumeration(number),
                worn: WrittenCase(member: self, value: .enumeration(number)))
        }
    }
}

/// One case of a property's vocabulary, written through the element's own `setValue`.
struct WrittenCase<Owner: WornContract, Value: HostRepresentable>: Worn {
    let member: ElementProperty<Owner, Value>

    /// The case, as it crosses.
    let value: PropValue

    func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element {
        Value(propValue: value).map { element.setValue(member, $0) } ?? element
    }

    func worn<Part: PropertyContainer>(byPart part: Part) -> Part where Part.Modified == Part {
        Value(propValue: value).map { part.setValue(member, $0) } ?? part
    }
}
