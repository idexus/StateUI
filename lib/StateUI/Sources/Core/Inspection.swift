// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT EACH RENDER COST AND WHAT IT BUILT, kept while an inspector is open.
//
// The renderer opens a PASS around every render and the differ writes an ENTRY
// for every composed view it reaches: BUILT, with the reason it could not be
// carried; CARRIED whole; or WALKED on the way to one that was built - each
// with the time its element took, the entries under it included and the time
// that was its own. The host adds its half once the message is applied: how
// long reading it and applying it took, per scene, and what that cost in
// controls. Views/Inspector.swift is what shows it.
//
// NOTHING HERE RUNS WHILE NOBODY LOOKS. Every hook in the differ is one read of
// `recording`, false until an inspector opens and false again when it closes or
// pauses - so an application that never opens one pays a branch per composed
// view and nothing else. The one other reader is the host, asked for every
// pass as text (`STATEUI_INSPECT=1`): recording then starts with the first
// render and stays on.
//
// THE INSPECTOR IS NOT ITS OWN SUBJECT. It is a tree like any other, built
// again whenever a pass lands, so its own views are MUTED - their time is kept
// apart and they write no entries - and a pass caused by nothing but its own
// state is not kept at all. Otherwise every pass would record the inspector
// drawing the pass before it.

/// One render, as the inspector shows it.
struct InspectedPass {
    /// Which of the three roads a render took.
    enum Road: Equatable {
        /// Only the views that read what changed were built - the clean walk.
        case walk

        /// The scenes were built again and reconciled against the last tree.
        case build

        /// Everything was described, for a host that lost track of the tree.
        case complete
    }

    /// Counts from 1 for as long as the inspector has been recording - the
    /// passes KEPT, so a pass the inspector caused leaves no gap.
    var number = 0

    /// The generation the message carried - what the host's report names.
    var generation: Int32 = 0

    /// When it happened, in milliseconds since recording began.
    let at: Double

    /// Which road it took.
    let road: Road

    /// What was written since the render before, in the author's own names.
    let causes: [String]

    /// Every composed view it reached, in walk order.
    var entries: [InspectedEntry] = []

    /// Whether entries past `Inspection.most` were left out.
    var truncated = false

    /// Microseconds the differ took, the inspector's own views left out.
    var describe: Double = 0

    /// Microseconds the inspector's own views took inside the differ.
    var own: Double = 0

    /// Microseconds writing the message.
    var encode: Double = 0

    /// How long the message is, in bytes.
    var bytes = 0

    /// The host's half, once it has reported.
    var host: InspectedHost?
}

/// One composed view a render reached.
struct InspectedEntry {
    /// What the render did with it.
    enum Outcome: Equatable {
        /// Built, and the reason it could not be carried.
        case built(String)

        /// Carried whole: not built, not compared, not sent.
        case carried

        /// Neither - walked past on the way to a view below it that was built.
        case walked
    }

    /// How many entries stand above it.
    let depth: Int

    /// The view's type, without its module.
    let view: String

    /// The scene it is in - the element of the entry at depth 0 above it, a
    /// scene's own entry being the outermost a render writes. What an
    /// inspector files the entry under.
    let scene: ElementId?

    /// What the render did with it.
    let outcome: Outcome

    /// Microseconds its element took, the entries under it included.
    var micros: Double = 0

    /// Microseconds that were its own, the entries under it left out.
    var own: Double = 0
}

/// What the host reported about applying one message.
struct InspectedHost {
    /// Microseconds reading the message off the buffer.
    var read: Double

    /// Microseconds applying it to the controls.
    var apply: Double

    /// Nodes the apply walked.
    var nodes: Int

    /// Controls that had to be built.
    var made: Int

    /// Controls found already standing where the message describes them.
    var kept: Int

    /// Controls taken out of a pool and stamped again.
    var adopted: Int

    /// Microseconds each scene's apply took, in the order the application
    /// lists them.
    var scenes: [Double] = []
}

/// The record an inspector reads, and the hooks the renderer and the differ
/// write it through.
///
/// Written only by the thread that renders, which is the one that reads it.
enum Inspection {
    /// Whether anything is being recorded.
    nonisolated(unsafe) static var recording = false

    /// The passes kept, oldest first.
    nonisolated(unsafe) private(set) static var passes: [InspectedPass] = []

    /// How many passes are kept.
    static let kept = 400

    /// How many entries one pass keeps - a complete description of a large
    /// application reaches every composed view it has.
    static let most = 5000

    /// The types of the inspector's own views, module-qualified: muted.
    nonisolated(unsafe) static var ownViews: Set<String> = []

    /// The storages of the inspector's own state: a pass caused by these alone
    /// is the inspector drawing itself, and is not kept.
    nonisolated(unsafe) static var ownStates: Set<ObjectIdentifier> = []

    /// Told whenever a pass lands or the host reports on one.
    nonisolated(unsafe) static var landed: (() -> Void)?

    /// Whether the host takes every pass as text too - `STATEUI_INSPECT=1`,
    /// read on its side. Set by its first `takeLog()`; from then on recording
    /// stays on whatever an inspector's own buttons say.
    nonisolated(unsafe) static var logging = false

    /// The passes written out as text and not yet taken.
    nonisolated(unsafe) private static var log = ""

    /// One composed view the differ is inside.
    private struct Frame {
        let view: String
        let outcome: InspectedEntry.Outcome
        let element: ElementId?
        let began: ContinuousClock.Instant
        let mutedBefore: Double
        let muted: Bool
        var entry: Int?
        var children: Double = 0
    }

    nonisolated(unsafe) private static var stack: [Frame] = []
    nonisolated(unsafe) private static var pass: InspectedPass?
    nonisolated(unsafe) private static var mutedMicros = 0.0
    nonisolated(unsafe) private static var muting = 0
    nonisolated(unsafe) private static var scene: ElementId?
    nonisolated(unsafe) private static var origin = ContinuousClock.now
    nonisolated(unsafe) private static var numbered = 0
    nonisolated(unsafe) private static var waiting: (generation: Int32, scenes: [Double])?

    /// Starts recording afresh.
    static func start() {
        passes.removeAll()
        origin = .now
        numbered = 0
        recording = true
    }

    /// Stops recording, keeping what was recorded - unless the host takes the
    /// passes as text, which keeps it recording.
    static func stop() {
        guard !logging else { return }

        recording = false
        pass = nil
        stack.removeAll()
    }

    /// Forgets every pass.
    static func clear() {
        passes.removeAll()
        landed?()
    }

    // MARK: - The renderer's hooks

    /// Opens the pass one render makes.
    ///
    /// - Parameters:
    ///   - road: which road the render is taking.
    ///   - causes: what was written since the render before, by name.
    static func begin(road: InspectedPass.Road, causes: [String]) {
        pass = InspectedPass(
            at: micros(since: origin) / 1000,
            road: road,
            causes: causes)
        stack.removeAll()
        mutedMicros = 0
        muting = 0
        scene = nil
    }

    /// Closes the pass, and keeps it unless the inspector's own state was all
    /// that caused it.
    ///
    /// - Parameters:
    ///   - generation: what the message carries.
    ///   - describe: microseconds the differ took, the inspector's own views
    ///     included - they are taken out here.
    ///   - encode: microseconds writing the message.
    ///   - bytes: how long the message is.
    ///   - keep: false for a pass the inspector caused.
    static func end(generation: Int32, describe: Double, encode: Double, bytes: Int, keep: Bool) {
        guard var done = pass else { return }

        pass = nil
        stack.removeAll()

        // AND A PASS THAT BUILT NOTHING BUT THE INSPECTOR is its own too, whatever
        // state caused it - a list inside it measuring its rows keeps state of
        // its own, which no model can name.
        guard keep, !(done.entries.isEmpty && done.own > 0) else { return }

        numbered += 1
        done.number = numbered
        done.generation = generation
        done.describe = max(0, describe - done.own)
        done.encode = encode
        done.bytes = bytes

        passes.append(done)

        if passes.count > kept {
            passes.removeFirst(passes.count - kept)
        }

        landed?()
    }

    // MARK: - The differ's hooks

    /// Enters one composed view, and answers whether the caller leaves it.
    ///
    /// A view WALKED past is written down only if something under it is built
    /// or carried - which is when it becomes the path to that view. Anything
    /// under one of the inspector's own views is muted.
    ///
    /// - Parameters:
    ///   - type: the view's type, module-qualified.
    ///   - outcome: what the render is doing with it.
    ///   - element: the element it is - what an entry at depth 0, a scene,
    ///     files everything under it by.
    /// - Returns: whether a frame was opened, which the caller must `leave()`.
    static func enter(
        _ type: String,
        _ outcome: InspectedEntry.Outcome,
        element: ElementId? = nil
    ) -> Bool {
        guard pass != nil else { return false }

        let muted = muting > 0 || ownViews.contains(type)

        if muted {
            muting += 1
        }

        var frame = Frame(
            view: short(type),
            outcome: outcome,
            element: element,
            began: .now,
            mutedBefore: mutedMicros,
            muted: muted)

        if !muted, outcome != .walked {
            materialize()
            frame.entry = append(frame.view, outcome, element: element)
        }

        stack.append(frame)

        return true
    }

    /// Leaves the view `enter` last opened a frame for.
    static func leave() {
        guard pass != nil, let frame = stack.popLast() else { return }

        let elapsed = micros(since: frame.began)

        if frame.muted {
            muting -= 1

            if muting == 0 {
                mutedMicros += elapsed
                pass?.own += elapsed
            }

            return
        }

        guard let entry = frame.entry else { return }

        let inclusive = max(0, elapsed - (mutedMicros - frame.mutedBefore))

        pass?.entries[entry].micros = inclusive
        pass?.entries[entry].own = max(0, inclusive - frame.children)

        if let parent = stack.indices.last {
            stack[parent].children += inclusive
        }
    }

    /// Writes an entry for every frame still waiting for one, outermost first,
    /// so the view about to be written down has its path above it.
    private static func materialize() {
        for index in stack.indices where stack[index].entry == nil && !stack[index].muted {
            stack[index].entry = append(
                stack[index].view, stack[index].outcome, element: stack[index].element)
        }
    }

    /// Appends one entry at the depth the stack stands at.
    private static func append(
        _ view: String,
        _ outcome: InspectedEntry.Outcome,
        element: ElementId?
    ) -> Int? {
        guard let count = pass?.entries.count else { return nil }

        guard count < most else {
            pass?.truncated = true
            return nil
        }

        let depth = stack.filter { $0.entry != nil }.count

        if depth == 0 {
            scene = element
        }

        pass?.entries.append(
            InspectedEntry(depth: depth, view: view, scene: scene, outcome: outcome))

        return count
    }

    // MARK: - The host's report

    /// One scene's apply, reported before the message's own.
    ///
    /// - Parameters:
    ///   - generation: the message.
    ///   - index: the scene, in the order the application lists them.
    ///   - micros: how long its apply took.
    static func applied(generation: Int32, scene index: Int, micros: Double) {
        var scenes = waiting?.generation == generation ? waiting!.scenes : []

        while scenes.count <= index {
            scenes.append(0)
        }

        scenes[index] = micros
        waiting = (generation, scenes)
    }

    /// The host's half of one message.
    ///
    /// - Parameters:
    ///   - generation: the message.
    ///   - host: what applying it cost.
    static func applied(generation: Int32, _ host: InspectedHost) {
        var host = host

        if waiting?.generation == generation {
            host.scenes = waiting!.scenes
        }

        waiting = nil

        guard let index = passes.lastIndex(where: { $0.generation == generation }) else {
            return
        }

        passes[index].host = host

        if logging {
            log += text(of: passes[index])
        }

        landed?()
    }

    // MARK: - As text

    /// Every pass the host has reported on since the last call, as text - what
    /// the host writes out beside the tally's lines for `STATEUI_INSPECT=1`.
    /// The first call is the host asking for them: recording starts, and stays
    /// on from then.
    static func takeLog() -> String {
        if !logging {
            logging = true

            if !recording {
                start()
            }
        }

        defer { log = "" }

        return log
    }

    /// One pass as text, the way an inspector shows it: what caused it, the
    /// road it took, what it cost on each side, and every composed view it
    /// reached, indented under the one above it - built with the reason it
    /// could not be carried, carried whole, or walked past.
    static func text(of pass: InspectedPass) -> String {
        let built = pass.entries.filter {
            if case .built = $0.outcome { return true } else { return false }
        }.count
        let carried = pass.entries.filter { $0.outcome == .carried }.count

        var head = "StateUI inspect #\(pass.number) \(pass.road) at \(Int(pass.at)) ms"

        if !pass.causes.isEmpty {
            head += " for " + pass.causes.joined(separator: ", ")
        }

        head += " · Swift \(whole(pass.describe + pass.encode)), \(pass.bytes) bytes"

        if let host = pass.host {
            head += " · C# \(whole(host.read + host.apply)), \(host.nodes) nodes,"
                + " \(host.made) made, \(host.kept) kept, \(host.adopted) adopted"
        }

        var lines = [head + " · \(built) built · \(carried) carried"]

        for entry in pass.entries {
            let indent = String(repeating: "  ", count: entry.depth + 1)

            switch entry.outcome {
            case let .built(reason):
                lines.append("\(indent)● \(entry.view) — \(reason) · "
                    + "\(whole(entry.micros)) (\(whole(entry.own)) own)")
            case .carried:
                lines.append("\(indent)○ \(entry.view) — carried")
            case .walked:
                lines.append("\(indent)· \(entry.view) — walked · \(whole(entry.micros))")
            }
        }

        if pass.truncated {
            lines.append("  … and more than \(most) views, left out")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Microseconds, whole.
    private static func whole(_ micros: Double) -> String {
        "\(Int(micros.rounded())) µs"
    }

    // MARK: - Arithmetic

    /// Microseconds since an instant.
    static func micros(since start: ContinuousClock.Instant) -> Double {
        let (seconds, attoseconds) = start.duration(to: .now).components

        return Double(seconds) * 1_000_000 + Double(attoseconds) / 1_000_000_000_000
    }

    /// A type as an author calls it: no module, no generic arguments, and none
    /// of the context a private type's name carries.
    static func short(_ type: String) -> String {
        let bare = type.split(separator: "<").first.map(String.init) ?? type

        return bare.split(separator: ".").last.map(String.init) ?? bare
    }
}
