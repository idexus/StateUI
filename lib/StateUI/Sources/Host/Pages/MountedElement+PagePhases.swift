// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The phases a page hears as it is shown and hidden, the same on every host, each rendered in its turn.
/// Design: docs/design/host/pages.md#a-pages-phases
extension MountedElement {
    /// Shows or hides this page tree: shown, a page is appearing, and navigated to on a move; hidden, it is navigated
    /// from on a move around its disappearing. An arrangement passes it on to what it shows.
    public func setPagePresented(_ presented: Bool, reason: PagePresentationReason) {
        guard NodeType.pageTypes.contains(type), isPagePresented != presented else { return }
        isPagePresented = presented

        switch type {
        case .page:
            if presented {
                tellPhase(.appearing)
                if reason == .navigation { tellPhase(.navigatedTo) }
            } else {
                if reason == .navigation { tellPhase(.navigatingFrom) }
                tellPhase(.disappearing)
                if reason == .navigation { tellPhase(.navigatedFrom) }
            }
        case .navigationStack:
            // A stack whose window comes is navigated to; one whose window goes only disappears.
            let passed: PagePresentationReason = reason == .window ? (presented ? .navigation : .appearance) : reason
            children.last?.setPagePresented(presented, reason: passed)
        case .tabbedView:
            selectedTab?.setPagePresented(presented, reason: .appearance)
        case .splitView:
            children.dropFirst().first?.setPagePresented(presented, reason: .appearance)
            if sidebarIsVisible { children.first?.setPagePresented(presented, reason: .appearance) }
        default:
            break
        }
    }

    /// After what this arrangement shows changed - a push or a pop, another tab, the sidebar shown or hidden - what
    /// stopped showing leaves first, then what started showing arrives.
    public func reconcilePresentation(from previous: [MountedElement]) {
        guard isPagePresented else { return }

        let current = shownChildren
        let reason: PagePresentationReason = type == .navigationStack ? .navigation : .appearance
        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }
}
