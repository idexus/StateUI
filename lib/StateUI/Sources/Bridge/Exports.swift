// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The C boundary: every function a runtime in another language calls, in one
// file. C types only, and memory returned to the caller has a matching free.
// Design: docs/design/core/bridge.md#one-file-of-exports

/// A null-terminated UTF-8 copy of a string, allocated here to be freed here.
/// Design: docs/design/core/bridge.md#memory-is-freed-where-it-was-allocated
private func makeCString(_ text: String) -> UnsafeMutablePointer<CChar>? {
    let bytes = Array(text.utf8CString)   // already includes the terminator
    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count)
    bytes.withUnsafeBufferPointer { source in
        buffer.initialize(from: source.baseAddress!, count: source.count)
    }
    return buffer
}

// Design: docs/design/core/bridge.md#the-wire-suffix
/// Renders and returns what changed as Wire bytes (Wire.swift), writing the
/// byte count into `length`.
///
/// `baseline` is the generation of the last message the caller applied in full,
/// or 0 for none. A caller holding the current generation gets a patch; anyone
/// else gets the whole tree. The caller releases the buffer with
/// `stateui_free_buffer`.
@_cdecl("stateui_render_wire")
public func stateui_render_wire(
    _ baseline: Int32,
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.renderWire(baseline: baseline), length)
}

/// A copy of a message for the caller, with its byte count; null for an empty one.
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

/// Reports that an event fired or an act finished, by the id from the tree -
/// positive for an element's event, negative for a completion - with `bytes` the
/// event's payload or the act's reply, as Wire values.
///
/// Returns 1 if a handler ran and 0 for an unknown id, which is not an error. The
/// buffer is read before this returns.
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
        // A reply that cannot be read still resumes its handler, as a failure.
        ReplyBuffer.current = Wire.decodeReply(payload)
            ?? .failed("the reply from the host could not be read. Usually a "
                + "native library and a runtime built from different versions.")
    } else {
        // An unreadable payload reads as empty: the typed readers leave everything alone.
        EventBuffer.current = Wire.decodePayload(payload) ?? []
    }

    return Renderer.shared.dispatch(Int(handlerId)) ? 1 : 0
}

/// Reports an event the host raised by name, with no element behind it - heard by
/// `HostEvents.on`. `bytes` is the host-event layout: the name, then the values.
///
/// Returns how many handlers heard it - zero is an ordinary answer - and -1 for a
/// buffer that would not read. The buffer is read before this returns.
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

/// Tells the core what the host realizes - the elements it makes a view for
/// and the members it realizes on each - in the layout
/// `Wire.encodeRealization` writes. Answers 0, or -1 for a buffer that would
/// not read, which leaves what the core knew as it was.
///
/// The buffer is read before the call returns, so nothing is pinned past it
/// and nothing is freed.
@_cdecl("stateui_set_realization_wire")
public func stateui_set_realization_wire(
    _ bytes: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    guard let realization = Wire.decodeRealization(buffer) else { return -1 }

    StateUIHost.setRealization(realization)
    return 0
}

/// Hands over the acts queued since the last call as Wire bytes and forgets them,
/// writing the byte count into `length`; null for an empty queue. The caller
/// releases the buffer with `stateui_free_buffer`.
@_cdecl("stateui_take_act_calls_wire")
public func stateui_take_act_calls_wire(
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.takeActCallsWire(), length)
}

/// Which version of the Wire this library writes. The host asks before the first
/// render and refuses a mismatch.
@_cdecl("stateui_wire_version")
public func stateui_wire_version() -> Int32 {
    Int32(Wire.version)
}

/// Releases a buffer a buffer export returned - the `_wire` ones,
/// `stateui_persistent_keys` and `stateui_inspect_log`.
@_cdecl("stateui_free_buffer")
public func stateui_free_buffer(_ pointer: UnsafeMutableRawPointer?) {
    guard let pointer = pointer else { return }
    pointer.deallocate()
}

/// Fails every act of the last taken batch with `reason`, because the host could
/// not read it: each awaiting handler throws instead of waiting for ever.
@_cdecl("stateui_fail_taken_act_calls")
public func stateui_fail_taken_act_calls(_ reason: UnsafePointer<CChar>?) {
    Renderer.shared.failTakenActCalls(reason.map { String(cString: $0) } ?? "")
}

// MARK: - The cycle

/// Takes in everything the host wrote since the last cycle, as a state batch:
/// `[count: U16]`, then per write `[number: I32][mask: U64][length: U32][bytes]`,
/// the mask naming the lanes the host wrote.
///
/// - Returns: how many states were written, or -1 where the bytes ran out.
@_cdecl("stateui_cycle_write")
public func stateui_cycle_write(_ batch: UnsafePointer<UInt8>?, _ length: Int32) -> Int32 {
    guard let batch = batch, length > 0 else { return 0 }

    return Int32(Renderer.shared.cycleWritten(
        UnsafeBufferPointer(start: batch, count: Int(length))))
}

/// Runs one cycle.
///
/// - Parameters:
///   - sync: which board; 0 is the display's own frame.
///   - now: the instant, in milliseconds on the host's own clock.
///   - reducesMotion: whether the user asked for less motion.
/// - Returns: how many states have lanes waiting, with `0x4000_0000` set where an
///   engine has more to do; -1 where there is no such board.
@_cdecl("stateui_cycle_run")
public func stateui_cycle_run(_ sync: Int32, _ now: Double, _ reducesMotion: Int32) -> Int32 {
    Renderer.shared.cycle(sync: sync, now: now, reducesMotion: reducesMotion != 0)
}

/// Reads out what the last cycle wrote, in `stateui_cycle_write`'s layout:
/// `number` 0 for every state with dirty lanes, ascending, its bits cleared; a
/// number for that one state whole, nothing cleared.
///
/// - Returns: bytes written, 0 for a state that has gone, or -1 where the buffer is
///   too small - nothing cleared.
@_cdecl("stateui_cycle_read")
public func stateui_cycle_read(
    _ number: Int32,
    _ into: UnsafeMutablePointer<UInt8>?,
    _ capacity: Int32
) -> Int32 {
    guard let buffer = into, capacity > 0 else { return -1 }

    return Int32(Renderer.shared.cycleRead(
        number, into: UnsafeMutableBufferPointer(start: buffer, count: Int(capacity))))
}

/// Whether anything is waiting for a cycle - a write not latched, a lane not read,
/// an engine armed or with more to do. Answers how many boards have something.
@_cdecl("stateui_cycle_awake")
public func stateui_cycle_awake() -> Int32 {
    Renderer.shared.cycleAwake()
}

/// The last cycle as one line - what it latched, ran, skipped and wrote. Released
/// with `stateui_free_string`.
@_cdecl("stateui_cycle_trace")
public func stateui_cycle_trace() -> UnsafeMutablePointer<CChar>? {
    makeCString(Renderer.shared.cycleTrace())
}


/// Whether the tree changed since the last render, so the host knows if it
/// needs to ask for a new one. Returns 1 when a re-render is needed.
@_cdecl("stateui_needs_render")
public func stateui_needs_render() -> Int32 {
    Renderer.shared.needsRender ? 1 : 0
}

/// How many renders this process made; `empty` receives how many carried nothing,
/// and `refused` how many writes asked for nothing.
@_cdecl("stateui_renders")
public func stateui_renders(
    _ empty: UnsafeMutablePointer<Int32>,
    _ refused: UnsafeMutablePointer<Int32>
) -> Int32 {
    empty.pointee = Int32(truncatingIfNeeded: Renderer.shared.emptyRenders)
    refused.pointee = Int32(truncatingIfNeeded: Renderer.shared.refusedWrites)
    return Int32(truncatingIfNeeded: Renderer.shared.renders)
}

/// How many rendered elements are alive now.
@_cdecl("stateui_alive")
public func stateui_alive() -> Int32 {
    Int32(truncatingIfNeeded: Renderer.shared.liveNodes)
}

/// Whether an inspector is recording - asked by the host once a render, which
/// measures its half of a message and reports it only while one is. See
/// Inspection.swift.
@_cdecl("stateui_inspecting")
public func stateui_inspecting() -> Int32 {
    Inspection.recording ? 1 : 0
}

/// The host's half of one message, for the inspector: how long reading it and
/// applying it took, in microseconds, and what the apply did with controls.
/// After every scene's own report on the same message.
@_cdecl("stateui_inspect_applied")
public func stateui_inspect_applied(
    _ generation: Int32,
    _ read: Double,
    _ apply: Double,
    _ nodes: Int32,
    _ made: Int32,
    _ kept: Int32,
    _ adopted: Int32
) {
    Inspection.applied(
        generation: generation,
        InspectedHost(
            read: read,
            apply: apply,
            nodes: Int(nodes),
            made: Int(made),
            kept: Int(kept),
            adopted: Int(adopted)))
}

/// How long one scene's part of a message took to apply, in microseconds -
/// the scene named by its place in the application's list.
@_cdecl("stateui_inspect_scene")
public func stateui_inspect_scene(_ generation: Int32, _ index: Int32, _ micros: Double) {
    Inspection.applied(generation: generation, scene: Int(index), micros: micros)
}

/// Every inspected pass the host reported on since the last call, as UTF-8 text;
/// the first call starts recording for good. Null with nothing new. Released
/// with `stateui_free_buffer`.
@_cdecl("stateui_inspect_log")
public func stateui_inspect_log(
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Array(Inspection.takeLog().utf8), length)
}

/// Hands over a platform window nobody here asked for, with what the platform kept
/// for its scene's keys - name and value pairs, in the payload's layout - before
/// the render that fills it. Returns 1, or -1 for a buffer that would not read.
@_cdecl("stateui_connect_scene")
public func stateui_connect_scene(_ bytes: UnsafePointer<UInt8>?, _ length: Int32) -> Int32 {
    let buffer: [UInt8] = bytes.map {
        Array(UnsafeBufferPointer(start: $0, count: Int(length)))
    } ?? []

    guard let values = Wire.decodePayload(buffer) else { return -1 }

    var kept: [String: PropValue] = [:]
    var index = 0

    while index + 1 < values.count {
        if let name = values[index].string {
            kept[name] = values[index + 1]
        }

        index += 2
    }

    Scenes.shared.connected(restoring: kept)
    return 1
}

/// Runs whatever suspended handlers have waiting, on the calling thread, and
/// returns how many jobs ran. The host calls it on its UI thread at the start of
/// every turn; whatever the handlers do happens inside this call.
@_cdecl("stateui_run_jobs")
public func stateui_run_jobs() -> Int32 {
    Int32(stateUIRunJobs())
}

/// Parks the calling thread until work lands, and returns how much is waiting -
/// which can be 0 when another turn got there first. The host gives this a thread
/// it created, and posts one turn onto its UI thread whenever it returns; nothing
/// ever runs on this thread.
@_cdecl("stateui_wait_work")
public func stateui_wait_work() -> Int32 {
    Int32(StateUIHost.waitForWork())
}

/// Pushes one standard provider's values in the environment layout - once per
/// domain before the first render, and whenever a platform event moves one.
/// Returns 1 applied, 0 for an unknown domain or a payload of the wrong shape, and
/// -1 for a buffer that would not read.
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

/// The store the application keeps state in and its keys, for the host to read
/// before the first render; null and 0 for an application that keeps nothing.
/// Released with `stateui_free_buffer`.
@_cdecl("stateui_persistent_keys")
public func stateui_persistent_keys(
    _ length: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    makeBuffer(Renderer.shared.persistentWire(), length)
}

/// Takes what the host read out of the store - a name and a value per key found -
/// before the first render. Returns 1, or -1 for a buffer that would not read.
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

/// Releases a string an export here returned - stateui_platform and
/// stateui_cycle_trace are the two that allocate this way.
@_cdecl("stateui_free_string")
public func stateui_free_string(_ pointer: UnsafeMutablePointer<CChar>?) {
    guard let pointer = pointer else { return }
    pointer.deallocate()
}

/// Reports which platform the Swift side was compiled for - a smoke test that the
/// right library loaded. `stateUIPlatform()` is the same string in Swift.
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
