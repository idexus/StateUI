// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using StateUI.Maui.Interop;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// Performs the acts the application calls on the host, and answers each: a
/// reply with its values, or a failure with the reason, so a Swift handler
/// awaiting one never waits on an act nobody performs.
/// </summary>
/// <remarks>
/// An act about a view names it at argument 0 - by the number the differ gave
/// it, or by the name its author wrote - and the view is found in the
/// renderer's maps as they stand; one not being shown fails with that reason.
/// What follows a reply - a pump for what it changed, a drain for the
/// continuation it resumed - is the session's, handed in.
/// </remarks>
internal sealed class ActPerformer
{
    private readonly IStateUITarget _target;
    private readonly StateUIRenderer _renderer;
    private readonly UiThread _uiThread;
    private readonly Action _replied;

    /// <summary>A performer for the acts one session's application calls.</summary>
    /// <param name="target">What the session renders into, whose pages a dialog is shown on.</param>
    /// <param name="renderer">Whose maps an act's view is found in.</param>
    /// <param name="uiThread">What checks that a reply crosses on the thread MAUI draws on.</param>
    /// <param name="replied">What follows a reply: the session's pump and drain.</param>
    internal ActPerformer(IStateUITarget target, StateUIRenderer renderer, UiThread uiThread, Action replied)
    {
        _target = target;
        _renderer = renderer;
        _uiThread = uiThread;
        _replied = replied;
    }

    /// <summary>
    /// Where a completed act's answer goes: into Swift, which resumes the
    /// handler awaiting it.
    /// </summary>
    /// <remarks>
    /// The one substitution point an act test needs, and it is deliberately
    /// the OUTWARD one: an act's arguments can be read from a fixture Swift
    /// wrote, but its answer has nowhere to go without a Swift runtime to
    /// resume. Substituted, a test reads exactly what an arm replied - the
    /// bytes, on the completion id the fixture named - which is the only thing
    /// an arm is contractually about. Never substituted in a running app.
    /// </remarks>
    internal Action<int, byte[]> Replies { get; set; } =
        static (id, reply) => CoreLink.DispatchWire(id, reply, reply.Length);

    /// <summary>
    /// Performs a batch of acts - what the session's pump ends with once it
    /// has taken them, and the door a test comes in through.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The take is the half that needs a Swift runtime: it reads a native
    /// buffer and frees it. Everything an ACT does is on this side of that, so
    /// splitting here is what lets a test hand the performer acts read from a
    /// `fixtures/act-calls/*.bin` - bytes SWIFT wrote - and watch the arms, the
    /// refusal sentences and the catch blocks run for real.
    /// </para>
    /// <para>
    /// A test drives it with <see cref="Replies"/> substituted. What follows a
    /// reply - <c>Pump</c>, and the drain it schedules - still reaches the
    /// native library and fails there with no Swift runtime loaded, so a test
    /// reads the REPLY it recorded and lets the target's failures be.
    /// </para>
    /// </remarks>
    /// <param name="calls">The batch, in the order Swift queued it.</param>
    internal void Perform(IReadOnlyList<HostActCall> calls)
    {
        foreach (HostActCall call in calls)
        {
            Perform(call);
        }
    }

    /// <summary>
    /// Performs one act and reports the outcome back.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <c>async void</c> deliberately: this is the far end of an event, with
    /// nobody to await it, and blocking the UI thread on a dialog, which waits
    /// for the reader, would defeat the point. Everything is inside a try, so nothing escapes to the
    /// synchronization context.
    /// </para>
    /// <para>
    /// The awaiting happens on this side, where MAUI's dispatcher puts the
    /// continuation back on the UI thread. What Swift gets is the OUTCOME,
    /// reported through the same event dispatch that carries a button tap - and
    /// what resumes there is a Swift continuation, on the thread MAUI draws on.
    /// See <c>Core/MainThread.swift</c>.
    /// </para>
    /// <para>
    /// The reply crosses as typed values (<see cref="WireCodec.WriteReply"/>):
    /// what the method returned, none for a method that returns nothing - or,
    /// when it could not be performed, a failure carrying the reason, which
    /// the awaiting Swift handler throws.
    /// </para>
    /// </remarks>
    private async void Perform(HostActCall call)
    {
        HostValue[] result = [];
        string? failure = null;

        try
        {
            switch (call.Act)
            {
                case HostAct.Focus:
                case HostAct.Unfocus:
                    (result, failure) = Aim(call);
                    break;

                case HostAct.GoBack:
                case HostAct.GoForward:
                case HostAct.Reload:
                case HostAct.EvaluateJavaScript:
                    (result, failure) = await Web(call);
                    break;

                case HostAct.MoveToRegion:
                    (result, failure) = MoveMap(call);
                    break;

                case HostAct.HideOnScreenKeyboard:
                    // Not a MAUI method - see Focus for why there is none
                    // to call. The page is asked which of its views has the
                    // focus, because the Swift side cannot know.
                    result = [HostValue.Of(Focus.Hide(Showing()))];
                    break;

                case HostAct.Alert:
                case HostAct.Confirm:
                case HostAct.ChooseAction:
                case HostAct.Prompt:
                    (result, failure) = await Dialog(call);
                    break;

                case HostAct.Announce:
                    // SAID OUT LOUD, and it interrupts whatever the reader was
                    // being told: a screen reader has one voice, so this is for
                    // what changed on its own - a search that finished, a row
                    // that went - and not for what the reader's own tap already
                    // said back to them.
                    SemanticScreenReader.Default.Announce(call.GetString(0) ?? "");
                    result = [];
                    break;

                case HostAct.CurrentTime:
                {
                    // The time of day, because the Swift side deliberately has
                    // no clock: reading one through Foundation arrives with
                    // ICU, the dependency that library cannot take. Four
                    // numbers - hour, minute, second, millisecond - with the
                    // fraction because a clock ticking once a second sleeps to
                    // the NEXT whole second, and without it every lap drifts a
                    // little until a tick reads the same second twice and the
                    // one after skips one.
                    DateTime now = DateTime.Now;
                    result = [HostValue.Of(now.Hour, now.Minute, now.Second, now.Millisecond)];
                    break;
                }

                case HostAct.CurrentTimeZone:
                    // The IANA name, whatever the platform calls its zones.
                    // Foundation's own database speaks IANA, and Windows is the
                    // one platform naming them its own way - the conversion maps
                    // "Central European Standard Time" to the CLDR canonical
                    // zone, which shares its rules with the device's even when
                    // it is a neighbouring city's name.
                    TimeZoneInfo zone = TimeZoneInfo.Local;
                    result = [HostValue.Of(
                        zone.HasIanaId ? zone.Id
                        : TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id, out string? iana) ? iana
                        : zone.Id)];
                    break;

                case HostAct.UtcOffset:
                {
                    // Minutes, signed, as one number - India is 330 and New
                    // York is -240 in summer. The Swift side reads them into a
                    // Duration, which is stdlib rather than Foundation.
                    // The zone is TEXT - an IANA identifier is not a member of
                    // any vocabulary - and the wire's own nothing means the
                    // host's own, an empty identifier reading the same way.
                    // The day is its three numbers, and the wire's own nothing
                    // when none was asked for, so a day nobody named cannot be
                    // mistaken for one that failed to arrive.
                    string? zoneId = call.GetString(0);
                    IReadOnlyList<double>? day = call.GetNumbers(1);

                    TimeZoneInfo asked = string.IsNullOrEmpty(zoneId)
                        ? TimeZoneInfo.Local
                        : TimeZoneInfo.FindSystemTimeZoneById(zoneId);

                    TimeSpan offset;

                    if (day is not [double year, double month, double dayOfMonth])
                    {
                        // A moment, so there is nothing to interpret: an offset
                        // for "now" asked as a local DateTime would be read in
                        // the HOST's zone before the asked-for one.
                        offset = asked.GetUtcOffset(DateTimeOffset.UtcNow);
                    }
                    else
                    {
                        // NOON, deliberately. A day is a day in the zone being
                        // asked about, and midnight is the hour summer time
                        // moves in several of them - Brazil put its clocks
                        // forward at exactly 00:00, so a date read there was
                        // one the calendar had skipped.
                        var when = new DateTime(
                            (int)year, (int)month, (int)dayOfMonth, 12, 0, 0, DateTimeKind.Unspecified);

                        offset = asked.GetUtcOffset(when);
                    }

                    result = [HostValue.Of((int)offset.TotalMinutes)];
                    break;
                }

                case HostAct.PersistValue:
                    // Nothing is waiting on this one: the value is already in
                    // Swift's own state, and the store is where it goes to
                    // survive the process.
                    StateUIPersistence.Save(call);
                    break;

                case HostAct.PersistSceneValue:
                    // Nothing waits on this one either: the value is in its
                    // scene's state already, and the platform keeps it WITH
                    // the scene, for the system to hand back when it restores
                    // that scene's window.
                    (_target as StateUIApplication)?.Keep(call);
                    break;

                case HostAct.HandlerFailed:
                    // A Swift handler let something escape. Nothing is waiting
                    // on this one - it is reported so that a failed `try await`
                    // is visible rather than lost.
                    //
                    // Through Report, like everything else here:
                    // Debug.WriteLine reaches logcat on Android and NOTHING on
                    // Apple without a debugger attached, which would leave a
                    // handler failing on a Mac silent.
                    StateUISession.Report($"a handler failed: {call.GetString(0)}");
                    break;

                default:
                    // The application's own acts first - a C# function
                    // registered under this name performs it, and its values
                    // answer the Swift `try await` exactly as a library act's
                    // would. See StateUIActs.
                    if (StateUIActs.Find(call.Name) is { } performer)
                    {
                        result = await performer(call);
                        break;
                    }

                    failure = $"unknown act '{call.Name}'";

                    // An act with a completion carries the failure to the
                    // Swift `try await` below; one WITHOUT would fail into
                    // silence - a version-skewed native library asking for an
                    // act this runtime has no case for - so it is reported
                    // here, the only place that will ever hear of it.
                    if (call.Completion is null)
                    {
                        StateUISession.Report(failure);
                    }

                    break;
            }
        }
        catch (Exception ex)
        {
            failure = ex.Message;
        }

        try
        {
            if (call.Completion is int id)
            {
                // The one chain whose thread an AWAIT decided: everything up to
                // here came back through whatever context the awaited API
                // resumed on, and what follows enters Swift.
                _uiThread.Verify(_target.Dispatcher, "a completed act");

                byte[] reply = failure is null
                    ? WireCodec.WriteReply(result)
                    : WireCodec.WriteFailure(failure);

                Replies(id, reply);

                // What follows is the session's: a pump for what the reply
                // changed, and a drain for the continuation it resumed,
                // which is not runnable yet.
                _replied();
            }
        }
        catch (Exception ex)
        {
            _target.Fail("Reporting a completed act failed", ex);
        }
    }

    // ---- Aiming an act at a view on screen ---------------------------------

    /// <summary>
    /// The view argument of an act: which map answers, the key into it, and
    /// how a failure names the view.
    /// </summary>
    /// <remarks>
    /// The same two namespaces the tree's ids travel in: a string is a name the
    /// author wrote (<see cref="StateUIRenderer.Named"/>), a number is the
    /// identity an <c>Aim</c> captured
    /// (<see cref="StateUIRenderer.Tracked"/>).
    /// </remarks>
    /// <param name="Key">The name, or the identity's text.</param>
    /// <param name="ByIdentity">Whether the argument was a number.</param>
    private readonly record struct ActTarget(string Key, bool ByIdentity)
    {
        /// <summary>How a message names the view - "called 'panel'" or "#17".</summary>
        public string Label => ByIdentity ? $"#{Key}" : $"called '{Key}'";
    }

    /// <summary>
    /// Reads which view an act is about from its argument 0, or null when
    /// nothing usable is there.
    /// </summary>
    /// <param name="call">The act.</param>
    /// <returns>The target, or null when argument 0 is neither kind of id.</returns>
    private static ActTarget? TargetOf(HostActCall call)
    {
        if (call.GetString(0) is string name)
        {
            return new ActTarget(name, ByIdentity: false);
        }

        // The differ's identities are integers, and the tracked map's keys are
        // their decimal spelling.
        if (call.GetDouble(0) is double identity)
        {
            return new ActTarget(
                ((long)identity).ToString(CultureInfo.InvariantCulture),
                ByIdentity: true);
        }

        return null;
    }

    /// <summary>
    /// The control an act's target resolves to, through whichever map its
    /// namespace says.
    /// </summary>
    /// <param name="target">The act's view argument.</param>
    /// <returns>Null when nothing it names is being shown.</returns>
    private (VisualElement View, string Type)? Find(ActTarget target) =>
        target.ByIdentity ? _renderer.Tracked(target.Key) : _renderer.Named(target.Key);

    /// <summary>
    /// The same lookup, for an APPLICATION's registered act - reached through
    /// <see cref="StateUIActs.TargetOf"/>, which is the only thing that calls
    /// this.
    /// </summary>
    /// <remarks>
    /// The two maps are the renderer's and stay its own; what an application
    /// needs is the answer, not the namespaces. Type is dropped on the way out
    /// because a performer written for one control tests for it with <c>is</c>,
    /// which reads better than comparing the name this side happens to use.
    /// </remarks>
    /// <param name="call">The act, with the control's identity at 0.</param>
    /// <returns>The control, or null when argument 0 names none on screen.</returns>
    internal VisualElement? Aimed(HostActCall call) =>
        TargetOf(call) is { } target && Find(target) is { } found ? found.View : null;

    /// <summary>
    /// Slides the Map the Swift side named to the region around a point -
    /// MAUI's <c>MoveToRegion</c>, the span built with
    /// <c>MapSpan.FromCenterAndRadius</c> and the radius in meters, which is
    /// what <c>Distance</c> is at bottom.
    /// </summary>
    /// <remarks>
    /// The same shape as a WebView act: the view at argument 0, found through
    /// <see cref="TargetOf"/>, and a view of another type is a FAILURE rather
    /// than a silence. The three numbers are REFUSED when absent or NaN - a map
    /// moved to a zero nobody asked for is the Atlantic, drawn perfectly.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private (HostValue[] Result, string? Failure) MoveMap(HostActCall call)
    {
        if (TargetOf(call) is not { } target)
        {
            return ([], "a Map act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (found.View is not Microsoft.Maui.Controls.Maps.Map map)
        {
            return ([], $"the view {target.Label} is a {found.Type}, not a Map");
        }

        if (call.GetDouble(1) is not double latitude
            || call.GetDouble(2) is not double longitude
            || call.GetDouble(3) is not double radius)
        {
            return ([], "Map.MoveToRegion needs latitude, longitude and a radius "
                + "in meters, and one of them is absent or not a number");
        }

        map.MoveToRegion(Values.MapSpan(latitude, longitude, radius));

        return ([], null);
    }

    /// <summary>
    /// Drives the WebView the Swift side named - back, forward, fetching the
    /// page again, and running JavaScript in it.
    /// </summary>
    /// <remarks>
    /// All four are MAUI methods on the control, named at argument 0 like every
    /// other act's view. A view of another type is a FAILURE rather than a
    /// silence: an act that does nothing looks exactly like a page with no
    /// history.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private async Task<(HostValue[] Result, string? Failure)> Web(HostActCall call)
    {
        if (TargetOf(call) is not { } target)
        {
            return ([], "a WebView act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (found.View is not WebView web)
        {
            return ([], $"the view {target.Label} is a {found.Type}, not a WebView");
        }

        switch (call.Act)
        {
            case HostAct.GoBack:
                web.GoBack();
                return ([], null);

            case HostAct.GoForward:
                web.GoForward();
                return ([], null);

            case HostAct.Reload:
                web.Reload();
                return ([], null);

            default:
                // What the script's last expression evaluated to, as the
                // platform writes it - null when the page answered nothing.
                string script = call.GetString(1) ?? "";
                return ([HostValue.Of(await web.EvaluateJavaScriptAsync(script) ?? "")], null);
        }
    }

    /// <summary>
    /// Moves the keyboard onto, or off, the control the Swift side named.
    /// </summary>
    /// <remarks>
    /// Both are MAUI methods on the view, named at argument 0 like every other
    /// act's view - an id being the only handle that survives a render.
    /// <c>Focus</c> answers whether the view took the focus, which is MAUI's own
    /// answer and an ordinary one: a disabled view, or one with nothing to type
    /// into, says no.
    /// <c>Unfocus</c> answers nothing, so the Swift call awaits and reads no
    /// result.
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private (HostValue[] Result, string? Failure) Aim(HostActCall call)
    {
        if (TargetOf(call) is not { } target)
        {
            return ([], "a focus act has to say which view it is for");
        }

        if (Find(target) is not { } found)
        {
            return ([], $"there is no view {target.Label} on screen");
        }

        if (call.Act == HostAct.Unfocus)
        {
            found.View.Unfocus();
            return ([], null);
        }

        return ([HostValue.Of(found.View.Focus())], null);
    }

    /// <summary>
    /// Shows a dialog on the page the reader is looking at, and reports what
    /// they chose. MAUI: Page.DisplayAlertAsync, DisplayActionSheetAsync and
    /// DisplayPromptAsync - the two alert forms told apart by their argument
    /// count, everything in the order MAUI's parameters have.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The act names no page: a dialog belongs to whatever is showing -
    /// the modal top included - which only the host can know. The SoftInput
    /// reasoning, one act over.
    /// </para>
    /// <para>
    /// The page must be ON SCREEN: MAUI completes these tasks from the
    /// platform's alert manager, so on a page with no handler they NEVER
    /// complete and the awaiting Swift handler hangs forever with nothing
    /// anywhere saying why. Reported as a failure instead, which reaches the
    /// Swift `try await` as a thrown error.
    /// </para>
    /// <para>
    /// Two of the answers can be NOTHING - an action sheet dismissed without
    /// choosing, a prompt cancelled - and the VALUE is what says so: a choice
    /// crosses as one string value, a dismissal as one <c>nothing</c> value -
    /// see <see cref="Chosen"/>. An accepted prompt with nothing typed is one
    /// empty string - an empty answer, which is not the same as no answer.
    /// </para>
    /// </remarks>
    /// <returns>What to report back, and why it could not be done.</returns>
    private async Task<(HostValue[] Result, string? Failure)> Dialog(HostActCall call)
    {
        if (Focus.Showing(Showing()) is not Page page)
        {
            return ([], "there is no page to show a dialog on");
        }

        if (page.Handler is null)
        {
            return ([], "the page is not on screen, so a dialog would never return");
        }

        string title = call.GetString(0) ?? "";

        switch (call.Act)
        {
            case HostAct.Alert:
                await page.DisplayAlertAsync(
                    title, call.GetString(1) ?? "", call.GetString(2) ?? "OK");
                return ([], null);

            case HostAct.Confirm:
                bool accepted = await page.DisplayAlertAsync(
                    title,
                    call.GetString(1) ?? "",
                    call.GetString(2) ?? "OK",
                    call.GetString(3) ?? "Cancel");
                return ([HostValue.Of(accepted)], null);

            case HostAct.ChooseAction:
                // The two optional captions arrive as the wire's own nothing
                // when they are absent, and read as null here without a
                // sentinel in between: an empty string is a caption someone
                // could have written, and telling the special ones apart would
                // be the reader's job.
                var buttons = new string[Math.Max(0, (call.Arguments?.Count ?? 3) - 3)];
                for (int index = 0; index < buttons.Length; index++)
                {
                    buttons[index] = call.GetString(index + 3) ?? "";
                }

                string? pressed = await page.DisplayActionSheetAsync(
                    title,
                    call.GetString(1),
                    call.GetString(2),
                    buttons);
                return (Chosen(pressed), null);

            default:
                string? typed = await page.DisplayPromptAsync(
                    title,
                    call.GetString(1) ?? "",
                    call.GetString(2) ?? "OK",
                    call.GetString(3) ?? "Cancel",
                    call.GetString(4),

                    // -1 is MAUI's own "no limit" for this parameter, not a
                    // sentinel of ours: the wire says the length is not there
                    // and this is what MAUI wants to hear for that.
                    call.GetInt(5) ?? -1,
                    Values.KeyboardOf(call.GetEnumeration(6)) ?? Keyboard.Default,
                    call.GetString(7) ?? "");
                return (Chosen(typed), null);
        }
    }

    /// <summary>
    /// An answer that may be nothing: the caption that was pressed, or the
    /// wire's own nothing for a dialog the reader dismissed.
    /// </summary>
    /// <remarks>
    /// One value either way, so that the fact sits IN the answer rather than in
    /// the shape of the reply: an empty reply already means "this act returns
    /// nothing at all", which is a different thing from a reader who chose
    /// nothing. Both read as null on the Swift side.
    /// </remarks>
    private static HostValue[] Chosen(string? answer) =>
        [answer is null ? new HostValue(HostValue.TagNothing) : HostValue.Of(answer)];

    /// <summary>
    /// The page whose focus is on screen, wherever the application put it.
    /// </summary>
    /// <remarks>
    /// The window's page - which is an ARRANGEMENT, so what the reader is
    /// actually looking at is found by descending through it; that is
    /// <see cref="Focus.Showing"/>'s job, and every caller here goes
    /// through it.
    /// <para>
    /// The window the reader is WORKING IN, where a desktop application has
    /// several. MAUI does not say which window has the keyboard, but it does
    /// report activation per window - so the application follows that, and an
    /// alert raised from the second window opens over the second window. Any
    /// other target - a Swift tree embedded in someone else's page - has no
    /// window list of its own and falls back to MAUI's first.
    /// </para>
    /// </remarks>
    /// <returns>The page, or null when the application has no window yet.</returns>
    private Page? Showing() =>
        (_target as StateUIApplication)?.Active?.Page
            ?? Application.Current?.Windows.FirstOrDefault()?.Page;
}
