// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The C boundary.
//
// Every function crossing into .NET lives here, in ONE file on purpose: @_cdecl
// is an underscored (compiler-private) attribute, so keeping all uses together
// makes a future migration to the official @cdecl a local change. It also keeps
// the exported surface easy to audit - what is here is the entire API .NET can
// reach.
//
// NOTE ON DIRECTION:
// This library knows nothing about any particular application. The app module
// (GalleryUI in the sample) depends on this one, registers its Application
// through stateUIUseApp, and exposes its own @_cdecl entry point for the host
// to call. The dependency runs app -> library and never the other way, which is
// what lets this package be published on its own.
//
// Rules for anything added here:
//   - must be a global function (not a method)
//   - parameters and return types must be representable in C: integers,
//     doubles, pointers - no String, Array, class, generic or throws
//   - memory returned to the caller must have a matching free function

/// Allocates a null-terminated UTF-8 copy of a string.
///
/// Uses allocate rather than strdup so allocation and release happen on the same
/// side of the boundary with the same allocator on every platform. Mixing
/// allocators is a classic source of crashes that only show up under load, and
/// strdup/free is unreliable on Windows where multiple C runtime copies exist.
private func makeCString(_ text: String) -> UnsafeMutablePointer<CChar>? {
    let bytes = Array(text.utf8CString)   // already includes the terminator
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count)
    bytes.withUnsafeBufferPointer { source in
        buffer.initialize(from: source.baseAddress!, count: source.count)
    }
    return buffer
}

/// Builds the current UI tree and returns what changed, in the binary wire
/// format (Core/Wire.swift). Writes the byte count into `length`.
///
/// `baseline` is the generation the caller is holding - the one that came with
/// the last message it applied SUCCESSFULLY, or 0 if it has nothing. A caller
/// still holding the current generation gets a patch; anyone else gets the whole
/// tree, which is how the two sides recover from ever losing track of each
/// other. The reply carries the new generation.
///
/// The `_wire` suffix names the FORMAT, for the reason
/// stateui_take_commands_wire carries it: a half built for another format
/// calls a name that is not here and fails with EntryPointNotFoundException -
/// a clean, nameable error - where one name over two signatures would read a
/// register as a pointer.
///
/// The caller owns the returned memory and must release it with
/// stateui_free_buffer.
@_cdecl("stateui_render_wire")
public func stateui_render_wire(
    _ baseline: Int32,
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.renderWire(baseline: baseline), length)
}

/// Allocates a copy of a wire message for the caller, writing its byte count
/// - the shape both `_wire` exports hand over. Null for an empty message,
/// which only the commands take produces.
private func makeBuffer(
    _ bytes: [UInt8],
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    length?.pointee = Int32(bytes.count)

    guard !bytes.isEmpty else { return nil }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
    bytes.withUnsafeBufferPointer { source in
        buffer.initialize(from: source.baseAddress!, count: source.count)
    }
    return buffer
}

/// Reports that an event fired or an act finished, identified by the id from
/// the tree - positive for an element's event, negative for a completion.
///
/// `bytes` carries the binary payload (Core/Wire.swift): for an event, the
/// typed values the control reported - null for an event with nothing to say -
/// and for a completion, the act's reply. Returns 1 if a handler ran, 0 if the
/// id was unknown - which happens when an event arrives for a tree that has
/// already been replaced, and is not an error.
///
/// The buffer is the caller's and is read before this returns; nothing is
/// kept, so there is nothing to free. The `_wire` suffix names the format, for
/// the reason the other two `_wire` exports carry it: a half built for another
/// format fails with EntryPointNotFoundException - a clean, nameable error -
/// instead of reading bytes as a C string.
@_cdecl("stateui_dispatch_wire")
public func stateui_dispatch_wire(
    _ handlerId: Int32,
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let payload: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    if handlerId < 0 {
        // A reply that cannot be read must still resume the handler waiting
        // on it - as a failure, never a hang. The same reasoning as
        // stateui_fail_taken_commands, one level down.
        ReplyBuffer.current = Wire.decodeReply(payload)
            ?? .failed("the reply from the host could not be read. Usually a "
                + "native library and a runtime built from different versions.")
    } else {
        // An unreadable payload is treated as an empty one: the typed readers
        // find nothing they expect and leave handler and binding alone - the
        // gesture parse rule, applied to the whole buffer.
        EventBuffer.current = Wire.decodePayload(payload) ?? []
    }

    return Renderer.shared.dispatch(Int(handlerId)) ? 1 : 0
}

/// Reports an event the HOST raised by NAME, with no element behind it - the
/// application's own pushes, registered on the C# side and heard by
/// `HostEvents.on`. `bytes` is the host-event layout (Core/Wire.swift): the
/// name, then the typed values.
///
/// Returns how many handlers heard it - zero is an ordinary answer, since the
/// battery reports whether a page is watching or not - and -1 for a buffer
/// that would not read, which the host reports as version skew. The buffer is
/// the caller's and is read before this returns.
@_cdecl("stateui_dispatch_host_event")
public func stateui_dispatch_host_event(
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    guard let event = Wire.decodeHostEvent(buffer) else { return -1 }

    return Int32(HostEvents.dispatch(event.name, event.payload))
}

/// Says where a WALK has got to: one sample of a flight in the air, on the
/// channel the transition named, in the payload layout an event uses.
///
/// Its own export rather than a reply, because a reply is one-shot and ENDS
/// the await - this says nothing about whether the walk is over, and there may
/// be dozens of them before the one message that is. The author asked for
/// these by the millisecond (`animateTo(reporting:every:)`); the host's frames
/// are the host's, and none of them crosses on its own account.
///
/// Returns 1 when a piece of state was waiting for it and 0 when none was,
/// which is the ordinary answer for a sample that crossed a frame after its
/// flight was stopped. The buffer is the caller's and is read before this
/// returns.
@_cdecl("stateui_report_flight")
public func stateui_report_flight(
    _ channel: Int32,
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    // An unreadable sample is a sample skipped: the walk goes on, the next one
    // is a frame away, and nothing about the tree depends on it. The gesture
    // parse rule, applied to a value that is by nature one of many.
    guard let value = Wire.decodePayload(buffer)?.first else { return 0 }

    return Renderer.shared.reported(channel, value) ? 1 : 0
}

/// Hands over the acts queued since the last time, in the binary wire format
/// (Core/Wire.swift), and forgets them. Writes the byte count into `length`
/// and answers null for an empty queue - the common case, every pump,
/// allocating nothing.
///
/// The `_wire` suffix names the FORMAT, and is what makes a mismatch loud: a
/// half built for another format calls a name that is not here and fails with
/// EntryPointNotFoundException - a clean, nameable error - where one name over
/// two signatures would read a register as a pointer.
///
/// The caller owns the returned memory and must release it with
/// stateui_free_buffer.
@_cdecl("stateui_take_commands_wire")
public func stateui_take_commands_wire(
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.takeCommandsWire(), length)
}

/// Which version of the binary wire format this library writes.
///
/// The host asks BEFORE the first render and refuses a mismatch loudly - two
/// halves built from different versions must fail at startup with a sentence,
/// never by reading each other's bytes wrong. A library too old to have this
/// export fails the same check as EntryPointNotFoundException, which is the
/// same sentence one step earlier.
@_cdecl("stateui_wire_version")
public func stateui_wire_version() -> Int32 {
    Int32(Wire.version)
}

/// Releases a buffer either `_wire` export returned. Allocated and freed on
/// this side of the boundary, the stateui_free_string rule.
@_cdecl("stateui_free_buffer")
public func stateui_free_buffer(_ pointer: UnsafeMutableRawPointer?) {
    guard let pointer = pointer else { return }
    pointer.deallocate()
}

/// Reports that the LAST taken batch could not be read at all, so every act in
/// it fails with `reason` - each awaiting handler resumes by throwing instead
/// of staying suspended forever.
///
/// The host cannot name the acts itself: their completion ids are inside the
/// very bytes that would not read, so the take keeps a receipt on this side
/// and this is how the host cashes it. See `Renderer.failTakenCommands`.
@_cdecl("stateui_fail_taken_commands")
public func stateui_fail_taken_commands(_ reason: UnsafePointer<CChar>?) {
    Renderer.shared.failTakenCommands(reason.map { String(cString: $0) } ?? "")
}

/// Says where a channel's value now stands - the platform reporting, with
/// nothing described for it.
///
/// The value is written down and NOTHING else happens: no dependency was ever
/// recorded on it, so no view is rebuilt and no message is packed. What follows
/// it is asked for separately, by `stateui_place`. See Core/Channel.swift.
///
/// - Parameters:
///   - channel: the channel, by the number it rides on.
///   - value: where its value now stands.
@_cdecl("stateui_channel_moved")
public func stateui_channel_moved(_ channel: Int32, _ value: Double) {
    Renderer.shared.moved(channel, to: value)
}

/// Answers where every view of a continuously placed layout goes - the second
/// path into this library, and the one that describes nothing.
///
/// The author's own arithmetic runs once per view, reading whatever channels
/// it reads, and the host writes the numbers onto the controls it is already
/// holding. Nothing is built, nothing is diffed and no message is
/// packed - which is what makes a value that moves with a finger affordable at
/// all.
///
/// ELEVEN DOUBLES A VIEW, in this order: x, y, width, height, translationX,
/// translationY, rotation, scaleX, scaleY, opacity, zIndex.
///
/// The buffer is the CALLER'S and is filled in place, so nothing crosses the
/// boundary but numbers. What this side does spend is the run itself: the
/// arithmetic is asked for every view before any is written, because a drawing
/// ORDER is the whole run's. Measured at 0.066 ms for fifteen cards.
///
/// Answers how many numbers were written, 0 where the rule is one no layout is
/// holding any more, and -1 where the buffer is too small for the count asked
/// about.
///
/// - Parameters:
///   - rule: the arithmetic, by the id the message carried.
///   - count: how many views are being placed.
///   - width: how wide the layout is.
///   - height: how tall the layout is.
///   - into: where to write the numbers.
///   - capacity: how many numbers fit there.
@_cdecl("stateui_place")
public func stateui_place(
    _ rule: Int32,
    _ count: Int32,
    _ width: Double,
    _ height: Double,
    _ into: UnsafeMutablePointer<Double>?,
    _ capacity: Int32
) -> Int32 {
    guard let buffer = into, count > 0,
        let place = Renderer.shared.placement(Int(rule)) else { return 0 }

    let views = Int(count)
    let needed = views * PackedPlacement.fields

    guard needed <= Int(capacity) else { return -1 }

    let room = Rect(0, 0, width, height)

    // THE DRAWING ORDER IS THE WHOLE RUN'S, so the arithmetic is asked for all
    // of them before any is written: what the host is told is each view's RANK
    // rather than the number the author answered, which is the same picture
    // and changes only when two views swap. See Placement.drawingOrder.
    let placements = (0..<views).map { place($0, views, room) }
    let order = Placement.drawingOrder(of: placements)

    for index in 0..<views {
        var placement = placements[index]
        placement.zIndex = order[index]

        PackedPlacement.write(
            placement,
            into: buffer,
            at: index * PackedPlacement.fields)
    }

    return Int32(needed)
}

/// Whether the tree changed since the last render, so the host knows if it
/// needs to ask for a new one. Returns 1 when a re-render is needed.
@_cdecl("stateui_needs_render")
public func stateui_needs_render() -> Int32 {
    Renderer.shared.needsRender ? 1 : 0
}

/// Runs whatever a suspended handler has waiting, and returns how many jobs ran.
///
/// This is where a handler comes back to life after an `await`. The host calls it
/// on the thread MAUI draws on, after reporting that an act has finished - the
/// job a resume produces does not exist yet when the report returns, so a host
/// that gets 0 should ask again on its next turn.
///
/// Anything the handler does - a state write, another act - happens inside this
/// call, so the host renders and drains the command queue afterwards exactly as
/// it does after an event.
///
/// Deliberately a call INTO this library rather than a callback out of it: a
/// resume arrives on a cooperative-pool thread, and entering .NET from a thread
/// it has never seen deadlocks Mono when a debugger is attached. See
/// Core/MainThread.swift.
@_cdecl("stateui_run_jobs")
public func stateui_run_jobs() -> Int32 {
    Int32(stateUIRunJobs())
}

/// How many handlers have been told their act is over and have not come back yet.
///
/// The host reports an outcome, gets 0 from `stateui_run_jobs` because the
/// resumed job does not exist yet, and needs to know whether to ask again. Above
/// zero it is still owed work; at zero there is nothing to wait for. That turns a
/// retry limit into a condition, which is the difference between a host that
/// gives up too early under load and one that does not.
@_cdecl("stateui_resumes_pending")
public func stateui_resumes_pending() -> Int32 {
    Int32(Renderer.shared.resumesPending)
}

/// Parks the calling thread until work lands, and returns how much is waiting
/// - jobs in the queue PLUS commands not yet taken - which can be 0, when
/// another drain got there first.
///
/// This is how a job NO command produced still runs promptly: a `Task.sleep`
/// coming due, a task an author started finishing. And the other way round -
/// the commands in the count are how a COMMAND no job announces is still
/// performed promptly: an act queued from a plain `Task` runs on the pool,
/// puts nothing on the executor, and `send`'s poke is the only thing that
/// says it exists. The host gives this library a thread - one it CREATED, so
/// the .NET runtime has always known it, which is the whole Mono constraint -
/// and that thread spends its life parked here. When it returns, the host
/// posts one drain onto its UI thread through its own dispatcher and calls
/// back in.
///
/// Nothing is ever run on this thread; it is a doorbell, not a worker.
@_cdecl("stateui_wait_work")
public func stateui_wait_work() -> Int32 {
    // A DIRTY TREE is work too. A write made inside something the host is
    // already driving - an event, a completed act, a flight booked on
    // `@MainThread` - is rendered by the drain that follows. A write a
    // `Task.detached` or an `async let` child makes from the cooperative pool
    // queues NOTHING: no job, no command, only the dirty flag and the wake
    // `stateChanged` makes - so without the dirty tree in this count the wake
    // finds no work and the screen waits for the next event.
    Int32(MainThreadExecutor.shared.waitForWork()
        + Renderer.shared.commandsPending
        + (Renderer.shared.needsRender ? 1 : 0))
}

/// How many jobs are sitting in the queue, waiting for stateui_run_jobs.
///
/// The other half of what `stateui_resumes_pending` says. A handler suspended
/// on its own child tasks - `async let` - resumes through a job that no
/// completion accounting can see, since what it awaited was never a host
/// command. Above zero there is work to run RIGHT NOW; the pending count says
/// work is still coming. A host that polls only the second gives up exactly one
/// job too early, which reads as an animation loop frozen mid-beat.
@_cdecl("stateui_jobs_pending")
public func stateui_jobs_pending() -> Int32 {
    Int32(MainThreadExecutor.shared.pendingCount)
}

/// Tells this library what the host knows - one standard provider's values
/// per call, in the environment layout (Core/Wire.swift): the version, the
/// domain byte, then the typed values in the order the provider declares its
/// properties. Called for every domain BEFORE the first render, so the first
/// tree already knows its idiom and its locale, and again whenever a platform
/// event says something moved - which is what rebuilds exactly the views that
/// read the changed provider. See Types/HostEnvironment.swift.
///
/// Returns 1 applied; 0 for a domain this library does not know or a payload
/// of the wrong shape, refused whole; -1 for a buffer that would not read.
/// The host reports either failure once, as version skew. The buffer is the
/// caller's and is read before this returns.
@_cdecl("stateui_set_environment")
public func stateui_set_environment(
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    guard let push = Wire.decodeEnvironment(buffer) else { return -1 }

    return StandardEnvironment.apply(domain: push.domain, values: push.payload) ? 1 : 0
}

/// Announces which store the application keeps state in and every key it keeps
/// there, so the host can read exactly those. Writes the byte count into
/// `length`.
///
/// Called ONCE, after the app registers and before the first render - the only
/// moment where the application exists and no view has been built yet, which is
/// what the hydration below has to happen inside. An application that keeps
/// nothing answers a null pointer and a count of 0.
///
/// The caller owns the returned memory and must release it with
/// stateui_free_buffer.
@_cdecl("stateui_persistent_keys")
public func stateui_persistent_keys(
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.persistentWire(), length)
}

/// Takes what the host read out of the store: a name and a value for each key
/// it FOUND, in the layout at `Wire.decodePersistent`.
///
/// Called once, before the first render, so a `@State` declared with one of
/// these keys already holds the kept value the first time anything reads it.
/// A key the store had nothing under is absent from the buffer, and the state
/// keeps the value written beside it.
///
/// Returns 1 applied, -1 for a buffer that would not read - which the host
/// reports once as version skew. The buffer is the caller's and is read before
/// this returns.
@_cdecl("stateui_set_persistent")
public func stateui_set_persistent(
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    guard let found = Wire.decodePersistent(buffer) else { return -1 }

    PersistentStore.shared.hydrate(found)

    return 1
}

/// Releases a string any export here returned - stateui_platform is the
/// only one that allocates this way.
@_cdecl("stateui_free_string")
public func stateui_free_string(_ pointer: UnsafeMutablePointer<CChar>?) {
    guard let pointer = pointer else { return }
    pointer.deallocate()
}

/// Reports which platform the Swift side was compiled for.
///
/// Useful as a smoke test: if this returns the expected platform, the native
/// library really was built for the target and loaded correctly. Available to
/// Swift code as `stateUIPlatform()`, which is the same string without the
/// trip across the boundary.
@_cdecl("stateui_platform")
public func stateui_platform() -> UnsafeMutablePointer<CChar>? {
    makeCString(stateUIPlatform())
}

/// Which platform and architecture this library was compiled for.
public func stateUIPlatform() -> String {
    #if os(Windows)
        let name = "Windows"
    #elseif os(Android)
        let name = "Android"
    #elseif targetEnvironment(macCatalyst)
        let name = "Mac Catalyst"
    #elseif os(iOS)
        #if targetEnvironment(simulator)
            let name = "iOS Simulator"
        #else
            let name = "iOS"
        #endif
    #elseif os(macOS)
        let name = "macOS"
    #elseif os(Linux)
        let name = "Linux"
    #else
        let name = "unknown"
    #endif

    #if arch(arm64)
        let arch = "arm64"
    #elseif arch(x86_64)
        let arch = "x86_64"
    #else
        let arch = "unknown"
    #endif

    return "\(name) (\(arch))"
}
