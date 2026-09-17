// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// What this host declares it realizes, read off the registrations themselves:
/// the elements it makes a view for and, on each, the members its control
/// takes and the events it raises.
/// </summary>
/// <remarks>
/// <para>
/// THE REGISTRATIONS ARE THE DECLARATION. Nothing here is written by hand, so
/// nothing here can disagree with the code - which is the whole point of
/// reading a runtime rather than holding a list beside it.
/// </para>
/// <para>
/// What it says is PRESENCE: which member this host realizes on which element.
/// It never says who DECLARES that member, because whether <c>borderColor</c>
/// belongs to a button or to a tier the button wears is a fact of the
/// contract, and the contracts live on the Swift side. The join happens there,
/// against <c>Contract.worn</c>.
/// </para>
/// <para>
/// The SHARED machinery is declared apart, in <see cref="SharedMembers"/> and
/// <see cref="SharedEvents"/>: the renderer applies margins, opacity, sizing
/// and the gestures AROUND every view instead of inside a registration, so
/// those members belong to no registration at all. They are the one list here
/// written by hand, because <c>ApplyView</c> is not a registry - and they are
/// held to the contracts, which refuse a name no tier declares.
/// </para>
/// </remarks>
internal static class MauiDeclaration
{
    /// <summary>
    /// What this host takes on EVERY element wearing the contract declaring it
    /// - applied around the view by <c>ApplyView</c> and, for the last two, by
    /// the layout's own applier.
    /// </summary>
    /// <remarks>
    /// Named rather than derived, and that is the honest shape of it: these
    /// are read by one method per tier rather than registered one by one, so
    /// nothing can read them back out. What keeps the list true is the join -
    /// a name no contract declares is refused there by name, never rendered.
    /// </remarks>
    internal static readonly HostProp[] SharedMembers =
    [
        HostProp.AbsoluteLayoutBounds, HostProp.AbsoluteLayoutProportions,
        HostProp.AccessibilityHeadingLevel, HostProp.AccessibilityHint,
        HostProp.AccessibilityIdentifier, HostProp.AccessibilityLabel, HostProp.AllowDrop,
        HostProp.AutomationExcludedWithChildren, HostProp.Background, HostProp.CanDrag,
        HostProp.DragText, HostProp.Frame, HostProp.GridColumn, HostProp.GridColumnSpan,
        HostProp.GridRow, HostProp.GridRowSpan, HostProp.Height, HostProp.HorizontalAlignment,
        HostProp.IgnoresInput, HostProp.IsAccessibilityHidden, HostProp.IsEnabled,
        HostProp.IsVisible, HostProp.LayoutDirection, HostProp.Margin, HostProp.MaximumHeight,
        HostProp.MaximumWidth, HostProp.MinimumHeight, HostProp.MinimumWidth, HostProp.Opacity,
        HostProp.PanTouchCount, HostProp.PanXChannel, HostProp.PanYChannel, HostProp.PivotX,
        HostProp.PivotY, HostProp.Rotation, HostProp.RotationX, HostProp.RotationY,
        HostProp.Scale, HostProp.ScaleX, HostProp.ScaleY, HostProp.SwipeDirection,
        HostProp.SwipeThreshold, HostProp.TapCount, HostProp.Tint, HostProp.TranslationX,
        HostProp.TranslationY, HostProp.VerticalAlignment, HostProp.Width, HostProp.ZIndex,

        // The layout tier's two, applied by the layout's own applier to the
        // stacks, the Grid and the AbsoluteLayout alike.
        HostProp.AvoidsSafeArea, HostProp.ClipsContent, HostProp.LetsInputThrough,
    ];

    /// <summary>
    /// What this host raises on EVERY element wearing the contract declaring
    /// it - the gestures and the pointer, the drag, and the two a view reports
    /// about itself.
    /// </summary>
    /// <remarks>
    /// <c>canGoBackChanged</c>, <c>canGoForwardChanged</c> and
    /// <c>isRefreshingChanged</c> are watched by the same machinery and are
    /// NOT here: they belong to a web view and a refresh view, so they are
    /// declared on those elements rather than on everything.
    /// </remarks>
    internal static readonly HostEvent[] SharedEvents =
    [
        HostEvent.DragLeave, HostEvent.DragOver, HostEvent.DragStarting, HostEvent.Drop,
        HostEvent.DropCompleted, HostEvent.FrameChanged, HostEvent.IsFocusedChanged,
        HostEvent.PanUpdated, HostEvent.PinchUpdated, HostEvent.PointerEntered,
        HostEvent.PointerExited, HostEvent.PointerMoved, HostEvent.PointerPressed,
        HostEvent.PointerReleased, HostEvent.Swiped, HostEvent.Tapped,

        // The state a view entered, reported by the same machinery that
        // applies the setters of the state it left - see VisualStates.
        HostEvent.VisualStateChanged,
    ];

    /// <summary>
    /// What a control's own machinery realizes outside its registration: MAUI
    /// gives these no event, so the renderer hears each by watching the
    /// property (<c>StateUIRenderer.Watch</c>).
    /// </summary>
    private static readonly Dictionary<string, HostEvent[]> Watched = new()
    {
        ["WebView"] = [HostEvent.CanGoBackChanged, HostEvent.CanGoForwardChanged],
        ["RefreshView"] = [HostEvent.IsRefreshingChanged],
    };

    /// <summary>
    /// The acts this host performs, whichever element each is aimed at -
    /// <c>ActPerformer</c>'s own vocabulary, said whole rather than per
    /// element.
    /// </summary>
    /// <remarks>
    /// An act carries the identity of the view it is aimed at and is performed
    /// against it, so nothing in the call says which element declares the act.
    /// The contracts do: <c>focus</c> belongs to a tier every element wears,
    /// <c>goBack</c> to one element. The few this host performs that no
    /// contract declares - choosing an action, prompting for a line - are its
    /// own business and are dropped by the join rather than reported as drift.
    /// </remarks>
    internal static readonly HostAct[] Acts =
    [
        HostAct.Alert, HostAct.Announce, HostAct.Confirm, HostAct.CurrentTime,
        HostAct.CurrentTimeZone, HostAct.EvaluateJavaScript, HostAct.Focus, HostAct.GoBack,
        HostAct.GoForward, HostAct.HideOnScreenKeyboard, HostAct.MoveToRegion,
        HostAct.PersistSceneValue, HostAct.PersistValue, HostAct.Reload, HostAct.Unfocus,
        HostAct.UtcOffset,
    ];
    /// <summary>
    /// Each element this host realizes, with its members and its events, named
    /// as the wire and the contracts name them.
    /// </summary>
    internal static IEnumerable<(string Element, IEnumerable<string> Members, IEnumerable<string> Events)>
        Elements =>
        StateUIControls.Realizations()
            .Select(registration => (
                registration.Type,
                registration.Realized.Members.Select(TokenNames<HostProp>.Spelling),
                registration.Realized.Raised.Select(TokenNames<HostEvent>.Spelling)
                    .Concat(Watched.GetValueOrDefault(registration.Type, [])
                        .Select(TokenNames<HostEvent>.Spelling))));

    /// <summary>The declaration as the wire writes it.</summary>
    internal static byte[] Bytes() =>
        WireCodec.WriteDeclaration(
            Elements,
            SharedMembers.Select(TokenNames<HostProp>.Spelling),
            SharedEvents.Select(TokenNames<HostEvent>.Spelling),
            Acts.Select(TokenNames<HostAct>.Spelling));

    /// <summary>
    /// The readable half, which a review diff reads instead of the bytes: one
    /// line per element, its members and then its events under it, an event
    /// told from a property by the parentheses every handler is called with.
    /// </summary>
    internal static string Sidecar()
    {
        List<string> lines = [];

        foreach ((string element, IEnumerable<string> members, IEnumerable<string> events) in
            Elements.OrderBy(element => element.Element, StringComparer.Ordinal))
        {
            lines.Add(element);
            lines.AddRange(Under(members, events));
        }

        // Last and under no element, as the bytes carry them: what the shared
        // machinery realizes on every element wearing the contract declaring
        // it.
        lines.Add("(every element)");
        lines.AddRange(Under(
            SharedMembers.Select(TokenNames<HostProp>.Spelling),
            SharedEvents.Select(TokenNames<HostEvent>.Spelling)));

        // The acts last, aimed at whatever element declares each.
        lines.Add("(acts)");
        lines.AddRange(Acts.Select(TokenNames<HostAct>.Spelling)
            .Distinct().Order(StringComparer.Ordinal).Select(act => $"  {act}()"));

        return string.Join("\n", lines) + "\n";
    }

    /// <summary>One indented line per member and then per event, sorted - an
    /// event told from a property by the parentheses.</summary>
    private static IEnumerable<string> Under(
        IEnumerable<string> members, IEnumerable<string> events) =>
        members.Distinct().Order(StringComparer.Ordinal).Select(member => $"  {member}")
            .Concat(events.Distinct().Order(StringComparer.Ordinal).Select(raised => $"  {raised}()"));
}
