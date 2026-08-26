// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Puts a pan's totals back into the coordinate frame the pan began in, on the
/// platforms that measure them against a frame that moves with the view.
/// </summary>
/// <remarks>
/// <para>
/// MAUI's own documentation says the totals are measured from where the pan
/// began, which is what makes moving a view a matter of assigning them to its
/// translation. On Android that is only true while the view holds still.
/// </para>
/// <para>
/// The two platforms measure differently, and the difference is the whole
/// reason this type exists. iOS asks UIKit for
/// <c>UIPanGestureRecognizer.TranslationInView</c>, which is a VECTOR - moving
/// the view cannot change it, because a vector has no origin to move. Android
/// subtracts two POINTS, <c>e2.RawX - e1.RawX</c>, where <c>e1</c> is the touch
/// that began the gesture: each is in the receiving view's own frame at the
/// moment it was delivered, so translating the view moves the frame the second
/// one was measured in, and the report comes back short by exactly the
/// translation.
/// </para>
/// <para>
/// A handler that answers a pan by translating the view therefore feeds its own
/// answer back into the next report, and the view lands between two positions
/// and stays there. Measured on an Android device and emulator: with the
/// translation held at zero the totals climb evenly to the finger's real
/// displacement, and with it live they alternate - and the alternating values
/// plus the view's translation come to the same even climb, which is what says
/// the contamination is the translation and nothing else.
/// </para>
/// <para>
/// To see it, drag continuously - a real finger, <c>adb shell input swipe</c>,
/// anything that produces a stream of touches. Injecting isolated events a
/// tenth of a second apart with <c>adb shell input motionevent</c> does not
/// reproduce it.
/// </para>
/// <para>
/// Only the running reports carry a total on any platform: started, completed
/// and canceled all arrive as zero, MAUI raising them without one, so those are
/// passed on exactly as they came.
/// </para>
/// </remarks>
internal sealed class PanFrame
{
    /// <summary>Where the view sat when the pan began.</summary>
    private double _fromX;

    /// <summary>The same, vertically.</summary>
    private double _fromY;

    /// <summary>Whether a pan is under way, and the origin above is its.</summary>
    private bool _panning;

    /// <summary>Whether the reports arriving need the correction.</summary>
    private readonly bool _movesWithTheView;

    /// <summary>A frame for one view, on whichever platform this is.</summary>
    internal PanFrame()
        : this(MovesWithTheView)
    {
    }

    /// <summary>
    /// A frame told which kind of platform it is on - which is how a test asks
    /// for the other one.
    /// </summary>
    /// <param name="movesWithTheView">
    /// Whether the platform measures a report against the view's own frame.
    /// </param>
    internal PanFrame(bool movesWithTheView)
    {
        _movesWithTheView = movesWithTheView;
    }

    /// <summary>
    /// Whether this platform measures a pan against a frame that moves with the
    /// view, and so needs the correction below.
    /// </summary>
    /// <remarks>
    /// Android does; iOS, Mac Catalyst and Windows report a translation that
    /// the view's own movement cannot reach. Asked at runtime rather than
    /// compiled in, so the headless tests can exercise both answers.
    /// </remarks>
    internal static bool MovesWithTheView { get; } = OperatingSystem.IsAndroid();

    /// <summary>
    /// What this report says the finger has done since the pan began, measured
    /// where the pan began.
    /// </summary>
    /// <param name="report">The report MAUI raised.</param>
    /// <param name="translationX">Where the view sits now. MAUI: VisualElement.TranslationX.</param>
    /// <param name="translationY">The same, vertically.</param>
    internal (double X, double Y) Totals(PanUpdatedEventArgs report, double translationX, double translationY)
    {
        // The origin is taken from the first report of a pan rather than from
        // the started one: which statuses a platform sends is the platform's
        // business, and a pan whose origin was never taken would be corrected
        // against the pan before it.
        if (!_panning)
        {
            _panning = true;
            _fromX = translationX;
            _fromY = translationY;
        }

        if (report.StatusType is GestureStatus.Completed or GestureStatus.Canceled)
        {
            _panning = false;
        }

        if (!_movesWithTheView || report.StatusType != GestureStatus.Running)
        {
            return (report.TotalX, report.TotalY);
        }

        return (report.TotalX + (translationX - _fromX), report.TotalY + (translationY - _fromY));
    }
}
