using System.Text.Json;
using StateUI.Runtime.Interop;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// A window whose title and pages all come from Swift.
/// </summary>
/// <remarks>
/// <para>
/// The whole application, from the window down:
/// <code>
/// protected override Window CreateWindow(IActivationState? state)
///     => new StateUIWindow();
/// </code>
/// </para>
/// <para>
/// This is what an ARRANGEMENT needs. A NavigationPage, a TabbedPage and a
/// FlyoutPage are Pages, and a Page goes in a Window - so an application whose
/// root is one of them cannot live inside <see cref="StateUIHost"/>, which is
/// a view. Use the host to put a Swift tree inside a page you wrote; use this
/// when Swift describes the application.
/// </para>
/// <para>
/// The pages themselves are <see cref="SwiftPages"/>'s: it builds them, keeps
/// them by node identity and reconciles whatever nests inside them. All this
/// window does is hand MAUI whichever page is now the root.
/// </para>
/// <para>
/// The SESSION is not here but on <see cref="StateUIApplication"/>, which
/// this window joins as it is built: an application can describe several
/// windows, and they share one render loop the way they share one tree. A
/// window applies the node it is given and nothing else.
/// </para>
/// </remarks>
public class StateUIWindow : Window
{
    /// <summary>The Swift application this window belongs to.</summary>
    private readonly StateUIApplication _application;

    /// <summary>
    /// What turns page nodes into MAUI pages, and keeps them by node identity.
    /// </summary>
    /// <remarks>
    /// Not a window's business, which is why it is not written here: pages nest,
    /// and a second window would materialize its own through the same call. See
    /// <see cref="SwiftPages"/>.
    /// </remarks>
    private readonly SwiftPages _pageRenderer;

    /// <summary>
    /// The identity of the node the window's title bar came from, so a message
    /// that removes it can be recognized - a window's page never leaves, and
    /// this is the one window child that can.
    /// </summary>
    private string? _titleBarKey;

    /// <summary>
    /// Joins the Swift application and renders at once, so the window has a
    /// page before MAUI asks to show one.
    /// </summary>
    /// <remarks>
    /// What an app returns from its <c>CreateWindow</c>. The first one built
    /// starts the session; a later one arrives when the platform has opened a
    /// window by itself - after the last was closed, on a Mac that kept the
    /// process alive.
    /// </remarks>
    public StateUIWindow()
        : this(StateUIApplication.Current, adopt: true)
    {
    }

    /// <summary>
    /// A window belonging to a given application - what that application uses
    /// to open the second and every window after it.
    /// </summary>
    /// <param name="application">The application this window renders for.</param>
    /// <param name="adopt">
    /// Whether the application should render into it at once, which is what a
    /// window the PLATFORM made needs and a window the application opened does
    /// not: that one already has the node that asked for it.
    /// </param>
    internal StateUIWindow(StateUIApplication application, bool adopt = false)
    {
        _application = application;

        _pageRenderer = new SwiftPages(
            application.Renderer,
            (message, exception) => ShowError(message, exception));

        // The window's own lifecycle, and the application's bookkeeping with
        // it: which handlers hear an event is the tree's business, because Apply
        // tracks this window's node and Raise quotes whatever ids it carries.
        application.Watch(this);

        // A modal page that has GONE, whoever took it away - a sheet dragged
        // down, Android's system back, or this side dismissing one. MAUI raises
        // it HERE rather than on any page, because the modal stack is the
        // window's: that is why the modal stack's handler is written on the
        // window's own node, and why this subscription is not in SwiftPages.
        ModalPopped += (_, _) => _pageRenderer.ModalWasPopped();

        if (adopt)
        {
            application.Adopt(this);
        }
    }

    /// <summary>What materializes the views.</summary>
    internal StateUIRenderer Renderer => _application.Renderer;

    /// <summary>
    /// Applies this window's own node: its properties, its chrome, whatever is
    /// presented over it, and the page it shows.
    /// </summary>
    /// <param name="window">The Window node, from the application's list.</param>
    /// <param name="complete">
    /// Whether the message describes everything rather than only what changed.
    /// </param>
    /// <returns>
    /// False to ask for the whole tree instead, which is what a window does
    /// when a patch names a page it does not have.
    /// </returns>
    internal bool Apply(SwiftNode window, bool complete)
    {
        // Nothing written below here is news to the Swift side - it is what the
        // Swift side just asked for. The renderer keeps this guard for the views
        // it reconciles; a window's own properties and the pages under it are
        // assigned by hand rather than reconciled, so the window holds it over
        // them. See StateUIRenderer.Applying.
        using StateUIRenderer.Suppressed suppressed = _application.Renderer.Applying();

        // This IS the MAUI window, so its own properties go straight on - and
        // its handler ids with them, which is what its lifecycle events report
        // with. See StateUIRenderer.WireWindow.
        window.ApplyWindow(this);
        _application.Renderer.Track(this, window);

        // The one window child that can LEAVE: a title bar written under an
        // `if` that turned false. Recognized by its absence from an arranged
        // list, the way every slot's leaving is.
        if (window.Arranged && _titleBarKey is string titleBar
            && window.Children?.Any(child => child.Key == titleBar) != true)
        {
            TitleBar = null;
            _titleBarKey = null;
        }

        // No child means nothing below the window changed.
        if (window.Children is not { Count: > 0 } children)
        {
            return true;
        }

        // Read by TYPE, not by position: a patch carries only what changed, so
        // what arrives is never a fixed list. The same rule a page's own
        // children follow.
        //
        // And read to the END rather than returned from: a window has more than
        // one child, the page is the FIRST of them, and a `return` in that arm
        // would be a modal stack nobody ever applies.
        foreach (SwiftNode child in children)
        {
            switch (child.Type)
            {
                // The window's own chrome, when the tree carries one - a real
                // MAUI TitleBar, so the renderer reconciles it like any other
                // view and the window hands MAUI the result.
                case SwiftNodeType.TitleBar:
                    TitleBar = _application.Renderer.Render(TitleBar as View, child) as TitleBar;
                    _titleBarKey = child.Key;
                    break;

                // What is presented OVER the page, which is the window's own
                // list: MAUI keeps modals on the window's navigation, and the
                // page renderer is handed both that and this window to report
                // a dismissal through.
                case SwiftNodeType.ModalStack:
                    _pageRenderer.ApplyModals(Navigation, this, child);
                    break;

                // Every page kind - a ContentPage on its own, a NavigationPage
                // holding a stack, a FlyoutPage over both - is the page
                // renderer's, which recurses through whatever nests inside it.
                default:
                    // A page that could not be built from a patch stops the
                    // whole message: the answer is a complete render, which
                    // describes everything under the window again anyway.
                    if (!ApplyOnlyPage(child, complete))
                    {
                        return false;
                    }

                    break;
            }
        }

        return true;
    }

    /// <summary>Shows a diagnostic in this window in place of its page.</summary>
    /// <param name="message">What went wrong, in a sentence or two.</param>
    /// <param name="exception">What was thrown, where something was.</param>
    internal void ShowError(string message, Exception? exception)
    {
        Page = new ContentPage { Content = StateUISession.BuildError(message, exception) };
        _pageRenderer.Forget();

        // The page maps are cleared above; the SESSION still names the tree
        // that is no longer here, so drop that too - or the next message would
        // be a patch onto a page this window has replaced with the error. See
        // StateUISession.Forget.
        _application.Forget();
    }

    // ---- Pages -------------------------------------------------------------

    /// <summary>Hands MAUI the page a node describes, and nothing else.</summary>
    /// <remarks>
    /// The page itself is the page renderer's to make and to keep - a
    /// ContentPage on its own, or a NavigationPage with a stack under it. All
    /// this window does is notice when the page it is SHOWING has changed and
    /// hand MAUI the new one.
    /// </remarks>
    private bool ApplyOnlyPage(SwiftNode node, bool complete)
    {
        // A page nobody has built yet needs the whole description, and a patch
        // does not carry one - unless it is describing an element that is NEW,
        // which the differ always describes entire.
        if (_pageRenderer.Known(node.Key) is null && !complete && node.Children is null)
        {
            return false;
        }

        Page shown = _pageRenderer.Render(Page, node);

        if (!ReferenceEquals(Page, shown))
        {
            Page = shown;
        }

        return true;
    }
}
