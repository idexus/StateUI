// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What every test here needs: a differ to talk to, and a way to say what came
// out of it.
//
// Foundation is fine here, and only here: a test target is never part of the
// library, and reading a file is not what the ICU rule is about.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

extension HostPatch {
    var props: [Prop: HostValue] { properties }
    var cleared: [Prop] { clearedProperties }
    var arranged: Bool {
        if case .arranged = children { return true }
        return false
    }
    var lanes: MotionLanes { motion?.lanes ?? .all }
}

extension HostDrivenUpdate {
    var bindings: [Prop: HostStateBinding] {
        switch self {
        case .replace(let bindings): bindings
        }
    }

    var isEmpty: Bool { bindings.isEmpty }
    subscript(property: Prop) -> HostStateBinding? { bindings[property] }
}

extension HostEventUpdate {
    var handlers: [Event: Int32] {
        switch self {
        case .replace(let handlers): handlers
        }
    }

    var keys: Dictionary<Event, Int32>.Keys { handlers.keys }
    var isEmpty: Bool { handlers.isEmpty }
    subscript(event: Event) -> Int? { handlers[event].map(Int.init) }
}

/// The queued acts, taken and decoded - the values already apart, so a test
/// asserts on an act rather than searching bytes.
func drainedActs() -> [WireAct] {
    WireProbe.decode(Renderer.shared.takeActCallsWire())
}

/// A composed view whose body does nothing but READ, through the closure it
/// is given - what a test hands a state, a model or a ticker to have a LIVE
/// READER of it, since a write to state no live element read asks for nothing
/// (see `Renderer.stateChanged`). The element counts as a reader for as long as
/// the tree that holds it stands, so the `Renders` that drew it is kept alive
/// for as long as the reader must count.
private struct Reading: ContentView {
    let read: () -> Void

    var content: any View {
        read()
        return ModifiedContent(node: label("reader"))
    }
}

/// Renders a view that reads through `read`, and answers the renderer holding
/// the tree it stands in - keep it for as long as the reader must count.
///
///     let reader = reading { _ = counter.get() }
///     counter.wrappedValue = 1
///     XCTAssertTrue(Renderer.shared.needsRender)
///     _ = reader
func reading(_ read: @escaping () -> Void) -> Renders {
    let renders = Renders()
    renders.render(Reading(read: read).body)
    return renders
}

/// A differ and the tree it last produced, so a test can render twice and look
/// at what the second render had to say.
final class Renders {
    private let differ = Differ()
    private var rendered: RenderedNode?

    /// Renders a tree and returns what would have been sent.
    ///
    /// `changed` is what the renderer collects from `stateChanged` between
    /// renders: the storages whose state moved - what `revisit` rebuilds a
    /// kept element for, and what a carried view is never asked about. A
    /// test that wrote a state some view read passes it, the way the renderer
    /// does on every path.
    ///
    /// `styles` is the application's sheet, which the differ resolves every
    /// element against - passed on each render, exactly as the renderer reads
    /// it on each build, so a test can move one and watch what follows.
    @discardableResult
    func render(
        _ tree: Node,
        styles: StyleSheet? = nil,
        motion: Motion = .standard,
        changed: Set<ObjectIdentifier> = []
    ) -> HostPatch {
        differ.motion = motion
        differ.named = Renderer.shared.pendingNames

        let result = differ.reconcile(rendered, with: tree, styles: styles, changed: changed)
        rendered = result.node
        runFired()
        return result.patch
    }

    /// Renders a tree the way the RENDERER sends it: the walk, then the
    /// handlers it found run before the message leaves and what they wrote
    /// walked into it - see `Renderer.renderWire`. What a page or a window
    /// writes into its session from `.onCreated` is in the patch this answers.
    ///
    /// The invalidation is TAKEN, as the renderer takes it: what a test wrote
    /// goes in as `changed`, what the passes walk is what the handlers wrote,
    /// and nothing is left pending for the next render - or the next test -
    /// to read. See `Differ.settling`.
    @discardableResult
    func settled(
        _ tree: Node,
        styles: StyleSheet? = nil,
        changed: Set<ObjectIdentifier> = []
    ) -> HostPatch {
        differ.motion = .standard
        differ.named = Renderer.shared.pendingNames

        let result = differ.settling(
            differ.reconcile(rendered, with: tree, styles: styles, changed: changed))

        rendered = result.node
        return result.patch
    }

    /// Renders with NO fresh tree at all - the clean walk `Renderer.renderWire`
    /// takes when every cause of the render named the state it wrote. Only the
    /// views whose recorded reads intersect `changed` are built again.
    @discardableResult
    func revisit(changed: Set<ObjectIdentifier>) -> HostPatch {
        differ.named = Renderer.shared.pendingNames
        let result = differ.revisit(rendered!, changed: changed)
        rendered = result.node
        runFired()
        return result.patch
    }

    /// Renders as if the host had lost track - which is what a mismatched
    /// generation does: everything is described, against the tree this side
    /// still holds, exactly as `Renderer.renderWire` does it. Identity, state
    /// and handlers survive; only the message gets bigger.
    @discardableResult
    func renderFromScratch(_ tree: Node) -> HostPatch {
        let result = differ.reconcile(rendered, with: tree, describeAll: true)
        rendered = result.node
        runFired()
        return result.patch
    }

    /// Runs what the walk found once it is done, each here and now up to its
    /// first suspension - `Renderer.run`, what a settling pass calls. The
    /// differ's view alone: the renderer also walks what these write into the
    /// same message, which a test of that renders through `Renderer.renderWire`.
    private func runFired() {
        for handler in differ.takeFired() {
            Renderer.shared.run(handler)
        }
    }

    /// Runs the closure an id refers to, the way a dispatched event does.
    ///
    /// Goes through `Renderer.start`, which is what `stateui_dispatch_wire`
    /// uses, rather than calling the closure - so what a test sees is the real
    /// path, including the executor a handler resumes on. Synchronous, because
    /// that path is: a handler with no `await` in it finishes before this
    /// returns, exactly as it did when handlers could not suspend at all.
    @discardableResult
    func fire(_ id: Int, with payload: [PropValue] = []) -> Bool {
        guard let handler = differ.handler(id) else { return false }

        // What stateui_dispatch_wire does before starting the handler: the
        // payload is left where the typed handlers read it from.
        EventBuffer.current = payload
        Renderer.shared.start(handler)
        return true
    }

    /// Runs a handler id carried by the typed host contract.
    @discardableResult
    func fire(_ id: Int32, with payload: [PropValue] = []) -> Bool {
        fire(Int(id), with: payload)
    }
}

extension Differ {
    /// A walk's answer with the renderer's settling passes run over it: the
    /// handlers the walk found run before the message leaves, and what they
    /// wrote is walked and merged into the same patch, up to
    /// `Renderer.settleLimit` times - `Renderer.renderWire`, for a test that
    /// holds a differ of its own. `Renders.settled` is the usual way in.
    ///
    /// The invalidation is taken first, as the renderer takes it before it
    /// builds, so what each pass walks is exactly what the handlers wrote.
    /// What there is no pass left for runs once the passes are done, which is
    /// where the renderer leaves it too: what it writes is the next render's.
    ///
    /// - Parameter walked: what `reconcile` answered.
    /// - Returns: the tree the passes left, and the one patch they make.
    func settling(
        _ walked: (node: RenderedNode, patch: HostPatch)
    ) -> (node: RenderedNode, patch: HostPatch) {
        Renderer.shared.clearInvalidation()

        var rendered = walked.node
        var patch = walked.patch

        for _ in 0..<Renderer.settleLimit {
            let handlers = takeFired()

            guard !handlers.isEmpty else { break }

            for handler in handlers {
                Renderer.shared.run(handler)
            }

            let wrote = Renderer.shared.pendingChanges

            guard !wrote.isEmpty else { break }

            Renderer.shared.clearInvalidation()

            let again = revisit(rendered, changed: wrote)
            rendered = again.node
            patch = patch.merging(again.patch)
        }

        for handler in takeFired() {
            Renderer.shared.run(handler)
        }

        return (rendered, patch)
    }
}

/// An aim filled BY HAND from a named element, for acts that must be sent
/// without a render: what an act sends is the element's identity, and this
/// is the named kind - the wire the command fixtures pin. The differ's own
/// filling of one is AimTests' business.
func named<Target>(_ name: String, _ type: Target.Type) -> Aim<Target> {
    let aim = Aim(type)
    aim.box.attach(.manual(name), walk: 1)
    return aim
}

/// One turn of the UI thread, taken by a test that stands on it - a
/// synchronous test, which runs on the main thread: what the host's drain runs,
/// then what the main run loop runs. Between them that is every MainActor job
/// waiting: the main queue's on Apple, the UI thread's queue elsewhere, which
/// its drain empties and the main queue's post drains too.
///
/// - Parameter seconds: how long the run loop may wait for work to arrive.
func turnTheUIThread(for seconds: TimeInterval = 0.002) {
    stateUIRunJobs()

    let until = Date(timeIntervalSinceNow: seconds)
    if !RunLoop.main.run(mode: .default, before: until) {
        Thread.sleep(until: until)
    }
}

/// Lets the UI thread run what a resumed handler left waiting, the way the
/// host's turns do.
///
/// `resume()` schedules the rest of a handler rather than continuing it, and the
/// job it produces arrives a moment later - so a test that reports an act as
/// finished takes turns of the UI thread until every handler told its act is
/// over has run again, where a host's doorbell rings as the job lands. A turn
/// is a hop to MainActor: it lands behind every job already waiting there -
/// the main queue's on Apple, the UI thread's queue elsewhere, which the host
/// drains and a test's run loop drains too.
///
/// - Returns: how many turns it took.
@discardableResult
func settle(timeout: TimeInterval = 2) async -> Int {
    let deadline = Date().addingTimeInterval(timeout)
    var turns = 0

    repeat {
        await MainActor.run { _ = stateUIRunJobs() }
        turns += 1
    } while (Renderer.shared.resumesPending > 0 || UIThreadExecutor.shared.pendingCount > 0)
        && Date() < deadline

    return turns
}

/// A walk of the sources, the tests or the fixtures that read almost nothing:
/// its directory moved, or its filter lets nothing through - and every guard
/// reading the walk would pass on nothing.
struct WalkReadAlmostNothing: Error, CustomStringConvertible {
    let root: String
    let read: Int

    var description: String { "the walk of \(root) read \(read) files, almost nothing" }
}

/// The fixtures, source trees, and test trees used by source-level guards.
/// Every walk refuses one that read almost nothing (`WalkReadAlmostNothing`).
enum Fixtures {
    /// `lib/StateUI/Tests/Fixtures`, found from this file rather than from a working
    /// directory that depends on who started the process.
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Support
            .deletingLastPathComponent()    // StateUITests
            .deletingLastPathComponent()    // Tests
            .appendingPathComponent("Fixtures")
    }

    /// `lib/StateUI/Sources`.
    static var sources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Support
            .deletingLastPathComponent()    // StateUITests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI
            .appendingPathComponent("Sources")
    }

    /// The repository root, for the few checks that are about the BUILD rather
    /// than about the code - a manifest, a script.
    static var repository: URL {
        sources
            .deletingLastPathComponent()    // StateUI
            .deletingLastPathComponent()    // lib
            .deletingLastPathComponent()    // the repository
    }

    /// Every file under `root`, as a path relative to it written with forward
    /// slashes, sorted - never entering a directory whose relative path
    /// `enters` refuses.
    ///
    /// Walked directory by directory rather than with `FileManager`'s
    /// enumerator: on Windows its `skipDescendants()` stops the walk entering
    /// any directory after the first one it skips, so a guard reads the first
    /// few files and nothing else.
    static func files(under root: URL, entering enters: (String) -> Bool) throws -> [String] {
        var found: [String] = []
        var pending = [""]

        while let directory = pending.popLast() {
            let url = directory.isEmpty ? root : root.appendingPathComponent(directory)
            let entries = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey])

            for entry in entries {
                let relative = directory.isEmpty ? entry.lastPathComponent : "\(directory)/\(entry.lastPathComponent)"

                if try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                    if enters(relative) { pending.append(relative) }
                } else {
                    found.append(relative)
                }
            }
        }

        return found.sorted()
    }

    /// Every C# source of the MAUI host, `lib/StateUI.Maui/Sources`, for the
    /// guards that read both languages - a name leaves Swift as a token and
    /// arrives there as a lookup, so only a reader of both can hold the two
    /// together.
    static func mauiSources() throws -> [(path: String, text: String)] {
        let root = repository.appendingPathComponent("lib/StateUI.Maui/Sources")
        var found: [(path: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw WalkReadAlmostNothing(root: root.path, read: 0)
        }

        for case let name as String in walk where name.hasSuffix(".cs") {
            // obj/ holds generated copies, and on a machine that has built for
            // four platforms four stale copies of everything besides.
            let path = name.replacingOccurrences(of: "\\", with: "/")
            if path.hasPrefix("obj/") || path.hasPrefix("bin/") { continue }

            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            found.append((path: path, text: text))
        }

        return try refusingAlmostNothing(found.sorted { $0.path < $1.path }, readFrom: root, moreThan: 50)
    }

    static var updating: Bool {
        ProcessInfo.processInfo.environment["STATEUI_UPDATE_FIXTURES"] == "1"
    }

    /// Checks a binary message and its readable sidecar against their
    /// fixtures, or writes both when updating.
    ///
    /// `name` carries no extension - `act-calls/Focus` is checked against
    /// `Focus.bin`, the CONTRACT a host reads, and `Focus.txt`, the
    /// rendering a review diff reads. It may name a subdirectory, which is
    /// created if it is not there. Both files are compared: a sidecar that
    /// drifted from its bytes would lie to exactly the reader it exists for.
    static func check(
        _ bytes: [UInt8],
        sidecar: String,
        against name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let binary = directory.appendingPathComponent(name + ".bin")
        let text = directory.appendingPathComponent(name + ".txt")

        if updating {
            try FileManager.default.createDirectory(
                at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(bytes).write(to: binary)
            try sidecar.write(to: text, atomically: true, encoding: .utf8)
            return
        }

        let hint = """
            Either something broke, or the format changed on purpose - in which
            case run the tests again with STATEUI_UPDATE_FIXTURES=1 and inspect
            both the binary fixture and its readable sidecar.
            """

        XCTAssertEqual(
            Data(bytes), try Data(contentsOf: binary),
            "The bytes no longer match \(name).bin.\n\n\(hint)",
            file: file, line: line)

        XCTAssertEqual(
            sidecar, try String(contentsOf: text, encoding: .utf8),
            "The rendering no longer matches \(name).txt.\n\n\(hint)",
            file: file, line: line)
    }

    /// Every property name a source file sets, read out of the file itself.
    ///
    /// A regex over source code is a poor way to know anything, and this is the
    /// one place it earns its keep: it is a TEST reading the library next to it,
    /// and it can only ever under-report. A key it fails to see is a key nothing
    /// insists on covering - never a false failure, and never anything the
    /// library does at run time.
    ///
    /// BOTH ways a property is written, because under-reporting is exactly what
    /// went wrong: a modifier that sets two things at once cannot chain
    /// `setValue`, so it writes `props[…]` inside `modified` - and a scanner
    /// looking only for `setValue` waved it through. The sources write TOKENS
    /// since the dictionary round, and a Prop token's member spelling IS the
    /// property name, so the scan reads the member.
    /// THREE ways, and the third is the one a scan can miss: a type that is
    /// not a `PropertyContainer` cannot write `setValue`, so it writes into
    /// `props` directly - a `Window`'s properties, a menu item's - and the
    /// subscript is therefore read as well, without a leading dot, which is
    /// also how the properties a PAGE contributes (`props[.title]` on a local
    /// dictionary in Application.swift) are seen.
    ///
    /// A member written with its contract counts in the same places -
    /// `setValue(VisualElementContract.opacity, …)`, `$0.write(ViewContract.tapCount, …)`,
    /// `$0.describe(…)`, `props[….token]` - resolved against the library's
    /// contracts, so the kind a contract declares, not the spelling, says it
    /// is a property.
    static func propertyKeys(in file: String) throws -> Set<String> {
        propertyKeys(inSource: try text(in: file))
    }

    /// `propertyKeys(in:)` over a source's text, for a guard that reads every
    /// source once.
    static func propertyKeys(inSource text: String) -> Set<String> {
        // COMMENTS FIRST. The doc above every modifier quotes the spellings it
        // is about, and a scan that reads them would claim a property is
        // declared because a sentence mentioned it.
        let source = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        return Set(source.occurrences(between: "setValue(.", and: ","))
            .union(source.words(before: "set(.", upTo: ","))
            .union(source.occurrences(between: "props[.", and: "]"))
            .union(members(of: .property, in: source,
                           after: #"\b(?:setValue|set|write|describe)\(\s*|props\[\s*"#))
    }

    /// Every EVENT a source file subscribes - `addHandler(.scrollYChanged)`,
    /// or the member with its contract, `onEvent(ViewContract.tapped, …)` and
    /// `addHandler(ViewContract.tapped.token, …)`, resolved as `propertyKeys`
    /// resolves one.
    ///
    /// The sibling of `propertyKeys`, and the reason it exists: a modifier
    /// whose whole body is an `addHandler` writes no property, so the modifier
    /// guard cannot see it at all. Two reached the shelf that way.
    static func handlerKeys(in file: String) throws -> Set<String> {
        handlerKeys(inSource: try text(in: file))
    }

    /// `handlerKeys(in:)` over a source's text.
    static func handlerKeys(inSource text: String) -> Set<String> {
        let source = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        // Character-wise, the way `nodeTypes` reads its members: the token ends
        // at the first character an identifier cannot hold. Reading up to the
        // closing parenthesis instead swallowed whole multi-line closures.
        var events: Set<String> = []
        var rest = Substring(source)

        while let found = rest.range(of: "addHandler(.") {
            rest = rest[found.upperBound...]
            let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

            if !name.isEmpty { events.insert(String(name)) }
        }

        return events.union(members(of: .event, in: source, after: #"\b(?:addHandler|onEvent)\(\s*"#))
    }

    /// Every library member of `kind` a source names right after one of the
    /// `openers` - `setValue(VisualElementContract.opacity`. The contract is
    /// found by its type's name among `LibraryContracts.all` and the member by
    /// its name there, so a name no library contract declares is no member.
    private static func members(of kind: MemberFacts.Kind, in source: String, after openers: String) -> Set<String> {
        let regex = try! NSRegularExpression(pattern: "(?:\(openers))(\\w+)\\.(\\w+)")
        var found: Set<String> = []

        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            let contract = String(source[Range(match.range(at: 1), in: source)!])
            let member = String(source[Range(match.range(at: 2), in: source)!])

            if libraryKinds[contract]?[member] == kind { found.insert(member) }
        }

        return found
    }

    /// Every library member's kind, under its contract type's name and its
    /// own: `libraryKinds["VisualElementContract"]?["opacity"] == .property`.
    private static let libraryKinds: [String: [String: MemberFacts.Kind]] = {
        var kinds: [String: [String: MemberFacts.Kind]] = [:]

        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members {
                kinds[String(describing: contract), default: [:]][member.name] = member.facts.kind
            }
        }

        return kinds
    }()

    /// Every node type a source file describes: each node it builds, built
    /// through its contract - `Node(contract: LabelContract.self)` - the one
    /// road a library source builds a node by
    /// (`testEveryNodeIsBuiltThroughItsContract`). A contract is named for its
    /// node type with `Contract` after it (`testEveryNodeTypeIsItsContractsName`),
    /// so the scan takes the suffix off; a name without it, a generic slot's
    /// `Slot.self`, is no contract the scan can read.
    ///
    /// Read TWICE, the second time with every space and newline taken out: a
    /// call wrapped over two lines is the same call, and a type visible only
    /// in the wrapped form would be one no guard ever asked about.
    static func nodeTypes(in file: String) throws -> Set<String> {
        nodeTypes(inSource: try text(in: file))
    }

    /// `nodeTypes(in:)` over a source's text.
    static func nodeTypes(inSource source: String) -> Set<String> {
        let squeezed = source.components(separatedBy: .whitespacesAndNewlines).joined()
        var types: Set<String> = []

        for read in [source, squeezed] {
            var rest = Substring(read)

            while let range = rest.range(of: "Node(contract:") {
                rest = rest[range.upperBound...].drop { $0 == " " }
                let name = rest.prefix { $0.isLetter || $0.isNumber }

                if name.hasSuffix("Contract"), rest.dropFirst(name.count).hasPrefix(".self") {
                    types.insert(String(name.dropLast("Contract".count)))
                }
            }
        }

        return types
    }

    /// One of the library's own source files, read as text - found by its name
    /// wherever it sits, the names being unique across the sources, or by its
    /// path under the sources, `Views/Label.swift`.
    static func text(in file: String) throws -> String {
        let found = try allSources().filter { $0.path == file || $0.path.hasSuffix("/" + file) }
        guard found.count == 1, let source = found.first else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(file): \(found.count) found"])
        }

        return source.text
    }

    /// A source's file name, without the folders it stands in: `Core/Tokens.swift` is `Tokens.swift`.
    static func name(of path: String) -> String {
        String(path.split(separator: "/").last ?? "")
    }

    /// The names one vocabulary's tokens stand for, read off Tokens.swift:
    /// a token stands under its member's name, and a node type's is that name
    /// capitalized - `"Prop"` answers `fontSize`, `"NodeType"` answers `Label`.
    static func tokenNames(of vocabulary: String) throws -> Set<String> {
        tokenNames(of: vocabulary, in: try text(in: "Tokens.swift"))
    }

    /// The same, read off the text of Tokens.swift a caller already holds.
    static func tokenNames(of vocabulary: String, in source: String) -> Set<String> {
        var names: Set<String> = []
        var inside = false

        for line in source.split(separator: "\n") {
            let code = line.trimmingCharacters(in: .whitespaces)

            if code == "@_spi(Host) public extension \(vocabulary) {" {
                inside = true
            } else if inside, code == "}" {
                inside = false
            } else if inside, code.hasPrefix("static let "), let equals = code.range(of: " = ") {
                let member = code[code.index(code.startIndex, offsetBy: "static let ".count)..<equals.lowerBound]
                    .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                names.insert(vocabulary == "NodeType" ? member.prefix(1).uppercased() + member.dropFirst() : member)
            }
        }

        return names
    }

    /// Every one of the library's sources, wherever it sits.
    ///
    /// Found by walking, not listed - the same rule the build follows, so a new
    /// subdirectory is covered without anything being told about it.
    ///
    /// The path is reported with FORWARD slashes on every platform. The walk
    /// yields `Bridge\Exports.swift` on Windows, and a caller comparing against
    /// a written path - `hasSuffix("/Exports.swift")`, which is how the
    /// one file allowed to declare `@_cdecl` is recognized - then matches
    /// nothing and names that very file as the offender.
    static func allSources() throws -> [(path: String, text: String)] {
        let root = sources
        var found: [(path: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw WalkReadAlmostNothing(root: root.path, read: 0)
        }

        for case let name as String in walk where name.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            found.append((path: name.replacingOccurrences(of: "\\", with: "/"), text: text))
        }

        return try refusingAlmostNothing(found.sorted { $0.path < $1.path }, readFrom: root, moreThan: 150)
    }

    /// Every Swift runtime's sources: the core's host layer, `Sources/Host`,
    /// and the package of each Swift host, for the guards that hold every
    /// runtime to one architecture. A path is relative to `lib/` and written
    /// with forward slashes - `StateUI/Sources/Host/Motion/Animator.swift`.
    static func runtimeSources() throws -> [(path: String, text: String)] {
        let lib = repository.appendingPathComponent("lib")
        let roots = ["StateUI/Sources/Host", "StateUI.AppKit/Sources"]
        var found: [(path: String, text: String)] = []

        for root in roots {
            let url = lib.appendingPathComponent(root)
            for file in try files(under: url, entering: { _ in true }) where file.hasSuffix(".swift") {
                let text = try String(contentsOf: url.appendingPathComponent(file), encoding: .utf8)
                found.append((path: "\(root)/\(file)", text: text))
            }
        }

        return try refusingAlmostNothing(found.sorted { $0.path < $1.path }, readFrom: lib, moreThan: 35)
    }

    /// Every active test source, so a guard can ask whether some test names a
    /// thing across the core, Gallery, and AppKit host suites.
    static func testSources() throws -> [(path: String, text: String)] {
        var found: [(path: String, text: String)] = []

        let targets = [
            ("StateUITests", repository.appendingPathComponent("lib/StateUI/Tests/StateUITests")),
            ("GalleryTests", repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests")),
            ("StateUIAppKitTests", repository.appendingPathComponent("lib/StateUI.AppKit/Tests")),
        ]

        for (target, root) in targets {

            guard let walk = FileManager.default.enumerator(atPath: root.path) else {
                throw WalkReadAlmostNothing(root: root.path, read: 0)
            }

            for case let name as String in walk where name.hasSuffix(".swift") {
                let text = try String(
                    contentsOf: root.appendingPathComponent(name), encoding: .utf8)
                found.append((
                    path: "\(target)/\(name.replacingOccurrences(of: "\\", with: "/"))",
                    text: text))
            }
        }

        return try refusingAlmostNothing(found.sorted { $0.path < $1.path }, readFrom: repository, moreThan: 90)
    }

    /// Every fixture sidecar - the readable half of the deterministic wire
    /// contract.
    static func fixtureSidecars() throws -> [String] {
        let root = directory
        var found: [String] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            throw WalkReadAlmostNothing(root: root.path, read: 0)
        }

        for case let name as String in walk where name.hasSuffix(".txt") {
            found.append(try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8))
        }

        return try refusingAlmostNothing(found, readFrom: root, moreThan: 80)
    }

    /// Node types described under Views/ that are not VIEWS.
    ///
    /// A SwipeAction is an action a swipe reveals - a caption, a picture and
    /// something to run - and SwipeActions is the collection holding them.
    /// Neither can be built on its own, placed anywhere else, or styled, so
    /// neither has a fixture of its own nor a StyleTarget conformance. They are
    /// described in SwipeView.swift because that is the only place they appear,
    /// and their modifiers are exercised by the SwipeView case, which builds
    /// both.
    ///
    /// A ToolbarItem and the menu types are items too - a caption, a picture
    /// and something to run - and they belong to a PAGE rather than sitting in
    /// one, so they have no fixture and no style. Their modifiers are exercised
    /// by `PageBarTests`, which is where a page is described.
    ///
    /// A Span is one run of text inside a Label - text and a font, and no
    /// opacity, no margin, no size - so it can neither be built alone nor
    /// styled. Spans is the collection holding the runs, exactly as
    /// SwipeActions holds swipe items. Both are exercised by the Label case,
    /// which builds them.
    ///
    /// The alternative would be leaving SwipeView.swift out of the scan
    /// altogether, the way the page arrangements are - which would take the
    /// SwipeView with them.
    /// ContextMenu is the one written by a MODIFIER rather than by a type:
    /// `.contextMenu` on any view appends it. It is a menu, not a view - and
    /// the entries in it are the menu bar's, already here. Covered by
    /// ContextMenuTests rather than by a control fixture, for the reason the
    /// toolbar's are: there is no control to build one on.
    /// A Pin is a map's marker - a label, an address and a point - so it
    /// cannot be built alone or styled, and its modifiers are exercised by the
    /// Map case, which builds both.
    static let notViews: Set<String> = [
        "SwipeAction", "SwipeActions",
        "Spans", "Span",
        "ToolbarItem", "Menu",
        "MenuItem", "MenuSeparator",
        "ContextMenu",
        "Pin",
    ]

    /// The files under Views/ that describe controls.
    ///
    /// Application.swift and Style.swift describe the application and the
    /// styles its controls are given - neither a control, and each with tests
    /// of its own; Elements.swift and ViewBuilder.swift describe no type at
    /// all.
    ///
    /// NavigationStack.swift and TabbedView.swift are the same kind of thing: a
    /// PAGE arranges other pages, so there is no control to build one on and
    /// nothing about it can be styled - what they do is a stack and a set of
    /// tabs, and NavigationStackTests and TabbedViewTests are where those are
    /// checked. ModalStack.swift arranges pages too, over the
    /// window rather than inside it.
    ///
    /// Elements.swift STAYS IN, describing no type of its own: its property
    /// keys are the shared tier, which `testEveryModifierIsExercised` reads
    /// and `testTheSharedTierIsCoveredOnce` unwraps a case for. Skipping it
    /// would leave three guards asking about nothing.
    ///
    /// The walk RECURSES, as the build's own glob does: a control added in a
    /// folder under Views/ compiles, and one this could not see would be a
    /// control no guard ever asked about.
    static func controlSources() throws -> [String] {
        let views = sources.appendingPathComponent("Views")
        let skipped: Set = [
            "Application.swift", "Style.swift", "ViewBuilder.swift",
            "NavigationStack.swift", "TabbedView.swift", "SplitView.swift",
            "ModalStack.swift",
        ]

        guard let walk = FileManager.default.enumerator(atPath: views.path) else {
            throw WalkReadAlmostNothing(root: views.path, read: 0)
        }
        var found: [String] = []

        for case let name as String in walk {
            let path = name.replacingOccurrences(of: "\\", with: "/")

            guard path.hasSuffix(".swift"), !skipped.contains(path) else { continue }

            found.append(path)
        }

        return try refusingAlmostNothing(found.sorted(), readFrom: views, moreThan: 40)
    }

    /// What a walk found, refused unless it read more than `floor` files - a
    /// floor well under what the tree holds, so a walk that moved or filters
    /// everything out fails where it is read.
    private static func refusingAlmostNothing<Found>(
        _ found: [Found], readFrom root: URL, moreThan floor: Int
    ) throws -> [Found] {
        guard found.count > floor else { throw WalkReadAlmostNothing(root: root.path, read: found.count) }

        return found
    }
}

extension String {
    /// Every piece of text between an opening marker and the next closing one.
    /// An empty opening marker means "from here". The ONE copy of this helper,
    /// internal so BridgeTests and the token guard read with the same eyes.
    /// The same, but only where `opening` starts a WORD.
    ///
    /// `set(.` is the private setter a type that cannot write `setValue` keeps
    /// - and it is also the tail of `offset(.` and `inset(.`, which set
    /// nothing. Requiring the character before it to be one an identifier
    /// cannot contain is what tells the two apart.
    func words(before opening: String, upTo closing: String) -> [String] {
        var found: [String] = []
        var rest = Substring(self)

        while let start = rest.range(of: opening) {
            let previous = rest[..<start.lowerBound].last
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: closing) else { break }

            if previous == nil || !(previous!.isLetter || previous!.isNumber || previous! == "_") {
                found.append(String(rest[..<end.lowerBound]))
            }

            rest = rest[end.upperBound...]
        }

        return found
    }

    func occurrences(between opening: String, and closing: String) -> [String] {
        var found: [String] = []
        var rest = Substring(self)

        while true {
            if opening.isEmpty {
                guard let end = rest.range(of: closing) else { break }
                found.append(String(rest[..<end.lowerBound]))
                return found
            }

            guard let start = rest.range(of: opening) else { break }
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: closing) else { break }
            found.append(String(rest[..<end.lowerBound]))
            rest = rest[end.upperBound...]
        }

        return found
    }
}

extension HostPatch {
    /// The child patch for an identity, or nil when the message says nothing
    /// about it - which is the usual answer and the one worth asserting.
    func child(_ id: ElementId) -> HostPatch? {
        children.first { $0.id == id }
    }

    func child(_ id: String) -> HostPatch? { child(.manual(id)) }

    var propNames: [Prop] { props.keys.sorted() }
}

extension ElementId: CustomStringConvertible {
    public var description: String {
        switch self {
        case .auto(let value): return "\(value)"
        case .manual(let value): return "\"\(value)\""
        }
    }
}

/// A label, as short as the tests need one.
func label(_ text: String, id: String? = nil) -> Node {
    Node(type: "Label", id: id, props: ["text": .string(text)])
}

/// A button with a click handler, for the tests about handler ids.
func button(_ text: String, id: String? = nil, onClicked: @escaping EventHandler) -> Node {
    var node = Node(type: "Button", id: id, props: ["text": .string(text)])
    node.events["clicked"] = onClicked
    return node
}

func stack(_ children: [Node], id: String? = nil) -> Node {
    Node(type: "VStack", id: id, children: children)
}

/// Runs the closure with the system theme set to `theme`, and puts back
/// whatever it was.
///
/// The theme is what the differ reads as it builds an element wearing a pair
/// - see Types/Color.swift - so this is how a test asks for the other half.
/// The provider is the one the host pushes into, which is exactly what a real
/// theme change writes.
func withTheme(_ theme: Theme, _ body: () -> Void) {
    let held = StandardEnvironment.app.requestedTheme
    StandardEnvironment.app.requestedTheme = theme
    defer { StandardEnvironment.app.requestedTheme = held }

    body()
}

/// Says where a number stands, the way the HOST says it: through the batch the
/// boundary actually carries, so a test walks the path a report walks rather
/// than a shortcut of its own.
///
/// - Parameters:
///   - number: which number, by the number it was issued.
///   - lanes: the value, lane by lane.
///   - mask: which of those lanes are being said. All of them, unless said.
func moved(_ number: Int32, to lanes: [Double], mask: UInt64 = ~0) {
    told(number, .lanes(lanes), mask: mask)
}

/// Says where the user SCROLLED a scroller to, the way the HOST says it for a
/// journey the user moved: where it is AND where it is going, both lanes of
/// each, and standing still - laid into the whole shape of the image, with the
/// law, the waiter and the stop counter left as they were.
///
/// - Parameters:
///   - number: which number, by the number it was issued.
///   - point: where the user left the offset.
func slid(_ number: Int32, to point: Point) {
    var lanes = [Double](repeating: 0, count: 11)

    lanes[0] = point.x
    lanes[1] = point.y
    lanes[2] = point.x
    lanes[3] = point.y

    moved(number, to: lanes, mask: 0b111111)
}

/// Says what the user TYPED into a field the host carries the text of, the
/// way the host says it: the words whole, every lane named.
///
/// - Parameters:
///   - number: which number, by the number it was issued.
///   - text: what was typed.
func typed(_ number: Int32, _ text: String) {
    told(number, .text(text), mask: ~0)
}

/// One state's write, in the batch the boundary carries.
private func told(_ number: Int32, _ value: StateCarried, mask: UInt64) {
    var bytes: [UInt8] = []

    func put(_ value: UInt64, _ width: Int) {
        for byte in 0..<width { bytes.append(UInt8((value >> (byte * 8)) & 0xFF)) }
    }

    let payload = StateImage.bytes(of: value)

    put(1, 2)
    put(UInt64(UInt32(bitPattern: number)), 4)
    put(mask, 8)
    put(UInt64(payload.count), 4)
    bytes += payload

    bytes.withUnsafeBufferPointer { _ = Renderer.shared.cycleWritten($0) }
}

/// The same, for the one-lane values a scroller and a drag report.
func moved(_ number: Int32, to value: Double) {
    moved(number, to: [value], mask: 1)
}

/// Says where a THUMB was dragged to, the way the host's tie says it for a
/// value it walks as a journey: the value and its destination together, and a
/// speed of nought - so nothing is left to travel.
func dragged(_ number: Int32, to value: Double) {
    moved(number, to: [value, value, 0, 0, 0, 0, 0, 0], mask: 0b111)
}

/// What a state holds, read back the way the host reads it.
///
/// - Parameters:
///   - number: which number, by the number it was issued.
///   - kind: what to read it as.
/// - Returns: the value, or nothing where the state has gone or the bytes do not
///   make one.
func standing<Value: StateValue>(_ number: Int32, as kind: Value.Type) -> Value? {
    var out = [UInt8](repeating: 0, count: 1 << 16)

    let written = out.withUnsafeMutableBufferPointer {
        Renderer.shared.cycleRead(number, into: $0)
    }

    // [count: U16] then [number: I32][mask: U64][length: U32] and the bytes.
    guard written > 18 else { return nil }

    var length = 0

    for shift in 0..<4 { length |= Int(out[14 + shift]) << (shift * 8) }

    guard 18 + length <= written else { return nil }

    return Value(carried: StateImage.carried(of: Array(out[18..<(18 + length)]), lanes: Value.lanes))
}
