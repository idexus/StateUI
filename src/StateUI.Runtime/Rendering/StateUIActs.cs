using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The application's own acts: C# functions registered under a name, callable
/// from Swift exactly like the acts this library ships.
/// </summary>
/// <remarks>
/// <para>
/// Register at startup, in <c>MauiProgram.CreateMauiApp</c>, then declare the
/// same name on the Swift side as an <c>Act</c> token and call it from any
/// handler:
/// </para>
/// <code>
/// // C#, MauiProgram.CreateMauiApp:
/// StateUIActs.Add("Gallery.BatteryLevel",
///     command => [SwiftWireValue.Of(Battery.Default.ChargeLevel)]);
///
/// // Swift, anywhere:
/// extension Act {
///     static let batteryLevel = Act("Gallery.BatteryLevel")
/// }
///
/// let level = try await stateUICall(.batteryLevel).value()?.number
/// </code>
/// <para>
/// A performer reads its arguments off the <see cref="SwiftCommand"/> with
/// the typed accessors and answers values built with
/// <see cref="SwiftWireValue"/>'s factories - empty for a function with
/// nothing to say. One that throws fails the act: the awaiting Swift handler
/// resumes by throwing <c>StateUIError</c> with the exception's message,
/// which is the same road every act of the library's takes.
/// </para>
/// <para>
/// Performers run on the thread MAUI draws on, where every act runs, and an
/// async one is awaited there - free to touch controls before its first
/// await and to call any async API after it. The registry is consulted for
/// names the session has no case of its own for, so a registration cannot
/// shadow a library act; prefix names with the application's own
/// (<c>"Gallery."</c>) and they never meet.
/// </para>
/// </remarks>
public static class StateUIActs
{
    private static readonly Lock Guard = new();
    private static readonly Dictionary<string, Func<SwiftCommand, Task<SwiftWireValue[]>>> Performers = [];

    /// <summary>
    /// Registers an async function under a name. Registering the same name
    /// again replaces the performer.
    /// </summary>
    /// <param name="name">The name Swift calls, e.g. <c>"Gallery.BatteryLevel"</c>.</param>
    /// <param name="performer">What to run; its values answer the Swift <c>try await</c>.</param>
    public static void Add(string name, Func<SwiftCommand, Task<SwiftWireValue[]>> performer)
    {
        lock (Guard)
        {
            Performers[name] = performer;
        }
    }

    /// <summary>
    /// Registers a plain function under a name - the same registration, for a
    /// function with nothing to await.
    /// </summary>
    /// <param name="name">The name Swift calls, e.g. <c>"Gallery.BatteryLevel"</c>.</param>
    /// <param name="performer">What to run; its values answer the Swift <c>try await</c>.</param>
    public static void Add(string name, Func<SwiftCommand, SwiftWireValue[]> performer)
    {
        Add(name, command => Task.FromResult(performer(command)));
    }

    /// <summary>
    /// The view an act is AIMED at, or null when it names none that is on
    /// screen.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The other half of Swift's <c>ControlState.target</c>: an application
    /// that aims an act of its own puts the control's identity in argument 0,
    /// exactly as every act of this library does, and this is what turns that
    /// identity back into the control. Without it a registered performer could
    /// be handed an aim it had no way to resolve - the identity is the
    /// DIFFER's, in one of two namespaces, and neither map is an application's
    /// to read.
    /// </para>
    /// <code>
    /// // Swift:
    /// extension ControlState where Target == ColorWheel {
    ///     public func spin(by degrees: Double) async throws {
    ///         try await stateUICall(.spin, [try target, .number(degrees)])
    ///     }
    /// }
    ///
    /// // C#, in MauiProgram.CreateMauiApp:
    /// StateUIActs.Add("Gallery.Spin", command =>
    /// {
    ///     if (StateUIActs.TargetOf(command) is ColorWheel wheel)
    ///     {
    ///         wheel.Rotation = command.GetDouble(1) ?? 0;
    ///     }
    ///
    ///     return [];
    /// });
    /// </code>
    /// <para>
    /// Null is an ordinary answer rather than a failure: the view may have left
    /// the tree between the act being written and the host draining it, which
    /// is what acting on a vanished view has always meant here. A performer
    /// that needs to say so throws, and the awaiting Swift handler resumes with
    /// the message.
    /// </para>
    /// </remarks>
    /// <param name="command">The act, as the performer received it.</param>
    /// <returns>The control argument 0 names, or null.</returns>
    public static VisualElement? TargetOf(SwiftCommand command) =>
        StateUIEnvironment.Session?.Aimed(command);

    /// <summary>The performer for a name, or null - consulted by
    /// <c>Perform</c>'s default arm before it reports an unknown command.</summary>
    internal static Func<SwiftCommand, Task<SwiftWireValue[]>>? Find(string name)
    {
        lock (Guard)
        {
            return Performers.GetValueOrDefault(name);
        }
    }
}
