// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry: the library's elements it makes none of yet, which it shows by
/// name as unsupported.
enum WebRealization {
    /// The elements the host makes itself, outside the registry: the pages and the arrangements they stand in.
    static let madeByHost: Set<NodeType> = [.page, .navigationStack, .splitView, .tabView]

    @MainActor static var unmade: Set<String> {
        Set(LibraryContracts.elements.map { $0.nodeType.name })
            .subtracting(WebRegistrations.registry.realization.elements)
            .subtracting(NodeType.viewlessTypes.map(\.name))
            .subtracting(madeByHost.map(\.name))
    }
}
