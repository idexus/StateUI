// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One element's work handed between the walk's bounded steps.
/// Design: docs/design/core/identity-and-diffing.md#the-walks-stack
@MainActor
final class ElementPass {
    let id: ElementID
    let rendered: RenderedNode?
    let forced: Bool
    let sizesArrive: Bool

    let start: Int
    var builtFrom: Int

    let atPageRoot: Bool
    let atPagePosition: Bool
    let outerScene: SceneRecord?

    let builds: Int
    let key: PathNumber?
    let identity: ElementIdentity?
    let written: AimBox?

    let authored: Node
    var node: Node

    var pushed = 0
    var entered = 0
    var inspected = false

    var enablement: Enablement?

    var branch: [Enablement.Key] = []

    var views: [BuiltView] = []
    var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

    var placeholder: Node?

    var expanded: Node?

    var refused = false

    var ownReads: Set<ObjectIdentifier> = []

    var readings: [Sampling] = []
    var reads: Set<ObjectIdentifier> = []
    var derived: [AnyObject] = []

    var frame: BuildScope.Frame?
    var within: BuildScope.Frame?

    var pageValues: PageValues?
    var described: (children: [RenderedNode], patch: HostPatch)?

    var visualInput: VisualInput?
    var visualState: KeyName?
    var engines: [Int] = []
    var previous: RenderedNode?
    var kept = RunSlots()
    var events: [Event: Int] = [:]
    var driven: [Prop: StateEntry] = [:]
    var patch: HostPatch
    var menuKey: MenuKeys.Key?

    init(
        id: ElementID, rendered: RenderedNode?, node: Node, forced: Bool, sizesArrive: Bool, atPageRoot: Bool,
        atPagePosition: Bool, outerScene: SceneRecord?, start: Int
    ) {
        self.id = id
        self.rendered = rendered
        self.forced = forced
        self.start = start
        builtFrom = start
        self.sizesArrive = sizesArrive
        self.atPageRoot = atPageRoot
        self.atPagePosition = atPagePosition
        self.outerScene = outerScene
        builds = (rendered?.builds ?? 0) + 1
        key = node.key
        identity = node.identity
        written = node.aim
        authored = node
        self.node = node
        placeholder = node.stateful != nil || node.producer != nil ? node : nil
        patch = HostPatch(id: id, type: node.type)
    }
}
