using StateUI.Runtime.Protocol;

// Aliased rather than imported, for the reason SwiftValues says: that namespace
// repeats MAUI's control names as static classes of its own.
using iOSPage = Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.Page;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Turns the page nodes of a message into real MAUI pages, and keeps them.
/// </summary>
/// <remarks>
/// <para>
/// A FUNCTION of a node, not a method on a window, and deliberately so: pages
/// nest - a NavigationPage holds ContentPages, and a TabbedPage will hold
/// NavigationPages - so materializing one has to be able to call itself. The
/// same call is what a SECOND window would make, which is the whole reason
/// this is not written inside <see cref="StateUIWindow"/>: nothing here
/// knows what a window is.
/// </para>
/// <para>
/// Pages are kept by the identity of the node they came from, so a page that
/// is described again keeps its controls, its scroll offsets and its focus.
/// A page nothing names any more is dropped when the stack it was on says so.
/// </para>
/// </remarks>
internal sealed class SwiftPages
{
    /// <summary>What materializes the views inside a page.</summary>
    private readonly StateUIRenderer _renderer;

    /// <summary>Every page this has built, by the key of its node.</summary>
    private readonly Dictionary<string, Page> _pages = [];

    /// <summary>The navigation stacks, by the key of their node.</summary>
    private readonly Dictionary<string, Stack> _stacks = [];

    /// <summary>The tab bars, by the key of their node.</summary>
    private readonly Dictionary<string, Tabs> _tabs = [];

    /// <summary>The flyouts, by the key of their node.</summary>
    private readonly Dictionary<string, Flyout> _flyouts = [];

    /// <summary>
    /// What is presented OVER all of it, once something has described one.
    /// </summary>
    /// <remarks>
    /// One per window rather than one per node, because that is what the
    /// platform has: a modal page covers the window, so the stack belongs to
    /// the window and there is nowhere else to put a second one.
    /// </remarks>
    private Modals? _modals;

    /// <summary>Reports a failure the way the target that owns this would.</summary>
    private readonly Action<string, Exception?> _fail;

    /// <summary>A page renderer over a renderer of views.</summary>
    /// <param name="renderer">What materializes the views inside a page.</param>
    /// <param name="fail">Called with anything that cannot be applied.</param>
    internal SwiftPages(StateUIRenderer renderer, Action<string, Exception?> fail)
    {
        _renderer = renderer;
        _fail = fail;
    }

    /// <summary>The page a key stands for, when one has been built.</summary>
    /// <param name="key">The node identity to look up.</param>
    /// <returns>The page, or null when nothing has been built for that key.</returns>
    internal Page? Known(string key) => _pages.GetValueOrDefault(key);

    /// <summary>Forgets every page, so the next message builds again.</summary>
    internal void Forget()
    {
        _pages.Clear();
        _stacks.Clear();
        _tabs.Clear();
        _flyouts.Clear();
        _modals = null;
    }

    /// <summary>
    /// The page a node describes - the one that was there when it can be, a new
    /// one when it cannot.
    /// </summary>
    /// <param name="existing">The page showing in this slot, if any.</param>
    /// <param name="node">What Swift says should be there.</param>
    /// <returns>The page to show.</returns>
    internal Page Render(Page? existing, SwiftNode node) => Render(existing, node, _pages);

    /// <summary>The same, within the set of pages one container is keeping.</summary>
    /// <remarks>
    /// A node identity is unique among its SIBLINGS, not in the tree: every
    /// stack calls its own root "root", so two stacks in one application would
    /// share a page if there were one flat map. Each container therefore keeps
    /// its own - the window's here, a stack's on its <see cref="Stack"/>.
    /// </remarks>
    /// <param name="existing">The page showing in this slot, if any.</param>
    /// <param name="node">What Swift says should be there.</param>
    /// <param name="kept">The pages this container is keeping.</param>
    /// <returns>The page to show.</returns>
    private Page Render(Page? existing, SwiftNode node, Dictionary<string, Page> kept)
    {
        Page? was = kept.GetValueOrDefault(node.Key);

        if (node.Replace && was is not null)
        {
            kept.Remove(node.Key);
            _stacks.Remove(node.Key);
            _tabs.Remove(node.Key);
            _flyouts.Remove(node.Key);
            was = null;
        }

        switch (node.Type)
        {
            case SwiftNodeType.ContentPage:
            {
                ContentPage page = was as ContentPage ?? new ContentPage();

                if (was is not ContentPage)
                {
                    // Once, where the page is CREATED - the rule every control
                    // follows. The id is read at fire time, so a later message
                    // that changes which handler listens needs nothing here.
                    //
                    // Through the dispatcher, the one-turn delay a tab bar's
                    // report uses and for the same reason: MAUI raises
                    // Appearing while the page is being put on screen, which is
                    // inside the message that described it, and a report made
                    // there is DROPPED. A turn later there is nothing to
                    // swallow it.
                    page.Appearing += (sender, _) => Announce(sender, SwiftEvent.Appearing);
                    page.Disappearing += (sender, _) => Announce(sender, SwiftEvent.Disappearing);
                }

                kept[node.Key] = page;
                ApplyContentPage(page, node);
                return page;
            }

            case SwiftNodeType.NavigationPage:
                return ApplyNavigationPage(was as NavigationPage, node, kept);

            case SwiftNodeType.TabbedPage:
                return ApplyTabbedPage(was as TabbedPage, node, kept);

            case SwiftNodeType.FlyoutPage:
                return ApplyFlyoutPage(was as FlyoutPage, node, kept);

            default:
                _fail($"A window can show a page, not a '{node.TypeName}'.", null);
                return existing ?? new ContentPage();
        }
    }

    // ---- The navigation stack ----------------------------------------------

    /// <summary>
    /// What a NavigationPage needs remembered between messages.
    /// </summary>
    /// <remarks>
    /// <c>Desired</c> is the whole pop protocol: it is how deep Swift last said
    /// the stack should be. A Popped that lands on that depth is this side's own
    /// doing and says nothing; a Popped that lands anywhere else is the reader's
    /// - a back arrow, a swipe, Android's system gesture - and is reported so
    /// the bound path can be truncated to match.
    /// </remarks>
    private sealed class Stack
    {
        /// <summary>The MAUI page holding the stack.</summary>
        internal required NavigationPage Page { get; init; }

        /// <summary>The node it was built from, for the handler ids.</summary>
        internal required SwiftNode Node { get; set; }

        /// <summary>
        /// The pages ON this stack, by the identity of the node each came from.
        /// </summary>
        /// <remarks>
        /// Its own map, not a share of one: every stack's root is identified
        /// "root", so one flat map would hand a second stack the first one's
        /// root page.
        /// </remarks>
        internal required Dictionary<string, Page> Pages { get; init; }

        /// <summary>
        /// The stack Swift last described, root first, as node identities.
        /// </summary>
        /// <remarks>
        /// KEYS rather than pages, so that a page rebuilt under an unchanged
        /// identity - which is what `replace` means - takes its own place in
        /// the target without anything having to notice.
        /// </remarks>
        internal List<string> Order { get; set; } = [];

        /// <summary>The stack Swift last described, as the pages it is made of.</summary>
        internal List<Page> Target =>
            [.. Order.Select(key => Pages.GetValueOrDefault(key)).OfType<Page>()];

        /// <summary>How deep above the root Swift last said it should be.</summary>
        internal int Desired { get; set; }

        /// <summary>Whether a reconciliation is already running.</summary>
        internal bool Settling { get; set; }
    }

    /// <summary>Applies a NavigationPage node, building the stack if it is new.</summary>
    /// <param name="existing">The stack page that was there, if any.</param>
    /// <param name="node">What Swift says the stack is.</param>
    /// <param name="kept">The pages the CONTAINER of this stack is keeping.</param>
    /// <returns>The NavigationPage to show.</returns>
    private Page ApplyNavigationPage(
        NavigationPage? existing, SwiftNode node, Dictionary<string, Page> kept)
    {
        List<SwiftNode> children = node.Children ?? [];

        if (existing is null || !_stacks.TryGetValue(node.Key, out Stack? stack))
        {
            if (children.Count == 0)
            {
                _fail("A NavigationPage arrived with no page under it.", null);
                return new ContentPage();
            }

            // This stack's OWN page map, filled before the NavigationPage
            // exists - the root has to be built first, MAUI having no empty
            // NavigationPage: the page under everything is a constructor
            // argument there.
            Dictionary<string, Page> mine = [];
            var built = new NavigationPage(Render(null, children[0], mine));

            stack = new Stack { Page = built, Node = node, Pages = mine };

            _stacks[node.Key] = stack;
            kept[node.Key] = built;

            // Before the subscription below, because that is where the handler
            // ids come from: an untracked page reports to nobody.
            _renderer.Track(built, node);

            // Once, where the page is created - the rule every control follows.
            // The id is read at fire time, so a later message that changes which
            // handler listens needs nothing done here.
            //
            // ChildRemoved rather than NavigationPage.Popped, measured: Popped
            // is raised by the PLATFORM's navigation completing, so it never
            // fires without a handler under it and nothing about the pop
            // protocol could be tested off a device. The children are where a
            // NavigationStack comes from - it IS the page list - so a stack
            // that shrank always says so here, on a device and in a test alike.
            built.ChildRemoved += (_, _) => Announce(stack);

            ApplyPageChrome(built, node);
            ApplyBar(built, node);

            foreach (SwiftNode child in children.Skip(1))
            {
                Render(null, child, stack.Pages);
            }

            stack.Order = Order(children, stack.Pages, "navigation stack");
            stack.Desired = stack.Order.Count - 1;

            Settle(stack);
            return built;
        }

        stack.Node = node;
        _renderer.Track(stack.Page, node);
        ApplyPageChrome(stack.Page, node);
        ApplyBar(stack.Page, node);

        // Every child that arrived is applied, whether or not the ORDER came
        // with it: a patch that changed one page's text carries that page alone.
        //
        // A page can come back a DIFFERENT object all the same - `replace` says
        // the old one cannot be patched into what the node now describes - and
        // then the native stack is holding a page nobody describes any more.
        // That is a reconciliation even though no arrangement arrived, which is
        // why this is watched rather than assumed.
        bool replaced = false;

        foreach (SwiftNode child in children)
        {
            Page? was = stack.Pages.GetValueOrDefault(child.Key);
            Page made = Render(was, child, stack.Pages);

            replaced = replaced || (was is not null && !ReferenceEquals(was, made));
        }

        // The order, the count and the removals in one - so a stack is only
        // rearranged when the message actually describes an arrangement. A
        // page REBUILT under an unchanged identity settles too: the order did
        // not move, but what stands at one of its places did.
        if (node.Arranged)
        {
            stack.Order = Order(children, stack.Pages, "navigation stack");

            foreach (string gone in stack.Pages.Keys.Except(stack.Order).ToList())
            {
                stack.Pages.Remove(gone);
            }
        }

        if (node.Arranged || replaced)
        {
            stack.Desired = stack.Order.Count - 1;
            Settle(stack);
        }

        return stack.Page;
    }

    /// <summary>
    /// The bar's own look, which belongs to the STACK rather than to a page on
    /// it: MAUI declares these three on NavigationPage itself.
    /// </summary>
    /// <remarks>
    /// What one page says about the bar - hidden, a different back button, a
    /// view in place of the title - is an attached property and is applied with
    /// the page, in <see cref="ApplyNavigationAppearance"/>.
    /// </remarks>
    /// <param name="navigation">The stack page to paint.</param>
    /// <param name="node">What Swift says about it.</param>
    private static void ApplyBar(NavigationPage navigation, SwiftNode node)
    {
        node.SetColor(SwiftProp.BarBackgroundColor, navigation, NavigationPage.BarBackgroundColorProperty);
        node.SetBrush(SwiftProp.BarBackground, navigation, NavigationPage.BarBackgroundProperty);
        node.SetColor(SwiftProp.BarTextColor, navigation, NavigationPage.BarTextColorProperty);
    }

    /// <summary>The same three, on the other page that draws a bar.</summary>
    /// <remarks>
    /// MAUI declares them on the interface both pages implement and repeats the
    /// static fields on each class, so this is the same three properties named
    /// through TabbedPage - which is exactly why the Swift side has them on one
    /// tier, <c>BarElement</c>, rather than twice.
    /// </remarks>
    /// <param name="tabbed">The tabbed page to paint.</param>
    /// <param name="node">What Swift says about it.</param>
    private static void ApplyBar(TabbedPage tabbed, SwiftNode node)
    {
        node.SetColor(SwiftProp.BarBackgroundColor, tabbed, TabbedPage.BarBackgroundColorProperty);
        node.SetBrush(SwiftProp.BarBackground, tabbed, TabbedPage.BarBackgroundProperty);
        node.SetColor(SwiftProp.BarTextColor, tabbed, TabbedPage.BarTextColorProperty);

        node.SetColor(SwiftProp.SelectedTabColor, tabbed, TabbedPage.SelectedTabColorProperty);
        node.SetColor(SwiftProp.UnselectedTabColor, tabbed, TabbedPage.UnselectedTabColorProperty);
    }

    /// <summary>
    /// What a page is called and what stands for it - the two properties MAUI
    /// declares on Page that a CONTAINER page needs as much as a content one.
    /// </summary>
    /// <remarks>
    /// A tab reads its caption and its icon off the page inside it, and that
    /// page is often a whole navigation stack - so these cannot be a content
    /// page's alone. The Swift side spells them as a written page's properties
    /// (<c>var title</c>) or as modifiers on a constructed one
    /// (<c>.title("Home")</c>); both arrive here as the same two keys.
    /// </remarks>
    /// <param name="page">The page to name.</param>
    /// <param name="node">What Swift says about it.</param>
    private static void ApplyPageChrome(Page page, SwiftNode node)
    {
        if (node.GetString(SwiftProp.Title) is string title) { page.Title = title; }

        node.SetImageSource(SwiftProp.IconImageSource, page, Page.IconImageSourceProperty);

        // How the page is drawn when it is PRESENTED, which is a page's own
        // property and not the modal stack's: a sheet knows what it looks like
        // wherever it is presented from. Set here rather than in the modal
        // stack so that a whole NavigationPage presented as a card - the usual
        // shape of a sheet on iOS - can say it as readily as a content page.
        //
        // UIKit's, and the only platform that reads it; assigning it elsewhere
        // is setting a bindable property nothing looks at.
        if (node.GetModalPresentationStyle(SwiftProp.ModalPresentationStyle) is { } style)
        {
            page.SetValue(iOSPage.ModalPresentationStyleProperty, style);
        }
    }

    /// <summary>The identities an arranged child list names, in order.</summary>
    /// <remarks>
    /// A child this renderer could not build - anything that is not a page -
    /// is REPORTED rather than skipped. Dropping it silently would leave a
    /// shorter arrangement than Swift described, which the reconciliation that
    /// follows can then never reach.
    /// </remarks>
    /// <param name="children">The arranged children of a page arrangement.</param>
    /// <param name="pages">The pages that arrangement has built.</param>
    /// <param name="arrangement">What to call it in a failure - "stack", "tab bar".</param>
    /// <returns>The identities, in the order they arrived.</returns>
    private List<string> Order(
        List<SwiftNode> children, Dictionary<string, Page> pages, string arrangement)
    {
        List<string> order = [];

        foreach (SwiftNode child in children)
        {
            if (pages.ContainsKey(child.Key))
            {
                order.Add(child.Key);
            }
            else
            {
                _fail($"A {arrangement} cannot hold a '{child.TypeName}'.", null);
            }
        }

        return order;
    }

    /// <summary>
    /// Brings the native stack to what Swift described, one move at a time.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Started rather than awaited: MAUI's pushes and pops are asynchronous and
    /// a message is applied synchronously, so the reconciliation runs on after
    /// the message is done with. One at a time per stack, and the loop re-reads
    /// the target after every move - which is what makes a second tap arriving
    /// mid-animation land on the stack that the first one produced instead of
    /// racing it.
    /// </para>
    /// <para>
    /// Only the move that REACHES the target is animated. The others are the
    /// middle of a multi-page jump, which no platform animates one page at a
    /// time either.
    /// </para>
    /// </remarks>
    /// <param name="stack">The stack to settle.</param>
    private void Settle(Stack stack)
    {
        if (stack.Settling)
        {
            return;
        }

        stack.Settling = true;
        _ = SettleAsync(stack);
    }

    /// <summary>The loop behind <see cref="Settle(Stack)"/>.</summary>
    /// <param name="stack">The stack to settle.</param>
    /// <returns>The task that finishes when the stack matches.</returns>
    private async Task SettleAsync(Stack stack)
    {
        try
        {
            while (true)
            {
                List<Page> target = stack.Target;
                INavigation navigation = stack.Page.Navigation;
                IReadOnlyList<Page> current = navigation.NavigationStack;

                if (target.Count == 0)
                {
                    // Nothing to reconcile TO. Swift never describes an empty
                    // stack, so this is a child that could not be built - the
                    // failure is already reported, and going on would be a loop
                    // with nothing to move towards.
                    return;
                }

                int common = 0;
                while (common < current.Count && common < target.Count
                    && ReferenceEquals(current[common], target[common]))
                {
                    common++;
                }

                if (common == current.Count && common == target.Count)
                {
                    return;
                }

                // What the stack was before this move, so a move that changes
                // nothing can be recognized rather than repeated - see the
                // guard at the bottom of the loop.
                (int Count, Page? Bottom) before =
                    (current.Count, current.Count > 0 ? current[0] : null);

                if (common == 0 && current.Count > 0)
                {
                    // The page at the BOTTOM is a different page now, which a
                    // pop cannot fix: MAUI refuses to pop a one-page stack, and
                    // a loop that keeps asking would spin the UI thread at 100%
                    // - measured, before this arm existed. The bottom of a
                    // stack is swapped by inserting under it and removing it.
                    //
                    // The old page is held in a LOCAL first: NavigationStack is
                    // a live view of the children, so after the insert
                    // `current[0]` is the page that was just put there, and
                    // removing that would undo the move and spin instead.
                    Page bottom = before.Bottom!;

                    navigation.InsertPageBefore(target[0], bottom);
                    navigation.RemovePage(bottom);
                }
                else if (current.Count > common)
                {
                    // Everything above the topmost survivor goes at once, and
                    // the page the reader is LOOKING AT leaves through PopAsync
                    // so the platform draws one transition from it to what they
                    // asked for.
                    //
                    // The doomed pages UNDER the visible one - indices
                    // `common` through `Count - 2` - and never the visible page
                    // itself: MAUI does not support removing the page that is
                    // showing, and on Apple it snapped to the page underneath
                    // before animating away from THAT, so going home from a
                    // sample flashed the group page the reader had not asked
                    // for. Measured on Catalyst; what goes silently
                    // is what nobody can see going.
                    for (int i = current.Count - 2; i >= common; i--)
                    {
                        navigation.RemovePage(current[i]);
                    }

                    await navigation.PopAsync(animated: target.Count == common);
                }
                else
                {
                    await navigation.PushAsync(
                        target[common], animated: common == target.Count - 1);
                }

                // A turn that moved NOTHING would go round for ever, and a spin
                // here is the UI thread. Whatever MAUI does or stops doing, this
                // loop reports and stops instead.
                IReadOnlyList<Page> after = stack.Page.Navigation.NavigationStack;

                if (after.Count == before.Count
                    && ReferenceEquals(after.Count > 0 ? after[0] : null, before.Bottom))
                {
                    _fail(
                        "The navigation stack could not be brought to what Swift described.",
                        null);
                    return;
                }
            }
        }
        catch (Exception exception)
        {
            _fail("The navigation stack could not be brought to what Swift described.", exception);
        }
        finally
        {
            stack.Settling = false;
        }
    }

    /// <summary>
    /// Tells Swift about a pop the READER made, and says nothing about ours.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A back gesture is cancellable, so this runs when MAUI has already
    /// finished the pop: what is reported is the depth that SURVIVED, never an
    /// intention. Swift truncates its path to it, and the render that follows
    /// finds the native stack already right and does nothing.
    /// </para>
    /// <para>
    /// A back press landing between two of our own moves is not reported, and
    /// is undone by the move that follows. That is deliberate - a reader
    /// cannot reach the screen mid-transition in any ordinary way - and what
    /// makes it so is the DEPTH comparison below rather than the
    /// <c>Settling</c> flag: by the time a queued report runs, the settle it
    /// landed in the middle of has finished, and the stack is where Swift
    /// asked.
    /// </para>
    /// <para>
    /// Reached a TURN LATE, through <see cref="Announce(Stack)"/>, and that is
    /// what makes the depth right rather than what makes it late: every
    /// removal on the way to what Swift described queues one of these, and each
    /// reads the stack at the moment it RUNS - so N queued reports all read the
    /// settled depth, the first writes <c>Desired</c>, and the rest compare
    /// equal and say nothing. It is the same shape modals uses
    /// (<see cref="Report(Modals)"/>): <c>Desired</c> is written BEFORE the
    /// settle starts, so a converged settle is silent by arithmetic.
    /// </para>
    /// <para>
    /// The deferral is required, not a nicety, for two reasons.
    /// <c>Raise</c> pumps the session synchronously, so an inline raise runs a
    /// whole Swift render from inside MAUI's own child-removal notification -
    /// the re-entrancy that takes Android down with
    /// <i>"No view found for id … for fragment"</i> when a render lands inside
    /// a MAUI setter. And a removal raised inside an apply would write
    /// <c>Desired</c> while <c>Raise</c> silently dropped the report, leaving
    /// this side believing Swift had been told something it never heard.
    /// </para>
    /// <para>
    /// What the delay gives up is distinguishing a settle that FAILED from a
    /// reader who popped, both being "the stack is not where Swift asked".
    /// Measured against the Swift handler, neither direction misleads it: a
    /// failed POP leaves the stack DEEPER than the described path, and the
    /// handler only ever shortens (<c>depth &lt; routes.count</c>), so it
    /// ignores it; a failed PUSH leaves it shallower, and truncating the path
    /// to the depth actually reached is what the screen shows.
    /// </para>
    /// </remarks>
    /// <param name="stack">The stack that popped.</param>
    private void Report(Stack stack)
    {
        // A reconciliation in progress is this side removing pages one at a
        // time on its way to what Swift described. Every depth it passes
        // through is a depth nobody asked to be at, so none of them is news.
        if (stack.Settling)
        {
            return;
        }

        int depth = stack.Page.Navigation.NavigationStack.Count - 1;

        if (depth == stack.Desired)
        {
            return;
        }

        stack.Desired = depth;
        _renderer.Raise(stack.Page, SwiftEvent.Popped, (double)depth);
    }

    /// <summary>Says how deep the stack is now, a turn from now.</summary>
    /// <remarks>
    /// EVERY report about a stack goes through here, for the reason
    /// <see cref="Announce(Flyout)"/> gives and one of its own: a report made
    /// inside a message is not queued but DROPPED, and raising one inline meant
    /// rendering from inside MAUI's own notification. See
    /// <see cref="Report(Stack)"/>.
    /// </remarks>
    /// <param name="stack">The stack that may have shrunk.</param>
    private void Announce(Stack stack) => stack.Page.Dispatcher.Dispatch(() => Report(stack));

    // ---- The tabs ------------------------------------------------------------

    /// <summary>
    /// What a TabbedPage needs remembered between messages.
    /// </summary>
    /// <remarks>
    /// <c>Desired</c> is the tab protocol, and it is the same shape as the
    /// stack's: the index Swift is known to believe is showing. A
    /// CurrentPageChanged that lands on it is this side's own assignment coming
    /// back and says nothing; one that lands anywhere else is the reader's
    /// finger - or the platform choosing for itself, when the tab that was
    /// showing has been taken away - and is reported so the bound selection can
    /// be written to match.
    /// </remarks>
    private sealed class Tabs
    {
        /// <summary>The MAUI page holding the tabs.</summary>
        internal required TabbedPage Page { get; init; }

        /// <summary>The pages in this tab bar, by the identity of their nodes.</summary>
        /// <remarks>Its own map, for the reason a stack's is: see <see cref="Stack.Pages"/>.</remarks>
        internal required Dictionary<string, Page> Pages { get; init; }

        /// <summary>The tabs Swift last described, in order, as node identities.</summary>
        internal List<string> Order { get; set; } = [];

        /// <summary>The tabs Swift last described, as the pages they are made of.</summary>
        internal List<Page> Target =>
            [.. Order.Select(key => Pages.GetValueOrDefault(key)).OfType<Page>()];

        /// <summary>Which tab Swift is known to believe is showing, or -1.</summary>
        internal int Desired { get; set; } = -1;

        /// <summary>Whether this side is the one moving the tabs about.</summary>
        internal bool Applying { get; set; }
    }

    /// <summary>Applies a TabbedPage node, building the tab bar if it is new.</summary>
    /// <remarks>
    /// Nothing here is asynchronous, which is the whole difference from a
    /// navigation stack: a TabbedPage's children are an ordinary list and the
    /// current page an ordinary property, so what Swift described is reached
    /// within the message rather than settled towards afterwards.
    /// </remarks>
    /// <param name="existing">The tabbed page that was there, if any.</param>
    /// <param name="node">What Swift says the tabs are.</param>
    /// <param name="kept">The pages the CONTAINER of this tab bar is keeping.</param>
    /// <returns>The TabbedPage to show.</returns>
    private Page ApplyTabbedPage(
        TabbedPage? existing, SwiftNode node, Dictionary<string, Page> kept)
    {
        if (existing is null || !_tabs.TryGetValue(node.Key, out Tabs? tabs))
        {
            // Unlike a NavigationPage, which MAUI will not build without a page
            // under it, an empty TabbedPage is a legal object - so the tabs are
            // added below like any other arrangement.
            var built = new TabbedPage();

            tabs = new Tabs { Page = built, Pages = [] };

            _tabs[node.Key] = tabs;
            kept[node.Key] = built;

            // Before the subscription, because that is where the handler ids
            // come from: an untracked page reports to nobody.
            _renderer.Track(built, node);

            // Once, where the page is created - the rule every control follows.
            // The id is read at fire time, so a later message that changes which
            // handler listens needs nothing done here.
            //
            // Through the same one-turn delay the arrangement uses, and for the
            // same reason: MAUI can move the current page while a message is
            // being applied, reporting is held off for the whole of one, and a
            // report made there is DROPPED - after `Report` has written down
            // that Swift was told. A turn later there is nothing to swallow it.
            built.CurrentPageChanged += (_, _) => Announce(tabs);
        }
        else
        {
            _renderer.Track(tabs.Page, node);
        }

        ApplyPageChrome(tabs.Page, node);
        ApplyBar(tabs.Page, node);

        List<SwiftNode> children = node.Children ?? [];

        foreach (SwiftNode child in children)
        {
            Render(tabs.Pages.GetValueOrDefault(child.Key), child, tabs.Pages);
        }

        if (node.Arranged)
        {
            tabs.Order = Order(children, tabs.Pages, "tab bar");

            foreach (string gone in tabs.Pages.Keys.Except(tabs.Order).ToList())
            {
                tabs.Pages.Remove(gone);
            }
        }

        // Every message, not only an arranged one: a page REBUILT under an
        // unchanged identity - which is what `replace` means - leaves the old
        // object in the children list, and comparing what is there against what
        // is described is both the cheapest way to notice and the only one that
        // cannot be reasoned wrong.
        Arrange(tabs, node.GetInt(SwiftProp.CurrentPage));

        return tabs.Page;
    }

    /// <summary>
    /// Brings the tab bar's children, and which of them is showing, to what
    /// Swift described.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The moves are made with <c>Applying</c> set, so the CurrentPageChanged
    /// that MAUI raises on the way - a tab bar always has a current page, so
    /// adding the first child picks one - is not read as the reader's doing.
    /// What the platform settled on is compared against what was asked for
    /// afterwards, once, by <see cref="Report(Tabs)"/>.
    /// </para>
    /// <para>
    /// The index is Swift's own position in the arranged list, which is the
    /// list this is arranging - so the two cannot disagree unless a child could
    /// not be built, which is reported when the order is read.
    /// </para>
    /// </remarks>
    /// <param name="tabs">The tab bar to arrange.</param>
    /// <param name="asked">Which tab Swift says is showing, if it said.</param>
    private void Arrange(Tabs tabs, int? asked)
    {
        List<Page> target = tabs.Target;
        IList<Page> children = tabs.Page.Children;

        // What is showing BEFORE the children are moved about, because the
        // moving destroys the answer. MAUI's own MultiPage puts CurrentPage
        // back to Children[0] the moment the showing page is not in the
        // collection, and the loop below takes every page it has to move OUT
        // and puts it back in - so a fallback read afterwards answers the first
        // tab whatever was showing. Which matters exactly when Swift said
        // nothing about the selection, and Swift says nothing when the showing
        // tab keeps its INDEX across a reorder: the differ sends a property
        // only when its value changed.
        Page? showing = tabs.Page.CurrentPage;

        tabs.Applying = true;

        try
        {
            for (int index = 0; index < target.Count; index++)
            {
                int at = children.IndexOf(target[index]);

                if (at == index)
                {
                    continue;
                }

                if (at >= 0)
                {
                    children.RemoveAt(at);
                }

                children.Insert(index, target[index]);
            }

            while (children.Count > target.Count)
            {
                children.RemoveAt(children.Count - 1);
            }

            if (target.Count > 0)
            {
                // What Swift asked for, or - when it asked for nothing -
                // wherever the tab that WAS showing has ended up. A tab bar
                // ends this with a current page that is one of its own
                // children either way, and Report below tells Swift which if it
                // is not what Swift believes: -1 here is the showing tab
                // described away, which falls back to the first and is
                // reported.
                int current = asked ?? target.IndexOf(showing ?? target[0]);

                if (current < 0 || current >= target.Count)
                {
                    current = 0;
                }

                tabs.Page.CurrentPage = target[current];

                if (asked is not null)
                {
                    tabs.Desired = current;
                }
            }
        }
        catch (Exception exception)
        {
            _fail("The tabs could not be brought to what Swift described.", exception);
        }
        finally
        {
            tabs.Applying = false;
        }

        // A TURN LATER, and that is not a detail: the window holds reporting
        // off for the WHOLE of a message - see StateUIRenderer.Applying - so
        // that Swift never hears its own writes echoed back. What this has to
        // say is not an echo, it is the platform's own answer to a tab being
        // described away; but said here it would be swallowed with the rest.
        //
        // MEASURED, and it is a trap for the test that covers it: calling the
        // page renderer directly, where nothing suppresses anything, passes
        // while the device stays silent. The test therefore applies the
        // message inside the same scope the window does.
        Announce(tabs);
    }

    /// <summary>Says which tab is showing, a turn from now.</summary>
    /// <remarks>
    /// EVERY report about a tab bar goes through here, whatever raised it - see
    /// <see cref="Announce(Flyout)"/> for why that matters: a report made
    /// inside a message is not queued but dropped, and <see cref="Report(Tabs)"/>
    /// has by then written down that Swift was told.
    /// </remarks>
    /// <param name="tabs">The tab bar that may have moved.</param>
    private void Announce(Tabs tabs) => tabs.Page.Dispatcher.Dispatch(() => Report(tabs));

    /// <summary>
    /// A page's own event, reported a TURN later.
    /// </summary>
    /// <remarks>
    /// The delay is the tab bar's, for the same reason: MAUI raises Appearing
    /// while the page is being put on screen, which happens inside the message
    /// that described it, and <see cref="StateUIRenderer.Raise(object?,
    /// SwiftEvent, byte[])"/> drops a report made from inside an apply - rendering
    /// there is a resync. A turn later there is nothing to swallow it.
    /// </remarks>
    /// <param name="sender">The page that raised it.</param>
    /// <param name="name">The event's name on the wire.</param>
    private void Announce(object? sender, SwiftEvent name)
    {
        if (sender is not Page page)
        {
            return;
        }

        page.Dispatcher.Dispatch(() => _renderer.Raise(page, name));
    }

    /// <summary>
    /// Tells Swift which tab is showing, when it is not the one Swift believes.
    /// </summary>
    /// <remarks>
    /// Two things reach this. One is the reader choosing a tab, which is what a
    /// TabbedPage is for. The other is the PLATFORM choosing: the tab that was
    /// showing is described away, MAUI moves to another, and the bound
    /// selection would otherwise name a tab that no longer exists. Both are the
    /// same news - "this is what is showing now" - and both are folded into the
    /// binding the same way a completed pop is.
    /// </remarks>
    /// <param name="tabs">The tab bar that moved.</param>
    private void Report(Tabs tabs)
    {
        // This side rearranging is not news: every intermediate current page it
        // passes through is one nobody asked to be at.
        if (tabs.Applying)
        {
            return;
        }

        int index = tabs.Page.CurrentPage is Page current
            ? tabs.Page.Children.IndexOf(current)
            : -1;

        if (index < 0 || index == tabs.Desired)
        {
            return;
        }

        tabs.Desired = index;
        _renderer.Raise(tabs.Page, SwiftEvent.CurrentPageChanged, (double)index);
    }

    // ---- The flyout ----------------------------------------------------------

    /// <summary>
    /// What a FlyoutPage needs remembered between messages.
    /// </summary>
    /// <remarks>
    /// The same two fields the other two arrangements keep, meaning the same
    /// two things: what Swift last said, and whether this side is the one
    /// moving things about. A flyout that opens because Swift said so is not
    /// news; one that opens because a finger swiped is.
    /// </remarks>
    private sealed class Flyout
    {
        /// <summary>The MAUI page holding the two halves.</summary>
        internal required FlyoutPage Page { get; init; }

        /// <summary>The two pages, by the identity of the nodes they came from.</summary>
        internal required Dictionary<string, Page> Pages { get; init; }

        /// <summary>Whether Swift believes the flyout is showing.</summary>
        internal bool Desired { get; set; }

        /// <summary>Whether this side is the one opening or closing it.</summary>
        internal bool Applying { get; set; }
    }

    /// <summary>Applies a FlyoutPage node, building it if it is new.</summary>
    /// <param name="existing">The flyout page that was there, if any.</param>
    /// <param name="node">What Swift says it is.</param>
    /// <param name="kept">The pages the CONTAINER of this one is keeping.</param>
    /// <returns>The FlyoutPage to show.</returns>
    private Page ApplyFlyoutPage(FlyoutPage? existing, SwiftNode node, Dictionary<string, Page> kept)
    {
        if (existing is null || !_flyouts.TryGetValue(node.Key, out Flyout? flyout))
        {
            var built = new FlyoutPage();

            flyout = new Flyout { Page = built, Pages = [] };

            _flyouts[node.Key] = flyout;
            kept[node.Key] = built;

            // Before the subscription, because that is where the handler ids
            // come from: an untracked page reports to nobody.
            _renderer.Track(built, node);

            // Once, where the page is created - the rule every control follows.
            built.IsPresentedChanged += (_, _) => Announce(flyout);
        }
        else
        {
            _renderer.Track(flyout.Page, node);
        }

        ApplyPageChrome(flyout.Page, node);

        if (node.GetFlyoutLayoutBehavior(SwiftProp.FlyoutLayoutBehavior) is FlyoutLayoutBehavior behavior)
        {
            flyout.Page.FlyoutLayoutBehavior = behavior;
        }

        if (node.GetBool(SwiftProp.IsGestureEnabled) is bool gestures)
        {
            flyout.Page.IsGestureEnabled = gestures;
        }

        foreach (SwiftNode child in node.Children ?? [])
        {
            Page made = Render(flyout.Pages.GetValueOrDefault(child.Key), child, flyout.Pages);

            // By IDENTITY, not by position: a patch carries only what changed,
            // so a message about the detail page alone is one child and it is
            // not the flyout.
            switch (child.Id.Name)
            {
                case "flyout":
                    // MAUI refuses a flyout with no title - it is what the
                    // platform draws where a title goes - and the refusal is an
                    // exception from the property setter, which would take the
                    // whole message down. Said plainly instead.
                    if (made.Title is null)
                    {
                        _fail("A FlyoutPage's flyout page must have a title.", null);
                        break;
                    }

                    if (!ReferenceEquals(flyout.Page.Flyout, made)) { flyout.Page.Flyout = made; }
                    break;

                case "detail":
                    if (!ReferenceEquals(flyout.Page.Detail, made)) { flyout.Page.Detail = made; }
                    break;

                default:
                    _fail(
                        $"A FlyoutPage holds a flyout and a detail, not a '{child.Id.Identity}'.",
                        null);
                    break;
            }
        }

        Present(flyout, node.GetBool(SwiftProp.IsPresented));

        return flyout.Page;
    }

    /// <summary>Opens or closes the flyout, if Swift said which.</summary>
    /// <remarks>
    /// <para>
    /// Assigned under <c>Applying</c>, so the IsPresentedChanged that MAUI
    /// raises for OUR write is not read as the reader's. What the platform
    /// settled on is compared against what was asked for afterwards, once, and
    /// a turn later - see <see cref="Report(Flyout)"/> for why the delay is not
    /// optional.
    /// </para>
    /// <para>
    /// A flyout laid out SIDE BY SIDE is always presented and MAUI says so;
    /// that answer comes back through the same report, which is how the bound
    /// value ends up telling an application there is nothing to open.
    /// </para>
    /// </remarks>
    /// <param name="flyout">The flyout to move.</param>
    /// <param name="asked">What Swift says, if it said.</param>
    private void Present(Flyout flyout, bool? asked)
    {
        if (asked is bool presented)
        {
            if (flyout.Page.IsPresented == presented)
            {
                flyout.Desired = presented;
            }
            else
            {
                flyout.Applying = true;

                try
                {
                    flyout.Page.IsPresented = presented;

                    // Written only where the assignment TOOK. A refusal leaves
                    // Swift believing what the platform holds, so the report
                    // below has nothing to say - one report per change, rather
                    // than one for the refusal and one for the truth.
                    flyout.Desired = presented;
                }
                catch (InvalidOperationException)
                {
                    // MEASURED: a FlyoutPage showing both halves SIDE BY SIDE
                    // refuses the property outright - *"Can't change
                    // IsPresented when setting Split"*, thrown from MAUI's own
                    // property-changing callback. It is not an error and it is
                    // not ours to prevent: the layout keeps the flyout open,
                    // which is the platform answering the question. The report
                    // below carries that answer back and the binding follows it
                    // there, exactly as a tab bar's does when the tab that was
                    // showing is described away.
                    //
                    // Caught rather than avoided because the condition is MAUI's
                    // `ShouldShowSplitMode`, which is internal and depends on
                    // the screen the app happens to be on - a rule this side
                    // would have to guess at and would get wrong on a rotation.
                }
                finally
                {
                    flyout.Applying = false;
                }
            }
        }

        Announce(flyout);
    }

    /// <summary>
    /// Says what the flyout is doing, a turn from now.
    /// </summary>
    /// <remarks>
    /// EVERY report goes through here, whatever raised it - a swipe, a tap on
    /// the dimmed detail page, the platform's own button, or a message of ours
    /// that MAUI answered differently. The delay is what makes them all safe:
    /// reporting is held off for the whole of a message (see
    /// <c>StateUIRenderer.Applying</c>), and a report made there is not
    /// queued but DROPPED - while <see cref="Report(Flyout)"/> has already
    /// written down that Swift was told. Said a turn later, the message is
    /// over and there is nothing to swallow it.
    /// </remarks>
    /// <param name="flyout">The flyout that may have moved.</param>
    private void Announce(Flyout flyout) =>
        flyout.Page.Dispatcher.Dispatch(() => Report(flyout));

    /// <summary>
    /// Tells Swift the flyout opened or closed, when it was not Swift's doing.
    /// </summary>
    /// <remarks>
    /// The reader's swipe, the tap on the dimmed detail page, the platform's
    /// own button - and the layout itself, which on a wide screen keeps the
    /// flyout open whatever anybody asks. All of it is the same news, and it is
    /// folded into the binding exactly as a completed pop is.
    /// </remarks>
    /// <param name="flyout">The flyout that moved.</param>
    private void Report(Flyout flyout)
    {
        if (flyout.Applying || flyout.Page.IsPresented == flyout.Desired)
        {
            return;
        }

        flyout.Desired = flyout.Page.IsPresented;
        _renderer.Raise(flyout.Page, SwiftEvent.IsPresentedChanged, flyout.Page.IsPresented);
    }

    // ---- What is over all of it ---------------------------------------------

    /// <summary>
    /// What the window's modal stack needs remembered between messages.
    /// </summary>
    /// <remarks>
    /// The same two fields the other arrangements keep - what Swift last said,
    /// and whether this side is the one moving pages about - over a stack that
    /// is not a page at all: MAUI keeps modals on the WINDOW's navigation, so
    /// there is no MAUI object standing for the list. The window itself is
    /// therefore what reports, and it is what Swift tracked the handler on.
    /// </remarks>
    private sealed class Modals
    {
        /// <summary>The navigation that presents and dismisses - the window's.</summary>
        internal required INavigation Navigation { get; init; }

        /// <summary>
        /// What a dismissal is reported through: the window, which is the
        /// element the modal stack's handler was written on.
        /// </summary>
        internal required Element Reporter { get; init; }

        /// <summary>The presented pages, by the identity of their nodes.</summary>
        /// <remarks>Its own map, for the reason a stack's is: see <see cref="Stack.Pages"/>.</remarks>
        internal required Dictionary<string, Page> Pages { get; init; }

        /// <summary>What Swift last described, innermost first, as identities.</summary>
        internal List<string> Order { get; set; } = [];

        /// <summary>The same, as the pages they are made of.</summary>
        internal List<Page> Target =>
            [.. Order.Select(key => Pages.GetValueOrDefault(key)).OfType<Page>()];

        /// <summary>How many Swift last said are presented.</summary>
        internal int Desired { get; set; }

        /// <summary>Whether a reconciliation is already running.</summary>
        internal bool Settling { get; set; }
    }

    /// <summary>Applies the modal stack node - what is presented over the window.</summary>
    /// <remarks>
    /// The navigation is handed in rather than found, so that nothing here has
    /// to know what a window is: a second window presents through its own.
    /// </remarks>
    /// <param name="navigation">The window's navigation, which owns the modal stack.</param>
    /// <param name="reporter">What a dismissal is reported through - the window.</param>
    /// <param name="node">What Swift says is presented.</param>
    internal void ApplyModals(INavigation navigation, Element reporter, SwiftNode node)
    {
        Modals modals = _modals ??=
            new Modals { Navigation = navigation, Reporter = reporter, Pages = [] };

        List<SwiftNode> children = node.Children ?? [];

        // A page can come back a DIFFERENT object - `replace` says the old one
        // cannot be patched into what the node now describes - and then what is
        // presented is a page nobody describes any more. That is a
        // reconciliation even though no arrangement arrived, which is why this
        // is watched rather than assumed. The navigation stack watches the same
        // thing, in the same words.
        bool replaced = false;

        foreach (SwiftNode child in children)
        {
            Page? was = modals.Pages.GetValueOrDefault(child.Key);
            Page made = Render(was, child, modals.Pages);

            replaced = replaced || (was is not null && !ReferenceEquals(was, made));
        }

        if (node.Arranged)
        {
            modals.Order = Order(children, modals.Pages, "modal stack");

            foreach (string gone in modals.Pages.Keys.Except(modals.Order).ToList())
            {
                modals.Pages.Remove(gone);
            }
        }

        if (node.Arranged || replaced)
        {
            modals.Desired = modals.Order.Count;
            Settle(modals);
        }
    }

    /// <summary>
    /// Tells Swift about a modal that has GONE, whoever took it away.
    /// </summary>
    /// <remarks>
    /// Called by the window, which is where MAUI raises it. A sheet the reader
    /// drags down on iOS and a modal Android's system back dismisses both
    /// arrive here, and so does every pop of ours - which <see cref="Report(Modals)"/>
    /// recognizes and says nothing about.
    /// </remarks>
    internal void ModalWasPopped()
    {
        if (_modals is Modals modals)
        {
            Announce(modals);
        }
    }

    /// <summary>
    /// Brings what is presented to what Swift described, one move at a time.
    /// </summary>
    /// <remarks>
    /// Started rather than awaited, and one at a time, for the reasons the
    /// navigation stack's <see cref="Settle(Stack)"/> gives. An EMPTY target is
    /// ordinary here, unlike a navigation stack's: a window with nothing
    /// presented over it is the usual state of one.
    /// </remarks>
    /// <param name="modals">The modal stack to settle.</param>
    private void Settle(Modals modals)
    {
        if (modals.Settling)
        {
            return;
        }

        modals.Settling = true;
        _ = SettleAsync(modals);
    }

    /// <summary>The loop behind <see cref="Settle(Modals)"/>.</summary>
    /// <param name="modals">The modal stack to settle.</param>
    /// <returns>The task that finishes when what is presented matches.</returns>
    private async Task SettleAsync(Modals modals)
    {
        try
        {
            while (true)
            {
                List<Page> target = modals.Target;
                IReadOnlyList<Page> current = modals.Navigation.ModalStack;

                int common = 0;
                while (common < current.Count && common < target.Count
                    && ReferenceEquals(current[common], target[common]))
                {
                    common++;
                }

                if (common == current.Count && common == target.Count)
                {
                    return;
                }

                // What was on top before this move, so a move that changed
                // nothing can be recognized rather than repeated.
                (int Count, Page? Top) before =
                    (current.Count, current.Count > 0 ? current[^1] : null);

                if (current.Count > common)
                {
                    // Only the TOP of a modal stack can leave - no platform
                    // offers taking one out from underneath - so a sheet that
                    // is no longer described takes whatever is over it with it,
                    // one at a time. Anything still described is pushed back by
                    // the turns that follow.
                    //
                    // Animated only when this pop REACHES the target: the
                    // others are the middle of a jump, which no platform draws
                    // one page at a time either.
                    await modals.Navigation.PopModalAsync(
                        animated: current.Count - 1 == target.Count);
                }
                else
                {
                    await modals.Navigation.PushModalAsync(
                        target[common], animated: common == target.Count - 1);
                }

                // A turn that moved NOTHING would go round for ever, and a spin
                // here is the UI thread. Whatever MAUI does or stops doing, this
                // reports and stops instead.
                IReadOnlyList<Page> after = modals.Navigation.ModalStack;

                if (after.Count == before.Count
                    && ReferenceEquals(after.Count > 0 ? after[^1] : null, before.Top))
                {
                    _fail("What is presented could not be brought to what Swift described.", null);
                    return;
                }
            }
        }
        catch (Exception exception)
        {
            _fail("What is presented could not be brought to what Swift described.", exception);
        }
        finally
        {
            modals.Settling = false;
        }
    }

    /// <summary>Says how many pages are presented, a turn from now.</summary>
    /// <remarks>
    /// EVERY report goes through here, for the reason
    /// <see cref="Announce(Flyout)"/> gives: a report made inside a message is
    /// not queued but DROPPED, while <see cref="Report(Modals)"/> has by then
    /// written down that Swift was told.
    /// </remarks>
    /// <param name="modals">The modal stack that may have moved.</param>
    private void Announce(Modals modals) =>
        modals.Reporter.Dispatcher.Dispatch(() => Report(modals));

    /// <summary>
    /// Tells Swift a modal has gone, when it was not Swift's doing.
    /// </summary>
    /// <remarks>
    /// What is reported is what SURVIVED - how many pages are still presented -
    /// never an intention, which is the navigation stack's protocol exactly. An
    /// iOS sheet is dragged down interactively and the drag can be let go
    /// halfway; nothing is said until the platform has finished dismissing one.
    /// </remarks>
    /// <param name="modals">The modal stack that moved.</param>
    private void Report(Modals modals)
    {
        // A reconciliation in progress is this side dismissing pages on its way
        // to what Swift described. Every depth it passes through is one nobody
        // asked to be at.
        if (modals.Settling)
        {
            return;
        }

        int depth = modals.Navigation.ModalStack.Count;

        if (depth == modals.Desired)
        {
            return;
        }

        modals.Desired = depth;
        _renderer.Raise(modals.Reporter, SwiftEvent.ModalPopped, (double)depth);
    }

    // ---- One page -----------------------------------------------------------

    /// <summary>
    /// Applies a page node: its own properties, what it asks of the
    /// NavigationPage it is on, its content, and whatever hangs off it besides -
    /// a title view for the bar, toolbar items, menu bar items.
    /// </summary>
    /// <remarks>
    /// The children are read by TYPE, not by position: the title view, the
    /// toolbar items and the menu bar items sit beside the content, and a patch
    /// carries only what changed - so taking <c>children[0]</c> as the content
    /// would sooner or later hand the page its title view instead.
    /// </remarks>
    /// <param name="page">The page to bring up to date.</param>
    /// <param name="node">What Swift says it should be.</param>
    internal void ApplyContentPage(ContentPage page, SwiftNode node)
    {
        // BEFORE anything else, because this is where the handler ids come
        // from: an untracked page reports to nobody.
        _renderer.Track(page, node);

        ApplyPageChrome(page, node);

        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { page.Padding = padding; }
        node.SetColor(SwiftProp.BackgroundColor, page, VisualElement.BackgroundColorProperty);

        // MAUI's own tap-to-dismiss, and the reason this library has no
        // tap-catching view of its own: MAUI recognizes the tap alongside
        // whatever else is listening, so scrolling, buttons and gestures on the
        // page go on working. A view laid over the content to catch touches
        // could not promise that.
        if (node.GetBool(SwiftProp.HideSoftInputOnTapped) is bool hideOnTapped)
        {
            page.HideSoftInputOnTapped = hideOnTapped;
        }

        // The PAGE's own inset, which is not the same question a layout's
        // SafeAreaEdges answers: measured on Mac Catalyst, a layout saying
        // `.none` still began below the window's title bar, because the page
        // under it had already taken that inset out of the room it handed on.
        // A flyout's banner is the case it exists for - without this, the
        // page's own colour shows above the picture in a strip.
        if (node.GetBool(SwiftProp.UseSafeArea) is bool useSafeArea)
        {
            // MAUI deprecates the platform-specific in favour of per-edge
            // SafeAreaEdges, but the page-level knob is the one that answers
            // BEFORE the page takes the inset out of the room it hands on -
            // the measured difference above - so it stays until a migration
            // round replaces it deliberately.
#pragma warning disable CS0618
            page.SetValue(iOSPage.UseSafeAreaProperty, useSafeArea);
#pragma warning restore CS0618
        }

        ApplyNavigationAppearance(page, node);

        foreach (SwiftNode child in node.Children ?? [])
        {
            switch (child.Type)
            {
                case SwiftNodeType.NavigationPageTitleView:
                    NavigationPage.SetTitleView(
                        page, RenderSlot(NavigationPage.GetTitleView(page), child));
                    WatchTitleViewWidth(page);
                    break;

                case SwiftNodeType.ToolbarItems:
                    _renderer.ApplyList(page.ToolbarItems, child, _renderer.ApplyToolbarItem);
                    break;

                case SwiftNodeType.MenuBarItems:
                    _renderer.ApplyList(page.MenuBarItems, child, _renderer.ApplyMenuBarItem);
                    break;

                default:
                    // Anything else is the page's content. Read by TYPE rather
                    // than by position, because a patch carries only what
                    // changed: a page whose title view changed sends one child,
                    // and it is not the content.
                    page.Content = _renderer.Render(page.Content, child);
                    break;
            }
        }
    }

    /// <summary>
    /// What this page asks of the NavigationPage it is on.
    /// </summary>
    /// <remarks>
    /// Attached properties, spelled with the class that declares them -
    /// <c>NavigationPage.HasNavigationBar</c> is
    /// <c>navigationPageHasNavigationBar</c>, the rule <c>.gridRow</c> follows.
    /// What the BAR looks like is not among them: that belongs to the stack
    /// drawing it, which is MAUI's own IBarElement.
    /// </remarks>
    /// <param name="page">The page carrying the attached properties.</param>
    /// <param name="node">What Swift says about them.</param>
    private static void ApplyNavigationAppearance(ContentPage page, SwiftNode node)
    {
        if (node.GetBool(SwiftProp.NavigationPageHasNavigationBar) is bool bar)
        {
            NavigationPage.SetHasNavigationBar(page, bar);
        }

        if (node.GetBool(SwiftProp.NavigationPageHasBackButton) is bool back)
        {
            NavigationPage.SetHasBackButton(page, back);
        }

        if (node.GetString(SwiftProp.NavigationPageBackButtonTitle) is string title)
        {
            NavigationPage.SetBackButtonTitle(page, title);
        }

        node.SetImageSource(
            SwiftProp.NavigationPageTitleIconImageSource,
            page,
            NavigationPage.TitleIconImageSourceProperty);
        node.SetColor(SwiftProp.NavigationPageIconColor, page, NavigationPage.IconColorProperty);
    }

    /// <summary>
    /// Pages whose title view is already watched for a bar that changed width.
    /// </summary>
    /// <remarks>
    /// Weak, for the reason every other table here is: there is no one place a
    /// page is dropped.
    /// </remarks>
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<Page, object> _titleViewWatched = new();

    /// <summary>
    /// Keeps a title view the width of the bar it is in, across a rotation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A title view's container is measured when it is set and keeps that
    /// width, so a bar that grows leaves it CENTERED at the old size: measured
    /// on an iPad mini in landscape, a container 667.5 points wide - the width
    /// of the portrait bar it was built in - sitting 232.5 points from each
    /// end, with the title's own text left-aligned inside it and so a third of
    /// the way across the bar. Only the page on screen while the device turns
    /// is affected; a page pushed afterwards is built at the new size.
    /// </para>
    /// <para>
    /// The page's own SizeChanged is the moment the bar has the new width, and
    /// SETTING THE TITLE VIEW AGAIN is what builds a container at that width -
    /// laying the bar out again is not enough, measured: the container answers
    /// with the size it was built with however often it is asked. The view
    /// itself is the same instance, so nothing is rebuilt on this side.
    /// Subscribed ONCE per page - a patch about a title view arrives on every
    /// render that touches it - and on iOS ALONE: a Mac Catalyst window taken
    /// from 700 to 1300 points keeps its title where it belongs (measured), and
    /// a resize there is a live drag, so acting on every report would rebuild
    /// the container tens of times for nothing.
    /// </para>
    /// </remarks>
    private static void WatchTitleViewWidth(Page page)
    {
#if IOS
        if (_titleViewWatched.TryGetValue(page, out _))
        {
            return;
        }

        _titleViewWatched.Add(page, new object());

        page.SizeChanged += (_, _) =>
        {
            if (NavigationPage.GetTitleView(page) is View titleView)
            {
                NavigationPage.SetTitleView(page, null);
                NavigationPage.SetTitleView(page, titleView);
            }
        };
#else
        _ = page;
#endif
    }

    /// <summary>
    /// The one view inside a wrapper node - a header, a footer, a title view.
    /// </summary>
    /// <param name="existing">The view that was in the slot.</param>
    /// <param name="wrapper">The node standing for the slot itself.</param>
    /// <returns>The view to put there, or what was there when nothing arrived.</returns>
    internal View? RenderSlot(View? existing, SwiftNode wrapper)
    {
        return wrapper.Children is { Count: > 0 } children
            ? _renderer.Render(existing, children[0])
            : existing;
    }
}
