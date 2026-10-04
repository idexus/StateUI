// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a view says of the page it stands on: written on the view a page shows - a window's, a stack's root or
// destination, a tab, a sheet - and said by that page. Written deeper, it is complained about and says nothing.
// Design: docs/design/views/pages.md#what-a-view-says-of-its-page

extension View {
    /// What the page is called: the bar's title while it is on top, a tab's caption, and the window's title where a
    /// platform takes one from the page.
    ///
    ///     SettingsPage().title("Settings")
    public func title(_ value: String) -> Modified {
        pageSays { $0.setValue(PageElementContract.title, value) }
    }

    /// The page's title from a state, `$x`: the host follows it, and no view is rebuilt for it.
    public func title(_ state: Binding<String>) -> Modified {
        pageSays { $0.words(PageElementContract.title, by: state) }
    }

    /// The picture that stands for the page: a tab's icon. A page not shown as an item of something else has nowhere
    /// to draw it.
    public func icon(_ value: ImageSource) -> Modified {
        pageSays { $0.setValue(PageElementContract.icon, value) }
    }

    /// What is drawn behind the whole page, also where the view it shows does not reach.
    public func pageBackground(_ value: Color) -> Modified {
        pageSays { $0.setValue(PageContract.background, value) }
    }

    /// The page's background from a state, `$x`: the host animates it to each new value.
    public func pageBackground(_ state: Binding<Color>) -> Modified {
        pageSays { $0.journey(PageContract.background, by: state) }
    }

    /// Whether the navigation bar shows while the page is on top of its stack.
    public func showsNavigationBar(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsNavigationBar, value) }
    }

    /// Whether the navigation bar shows, from a state, `$x`.
    public func showsNavigationBar(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.plain(PageContract.showsNavigationBar, by: state) }
    }

    /// Whether the way back is offered while the page is on top - false for a page the user must finish rather than
    /// leave. It controls the stack's own back affordances, not every system way of leaving.
    public func showsBackButton(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsBackButton, value) }
    }

    /// Whether the way back is offered, from a state, `$x`.
    public func showsBackButton(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.plain(PageContract.showsBackButton, by: state) }
    }

    /// What the back button reads while the page ABOVE this one is on top - written on the page the user would go
    /// back to. A host whose back affordance has no words leaves it out.
    public func backButtonTitle(_ value: String) -> Modified {
        pageSays { $0.setValue(PageContract.backButtonTitle, value) }
    }

    /// The back button's words from a state, `$x`.
    public func backButtonTitle(_ state: Binding<String>) -> Modified {
        pageSays { $0.words(PageContract.backButtonTitle, by: state) }
    }

    /// Runs as the page comes on screen - on every arrival, coming back from a pushed page included.
    public func onAppearing(_ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.appearing, handler) } }
    }

    /// Runs as the page leaves the screen - covered, left, or another tab chosen.
    public func onDisappearing(_ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.disappearing, handler) } }
    }

    /// Runs once navigation has arrived at the page. Only navigation says it; `onAppearing` answers any showing.
    public func onNavigatedTo(_ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedTo, handler) } }
    }

    /// Runs as navigation is about to leave the page, while it is still on screen.
    public func onNavigatingFrom(_ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatingFrom, handler) } }
    }

    /// Runs once navigation has left the page, its destination on screen.
    public func onNavigatedFrom(_ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedFrom, handler) } }
    }
}
