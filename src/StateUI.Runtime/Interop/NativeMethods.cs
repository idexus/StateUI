using System.Runtime.InteropServices;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Interop;

/// <summary>
/// The surface of the StateUI LIBRARY reachable across the P/Invoke boundary.
///
/// Everything here has a counterpart marked <c>@_cdecl</c> in the library's
/// <c>Bridge/Exports.swift</c>; the two files should be read together.
/// </summary>
/// <remarks>
/// The application's own Swift module is a separate native library with a name
/// derived from the project, so it cannot be referenced by a compile-time
/// constant here. It is reached through <see cref="Rendering.StateUIHost.RegisterApp"/>,
/// which the app project's generated interop file supplies.
/// </remarks>
/// <remarks>
/// <para>
/// Uses <c>[LibraryImport]</c> (a source generator, .NET 7+) rather than
/// <c>[DllImport]</c>: the marshalling code is produced at compile time, making
/// it faster and fully compatible with Native AOT. That is why the class and its
/// methods are <c>partial</c>.
/// </para>
/// <para>
/// The library name differs by platform because of how the library is linked.
/// On Apple platforms it is a static archive linked into the app binary, so the
/// symbols live in the executable itself - which is what the magic
/// <c>__Internal</c> name means. Elsewhere it is a real shared library and .NET
/// resolves the platform convention itself (libStateUI.so, StateUI.dll).
/// </para>
/// </remarks>
internal static partial class NativeMethods
{
    /// <summary>
    /// Where the exports live. See the remarks on this class for why it differs
    /// by platform.
    /// </summary>
#if IOS || MACCATALYST
    private const string Lib = "__Internal";
#else
    private const string Lib = "StateUI";
#endif

    /// <summary>
    /// Builds the current UI tree and returns what changed, in the binary wire
    /// format. Writes the byte count into <paramref name="length"/>. The
    /// caller owns the memory and must release it with <see cref="FreeBuffer"/>.
    /// </summary>
    /// <param name="baseline">
    /// The generation the caller is holding - the one that came with the last
    /// message it applied successfully, or 0 for nothing. A caller still holding
    /// the current generation is sent a patch; anyone else is sent the whole
    /// tree.
    /// </param>
    /// <param name="length">The message's byte count.</param>
    /// <remarks>
    /// Named <c>_wire</c> for the reason <see cref="TakeCommandsWire"/> is: a
    /// half built before this format fails with
    /// <see cref="EntryPointNotFoundException"/> instead of reading a register
    /// as a pointer.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_render_wire")]
    internal static partial IntPtr RenderWire(int baseline, out int length);

    /// <summary>
    /// Reports that an event fired or an act finished - positive ids are an
    /// element's events, negative ids are completions. <paramref name="payload"/>
    /// carries the binary payload (<see cref="SwiftWire.WritePayload"/> for an
    /// event, <see cref="SwiftWire.WriteReply"/> or
    /// <see cref="SwiftWire.WriteFailure"/> for a completion), or null for an
    /// event with nothing to say. Returns 1 if a handler ran, 0 if the id was
    /// unknown - which happens for events arriving against a replaced tree and
    /// is not an error.
    /// </summary>
    /// <remarks>
    /// The buffer is read before the call returns, so nothing is pinned past
    /// it and nothing is freed. Named <c>_wire</c> for the reason the other
    /// wire exports are: a half built before this format fails with
    /// <see cref="EntryPointNotFoundException"/> instead of reading bytes as
    /// a C string.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_dispatch_wire")]
    internal static partial int DispatchWire(int handlerId, byte[]? payload, int length);

    /// <summary>
    /// Reports an event the host raised by NAME, with no element behind it -
    /// the application's own pushes, written with
    /// <see cref="SwiftWire.WriteHostEvent"/> and heard by whatever the Swift
    /// side subscribed with <c>HostEvents.on</c>. Returns how many handlers
    /// heard it - zero is ordinary - and -1 for a buffer the library could
    /// not read, which the session reports as version skew.
    /// </summary>
    /// <remarks>
    /// The buffer is read before the call returns, so nothing is pinned past
    /// it and nothing is freed.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_dispatch_host_event")]
    internal static partial int DispatchHostEvent(byte[] bytes, int length);

    /// <summary>
    /// Says where a WALK has got to: one sample of a flight in the air, on the
    /// channel its transition named, in the payload layout an event uses.
    /// Returns 1 when a piece of state was waiting for it and 0 when none was.
    /// </summary>
    /// <remarks>
    /// Its own entry point rather than a reply, because a reply is one-shot
    /// and ENDS the await: there may be dozens of these before the one message
    /// that says the walk is over. The buffer is read before the call returns,
    /// so nothing is pinned past it and nothing is freed.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_report_flight")]
    internal static partial int ReportFlight(int channel, byte[]? payload, int length);

    /// <summary>
    /// Takes the acts queued by the Swift side since the last call, in the
    /// binary wire format, and clears the queue. Writes the byte count into
    /// <paramref name="length"/> and returns <see cref="IntPtr.Zero"/> for an
    /// empty queue - the common case, every pump, allocating nothing.
    /// </summary>
    /// <remarks>
    /// The caller owns the memory and must release it with
    /// <see cref="FreeBuffer"/>. Named <c>_wire</c> rather than reusing the
    /// old JSON export's name on purpose: a half built before this format
    /// fails with <see cref="EntryPointNotFoundException"/> - a clean,
    /// nameable error - where the same name with a changed signature would
    /// read a register as a pointer.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_take_commands_wire")]
    internal static partial IntPtr TakeCommandsWire(out int length);

    /// <summary>
    /// Which version of the binary wire format the native library writes.
    /// Checked before the first render, so two halves built from different
    /// versions fail at startup with a sentence instead of reading each
    /// other's bytes wrong.
    /// </summary>
    [LibraryImport(Lib, EntryPoint = "stateui_wire_version")]
    internal static partial int WireVersion();

    /// <summary>
    /// Releases a buffer <see cref="TakeCommandsWire"/> returned. Memory
    /// allocated in Swift is freed in Swift - the <see cref="FreeString"/>
    /// rule.
    /// </summary>
    [LibraryImport(Lib, EntryPoint = "stateui_free_buffer")]
    internal static partial void FreeBuffer(IntPtr pointer);

    /// <summary>
    /// Reports that the last taken batch could not be read at all, so the
    /// Swift side fails every act in it with <paramref name="reason"/> and
    /// each awaiting handler resumes by throwing.
    /// </summary>
    /// <remarks>
    /// The host cannot name the acts itself - their completion ids are inside
    /// the very JSON that would not parse - so the take keeps a receipt on the
    /// Swift side, and this is how a failed parse cashes it.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_fail_taken_commands", StringMarshalling = StringMarshalling.Utf8)]
    internal static partial void FailTakenCommands(string reason);

    /// <summary>Whether state changed since the last render.</summary>
    [LibraryImport(Lib, EntryPoint = "stateui_needs_render")]
    internal static partial int NeedsRender();

    /// <summary>
    /// Runs whatever a suspended Swift handler has waiting, and returns how many
    /// jobs ran. This is where a handler comes back to life after an
    /// <c>await</c>.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Must be called on the thread MAUI draws on: whatever the handler does
    /// next happens inside this call.
    /// </para>
    /// <para>
    /// A call IN rather than a callback out, deliberately. Swift produces the
    /// resumed job on a cooperative-pool thread, and entering .NET from a thread
    /// it has never seen makes Mono attach that thread - which deadlocks the UI
    /// thread when a debugger is attached, on Android. Measured. See
    /// <c>Core/MainThread.swift</c>.
    /// </para>
    /// <para>
    /// The job does not exist yet when the completion is reported, so a caller
    /// that gets 0 should ask again on its next turn - see
    /// <c>StateUISession.DrainWhenTheResumeArrives</c>.
    /// </para>
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_run_jobs")]
    internal static partial int RunJobs();

    /// <summary>
    /// How many handlers have been told their act is over and have not come back
    /// yet. Zero when there is nothing to wait for.
    /// </summary>
    /// <remarks>
    /// What makes <c>StateUISession.DrainWhenTheResumeArrives</c> a condition
    /// rather than a guess: <see cref="RunJobs"/> returning 0 says only that the
    /// work has not appeared, never whether it is coming.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_resumes_pending")]
    internal static partial int ResumesPending();

    /// <summary>
    /// How many jobs are sitting in Swift's queue right now, waiting for
    /// <see cref="RunJobs"/>.
    /// </summary>
    /// <remarks>
    /// The half <see cref="ResumesPending"/> cannot see: a handler suspended on
    /// its own child tasks - <c>async let</c> - resumes through a job no
    /// completion accounting covers, because what it awaited was never a host
    /// command. Polling only the resume count gave up exactly one job too
    /// early, which read as an animation loop frozen mid-beat.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_jobs_pending")]
    internal static partial int JobsPending();

    /// <summary>
    /// Parks the calling thread inside Swift until a job lands in its queue,
    /// and returns how many are waiting - possibly 0, when another drain got
    /// there first.
    /// </summary>
    /// <remarks>
    /// BLOCKS, by design - call it only from the thread the session dedicates
    /// to it. That thread is created by .NET, which is the whole point: Mono
    /// deadlocks when native code enters managed from a thread it has never
    /// seen, so instead of Swift calling out, the host sends a thread IN to
    /// wait. It is what lets a <c>Task.sleep</c> or an author's own task resume
    /// promptly with no command in flight - see
    /// <c>StateUISession.AskWheneverWorkLands</c>.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_wait_work")]
    internal static partial int WaitWork();

    /// <summary>
    /// Releases a string Swift allocated. Memory allocated in Swift is freed in
    /// Swift: several C runtimes can coexist on Windows, and freeing across them
    /// crashes unpredictably.
    /// </summary>
    [LibraryImport(Lib, EntryPoint = "stateui_free_string")]
    internal static partial void FreeString(IntPtr pointer);

    /// <summary>Platform and architecture the Swift side was compiled for.</summary>
    [LibraryImport(Lib, EntryPoint = "stateui_platform")]
    internal static partial IntPtr Platform();

    /// <summary>
    /// Tells Swift what the host knows - one standard provider's values per
    /// call, written with <see cref="SwiftWire.WriteEnvironment"/>. Called for
    /// every domain before the first render, so the first tree already knows
    /// its idiom and its locale - which is the whole point: an act could only
    /// answer a handler, and which pages EXIST is decided while the tree is
    /// built - and again whenever a platform event reports a change.
    /// </summary>
    /// <remarks>
    /// Returns 1 applied, 0 for a domain or shape the library does not know
    /// (refused whole), -1 for a buffer that would not read - either failure
    /// is reported once as version skew. The buffer is read before the call
    /// returns, so nothing is pinned past it and nothing is freed.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_set_environment")]
    internal static partial int SetEnvironment(byte[] bytes, int length);

    /// <summary>
    /// Asks which store the application keeps state in and every key it keeps
    /// there. Writes the byte count into <paramref name="length"/> and returns
    /// <see cref="IntPtr.Zero"/> for an application that keeps nothing.
    /// </summary>
    /// <remarks>
    /// Called once, after the app registers and before the first render: a
    /// settings store is read key by key and never enumerated, so this is the
    /// only way the host can learn what to ask it for - and the state has to
    /// hold the kept value before the first view reads it. The caller owns the
    /// memory and must release it with <see cref="FreeBuffer"/>.
    /// </remarks>
    /// <param name="length">The announcement's byte count.</param>
    [LibraryImport(Lib, EntryPoint = "stateui_persistent_keys")]
    internal static partial IntPtr PersistentKeys(out int length);

    /// <summary>
    /// Tells Swift what the store held - a name and a value per key that was
    /// there, written with <see cref="SwiftWire.WritePersistent"/>.
    /// </summary>
    /// <remarks>
    /// Returns 1 applied, -1 for a buffer that would not read, which is
    /// reported once as version skew. The buffer is read before the call
    /// returns, so nothing is pinned past it and nothing is freed.
    /// </remarks>
    [LibraryImport(Lib, EntryPoint = "stateui_set_persistent")]
    internal static partial int SetPersistent(byte[] bytes, int length);

    /// <summary>
    /// Copies a string returned by Swift and releases the native allocation.
    /// </summary>
    /// <remarks>
    /// The release happens in a <c>finally</c> so the memory returns to Swift
    /// even if the conversion throws.
    /// </remarks>
    internal static string TakeString(IntPtr pointer)
    {
        if (pointer == IntPtr.Zero)
        {
            return string.Empty;
        }

        try
        {
            return Marshal.PtrToStringUTF8(pointer) ?? string.Empty;
        }
        finally
        {
            FreeString(pointer);
        }
    }
}
