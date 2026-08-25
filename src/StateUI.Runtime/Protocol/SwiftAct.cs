// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Protocol;

/// <summary>
/// Every act this runtime performs itself - the dispatch table behind
/// <c>Perform</c>'s switch. The values are this enum's own: on the wire an
/// act travels as its number from the SESSION's dictionary, and
/// <see cref="SwiftTokenNames{TToken}"/> maps the announced name to a member
/// once, as the batch is read - so no spelling is compared per act.
/// </summary>
/// <remarks>
/// <see cref="None"/> is a name this runtime has no case for - an
/// application's registered act, answered by the registry consulted in
/// <c>Perform</c>'s default arm, or an unknown command reported as one.
/// </remarks>
public enum SwiftAct : ushort
{
    /// <summary>A name with no case here - the registry's, or unknown.</summary>
    None = 0,

    // The numbering is not contiguous, and nothing needs it to be: these
    // values never leave this assembly - an act rides the wire as the number
    // the SESSION gave its NAME, and SwiftTokenNames turns that name back into
    // a member - so a gap costs nothing and a member keeps whatever number it
    // has.

    /// <summary>VisualElement.Focus.</summary>
    Focus = 16,

    /// <summary>VisualElement.Unfocus.</summary>
    Unfocus = 17,

    /// <summary>WebView.GoBack.</summary>
    GoBack = 18,

    /// <summary>WebView.GoForward.</summary>
    GoForward = 19,

    /// <summary>WebView.Reload.</summary>
    Reload = 20,

    /// <summary>WebView.EvaluateJavaScriptAsync.</summary>
    EvaluateJavaScriptAsync = 21,

    /// <summary>Map.MoveToRegion.</summary>
    MoveToRegion = 22,

    /// <summary>ScrollView.ScrollToAsync.</summary>
    ScrollToAsync = 23,

    /// <summary>SoftInput.Hide - this library's own, MAUI having no method.</summary>
    HideSoftInput = 25,

    /// <summary>Page.DisplayAlertAsync.</summary>
    DisplayAlertAsync = 26,

    /// <summary>Page.DisplayActionSheetAsync.</summary>
    DisplayActionSheetAsync = 27,

    /// <summary>Page.DisplayPromptAsync.</summary>
    DisplayPromptAsync = 28,

    /// <summary>DateTime.Now - the host's clock, asked.</summary>
    DateTimeNow = 29,

    /// <summary>TimeZoneInfo.Local.</summary>
    LocalTimeZone = 30,

    /// <summary>TimeZoneInfo.GetUtcOffset.</summary>
    GetUtcOffset = 31,

    /// <summary>StateUI.HandlerFailed - a handler's escaped error, reported.</summary>
    HandlerFailed = 32,

    /// <summary>StateUI.StopFlight - this library's own: ends the walk on an
    /// armed property and answers where it reached.</summary>
    StopFlight = 33,

    /// <summary>StateUI.PersistValue - this library's own: one kept key's new
    /// value, on its way to the store.</summary>
    PersistValue = 34,
}
