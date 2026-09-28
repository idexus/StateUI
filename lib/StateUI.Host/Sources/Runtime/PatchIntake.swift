// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Takes the core's messages into the mounted tree, one whole message at a time.
/// Design: docs/design/host/patches.md#patch-intake
@_spi(Host) @MainActor public final class PatchIntake {
    /// The generation of the last message applied in full; zero asks for the whole tree.
    public private(set) var baseline: Int32 = 0

    /// What made the last refused message drift.
    public private(set) var lastDrift: String?

    /// Whether a message is being applied.
    public var isApplying: Bool { depth > 0 }

    /// The generation of the message being applied; nil between messages.
    private(set) var generationBeingApplied: Int32?

    private var depth = 0
    private var interrupted = false
    private var drift: String?

    /// An intake holding no message yet: its first render is complete.
    public init() {}

    /// Notes that the message being applied describes a tree the host does not hold.
    public func drifted(_ reason: String) {
        if drift == nil { drift = reason }
    }

    /// Applies the message `root` of `generation` through `apply`; says whether it went in whole.
    @discardableResult
    public func take(_ root: HostPatch, generation: Int32, apply: (HostPatch) -> Void) -> Bool {
        if depth > 0 { interrupted = true }
        let outer = drift
        drift = nil

        let outerGeneration = generationBeingApplied
        generationBeingApplied = generation
        depth += 1
        ProgramWrite.perform { apply(root) }
        depth -= 1
        generationBeingApplied = outerGeneration

        let found = drift
        drift = outer

        if let found {
            baseline = 0
            lastDrift = found
            return false
        }

        if depth == 0, interrupted {
            interrupted = false
            baseline = 0
        } else {
            baseline = generation
        }
        return true
    }
}
