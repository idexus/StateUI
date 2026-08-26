// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a pan reports, on a platform that measures it against a frame the view
// itself moves - and on one that does not.
//
// The numbers below are the ones an Android emulator produced, drag by drag: a
// finger crossing 136.8 device-independent units in 800ms while the handler
// answered every report by translating the view. What arrived was a value
// alternating between two series, and each of them plus the view's translation
// at that moment came back to the finger's real position. That is what these
// tests replay.
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class PanTests
{
    /// <summary>One report, of the shape MAUI raises.</summary>
    private static PanUpdatedEventArgs Report(GestureStatus status, double totalX = 0, double totalY = 0) =>
        status is GestureStatus.Running
            ? new PanUpdatedEventArgs(status, 0, totalX, totalY)
            : new PanUpdatedEventArgs(status, 0);

    [Fact]
    public void APanIsMeasuredFromWhereItBeganEvenWhileTheViewFollowsIt()
    {
        var frame = new PanFrame(movesWithTheView: true);

        // The finger, evenly: 10, 20, 30, 40. The view is one report behind it,
        // because a handler cannot move it until it has heard.
        double[] finger = [10, 20, 30, 40];
        double translation = 0;
        var reported = new List<double>();

        frame.Totals(Report(GestureStatus.Started), translation, 0);

        foreach (double where in finger)
        {
            // What Android sends: two points subtracted, each in the view's own
            // frame at the moment it was measured.
            (double x, double _) = frame.Totals(Report(GestureStatus.Running, where - translation), translation, 0);

            reported.Add(x);
            translation = x;   // the handler answers by moving the view there
        }

        Assert.Equal(finger, reported);
    }

    [Fact]
    public void WhereAPanIsAlreadyMeasuredFromWhereItBeganNothingIsChanged()
    {
        var frame = new PanFrame(movesWithTheView: false);

        frame.Totals(Report(GestureStatus.Started), 0, 0);

        // iOS asks UIKit for a vector, which moving the view cannot reach. The
        // same reports, the same numbers back, translation or no translation.
        Assert.Equal((10.0, -4.0), frame.Totals(Report(GestureStatus.Running, 10, -4), 0, 0));
        Assert.Equal((20.0, -8.0), frame.Totals(Report(GestureStatus.Running, 20, -8), 10, -4));
        Assert.Equal((30.0, -12.0), frame.Totals(Report(GestureStatus.Running, 30, -12), 20, -8));
    }

    [Fact]
    public void OnlyTheRunningReportsCarryATotalToCorrect()
    {
        var frame = new PanFrame(movesWithTheView: true);

        // MAUI raises started, completed and canceled without totals on every
        // platform, so there is nothing there to put back - and a correction
        // would invent a value the platform never reported.
        Assert.Equal((0.0, 0.0), frame.Totals(Report(GestureStatus.Started), 0, 0));
        Assert.Equal((25.0, 0.0), frame.Totals(Report(GestureStatus.Running, 10), 15, 0));
        Assert.Equal((0.0, 0.0), frame.Totals(Report(GestureStatus.Completed), 25, 0));
    }

    [Fact]
    public void ASecondPanIsMeasuredFromWhereTheViewWasLeft()
    {
        var frame = new PanFrame(movesWithTheView: true);

        frame.Totals(Report(GestureStatus.Started), 0, 0);
        frame.Totals(Report(GestureStatus.Running, 10), 0, 0);
        frame.Totals(Report(GestureStatus.Completed), 10, 0);

        // The view is 10 along now. A pan that begins here has moved nothing
        // yet, so its first report is its own, not 10 more than it.
        frame.Totals(Report(GestureStatus.Started), 10, 0);

        Assert.Equal((5.0, 0.0), frame.Totals(Report(GestureStatus.Running, 5), 10, 0));
        Assert.Equal((9.0, 0.0), frame.Totals(Report(GestureStatus.Running, 4), 15, 0));
    }

    [Fact]
    public void APanWithNoStartedReportStillBeginsWhereItBegan()
    {
        var frame = new PanFrame(movesWithTheView: true);

        frame.Totals(Report(GestureStatus.Running, 10), 0, 0);
        frame.Totals(Report(GestureStatus.Completed), 10, 0);

        // Which statuses a platform sends is the platform's business - a
        // magnification on Mac Catalyst never says it started. So the origin is
        // taken from the first report of a pan, whatever that report is, or the
        // second pan would be corrected against the first one's.
        Assert.Equal((5.0, 0.0), frame.Totals(Report(GestureStatus.Running, 5), 10, 0));
    }

    [Fact]
    public void TheRendererReportsAPanInTheOrderMauiDeclaresIt()
    {
        var host = new Host();

        var view = (Border)host.Apply("""
            {"id":"p","type":"Border","events":{"panUpdated":9}}
            """);

        var pan = Assert.Single(view.GestureRecognizers.OfType<PanGestureRecognizer>());
        var controller = (IPanGestureController)pan;

        controller.SendPanStarted(view, 0);
        controller.SendPan(view, 12.5, -3, 0);
        controller.SendPanCompleted(view, 0);

        // The status as a MEMBER of our own vocabulary - started, running,
        // completed - then the two totals as plain numbers, which is the shape
        // Types/Gestures.swift reads. The correction is a platform's business
        // and these tests run on none, so what arrives is what MAUI gave.
        Assert.Equal(
            [(9, "enum 0, 0, 0"), (9, "enum 1, 12.5, -3"), (9, "enum 2, 0, 0")],
            host.Dispatched);
    }
}
