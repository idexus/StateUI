// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// A MAUI view whose content is defined in Swift.
/// </summary>
/// <remarks>
/// <para>
/// Drop one of these into any page and part of the interface comes from the
/// Swift side:
/// <code>Content = new StateUIHost();</code>
/// </para>
/// <para>
/// For an application that Swift describes whole - window, arrangement and
/// pages - use <see cref="StateUIWindow"/> instead. A NavigationPage, a
/// TabbedPage and a FlyoutPage are Pages and cannot live inside a view, so a
/// Swift tree shown here has to be a ContentPage.
/// </para>
/// <para>
/// <b>One host to a process, and never one beside a <see cref="StateUIWindow"/>.</b>
/// The Swift side is a single renderer holding a single tree - one generation,
/// one handler registry, one command queue, one wire dictionary - so exactly
/// one session may render it. A second host shows a diagnostic where its tree
/// would have been; see <see cref="StateUISession"/>.
/// </para>
/// <para>
/// The loop is deliberately simple - ask Swift what changed, apply it, forward
/// events, ask again. Swift builds its whole tree every time and sends only the
/// difference, so a keystroke costs a message naming one Label rather than a new
/// visual tree.
/// </para>
/// </remarks>
public class StateUIHost : ContentView, IStateUITarget
{
    /// <summary>The render loop behind this host.</summary>
    private readonly StateUISession _session;

    /// <summary>
    /// The page title last described, kept because there may be nowhere to put
    /// it yet.
    /// </summary>
    /// <remarks>
    /// A view has no parent until it is placed, and the first render happens in
    /// the constructor - so on the first pass there is no MAUI page or window to
    /// reach. It is applied again once this host is really in the tree.
    /// </remarks>
    private string? _pageTitle;

    /// <summary>
    /// Whether the page above this host closes the keyboard on a tap beside a
    /// field, kept for the same reason as the title.
    /// </summary>
    /// <remarks>
    /// MAUI declares it on ContentPage rather than on Page, which is why it is
    /// applied to a narrower ancestor than the title is. A host embedded in
    /// something else - a NavigationPage's own page, a TabbedPage - simply has
    /// nowhere to put it.
    /// </remarks>
    private bool? _hideSoftInputOnTapped;

    /// <summary>
    /// The window node last described, kept for the same reason - and kept
    /// whole, because a window is a title, a position and a size.
    /// </summary>
    private SwiftNode? _window;

    /// <summary>
    /// Called once before the first render, to let the application's Swift
    /// module register itself.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A hook rather than a direct P/Invoke because the app's Swift module is a
    /// separate native library whose name follows the project - so this library,
    /// which is published independently, cannot name it at compile time.
    /// </para>
    /// <para>
    /// The app project's build generates a small interop file that assigns this
    /// from a <c>[ModuleInitializer]</c>, so nothing has to be wired up by hand.
    /// It lives here, on the type an application is most likely to name, and the
    /// session behind every entry point reads it.
    /// </para>
    /// </remarks>
    public static Action? RegisterApp
    {
        get => StateUISession.RegisterApp;
        set => StateUISession.RegisterApp = value;
    }

    /// <summary>
    /// Starts a session and renders at once, so a host has content the moment it
    /// is constructed.
    /// </summary>
    public StateUIHost()
    {
        _session = new StateUISession(this);

        // The page and window are reached again once this host is really in the
        // visual tree. OnParentSet alone is not enough: a host added to a layout
        // that is added to a page afterwards has a parent long before there is a
        // page above it.
        Loaded += (_, _) => ApplyTitles();

        _session.Render();
    }

    /// <summary>
    /// Platform and architecture reported by the native library.
    /// </summary>
    /// <remarks>
    /// A smoke test: a correct value proves the library was built for this
    /// target and actually loaded.
    /// </remarks>
    public static string NativePlatform
    {
        get
        {
            try
            {
                return NativeMethods.TakeString(NativeMethods.Platform());
            }
            catch (Exception ex) when (ex is DllNotFoundException or EntryPointNotFoundException)
            {
                return "unavailable";
            }
        }
    }

    bool IStateUITarget.Apply(SwiftNode application, bool complete)
    {
        try
        {
            return ApplyApplication(application);
        }
        catch (SwiftTreeDriftException drift)
        {
            // A patch about a tree this host is not holding. REFUSED rather
            // than failed: the session answers a refusal by dropping the
            // generation and asking Swift for everything, which is the
            // recovery this condition wants. See SwiftTreeDriftException.
            StateUISession.Report(
                $"The interface drifted and is being asked for again: {drift.Message}");

            return false;
        }
    }

    /// <summary>The one window this host stands for, out of what arrived.</summary>
    /// <param name="application">The application node - the root of a message.</param>
    private bool ApplyApplication(SwiftNode application)
    {
        // ONE window's worth, whatever the application describes: this host is a
        // view inside a page someone else opened, so there is nowhere to put a
        // second one. The first is the one it shows.
        if (application.Children is not { Count: > 0 } windows)
        {
            return true;
        }

        if (windows.Count > 1)
        {
            ((IStateUITarget)this).Fail(
                $"A StateUIHost shows one window; this application describes " +
                $"{windows.Count}.\n\n" +
                "An application with several windows describes them whole: return " +
                "a StateUIWindow from the application's CreateWindow instead.",
                null);

            return true;
        }

        return ApplyWindow(windows[0]);
    }

    /// <summary>
    /// Applies the one window this host stands for: its own properties, kept
    /// until there is somewhere to write them, and the page it shows.
    /// </summary>
    private bool ApplyWindow(SwiftNode window)
    {
        // Kept rather than applied: there may be no MAUI window above this host
        // yet. What arrives is merged into what was already known, because a
        // patch carries only the properties that changed.
        _window = Merge(_window, window);

        // No child means nothing below the window changed. Read by TYPE, the
        // rule a page's own children follow.
        foreach (SwiftNode child in window.Children ?? [])
        {
            switch (child.Type)
            {
                case SwiftNodeType.ContentPage:
                    ApplyPage(child);
                    break;

                default:
                    ((IStateUITarget)this).Fail(
                        $"A StateUIHost can show a ContentPage, not a '{child.TypeName}'.\n\n" +
                        "An arrangement - a NavigationPage, a TabbedPage, a FlyoutPage - " +
                        "is a page and needs a window of its own: return a StateUIWindow " +
                        "from the application's CreateWindow instead.",
                        null);
                    return true;
            }
        }

        ApplyTitles();
        return true;
    }

    void IStateUITarget.Fail(string message, Exception? exception)
    {
        Content = StateUISession.BuildError(message, exception);
    }

    /// <summary>
    /// Applies the ContentPage node: the page's own properties onto this view,
    /// and its content through the renderer.
    /// </summary>
    private void ApplyPage(SwiftNode page)
    {
        if (page.GetString(SwiftProp.Title) is string title) { _pageTitle = title; }
        if (page.GetBool(SwiftProp.HideSoftInputOnTapped) is bool hideOnTapped) { _hideSoftInputOnTapped = hideOnTapped; }
        if (page.GetThickness(SwiftProp.Padding) is Thickness padding) { Padding = padding; }
        page.SetColor(SwiftProp.BackgroundColor, this, VisualElement.BackgroundColorProperty);

        // The current content goes back in, so the renderer can keep every
        // control the message does not speak about. An error view from a
        // previous attempt came from no node and is simply replaced.
        if (page.Children is { Count: > 0 } children)
        {
            Content = _session.Renderer.Render(Content, children[0]);
        }
    }

    /// <summary>
    /// Everything a patch left behind, plus what has just arrived.
    /// </summary>
    /// <remarks>
    /// A message carries only the properties that changed, and this host may not
    /// have a window to write them to yet - so they have to accumulate until it
    /// does, or a title arriving on its own would lose the size that came with
    /// the first render. A node marked <c>replace</c> is complete by definition
    /// and starts again.
    /// </remarks>
    private static SwiftNode Merge(SwiftNode? kept, SwiftNode arrived)
    {
        if (kept?.Props is null || arrived.Replace)
        {
            return arrived;
        }

        var merged = new Dictionary<SwiftProp, SwiftWireValue>(kept.Props);

        foreach (KeyValuePair<SwiftProp, SwiftWireValue> property in arrived.Props ?? [])
        {
            merged[property.Key] = property.Value;
        }

        arrived.Props = merged;

        // A window is the library's own type, so it has no properties of its
        // own vocabulary - but the bag is carried through all the same, so
        // that nothing here has to be the one place that quietly drops half a
        // node.
        if (kept.OwnProps is not null)
        {
            var own = new Dictionary<string, SwiftWireValue>(kept.OwnProps);

            foreach (KeyValuePair<string, SwiftWireValue> property in arrived.OwnProps ?? [])
            {
                own[property.Key] = property.Value;
            }

            arrived.OwnProps = own;
        }

        return arrived;
    }

    /// <summary>
    /// Puts the page title and the window's own properties on the MAUI page and
    /// window this host is inside, if it has been placed in one yet.
    /// </summary>
    private void ApplyTitles()
    {
        if (_pageTitle is not null && Ancestor<Page>() is Page page)
        {
            page.Title = _pageTitle;
        }

        if (_hideSoftInputOnTapped is bool hideOnTapped && Ancestor<ContentPage>() is ContentPage content)
        {
            content.HideSoftInputOnTapped = hideOnTapped;
        }

        if (_window is not null && Ancestor<Window>() is Window window)
        {
            _window.ApplyWindow(window);
        }
    }

    /// <summary>
    /// Applies them again once this host has a parent - it may now have a page
    /// above it.
    /// </summary>
    protected override void OnParentSet()
    {
        base.OnParentSet();
        ApplyTitles();
    }

    /// <summary>
    /// The nearest ancestor of a type, or null. How a host reaches the real MAUI
    /// page and window it is sitting in.
    /// </summary>
    private T? Ancestor<T>() where T : Element
    {
        for (Element? element = Parent; element is not null; element = element.Parent)
        {
            if (element is T match)
            {
                return match;
            }
        }

        return null;
    }
}
