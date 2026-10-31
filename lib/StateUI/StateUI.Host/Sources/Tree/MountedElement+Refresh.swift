// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The pull to refresh a scroller or a list offers, alike on every host.
/// Design: docs/design/host/runtime.md#the-pull-to-refresh
extension MountedElement {
    /// Whether the element hears the pull: a handler of `refreshRequested`, or a state `isRefreshing` the pull
    /// writes into.
    var hearsPull: Bool {
        handler(.refreshRequested) != nil || driven[.isRefreshing]?.mode == .inOut
    }

    /// Whether the element offers the pull, as its view is given `isRefreshEnabled`: as the element says, else
    /// wherever it hears the pull.
    var offeredRefresh: HostValue? {
        value(.isRefreshEnabled) ?? (hearsPull ? .bool(true) : nil)
    }

    /// The user pulled the element to refresh it: `isRefreshing` true onto the state carrying it, then
    /// `refreshRequested`. Answers whether the spinner stays - where a state carries `isRefreshing` or the element
    /// describes it, which ends it - or goes at once, as nothing would.
    public func reportRefreshRequested(in runtime: HostRuntime) -> Bool {
        guard !ProgramWrite.isWriting else { return true }
        let stays = driven[.isRefreshing] != nil || properties[.isRefreshing] != nil
        carry(.isRefreshing, .bool(true), then: .refreshRequested, [], in: runtime)
        return stays
    }
}
