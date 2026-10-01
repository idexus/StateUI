// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the one page a page position shows: a page, or one of several an
/// `if`/`else` or a `switch` chooses - each branch a page of its own, which a
/// swap replaces even where both branches are the same view.
///
///     var page: any Page {
///         if signedIn {
///             HomePage()
///         } else {
///             SignInPage()
///         }
///     }
///
/// An `if` with no `else` does not compile: a position always shows a page.
@resultBuilder
public enum PageBuilder {
    /// The page written.
    public static func buildBlock(_ page: any Page) -> any Page {
        page
    }

    /// The `if` branch.
    public static func buildEither(first page: any Page) -> any Page {
        BranchPage(segment: "if", page: page)
    }

    /// The `else` branch.
    public static func buildEither(second page: any Page) -> any Page {
        BranchPage(segment: "else", page: page)
    }
}

/// The page a branch chose, its node keyed by which.
struct BranchPage: Page {
    let segment: String
    let page: any Page

    var body: Node { BuilderPath.tagged(segment, page.body) }
}
