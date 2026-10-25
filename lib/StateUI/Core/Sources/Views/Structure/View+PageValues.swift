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

    /// The line under the page's title, wherever its title shows: the current document or section. An empty one is
    /// none.
    ///
    ///     NotesPage().title("Notes").subtitle(folder.name)
    public func subtitle(_ value: String) -> Modified {
        pageSays { $0.setValue(PageContract.subtitle, value) }
    }

    /// The line under the page's title from a state, `$x`: the host follows it, and no view is rebuilt for it.
    public func subtitle(_ state: Binding<String>) -> Modified {
        pageSays { $0.words(PageContract.subtitle, by: state) }
    }

    /// The picture that stands for the page: a tab's icon, and the mark beside the title of a sidebar's page, which
    /// names the application.
    public func icon(_ value: ImageSource) -> Modified {
        pageSays { $0.setValue(PageElementContract.icon, value) }
    }

    /// What the whole page is made of behind what it shows, also where the view it shows does not reach. Written on
    /// an arrangement, it is what each of its pages that says none stands on.
    public func pageBackground(_ value: Material) -> Modified {
        pageSays { $0.setValue(PageElementContract.background, value) }
    }

    /// The page's background in one color.
    public func pageBackground(_ value: Color) -> Modified {
        pageBackground(.color(value))
    }

    /// The page's background from a state, `$x`: the host animates its color to each new value.
    public func pageBackground(_ state: Binding<Color>) -> Modified {
        pageSays { $0.twin(PageElementContract.background, carrying: state) }
    }

    /// The page's background from a material state, `$x`: the host shows each
    /// new material as it stands.
    public func pageBackground(_ state: Binding<Material>) -> Modified {
        pageSays { $0.twin(PageElementContract.background, by: state) }
    }

    /// Whether the navigation bar shows while the page is on top of its stack.
    public func showsNavigationBar(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsNavigationBar, value) }
    }

    /// Whether the navigation bar shows, from a state, `$x`.
    public func showsNavigationBar(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.twin(PageContract.showsNavigationBar, by: state) }
    }

    /// Whether the page shows its title - false for a page whose own content names it: the title still names the
    /// window and the way back, and stands on no bar and over no content.
    ///
    ///     HomePage().title("Home").showsTitle(false)
    public func showsTitle(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsTitle, value) }
    }

    /// Whether the page shows its title, from a state, `$x`.
    public func showsTitle(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.twin(PageContract.showsTitle, by: state) }
    }

    /// Whether the way back is offered while the page is on top - false for a page the user must finish rather than
    /// leave. It controls the stack's own back affordances, not every system way of leaving.
    public func showsBackButton(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsBackButton, value) }
    }

    /// Whether the way back is offered, from a state, `$x`.
    public func showsBackButton(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.twin(PageContract.showsBackButton, by: state) }
    }

    /// Whether the bar over the page, where its stack stands in a sheet, offers a button closing the sheet - false
    /// for a page the user must finish rather than leave. Escape and the system's way back close the sheet all the
    /// same.
    ///
    ///     SettingsForm().title("Settings").showsCloseButton(false)
    public func showsCloseButton(_ value: Bool) -> Modified {
        pageSays { $0.setValue(PageContract.showsCloseButton, value) }
    }

    /// Whether the bar offers the sheet's close button, from a state, `$x`.
    public func showsCloseButton(_ state: Binding<Bool>) -> Modified {
        pageSays { $0.twin(PageContract.showsCloseButton, by: state) }
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
    public func onAppearing(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.appearing, handler) } }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onAppearing(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.appearing, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onAppearing(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.appearing, gate: gate, handler) } }
    }

    /// Runs as the page leaves the screen - covered, left, or another tab chosen.
    public func onDisappearing(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.disappearing, handler) } }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDisappearing(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.disappearing, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDisappearing(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.disappearing, gate: gate, handler) } }
    }

    /// Runs when the application is asked to open a link - one the user chose elsewhere, of a scheme the
    /// application's head registers - and gives it to the window the page this view stands on stands in: its
    /// address. Said of the page, as its title is: on a view the page shows, or on an arrangement where a page
    /// stands.
    ///
    ///     NavigationStack($path) { NotesPage() } destination: { NotePage($0) }
    ///         .onLinkOpened { address in path = Route.path(for: address) }
    ///
    /// The handler writes the view's own state, and its scene's through a binding. Every page and arrangement of
    /// the window that hears links hears the same one, the outermost first.
    public func onLinkOpened(_ handler: @escaping @MainActor (String) throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageElementContract.linkOpened, handler) } }
    }

    /// The same, with a handler that awaits - a sign-in finished in a browser exchanging its code: its `policy`
    /// says what a link does when it comes again while a run is under way.
    public func onLinkOpened(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageElementContract.linkOpened, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onLinkOpened(gate: Gate, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageElementContract.linkOpened, gate: gate, handler) } }
    }

    /// Runs once navigation has arrived at the page. Only navigation says it; `onAppearing` answers any showing.
    public func onNavigatedTo(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedTo, handler) } }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onNavigatedTo(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedTo, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onNavigatedTo(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedTo, gate: gate, handler) } }
    }

    /// Runs as navigation is about to leave the page, while it is still on screen.
    public func onNavigatingFrom(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatingFrom, handler) } }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onNavigatingFrom(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatingFrom, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onNavigatingFrom(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatingFrom, gate: gate, handler) } }
    }

    /// Runs once navigation has left the page, its destination on screen.
    public func onNavigatedFrom(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedFrom, handler) } }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onNavigatedFrom(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedFrom, policy: policy, handler) } }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onNavigatedFrom(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        pageSays { $0.modified { $0.addHandler(PageContract.navigatedFrom, gate: gate, handler) } }
    }
}
