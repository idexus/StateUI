// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The result builder behind the nested syntax. Its result's type says what was
// written - one view, a branch, several statements - and every piece records
// where each view was written: a path such as "1.else" that `Node.key` carries
// to the differ as the view's key.
// Design: docs/design/views/builders.md#every-statement-records-where-it-stood

/// Collects views written as consecutive statements. Every closure in this
/// library that takes views is one of these, and so is a composed view's
/// `body`.
///
/// `if`, `if/else`, `switch` and `ForEach` work inside one. A plain `for` does
/// not compile: repeat views with `ForEach`, which keys each view by its item.
///
///     VStack {
///         Text("Files")
///
///         ForEach(files, id: \.path) { file in
///             Text(file.name)
///         }
///     }
///
/// One statement keeps its type, and an `if`/`else` whose branches are views
/// is a view (`Either`); several statements or an `if` with no `else` are
/// what a container holds and never one view. A value held as `any View` goes
/// in as `ModifiedContent(node: view.node)`.
@resultBuilder
@MainActor
public enum ViewBuilder {
    /// One statement: what it wrote, one view staying one view.
    public static func buildBlock<Content: Views>(_ content: Content) -> Content {
        content
    }

    /// Several statements, in the order they are written.
    public static func buildBlock<each Part: Views>(_ part: repeat each Part) -> Statements<repeat each Part> {
        Statements(repeat each part)
    }

    /// An `if` without an `else`: nothing, or its branch.
    public static func buildOptional<Wrapped: Views>(_ wrapped: Wrapped?) -> Wrapped? {
        wrapped
    }

    /// The `if` branch of an if/else.
    public static func buildEither<First, Second>(first: First) -> Either<First, Second> {
        .first(first)
    }

    /// The `else` branch. Its views are keyed apart from the `if` branch's, so
    /// switching branches replaces the control rather than editing it.
    public static func buildEither<First, Second>(second: Second) -> Either<First, Second> {
        .second(second)
    }
}
