// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Why a page tree is shown or hidden: a change of what an arrangement shows, a move on a stack, or its window's.
enum GTKPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// Pages and their arrangements: what each shows, the phases its pages hear, and the chrome each page's header bar
/// shows - its title or title view, its actions, whether it offers the way back.
/// Design: docs/design/platforms/gtk/pages.md
extension GTKElement {
    /// A page's children that furnish its header bar rather than stand in its room.
    static let slotTypes: Set<NodeType> = [.toolbarItems, .titleView, .menuBar, .contextMenu]

    /// The page the user sees in this arrangement: a stack's top.
    var visiblePage: GTKElement? {
        switch type {
        case .page: self
        case .navigationStack: children.last?.visiblePage
        default: nil
        }
    }

    /// The stack surrounding the visible content, if this arrangement has one.
    var visibleNavigationStack: GTKElement? {
        type == .navigationStack ? self : nil
    }

    /// What this arrangement shows while it is shown itself: a stack's top page.
    var shownChildren: [GTKElement] {
        type == .navigationStack ? children.last.map { [$0] } ?? [] : []
    }

    // MARK: - The header bar

    /// What a page's header bar shows, composed from the page: its title or title view, its actions in their
    /// priority's order with the overflow's apart, whether its bar shows and whether it offers the way back.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    var chrome: GTKPageChrome {
        var chrome = GTKPageChrome()
        chrome.title = value(.title)?.string ?? ""
        chrome.titleView = firstView(in: .titleView)
        chrome.showsBar = value(.hasNavigationBar)?.bool != false
        chrome.offersBack = value(.hasBackButton)?.bool != false

        let items = children.first { $0.type == .toolbarItems }?.children.filter { $0.type == .toolbarItem } ?? []
        let ordered = items.enumerated().sorted {
            let left = $0.element.value(.priority)?.number ?? 0
            let right = $1.element.value(.priority)?.number ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        for item in ordered {
            let action = GTKToolbarAction(
                title: item.value(.text)?.string ?? "", isEnabled: item.value(.isEnabled)?.bool ?? true,
                perform: { [weak item] in item?.send(.clicked, []) })
            if item.value(.placement)?.enumeration == 2 { chrome.overflow.append(action) } else { chrome.actions.append(action) }
        }
        return chrome
    }

    /// Writes each page's chrome on its header bar, for every page this arrangement holds in a frame.
    func composeChrome() {
        guard type == .navigationStack, let navigation = view as? GTKNavigationView else { return }

        for (page, frame) in zip(children, navigation.frames) {
            frame.show(page.chrome)
            navigation.describe(frame, title: page.value(.title)?.string ?? "", canPop: page.value(.hasBackButton)?.bool != false)
        }
    }

    /// The view of a slot's first child: a page's title view.
    func firstView(in slot: NodeType) -> GTKView? {
        children.first { $0.type == slot }?.children.lazy.compactMap(\.layoutItem).first?.view
    }

    // MARK: - A page's phases

    /// Shows or hides this page tree, each page hearing its phases in its turn.
    /// Design: docs/design/platforms/gtk/pages.md#a-pages-phases
    func setPagePresented(_ presented: Bool, reason: GTKPagePresentationReason) {
        guard Self.pageTypes.contains(type), pagePresented != presented else { return }
        pagePresented = presented

        switch type {
        case .page:
            if presented {
                announce(.appearing)
                if reason == .navigation { announce(.navigatedTo) }
            } else {
                if reason == .navigation { announce(.navigatingFrom) }
                announce(.disappearing)
                if reason == .navigation { announce(.navigatedFrom) }
            }
        case .navigationStack:
            children.last?.setPagePresented(
                presented, reason: reason == .window && presented ? .navigation : reason == .window ? .appearance : reason)
        default:
            break
        }
    }

    /// Moves presentation after the arrangement changed - a push or a pop: what stopped showing leaves first, then
    /// what started showing arrives.
    func reconcilePresentation(from previous: [GTKElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: GTKPagePresentationReason = type == .navigationStack ? .navigation : .appearance

        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }

    /// Hands a page's phase to its handler, rendered before the next phase is heard.
    private func announce(_ event: Event) {
        guard let handler = element.handler(event) else { return }
        host?.pump.handlers.enqueuePhase(handler)
    }

    /// Keeps an arrangement's own parts with the tree: a stack hears the user take its top page away.
    func arrangePages() {
        guard type == .navigationStack, let navigation = view as? GTKNavigationView else { return }
        navigation.onPopped = { [weak self] remaining in self?.userPopped(remaining: remaining) }
    }

    // MARK: - The way back

    /// Takes the visible stack's top page away as the user does; whether there was one to take.
    func goBack() -> Bool {
        guard let stack = visibleNavigationStack, stack.children.count > 1,
              let navigation = stack.view as? GTKNavigationView
        else { return false }

        return navigation.popByUser()
    }

    /// The user took the stack's top pages away - the back button, the swipe, the keys: the path is told how long
    /// it is now.
    private func userPopped(remaining: Int) {
        guard type == .navigationStack, let handler = element.handler(.popped) else { return }
        host?.dispatch(handler, payload: [.number(Double(remaining - 1))])
    }
}
