// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// The stacks: the room between their children, and inside their own edge.
    static func layouts(_ registry: Registry<WinUIView>) {
        registry.add(VStackContract.self, create: { _ in WinUIStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
        }

        registry.add(HStackContract.self, create: { _ in WinUIStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
        }
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackBaseContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(_ view: WinUIStackView, _ values: ElementValues<Realized>) {
        view.spacing = values[StackBaseContract.spacing] ?? 0
        view.padding = values[PaddingElementContract.padding] ?? Insets(0)
    }
}
