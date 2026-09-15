// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What each gesture REPORTS when its recognizer fires.
//
// RendererTests checks that the tree's handlers put the right recognizers on a
// view, configured from their properties; this is the other half, the report
// each one makes. MAUI raises a gesture from its platform handler through a
// sender, and most of those senders are internal to MAUI - so they are reached
// here by name. A MAUI that renames one fails here, saying which, rather than
// leaving a gesture untested.
using System.Reflection;

namespace StateUI.Maui.Tests;

public class GestureTests
{
    /// <summary>
    /// Calls a sender MAUI keeps internal - the one its platform handler calls
    /// when the gesture happens.
    /// </summary>
    /// <param name="recognizer">The recognizer the renderer put on the view.</param>
    /// <param name="sender">The sender's name.</param>
    /// <param name="arguments">Every argument it takes.</param>
    /// <returns>What the sender answers.</returns>
    private static object? Send(object recognizer, string sender, params object?[] arguments)
    {
        MethodInfo? method = recognizer.GetType().GetMethod(
            sender, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

        Assert.True(method is not null, $"MAUI's {recognizer.GetType().Name} has no {sender} any more");

        return method!.Invoke(recognizer, arguments);
    }

    /// <summary>Where every pointer in these tests is: three across, four down.</summary>
    private static readonly Func<IElement?, Point?> Here = _ => new Point(3, 4);

    [Fact]
    public void ATapReportsToItsHandler()
    {
        var host = new Host();

        var view = (Border)host.Apply("""{"id":"t","type":"Border","events":{"tapped":3}}""");
        TapGestureRecognizer tap = Assert.Single(view.GestureRecognizers.OfType<TapGestureRecognizer>());

        Send(tap, "SendTapped", view, null);

        Assert.Equal([(3, (string?)null)], host.Dispatched);
    }

    /// <summary>
    /// A pinch reports its phase, its scale and where it is centred - in the
    /// order MAUI declares them, which is the order Types/Gestures.swift reads.
    /// </summary>
    [Fact]
    public void APinchReportsItsPhaseItsScaleAndWhereItIs()
    {
        var host = new Host();

        var view = (Border)host.Apply("""{"id":"p","type":"Border","events":{"pinchUpdated":5}}""");
        var pinch = (IPinchGestureController)Assert.Single(view.GestureRecognizers.OfType<PinchGestureRecognizer>());

        pinch.SendPinchStarted(view, new Point(0.25, 0.75));
        pinch.SendPinch(view, 1.5, new Point(0.25, 0.75));
        pinch.SendPinchEnded(view);

        Assert.Equal(3, host.Dispatched.Count);
        Assert.Equal((5, "enum 0, 1, [0.25, 0.75]"), host.Dispatched[0]);
        Assert.Equal((5, "enum 1, 1.5, [0.25, 0.75]"), host.Dispatched[1]);
        Assert.StartsWith("enum 2, ", host.Dispatched[2].Payload);
    }

    /// <summary>
    /// Each moment of a pointer reports to its own handler, the three that
    /// happen somewhere with where, in the view's own coordinates.
    /// </summary>
    [Fact]
    public void EachMomentOfAPointerIsReportedWithWhereItWas()
    {
        var host = new Host();

        var view = (Border)host.Apply("""
            {"id":"o","type":"Border","events":{"pointerEntered":1,"pointerExited":2,
              "pointerMoved":3,"pointerPressed":4,"pointerReleased":5}}
            """);
        PointerGestureRecognizer pointer = Assert.Single(view.GestureRecognizers.OfType<PointerGestureRecognizer>());

        foreach (string moment in (string[])
            ["SendPointerEntered", "SendPointerMoved", "SendPointerPressed", "SendPointerReleased", "SendPointerExited"])
        {
            Send(pointer, moment, view, Here, null, ButtonsMask.Primary);
        }

        Assert.Equal(
            [(1, null), (3, "[3, 4]"), (4, "[3, 4]"), (5, "[3, 4]"), (2, (string?)null)],
            host.Dispatched);
    }

    /// <summary>A drag reports both its ends.</summary>
    [Fact]
    public void ADragReportsBothItsEnds()
    {
        var host = new Host();

        var view = (Border)host.Apply("""
            {"id":"d","type":"Border","props":{"canDrag":true},
             "events":{"dragStarting":1,"dropCompleted":2}}
            """);
        DragGestureRecognizer drag = Assert.Single(view.GestureRecognizers.OfType<DragGestureRecognizer>());

        Send(drag, "SendDragStarting", view, null, null);

        Assert.Equal((1, (string?)null), host.Dispatched[^1]);

        Send(drag, "SendDropCompleted", new DropCompletedEventArgs());

        Assert.Equal((2, (string?)null), host.Dispatched[^1]);
    }

    /// <summary>
    /// A view that takes drops reports a drag over it, a drag leaving it, and
    /// the text of what landed on it.
    /// </summary>
    [Fact]
    public async Task ADropReportsWhatHoversAndWhatLands()
    {
        var host = new Host();

        var view = (Border)host.Apply("""
            {"id":"r","type":"Border","props":{"allowDrop":true},
             "events":{"dragLeave":1,"dragOver":2,"drop":3}}
            """);
        DropGestureRecognizer drop = Assert.Single(view.GestureRecognizers.OfType<DropGestureRecognizer>());

        drop.SendDragOver(new DragEventArgs(new DataPackage()));

        Assert.Equal((2, (string?)null), host.Dispatched[^1]);

        Send(drop, "SendDragLeave", new DragEventArgs(new DataPackage()));

        Assert.Equal((1, (string?)null), host.Dispatched[^1]);

        var package = new DataPackage { Text = "Alpha" };

        await Assert.IsAssignableFrom<Task>(Send(drop, "SendDrop", new DropEventArgs(package.View)));

        Assert.Equal((3, "\"Alpha\""), host.Dispatched[^1]);
    }
}
