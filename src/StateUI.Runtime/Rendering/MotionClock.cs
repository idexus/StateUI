// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What says WHEN to draw the next frame of everything that is moving.
/// </summary>
/// <remarks>
/// <para>
/// A clock says nothing about what time it is - that is
/// <see cref="System.Diagnostics.Stopwatch"/>'s job and there is exactly one of
/// those - it only says that the screen is about to be painted. Every platform
/// has such a signal and every one of them is tied to the display's own rhythm,
/// which is what keeps a motion smooth at 60Hz and at 120 without a number
/// anywhere having to say which.
/// </para>
/// <para>
/// It STOPS when nothing is moving. A signal that goes on arriving sixty times
/// a second over a still screen is a battery being spent on nothing, and on one
/// platform it is measurable in the process's own CPU line.
/// </para>
/// </remarks>
internal interface IMotionClock
{
    /// <summary>
    /// What time it is, in stopwatch ticks.
    /// </summary>
    /// <remarks>
    /// One monotonic timebase for the whole engine, and every platform's clock
    /// answers it the same way - a frame signal says WHEN to draw and never
    /// what time it is, its own timestamps being in units of its own. The one
    /// clock that answers differently is the one a test winds, which is what
    /// makes a trajectory something a test can assert to the digit.
    /// </remarks>
    long Now => System.Diagnostics.Stopwatch.GetTimestamp();

    /// <summary>Begins asking for frames.</summary>
    void Start();

    /// <summary>Stops asking.</summary>
    void Stop();

    /// <summary>Raised on the thread the platform draws on, once per frame.</summary>
    event Action? Frame;
}

/// <summary>
/// One frame signal in flight at a time, wherever the next one has to be asked
/// for.
/// </summary>
/// <remarks>
/// <para>
/// A platform that answers ONE frame and then forgets is asked again from
/// inside the frame it has just given. So something has to answer "is one
/// already on its way?", and the answer cannot be "are frames wanted?": a
/// frame that stops the clock and starts it again - which is exactly what one
/// value landing beside another starting does - would leave TWO signals in
/// motion, each asking for itself, for the rest of the session.
/// </para>
/// <para>
/// The rule is one flag: while a signal is outstanding nothing asks for
/// another, and the one that arrives asks for the next only if frames are
/// still wanted.
/// </para>
/// </remarks>
internal sealed class FramePump
{
    private readonly Action _ask;
    private bool _running;
    private bool _asked;

    /// <summary>The pump, over whatever asks the platform for one frame.</summary>
    /// <param name="ask">Asks the platform for the next signal.</param>
    internal FramePump(Action ask) => _ask = ask;

    /// <summary>Whether frames are wanted.</summary>
    internal bool Running => _running;

    /// <summary>Begins asking for them.</summary>
    internal void Start()
    {
        if (_running)
        {
            return;
        }

        _running = true;
        Ask();
    }

    /// <summary>Stops wanting them. One already in flight still arrives.</summary>
    internal void Stop() => _running = false;

    /// <summary>
    /// The platform's signal has arrived - answers whether to make a frame of
    /// it.
    /// </summary>
    /// <returns>True while frames are wanted.</returns>
    internal bool Arrived()
    {
        _asked = false;
        return _running;
    }

    /// <summary>
    /// Asks for the next one, unless frames have stopped being wanted or one
    /// was asked for while this frame ran.
    /// </summary>
    internal void Again()
    {
        if (_running)
        {
            Ask();
        }
    }

    private void Ask()
    {
        if (_asked)
        {
            return;
        }

        _asked = true;
        _ask();
    }
}

/// <summary>
/// The clock this platform draws by.
/// </summary>
/// <remarks>
/// One per process rather than one per window: the engine is one, and two
/// windows' clocks would only tick it twice for the same instant - which the
/// engine would answer with two frames' worth of nothing, since a frame that
/// takes no time moves nothing.
/// </remarks>
internal static class MotionClock
{
    /// <summary>
    /// What answers a clock where this build has none of its own - set by a
    /// platform package before anything renders.
    /// </summary>
    /// <remarks>
    /// The plain build is two different things: the headless tests, which drive
    /// the engine by hand and want no clock at all, and Linux, whose GTK4
    /// backend brings its own package and sets one here from the window's frame
    /// clock. Neither can be told apart by a compiler switch, so it is asked
    /// for rather than compiled in.
    /// </remarks>
    internal static Func<IMotionClock?>? Provided { get; set; }

    /// <summary>Makes the clock, or nothing where this platform has none.</summary>
    /// <returns>A clock nobody has started yet.</returns>
    internal static IMotionClock? Create()
    {
#if IOS || MACCATALYST
        return new DisplayLink();
#elif ANDROID
        return new FrameCallback();
#elif WINDOWS
        return new Composition();
#else
        return Provided?.Invoke();
#endif
    }

#if IOS || MACCATALYST
    /// <summary>Apple's own frame signal, tied to the display.</summary>
    /// <remarks>
    /// The COMMON run loop mode is load-bearing: in the default mode the signal
    /// stops arriving while a finger is tracking a scroller, which is exactly
    /// when a motion beside it must not stall.
    /// </remarks>
    private sealed class DisplayLink : IMotionClock
    {
        /// <summary>
        /// How long the link goes on running after the engine stops wanting
        /// frames, in milliseconds.
        /// </summary>
        /// <remarks>
        /// **A LINK THAT WAS ASKED TO STOP DOES NOT ANSWER AGAIN FOR ~90 ms**,
        /// and the engine stops wanting frames the moment nothing is moving -
        /// which inside one scroller's settle is every frame or two: measured
        /// on Mac Catalyst as 635 stops and starts in a single scroll, and a
        /// settle that brakes, holds for ~90 ms and then arrives in one step.
        /// Half a second of running on costs a swallowed callback a frame and
        /// buys every movement that follows another its frames at once.
        /// </remarks>
        private const double GraceMs = 500;

        /// <summary>The clock the grace is counted on.</summary>
        private static readonly System.Diagnostics.Stopwatch Clock =
            System.Diagnostics.Stopwatch.StartNew();

        private CoreAnimation.CADisplayLink? _link;

        /// <summary>
        /// When the engine last stopped wanting frames, or -1 while it wants
        /// them.
        /// </summary>
        private double _idleSince = -1;

        public event Action? Frame;

        public void Start()
        {
            _idleSince = -1;

            if (_link is null)
            {
                _link = CoreAnimation.CADisplayLink.Create(Tick);

                _link.AddToRunLoop(Foundation.NSRunLoop.Main, Foundation.NSRunLoopMode.Common);
            }

            _link.Paused = false;
        }

        /// <summary>
        /// One frame from the display: handed on where the engine wants it,
        /// swallowed while it does not, and the link paused once the grace has
        /// run out.
        /// </summary>
        private void Tick()
        {
            if (_idleSince < 0)
            {
                Frame?.Invoke();
                return;
            }

            if (Clock.Elapsed.TotalMilliseconds - _idleSince > GraceMs && _link is not null)
            {
                _link.Paused = true;
            }
        }

        /// <summary>Stops wanting frames - PAUSED, never taken down.</summary>
        /// <remarks>
        /// **A LINK MADE AFRESH DOES NOT ANSWER AT ONCE**, and the engine asks
        /// for frames in bursts: a scroller's settle is stopped and re-aimed
        /// every frame or two - each report of the offset lands on the state
        /// and halts what carries it - so a clock that was invalidated and
        /// built again on each of those took ~90 ms to speak, several times in
        /// one movement. Measured on Mac Catalyst: 635 starts and stops in one
        /// scroll, and a settle drawn in three pieces with the value jumping
        /// between them. Paused, the link costs a flag and answers on the next
        /// frame. notes/driven-state.md.
        /// </remarks>
        public void Stop()
        {
            if (_idleSince < 0)
            {
                _idleSince = Clock.Elapsed.TotalMilliseconds;
            }
        }
    }
#elif ANDROID
    /// <summary>
    /// Android's own frame signal, asked for one frame at a time.
    /// </summary>
    /// <remarks>
    /// A callback is good for a single frame there, so it posts itself again
    /// from inside the one it is answering - which is what
    /// <see cref="FramePump"/> keeps to one. The choreographer belongs to the
    /// THREAD that asks for it, which is why this is only ever started from the
    /// thread the platform draws on.
    /// </remarks>
    private sealed class FrameCallback : Java.Lang.Object, Android.Views.Choreographer.IFrameCallback, IMotionClock
    {
        private readonly FramePump _pump;

        public FrameCallback() =>
            _pump = new FramePump(() => Android.Views.Choreographer.Instance?.PostFrameCallback(this));

        public event Action? Frame;

        public void Start() => _pump.Start();

        public void Stop() => _pump.Stop();

        public void DoFrame(long frameTimeNanos)
        {
            if (!_pump.Arrived())
            {
                return;
            }

            Frame?.Invoke();
            _pump.Again();
        }
    }
#elif WINDOWS
    /// <summary>
    /// The composition's own frame signal.
    /// </summary>
    /// <remarks>
    /// Detached when it stops rather than left attached behind a flag: it fires
    /// for every frame the whole window composes, whether anything of ours is
    /// moving or not.
    /// </remarks>
    private sealed class Composition : IMotionClock
    {
        private bool _running;

        public event Action? Frame;

        public void Start()
        {
            if (_running)
            {
                return;
            }

            _running = true;
            Microsoft.UI.Xaml.Media.CompositionTarget.Rendering += OnRendering;
        }

        public void Stop()
        {
            if (!_running)
            {
                return;
            }

            _running = false;
            Microsoft.UI.Xaml.Media.CompositionTarget.Rendering -= OnRendering;
        }

        private void OnRendering(object? sender, object e) => Frame?.Invoke();
    }
#endif
}

/// <summary>
/// A clock a test winds by hand.
/// </summary>
/// <remarks>
/// Every trajectory is a pure function of the time since it began, so a scripted
/// sequence of instants makes a motion something a test can assert to the digit
/// - and a test that never winds it is a test where nothing moves, which is the
/// honest answer for a control with no screen under it.
/// </remarks>
internal sealed class HandMotionClock : IMotionClock
{
    /// <summary>Whether anything has asked for frames.</summary>
    internal bool Running { get; private set; }

    /// <inheritdoc/>
    public long Now { get; private set; } = 1;

    /// <inheritdoc/>
    public event Action? Frame;

    /// <inheritdoc/>
    public void Start() => Running = true;

    /// <inheritdoc/>
    public void Stop() => Running = false;

    /// <summary>Moves the clock on and delivers one frame.</summary>
    /// <param name="ms">How many milliseconds have passed.</param>
    internal void Tick(double ms = 16)
    {
        Now += (long)Math.Round(ms * System.Diagnostics.Stopwatch.Frequency / 1000.0);
        Frame?.Invoke();
    }
}
