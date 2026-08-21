// A whole session, message by message.
//
// Every other fixture here is ONE message, decoded with a dictionary of its
// own. These five are a SEQUENCE: one session's numbering, announced by the
// first message that uses each name and spoken as a number ever after - so
// applying the fourth without the first would be unreadable, which is exactly
// the property worth pinning.
//
// What Swift writes, and why the bytes are the same on every run and in every
// process, is next door in the Swift DeterminismTests.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class SessionTests
{
    /// <summary>The session's messages, in the order they were written.</summary>
    /// <remarks>
    /// A WALK of the directory rather than a list of names: a message added to
    /// the session and not applied here would otherwise ride along unread, and
    /// the sequence is numbered so that its own order is the file order.
    /// </remarks>
    private static string[] Messages()
    {
        string[] files =
            [.. Directory.GetFiles(Path.Combine(Fixtures.Directory, "sessions"), "*.bin")
                .OrderBy(path => path, StringComparer.Ordinal)];

        Assert.NotEmpty(files);
        return files;
    }

    /// <summary>
    /// Applies the whole session to one page renderer, the way the host does -
    /// one wire dictionary, one page tree, message after message.
    /// </summary>
    private static (Page Page, Host Host, List<string> Failures) Apply(int upTo = int.MaxValue)
    {
        var host = new Host();
        List<string> failures = [];
        var pages = new SwiftPages(host.Renderer, (message, _) => failures.Add(message));

        Page? page = null;
        int applied = 0;

        foreach (string file in Messages())
        {
            SwiftNode root = SwiftWire.ReadMessage(File.ReadAllBytes(file), host.Names).Root!;

            // The application and its one window are above the page, as they
            // are in a real message; what a page renderer is given is the page.
            SwiftNode? window = root.Children is { Count: > 0 } windows ? windows[0] : null;

            if (window?.Children is { Count: > 0 } children)
            {
                page = pages.Render(page, children[0]);
            }

            if (++applied >= upTo)
            {
                break;
            }
        }

        Assert.NotNull(page);
        return (page, host, failures);
    }

    /// <summary>
    /// The session, applied: it opens on the first tab with one page on the
    /// stack, pushes, changes tab, pops, and is described again from scratch -
    /// and what is on screen at the end is what Swift last said.
    /// </summary>
    [Fact]
    public void TheSessionBuildsTheApplication()
    {
        (Page page, _, List<string> failures) = Apply();

        Assert.Empty(failures);

        var tabbed = Assert.IsType<TabbedPage>(page);

        Assert.Equal(["Home", "Settings"], tabbed.Children.Select(child => child.Title));
        Assert.Equal("Settings", tabbed.CurrentPage.Title);

        // The stack popped back to its root, which is where the session left it.
        var stack = Assert.IsType<NavigationPage>(tabbed.Children[0]);

        Assert.Equal(["Home"], stack.Navigation.NavigationStack.Select(child => child.Title));

        // And the styles the differ resolved arrived as ordinary properties.
        var content = Assert.IsType<VerticalStackLayout>(
            ((ContentPage)stack.Navigation.NavigationStack[0]).Content);

        Assert.Equal(20, ((Label)content.Children[0]).FontSize);
        Assert.Equal(14, ((Label)content.Children[2]).FontSize);
        Assert.Equal(Color.FromArgb("#512BD4"), ((Button)content.Children[1]).BackgroundColor);

        // And the CLEAN WALK reached one label and nothing else: the fifth
        // message is the whole of what a state change costs.
        Assert.Equal("Count: 1", ((Label)content.Children[0]).Text);
    }

    /// <summary>
    /// Half way through, the state the session was in: pushed one page deep,
    /// still on the first tab. It is what makes the messages after it a
    /// sequence rather than five independent trees.
    /// </summary>
    [Fact]
    public void TheSecondMessagePushesAPage()
    {
        (Page page, _, _) = Apply(upTo: 2);

        var tabbed = Assert.IsType<TabbedPage>(page);
        var stack = Assert.IsType<NavigationPage>(tabbed.Children[0]);

        Assert.Equal("Home", tabbed.CurrentPage.Title);
        Assert.Equal(["Home", "one"], stack.Navigation.NavigationStack.Select(child => child.Title));
    }

    /// <summary>
    /// And the whole session applied twice builds the same thing twice - two
    /// hosts, two sets of MAUI objects, one description.
    /// </summary>
    /// <remarks>
    /// The Swift side proves the BYTES are the same on every run; this is the
    /// other half of the sentence, and what it rules out is this side carrying
    /// something between hosts that it should not - a static, a cache, a
    /// counter.
    /// </remarks>
    [Fact]
    public void TheSameSessionBuildsTheSameTreeTwice()
    {
        (Page first, _, _) = Apply();
        (Page second, _, _) = Apply();

        Assert.Equal(Describe(first), Describe(second));
        Assert.NotSame(first, second);
    }

    /// <summary>
    /// Applying a session teaches the reader its names, and no message
    /// re-announces one - so a message on its own, read with a fresh
    /// dictionary, is unreadable from the second onwards.
    /// </summary>
    /// <remarks>
    /// This is the cost of the per-session dictionary and the reason it is
    /// worth it: a name crosses once and rides two bytes ever after. What must
    /// hold is that the reader learns them in the order the writer assigned
    /// them, which is what reading the sequence with ONE dictionary proves.
    /// </remarks>
    [Fact]
    public void AMessageFromTheMiddleCannotBeReadOnItsOwn()
    {
        string[] files = Messages();

        // The first message announces every name it uses, so it reads alone.
        Assert.NotNull(SwiftWire.ReadMessage(
            File.ReadAllBytes(files[0]), new SwiftWireDictionary()).Root);

        // A later one speaks numbers nobody announced to a fresh reader, and
        // says so rather than reading them as anything.
        InvalidDataException refused = Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadMessage(
                File.ReadAllBytes(files[2]), new SwiftWireDictionary()));

        Assert.Contains("never announced", refused.Message);
    }

    // ---- One live session per process ---------------------------------------

    /// <summary>
    /// A second session is refused, so the first keeps the Swift runtime.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The other side is ONE renderer over one tree, with one generation, one
    /// handler registry, one command queue and one wire dictionary. A second
    /// session starts with an empty dictionary of its own and Swift, having
    /// announced each name once already, would never say them again - which is
    /// precisely what
    /// <see cref="AMessageFromTheMiddleCannotBeReadOnItsOwn"/> measures. Its
    /// commands would be drained by whichever session asked first, too, the
    /// wire carrying no session to sort them by.
    /// </para>
    /// <para>
    /// So the FIRST render takes the process and a second says so where its
    /// interface would have been. The first here gets as far as the native
    /// library, which a test does not have - and that is the proof it claimed:
    /// it was allowed through to the crossing.
    /// </para>
    /// </remarks>
    [Fact]
    public void ASecondSessionIsRefusedSoTheFirstKeepsTheRuntime()
    {
        Action? had = StateUIHost.RegisterApp;
        StateUIHost.RegisterApp = () => { };

        try
        {
            var first = new StateUIHost();
            var second = new StateUIHost();

            // The first was let through to the crossing, where a test has no
            // native library; the second never got that far.
            Assert.DoesNotContain("already showing", Host.TextOf(first));
            Assert.Contains("already showing an interface", Host.TextOf(second));
            Assert.Contains("lists them as windows", Host.TextOf(second));
        }
        finally
        {
            StateUISession.Release();
            StateUIHost.RegisterApp = had;
        }
    }

    /// <summary>
    /// The SAME session renders as often as it likes: the claim is the
    /// process's, not a one-shot.
    /// </summary>
    [Fact]
    public void TheLiveSessionGoesOnRendering()
    {
        Action? had = StateUIHost.RegisterApp;
        StateUIHost.RegisterApp = () => { };

        try
        {
            var live = new Sink();
            var other = new Sink();
            var session = new StateUISession(live);

            session.Render();
            session.Render();
            new StateUISession(other).Render();

            // Twice through to the crossing for the one that is live, and a
            // refusal - and nothing else, no drained queue - for the one that
            // is not.
            Assert.Equal(2, live.Failures.Count(said => said.Contains("native library")));
            Assert.Contains("already showing an interface", Assert.Single(other.Failures));
        }
        finally
        {
            StateUISession.Release();
            StateUIHost.RegisterApp = had;
        }
    }

    /// <summary>A target that renders nowhere and keeps what it was told.</summary>
    private sealed class Sink : IStateUITarget
    {
        public List<string> Failures { get; } = [];

        public bool Apply(SwiftNode application, bool complete) => true;

        public void Fail(string message, Exception? exception) => Failures.Add(message);

        /// <summary>None, which is what keeps a thread out of the native park.</summary>
        public IDispatcher? Dispatcher => null;
    }

    /// <summary>One page tree, as text: the type, the title, and what is in it.</summary>
    private static string Describe(Element element, int depth = 0)
    {
        string title = element switch
        {
            Page page => page.Title ?? "",
            Label label => label.Text ?? "",
            Button button => button.Text ?? "",
            _ => "",
        };

        IEnumerable<Element> children = element switch
        {
            NavigationPage stack => stack.Navigation.NavigationStack,
            TabbedPage tabbed => tabbed.Children,
            ContentPage page => page.Content is null ? [] : [page.Content],
            Layout layout => layout.Children.OfType<Element>(),
            _ => [],
        };

        return new string(' ', depth * 2) + element.GetType().Name + " " + title + "\n"
            + string.Concat(children.Select(child => Describe(child, depth + 1)));
    }
}
