// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What these tests need of the core: a differ to talk to, the acts a host is
// handed, and an aim filled by hand.

import Foundation
@_spi(Host) @testable import StateUI

/// A differ rendering trees one after another, and firing the handlers a patch names, as a host's report does.
final class Renders {
    private let differ = Differ()
    private var rendered: RenderedNode?

    /// Renders `tree` and answers the patch a host would be handed.
    @discardableResult
    func render(_ tree: Node) -> HostPatch {
        differ.named = Renderer.shared.pendingNames
        let result = differ.reconcile(rendered, with: tree)
        rendered = result.node
        for handler in differ.takeFired() { Renderer.shared.run(handler) }
        return result.patch
    }

    /// Runs the handler `id` names with `payload`, as a host's report does.
    @discardableResult
    func fire(_ id: Int32?, with payload: [PropValue] = []) -> Bool {
        guard let id, let handler = differ.handler(Int(id)) else { return false }
        EventBuffer.current = payload
        Renderer.shared.start(handler)
        return true
    }
}

/// The queued acts, taken as a host takes them.
@discardableResult
func drainedActs() -> [HostActCall] {
    HostBoundary.takeActCalls()
}

/// An aim filled by hand from a named element, for an act sent without a render.
func named<Target>(_ name: String, _ type: Target.Type) -> Aim<Target> {
    let aim = Aim(type)
    aim.box.attach(.manual(name), walk: 1)
    return aim
}

/// Turns of the UI thread until every resumed handler has run, as a host's turns do.
@discardableResult
func settle(timeout: TimeInterval = 2) async -> Int {
    let deadline = Date().addingTimeInterval(timeout)
    var turns = 0
    repeat {
        await MainActor.run { _ = stateUIRunJobs() }
        turns += 1
    } while (Renderer.shared.resumesPending > 0 || UIThreadExecutor.shared.pendingCount > 0) && Date() < deadline
    return turns
}
