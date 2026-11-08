// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Differ {
    /// The element as it now stands, its children walked.
    @inline(never)
    func finish(_ pass: ElementPass, children: [RenderedNode]) -> (node: RenderedNode, patch: HostPatch) {
        let node = pass.node
        let result = RenderedNode(
            id: pass.id,
            type: node.type,
            props: node.props,
            events: pass.events,
            motion: pass.patch.motion?.motion ?? pass.previous?.motion ?? .inherited,
            lanes: pass.patch.motion?.lanes ?? pass.previous?.lanes ?? .all,
            key: pass.key,
            views: pass.views,
            placeholder: pass.placeholder,
            view: pass.within?.view,
            reads: pass.reads,
            builds: pass.builds,
            provided: Array(scope.suffix(pass.pushed)),
            seen: pass.seen,
            watched: node.watches.map(\.value),
            engines: pass.engines,
            driven: pass.driven,
            readings: pass.readings,
            derived: pass.derived,
            children: children
        )
        result.contentAim = node.aim
        result.identity = pass.identity
        result.menuKey = pass.menuKey
        if pass.patch.fresh || pass.patch.replace { pass.patch.menuKey = pass.menuKey?.host }
        result.expanded = pass.expanded
        result.refused = pass.refused
        result.enablement = pass.enablement
        result.branch = pass.branch
        result.ownReads = pass.ownReads
        result.sizesArrive = pass.sizesArrive
        result.atPagePosition = pass.atPagePosition
        result.visualInput = pass.visualInput
        result.runs = pass.kept
        result.visualState = pass.visualState

        // What it says of the page it is the view of.
        result.pageValues = !pass.atPageRoot ? nil : node.type == .anchor ? children.first?.pageValues : pass.pageValues

        // What it runs as it leaves: this build's closures, the newest; and what it hears.
        result.destroying = node.destroying
        result.hostEvents = node.hostEvents

        return (result, pass.patch)
    }
}
