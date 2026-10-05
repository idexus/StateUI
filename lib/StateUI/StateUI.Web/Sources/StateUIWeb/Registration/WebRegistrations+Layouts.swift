// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// The stacks: the room they leave around and between their children, and what fills their box.
    static func layouts(_ registry: Registry<WebDOMView>) {
        registry.add(VStackContract.self, create: { _ in WebLayoutView(arrangement: .stack(.vertical)) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.property(VisualElementContract.background) { view, background in view.setBackground(background?.propValue) }
        }

        registry.add(HStackContract.self, create: { _ in WebLayoutView(arrangement: .stack(.horizontal)) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.property(VisualElementContract.background) { view, background in view.setBackground(background?.propValue) }
        }
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(_ view: WebLayoutView, _ values: ElementValues<Realized>) {
        view.setSpacing(values[StackContract.spacing] ?? 0)
        view.setPadding(values[PaddingElementContract.padding])
    }
}
