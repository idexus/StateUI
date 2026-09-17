// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using StateUI.Maui.Interop;

/// <summary>
/// The far end of the Swift side's image: one call in, one cycle, one call
/// out.
/// </summary>
/// <remarks>
/// A seam rather than a set of P/Invokes so that the tests can wind the whole
/// thing by hand - the cycle is a pure function over there, and a stub that
/// records what crossed is what makes it one over here too.
/// </remarks>
internal interface ICycleCrossing
{
    /// <summary>Takes a batch of writes into the image.</summary>
    /// <param name="batch">The bytes, in the layout CoreLink describes.</param>
    /// <returns>How many states were written, or -1 for bytes that could not be read.</returns>
    int Write(ReadOnlySpan<byte> batch);

    /// <summary>Runs one cycle.</summary>
    /// <param name="sync">Which board.</param>
    /// <param name="now">The instant, in milliseconds.</param>
    /// <param name="reducesMotion">Whether the reader asked for less movement.</param>
    /// <returns>
    /// How many states have lanes waiting, with <c>0x4000_0000</c> set while
    /// any engine says it has more to do.
    /// </returns>
    int Cycle(int sync, double now, bool reducesMotion);

    /// <summary>Reads out what a cycle wrote.</summary>
    /// <param name="number">Which number, or 0 for every one with lanes waiting.</param>
    /// <param name="into">Where to write.</param>
    /// <returns>How many bytes were written, 0 for a state that has gone, -1 for no room.</returns>
    int Read(int number, Span<byte> into);

    /// <summary>Whether anything at all is waiting for a cycle.</summary>
    /// <returns>How many boards have something waiting.</returns>
    int Awake();

    /// <summary>The last cycle, as one line, or null where nothing answers.</summary>
    /// <returns>The line.</returns>
    string? Trace();
}

/// <summary>The crossing itself, over the Swift exports.</summary>
/// <remarks>
/// EVERY CALL IS BEHIND THE SAME QUESTION the rest of this runtime asks before
/// it enters Swift: whether there is a Swift half at all. A build with no
/// module - the tests, and a host that never registered an application -
/// answers as an empty image does, which is what "nothing is moving" means.
/// </remarks>
internal sealed class NativeCycleCrossing : ICycleCrossing
{
    /// <summary>Whether there is a Swift half to talk to.</summary>
    private static bool Live => StateUISession.RegisterApp is not null;

    /// <inheritdoc/>
    public unsafe int Write(ReadOnlySpan<byte> batch)
    {
        if (!Live)
        {
            return 0;
        }

        fixed (byte* bytes = batch)
        {
            return CoreLink.CycleWrite(bytes, batch.Length);
        }
    }

    /// <inheritdoc/>
    public int Cycle(int sync, double now, bool reducesMotion) =>
        Live ? CoreLink.CycleRun(sync, now, reducesMotion ? 1 : 0) : 0;

    /// <inheritdoc/>
    public unsafe int Read(int number, Span<byte> into)
    {
        if (!Live)
        {
            return 0;
        }

        fixed (byte* bytes = into)
        {
            return CoreLink.CycleRead(number, bytes, into.Length);
        }
    }

    /// <inheritdoc/>
    public int Awake() => Live ? CoreLink.CycleAwake() : 0;

    /// <inheritdoc/>
    public string? Trace() => Live ? CoreLink.TakeString(CoreLink.CycleTrace()) : null;
}

/// <summary>
/// A crossing a test winds by hand: it records every call and answers scripted
/// bytes.
/// </summary>
/// <remarks>
/// It reimplements NOTHING - there is no image here, no engine order and no
/// arithmetic, because all of that is asserted on the Swift side where it
/// lives. What this holds up is the HOST's half: that a report is written
/// before the cycle runs, that what a cycle answers is worn by the right
/// property, and that one frame is one cycle.
/// </remarks>
internal sealed class HandCrossing : ICycleCrossing
{
    /// <summary>Every batch this side wrote, in the order it wrote them.</summary>
    internal List<byte[]> Written { get; } = [];

    /// <summary>Every cycle asked for: which board, when, and whether reduced.</summary>
    internal List<(int Sync, double Now, bool Reduced)> Cycles { get; } = [];

    /// <summary>What the next cycle answers.</summary>
    internal int Answers { get; set; }

    /// <summary>
    /// What the next read of every dirty number answers, as a batch.
    /// </summary>
    /// <remarks>
    /// TAKEN, not kept: a read clears the lanes it answered over there, so a
    /// stub that went on answering the same bytes would have every frame
    /// re-aim a journey the last one started - which is not a thing the real
    /// crossing can do.
    /// </remarks>
    internal byte[] Dirty { get; set; } = [];

    /// <summary>What a read of one number answers, by number.</summary>
    internal Dictionary<int, byte[]> Whole { get; } = [];

    /// <summary>What <see cref="Awake"/> answers.</summary>
    internal int Waiting { get; set; }

    /// <inheritdoc/>
    public int Write(ReadOnlySpan<byte> batch)
    {
        Written.Add(batch.ToArray());
        return 1;
    }

    /// <inheritdoc/>
    public int Cycle(int sync, double now, bool reducesMotion)
    {
        Cycles.Add((sync, now, reducesMotion));
        return Answers;
    }

    /// <inheritdoc/>
    public int Read(int number, Span<byte> into)
    {
        byte[] answer = number == 0 ? Dirty : Whole.GetValueOrDefault(number, []);

        if (answer.Length == 0)
        {
            return 0;
        }

        if (answer.Length > into.Length)
        {
            return -1;
        }

        answer.CopyTo(into);

        if (number == 0)
        {
            Dirty = [];
        }

        return answer.Length;
    }

    /// <inheritdoc/>
    public int Awake() => Waiting;

    /// <inheritdoc/>
    public string? Trace() => null;
}
