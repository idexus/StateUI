using System.Runtime.CompilerServices;
using Microsoft.Maui.Platform;
using Microsoft.Maui.Platform.Linux.Handlers;

namespace Gallery;

/// <summary>
/// Makes the Linux navigation bar's own back arrow reach the tree.
/// </summary>
/// <remarks>
/// <para>
/// OpenMaui 10.0.90.1 draws the back chevron itself and answers it itself:
/// <c>SkiaNavigationPage.Pop()</c> runs straight out of the pointer handler and
/// pops the PLATFORM's stack, while <c>NavigationPageHandler.OnPopped</c> - the
/// one place that hears it - has an empty body. So the page leaves the screen
/// and MAUI's own <c>NavigationStack</c> never changes: nothing above the
/// platform is told anything, and StateUI reports a depth to Swift only when
/// MAUI's stack shrinks.
/// </para>
/// <para>
/// What that costs is not one missed report. The two stacks are then one page
/// apart for good, and that platform's <c>MapRequestNavigation</c> reconciles
/// them by COUNT alone - it pops or pushes the difference and reads no identity
/// - so the next page pushed arrives as a request one deeper than the platform,
/// and the platform answers it by pushing the page the reader had already left.
/// Measured: Home, then State, then back, then Fundamentals, drew State. The
/// second push of that pair is dropped outright, <c>Push</c> and <c>Pop</c>
/// both being no-ops while the 250 ms slide runs.
/// </para>
/// <para>
/// The answer is to pop MAUI's stack to the depth the platform reached, which
/// is what every other platform's back button does for itself. The DEPTH
/// comparison is what tells the reader's pop from our own: a pop this side
/// asked for has already shortened MAUI's stack by the time the platform raises
/// this, so the two agree and there is nothing to do.
/// </para>
/// <para>
/// <c>STATEUI_LINUX_NAV=1</c> writes what each navigation asked for and how deep
/// the platform was when it was asked, which is how the above was measured.
/// </para>
/// </remarks>
internal static class LinuxNavigation
{
    /// <summary>The platform views already listened to, so each is heard once.</summary>
    private static readonly ConditionalWeakTable<SkiaNavigationPage, object> Heard = new();

    /// <summary>Whether the trace is being written.</summary>
    private static readonly bool Tracing =
        Environment.GetEnvironmentVariable("STATEUI_LINUX_NAV") == "1";

    /// <summary>Arms the whole application's navigation pages.</summary>
    /// <remarks>
    /// A mapping rather than a subclassed handler: OpenMaui resolves handlers
    /// from a private static table of its own and reaches MAUI's registry only
    /// for the types it does not list, so a replacement registered the ordinary
    /// way is never asked for. Appending to the mapper is the door that is open.
    /// </remarks>
    internal static void Hear()
    {
        NavigationPageHandler.Mapper.AppendToMapping<NavigationPage, NavigationPageHandler>(
            "StateUILinuxBackArrow",
            (handler, page) =>
            {
                if (handler.PlatformView is not { } platform
                    || Heard.TryGetValue(platform, out _))
                {
                    return;
                }

                Heard.Add(platform, new object());

                platform.Popped += (_, _) =>
                {
                    if (Tracing)
                    {
                        Trace($"popped · platform {platform.StackDepth}"
                            + $" · maui {page.Navigation.NavigationStack.Count}");
                    }

                    Follow(page, platform);
                };
            });

        if (Tracing)
        {
            NavigationPageHandler.CommandMapper
                .PrependToMapping<NavigationPage, NavigationPageHandler>(
                    "RequestNavigation",
                    (handler, page, args) =>
                    {
                        if (args is NavigationRequest request)
                        {
                            Trace($"asked for [{string.Join(", ", request.NavigationStack
                                    .Select(view => (view as Page)?.Title ?? "?"))}]"
                                + $" · platform {handler.PlatformView?.StackDepth}"
                                + $" · animated {request.Animated}");
                        }
                    });
        }
    }

    /// <summary>Brings MAUI's stack down to where the platform's already is.</summary>
    /// <remarks>
    /// Deferred, for the reason StateUI defers its own reports: this arrives
    /// from inside the platform's pointer handling, and popping MAUI's stack
    /// there would run a whole render inside the notification. A turn later the
    /// slide is under way and the depth is already final - <c>StackDepth</c>
    /// counts what the animation will land on, not what is drawn.
    /// </remarks>
    /// <param name="page">The stack MAUI holds.</param>
    /// <param name="platform">The stack the reader sees.</param>
    private static void Follow(NavigationPage page, SkiaNavigationPage platform)
    {
        page.Dispatcher.Dispatch(async () =>
        {
            // The root is never popped: MAUI refuses a one-page stack, and the
            // platform cannot be shallower than that either.
            while (page.Navigation.NavigationStack.Count > Math.Max(platform.StackDepth, 1))
            {
                await page.Navigation.PopAsync(animated: false);
            }
        });
    }

    /// <summary>Writes one line of the trace.</summary>
    /// <param name="what">The line.</param>
    private static void Trace(string what) => Console.WriteLine($"[nav] {what}");
}
