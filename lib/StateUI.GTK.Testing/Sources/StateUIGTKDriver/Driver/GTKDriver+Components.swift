// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@_spi(Host) import StateUIConformance

/// What a component's backend lets the driver reach on its element's view - a widget of the component's own, which
/// this driver does not know: a member GTK holds there, an act through it, and what it reaches only past GTK.
/// Design: docs/design/host/conformance.md#a-components-element
struct GTKComponentDriving {
    /// The element's contract.
    let contract: any ElementContract.Type

    /// What the view holds of a member; nil for a member this does not read.
    let held: @MainActor (Prop, GTKView) -> HostValue??

    /// Performs an act on the view; false for an act it is not.
    let perform: @MainActor (UserAct, GTKView) throws -> Bool

    /// What it reaches past GTK, by ability, and why - 🔌.
    let byHost: [String: String]
}

extension GTKDriver {
    /// The components' drivers by their element's node type, which a component's tests add before they run.
    static var components: [NodeType: GTKComponentDriving] = [:]

    /// What a component's driver reads of `property` on `element`; nil where no component's driver reads it.
    func componentHolds(_ property: Prop, on element: MountedElement) -> HostValue?? {
        guard let component = Self.components[element.type], let view = (element.native as? GTKElement)?.view else {
            return nil
        }
        return component.held(property, view)
    }

    /// What GTK realizes of the components' elements: each member their registration takes or raises, and each act of
    /// their contracts the application registered - the register of the library's elements knows none of them.
    var componentRecords: [HostRecord] {
        let elements = Set(Self.components.keys.map(\.name))
        let realized = GTKRegistrations.registry.realization.members.filter { elements.contains($0.element) }
            .map { HostRecord.complete($0.element, $0.member) }
        let performed = Set(GTKInterop.acts.performers.keys.map(\.name))
        let acts = Self.components.values.flatMap { component in
            component.contract.members.filter { performed.contains($0.name) }
                .map { HostRecord.complete(component.contract.nodeType.name, $0.name) }
        }
        return (realized + acts).sorted { ($0.owner, $0.member) < ($1.owner, $1.member) }
    }

    /// Performs `act` through a component's driver; false where none performs it.
    func componentPerforms(_ act: UserAct, on element: MountedElement) throws -> Bool {
        guard let component = Self.components[element.type], let view = (element.native as? GTKElement)?.view else {
            return false
        }
        return try component.perform(act, view)
    }
}
