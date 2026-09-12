// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Running something when an element comes into the tree, and as it leaves.
//
//     Label(name)
//         .onCreated { window.title = name }
//         .onDestroying { try await save() }
//
// This library's own, and about the TREE rather than the platform: an element
// is created by the first render that describes it, and is destroying in the
// first render that no longer does. The two words are the ones MAUI gives a
// window's own pair, `Created` and `Destroying`.
//
// NOTHING ABOUT IT CROSSES THE BOUNDARY, and the handlers run once the walk is
// done, as `.onChanged`'s do and for the same reason: a handler may write
// `@State`, and a write landing mid-walk would be cleared by that walk's own
// bookkeeping. What they write before the message leaves is IN it - see
// `Renderer.renderWire` - which is what makes `.onCreated` the place to give
// an element's session its first values.

extension BindableObject {
    /// Runs something once, when the element is first described - the render
    /// that brings it into the tree, its `@State` adopted and its
    /// `@Environment` resolved. This library's own.
    ///
    ///     VStack { … }
    ///         .onCreated { window.title = "Gallery" }
    ///
    /// Once per element, the outermost first: a render that describes it
    /// again, or carries it, runs nothing, and an element that leaves the tree
    /// and comes back is a new one and runs it again.
    ///
    /// The handler runs once the render that brings the element has walked
    /// the tree, and what it writes before its first suspension is sent in
    /// that render's message - which is what makes it the place to give a
    /// window its title and its size, the `WindowSession` in the environment
    /// being written like any state: the window arrives with them.
    ///
    /// - Parameter handler: what to run.
    public func onCreated(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.created.append(handler) }
    }

    /// Runs something once, as the element leaves the tree - in the first
    /// render that no longer describes it, once its walk is done and before its
    /// message leaves, while its `@State` and `@Environment` still answer. This
    /// library's own.
    ///
    ///     Editor(text)
    ///         .onDestroying { try await save(text) }
    ///
    /// A state written here has nobody left to show it, and one read here holds
    /// what the element last held, which is what saving needs. Everything under
    /// an element that leaves goes with it, the innermost first - and what
    /// leaves says so before anything arriving in its place is created, so what
    /// it saves is there for that one to read.
    ///
    /// - Parameter handler: what to run.
    public func onDestroying(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.destroying.append(handler) }
    }
}

extension PageElement {
    /// Runs something once, when the page is first described - the render that
    /// brings it into the tree. The same as a view's `onCreated`.
    ///
    ///     FlyoutPage($open) { … } detail: { … }
    ///         .onCreated { window.title = "Gallery" }
    ///
    /// - Parameter handler: what to run.
    public func onCreated(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.created.append(handler) }
    }

    /// Runs something once, as the page leaves the tree. The same as a view's
    /// `onDestroying`.
    ///
    /// - Parameter handler: what to run.
    public func onDestroying(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.destroying.append(handler) }
    }
}
