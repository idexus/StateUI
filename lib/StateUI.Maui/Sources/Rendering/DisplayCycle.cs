// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using StateUI.Maui.Protocol;

/// <summary>Why a cycle is being run.</summary>
internal enum CycleReason : byte
{
    /// <summary>The display is about to draw. Every tick, and the ordinary case.</summary>
    Frame = 0,

    /// <summary>
    /// Something was drained - a report landed, a handler wrote a value - and
    /// there may be nothing else about to make a frame.
    /// </summary>
    Drained = 1,

    /// <summary>
    /// A message registered or replaced a state, so the engines it armed have a
    /// picture to work out before anything is drawn.
    /// </summary>
    Registered = 2,

    /// <summary>A value the platform reports has moved.</summary>
    Told = 3,
}

/// <summary>
/// One sync's cycle, as this side runs it: what the platform has to say, then
/// the arithmetic, then what to write onto the controls.
/// </summary>
/// <remarks>
/// <para>
/// THREE PHASES, ONE ORDER, ONCE A FRAME. Everything the platform reported
/// goes in first, in the order it arrived; the Swift side then runs every
/// engine that has a reason to; and what those engines wrote comes back and is
/// written onto the controls. Nothing in the middle can see a value change
/// under it, which is what makes a run of frames reproducible.
/// </para>
/// <para>
/// <c>STATEUI_FRAMES</c> puts every cycle in the motion log beside the frames
/// it shares a clock with - what was latched in, how many engines ran, how many
/// were skipped, what was written and whether anything says it has more to do.
/// </para>
/// </remarks>
internal sealed class DisplayCycle
{
    /// <summary>How much room a read is given before it asks for more.</summary>
    private const int Room = 4096;

    private readonly Walker _walker;
    private readonly StateChannels _channels;
    private readonly Func<ICycleCrossing> _crossing;
    private readonly int _sync;

    /// <summary>What a cycle reads into, kept rather than made per frame.</summary>
    private byte[] _buffer = new byte[Room];

    private bool _cycling;
    private bool _inFrame;

    /// <summary>Whether a message is being applied, which defers every cycle.</summary>
    internal Func<bool>? Held { get; set; }

    /// <summary>One sync's cycle over the given states.</summary>
    /// <param name="walker">What moves the values.</param>
    /// <param name="channels">The states the cycle reads and writes.</param>
    /// <param name="crossing">The far end of the image, as it stands.</param>
    /// <param name="sync">Which board.</param>
    internal DisplayCycle(Walker walker, StateChannels channels, Func<ICycleCrossing> crossing, int sync = 0)
    {
        _walker = walker;
        _channels = channels;
        _crossing = crossing;
        _sync = sync;
    }

    /// <summary>
    /// Whether nothing is waiting for a frame - what the walker asks before it
    /// stops the clock.
    /// </summary>
    /// <returns>True when the clock may stop.</returns>
    internal bool Idle() => _crossing().Awake() == 0;

    /// <summary>
    /// One cycle: in, work out, out.
    /// </summary>
    /// <remarks>
    /// ONE PER FRAME, whatever else asks. A drained run is skipped inside a
    /// frame, because the frame's own cycle is about to catch whatever the
    /// drain wrote; and every run is skipped while a message is being applied,
    /// for the reason the walker skips a frame there - a value written inside
    /// an apply is a render inside an apply.
    /// </remarks>
    /// <param name="reason">Why.</param>
    internal void Run(CycleReason reason)
    {
        if (_cycling || Held?.Invoke() == true)
        {
            return;
        }

        if (reason == CycleReason.Drained && _inFrame)
        {
            return;
        }

        _cycling = true;

        try
        {
            _channels.Prune();
            Told();

            int answer = _crossing().Cycle(_sync, _walker.Clock?.Now is long now
                ? now * 1000.0 / System.Diagnostics.Stopwatch.Frequency
                : 0, MotionMood.Reduced);

            if (answer > 0)
            {
                Wear();
            }

            if (MotionTrace.Watching && _crossing().Trace() is string line)
            {
                MotionTrace.Say($"{reason.ToString().ToLowerInvariant()} {line}");
            }

            // AND THE DISPLAY IS WOKEN WHERE THE CYCLE SAYS THERE IS MORE TO
            // COME. An engine that answers "moving" is asking for the next
            // frame, and one that only ever writes a value it works out itself
            // aims nothing, so nothing else would start the clock for it.
            if (!Idle())
            {
                _walker.Clock?.Start();
            }
        }
        finally
        {
            _cycling = false;
        }
    }

    /// <summary>Runs a cycle as the frame's own, which is what a tick is.</summary>
    internal void Frame()
    {
        _inFrame = true;

        try
        {
            Run(CycleReason.Frame);
        }
        finally
        {
            _inFrame = false;
        }
    }

    /// <summary>
    /// PHASE ONE: what the platform has to say, written into the image before
    /// any arithmetic runs.
    /// </summary>
    /// <remarks>
    /// Where a value is and how fast it is going, for every state-driven
    /// property the walker has written since the last cycle - so an engine
    /// steering by a value the host is carrying is reading where it actually
    /// got to rather than where it was sent.
    /// </remarks>
    private void Told()
    {
        List<(int Number, ulong Mask, double[] Lanes)> batch = _channels.Readings();

        if (batch.Count > 0)
        {
            _crossing().Write(StateBatch.Bytes(batch));
        }
    }

    /// <summary>
    /// PHASE THREE: what the cycle wrote, onto the controls.
    /// </summary>
    private void Wear()
    {
        int written = _crossing().Read(0, _buffer);

        if (written < 0)
        {
            // Too small - and nothing was cleared over there, so asking again
            // with room answers the same bytes.
            _buffer = new byte[_buffer.Length * 2];
            written = _crossing().Read(0, _buffer);
        }

        if (written <= 0)
        {
            return;
        }

        _channels.Wear(_buffer.AsSpan(0, written));
    }
}
