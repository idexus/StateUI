// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onCreated` and `.onDestroying`: about the tree, not the platform. They run
// after the render's walk, and what they write is in its message.
// Design: docs/design/core/identity-and-diffing.md#created-and-destroying

extension ModifiableElement {
    /// Runs something once, when the element is first described - its `@State`
    /// adopted and its `@Environment` resolved. This library's own.
    ///
    ///     VStack { … }
    ///         .onCreated { window.title = "Gallery" }
    ///
    /// Once per element, the outermost first; an element that leaves the tree and
    /// comes back is a new one. What it writes before its first suspension is sent
    /// in the render that brings the element, so a window arrives with the title
    /// and size written here.
    ///
    /// - Parameter handler: what to run.
    public func onCreated(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.created.append(handler) }
    }

    /// Runs something once, as the element leaves the tree, while its `@State` and
    /// `@Environment` still answer. This library's own.
    ///
    ///     TextEditor(text)
    ///         .onDestroying { try await save(text) }
    ///
    /// Everything under a leaving element goes with it, innermost first, before
    /// anything arriving in its place is created - so what it saves is there for
    /// that one to read.
    ///
    /// - Parameter handler: what to run.
    public func onDestroying(_ handler: @escaping EventHandler) -> Modified {
        modified { $0.destroying.append(handler) }
    }
}
