// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI

/// Takes the core's messages into the mounted tree, one whole message at a
/// time.
///
/// A patch means something only against the exact tree it was computed from.
/// The intake quotes the generation of the last message applied in full,
/// applies the next as one transaction - every native write the program's,
/// every handler it raises held until the message is in - and claims that
/// message's generation only once it applied without drift: a sparse message
/// about an element the tree does not hold. A drift is refused, and the host
/// asks for the whole tree once, which keeps every identity, handler and
/// state. A message applied while another is still being applied is computed
/// against a tree half written, so the outer one claims nothing and the next
/// render is complete.
@MainActor
final class AppKitPatchIntake {
    /// The generation of the last message applied in full; zero asks the core
    /// for the whole tree.
    private(set) var baseline: Int32 = 0

    /// What made the last refused message drift.
    private(set) var lastDrift: String?

    /// Whether a message is being applied.
    var isApplying: Bool { depth > 0 }

    private var depth = 0
    private var interrupted = false
    private var drift: String?

    /// Notes that the message being applied describes a tree the host is not
    /// holding.
    func drifted(_ reason: String) {
        if drift == nil { drift = reason }
    }

    /// Applies one message through `apply`, and says whether it went in whole.
    ///
    /// - Parameters:
    ///   - root: The message's root patch.
    ///   - generation: The generation the core gave the message.
    ///   - apply: What writes the patch into the mounted tree.
    @discardableResult
    func take(_ root: HostPatch, generation: Int32, apply: (HostPatch) -> Void) -> Bool {
        if depth > 0 { interrupted = true }
        let outer = drift
        drift = nil

        depth += 1
        AppKitProgramWrite.perform { apply(root) }
        depth -= 1

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
#endif
