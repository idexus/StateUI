// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The links the application was asked to open, each given to one window by one rule on every host - the window the
/// platform names where it hears links, else the one activated last that does, else the first that does - and
/// held, in order, until a window that hears links stands.
/// Design: docs/design/host/runtime.md#a-link-opened
@_spi(Host) @MainActor public struct LinkInbox {
    private struct Waiting {
        let address: String
        weak var window: MountedElement?
    }

    private var waiting: [Waiting] = []

    /// None waiting.
    public init() {}

    /// Whether a link waits for a window that hears it.
    public var isWaiting: Bool { !waiting.isEmpty }

    /// The application was asked to open `address`, which the platform gave `window` where it names one.
    public mutating func opened(_ address: String, in window: MountedElement?) {
        waiting.append(Waiting(address: address, window: window))
    }

    /// Each waiting link and the window of `windows` it goes to, `activatedLast` naming the window of those given it
    /// that was activated last; none, every link still waiting, where no window hears links.
    public mutating func deliver(
        to windows: [MountedElement], activatedLast: ([MountedElement]) -> MountedElement?
    ) -> [(window: MountedElement, address: String)] {
        let hearing = windows.filter { $0.handler(.linkOpened) != nil }
        guard let first = hearing.first else { return [] }

        let front = activatedLast(hearing) ?? first
        defer { waiting = [] }
        return waiting.map { each in
            let named = each.window.flatMap { window in hearing.first { $0 === window } }
            return (window: named ?? front, address: each.address)
        }
    }
}
