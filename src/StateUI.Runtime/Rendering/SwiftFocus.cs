// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Closing the keyboard when the Swift side cannot say which control opened it.
/// </summary>
/// <remarks>
/// <para>
/// MAUI has no method for this, and never needs one: a page written in C# is
/// holding its Entry, so it calls <c>Unfocus</c> on that. The Swift side holds a
/// description rebuilt on every render, so what it can name is an identity - and
/// a Done button above a form of six fields does not know which of them the
/// reader touched last.
/// </para>
/// <para>
/// So the question is asked of the PAGE: who here has the focus. That keeps the
/// answer where the truth is, rather than having Swift track focus itself and be
/// wrong the first time the platform moves it - which it does on every Next key,
/// on every tab, and whenever the system takes a keyboard down.
/// </para>
/// <para>
/// MAUI's own two routes are both reachable from Swift and neither is replaced
/// here: <c>ContentPage.HideSoftInputOnTapped</c> is the page property
/// <c>hideSoftInputOnTapped</c>, and <c>VisualElement.Unfocus</c> is
/// <c>unfocus()</c> on the view's handle.
/// </para>
/// <para>
/// The DECISION and the ACT are separate on purpose. <see cref="Holding"/> is
/// the whole of the thinking and can be checked headlessly; the unfocusing
/// itself goes through a platform handler, so a test without one sees nothing
/// happen - the same limit every renderer test here has.
/// </para>
/// </remarks>
internal static class SwiftFocus
{
    /// <summary>
    /// Takes the focus off whatever holds it on the page that is showing.
    /// </summary>
    /// <param name="root">The page to look at, usually the window's.</param>
    /// <returns>
    /// True when something was focused and has been told to give it up; false
    /// when the keyboard was already down, which is an answer rather than a
    /// failure.
    /// </returns>
    public static bool Hide(Page? root)
    {
        switch (Holding(root))
        {
            case VisualElement view:
                view.Unfocus();
                return true;

            default:
                return false;
        }
    }

    /// <summary>
    /// What has the keyboard on the page that is showing, if anything has.
    /// </summary>
    /// <remarks>
    /// A view in the page's own tree, found by walking it: one thing holds the
    /// focus at a time, and everything that can hold it is IN that tree. A
    /// search box on the navigation bar is a view like any other - a page's
    /// title view - so the same walk reaches it.
    /// </remarks>
    /// <param name="root">The page to look at, usually the window's.</param>
    /// <returns>The view holding the focus, or null.</returns>
    public static BindableObject? Holding(Page? root)
    {
        return Showing(root) is Page page ? Focused(page) : null;
    }

    /// <summary>
    /// The page a reader is actually looking at.
    /// </summary>
    /// <remarks>
    /// A modal sheet is over everything, so it wins. After that it DESCENDS,
    /// because the page arrangements nest: a window's page is a FlyoutPage
    /// whose detail is a TabbedPage whose current tab is a NavigationPage whose
    /// current page is the one being read. A single hop lands on a container
    /// rather than on the page inside it, and every dialog and the keyboard
    /// would aim at the container instead.
    /// </remarks>
    /// <param name="root">Where to start - the window's page.</param>
    /// <returns>The page showing, or null when there is none.</returns>
    public static Page? Showing(Page? root)
    {
        if (root is null)
        {
            return null;
        }

        if (root.Navigation?.ModalStack is { Count: > 0 } modals)
        {
            return modals[^1];
        }

        Page page = root;

        // Bounded rather than `while (true)`: a container that answered itself
        // would spin, and an arrangement is never deeper than a handful.
        for (int hop = 0; hop < 8; hop++)
        {
            Page? inside = page switch
            {
                // Its DETAIL is what the reader is looking at; the pane is the
                // menu over it, and MAUI reports it separately.
                FlyoutPage flyout => flyout.Detail,
                IPageContainer<Page> container => container.CurrentPage,
                _ => null,
            };

            if (inside is null || ReferenceEquals(inside, page))
            {
                return page;
            }

            page = inside;
        }

        return page;
    }

    /// <summary>
    /// The first focused view under an element, depth first.
    /// </summary>
    /// <remarks>
    /// One thing holds the focus at a time, so the first found is the one. The
    /// walk costs a traversal per call - a reader's tap, never a render.
    /// </remarks>
    /// <param name="element">Where to look.</param>
    /// <returns>The focused view, or null when nothing under it has the focus.</returns>
    private static VisualElement? Focused(IVisualTreeElement element)
    {
        foreach (IVisualTreeElement child in element.GetVisualChildren())
        {
            if (child is VisualElement { IsFocused: true } found)
            {
                return found;
            }

            if (Focused(child) is VisualElement deeper)
            {
                return deeper;
            }
        }

        return null;
    }
}
