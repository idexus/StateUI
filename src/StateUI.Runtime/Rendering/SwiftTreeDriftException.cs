namespace StateUI.Runtime.Rendering;

/// <summary>
/// A correct message read against the wrong baseline: the patch describes a
/// tree this side is not holding.
/// </summary>
/// <remarks>
/// <para>
/// Deliberately NOT an <see cref="System.IO.InvalidDataException"/>. That one
/// means the bytes are malformed - a name never announced, a field the reader
/// does not know, a message from another wire version - and there is nothing
/// to do about it but say so and stop. Drift is the opposite kind of failure:
/// the bytes are perfect and the two sides have simply lost their common
/// baseline, which is exactly the condition the generation handshake exists to
/// recover from. Sharing one exception type made the recoverable case fatal.
/// </para>
/// <para>
/// It is thrown from deep inside a reconcile, where returning a value would
/// have to be threaded through every list, every child and every control. What
/// catches it is the <see cref="IStateUITarget.Apply"/> boundary - the one the
/// session calls - which turns it into the REFUSAL that interface already
/// speaks: false means "I could not apply this", and the session answers a
/// refusal by dropping the generation and asking Swift for the whole tree.
/// </para>
/// </remarks>
internal sealed class SwiftTreeDriftException : Exception
{
    /// <summary>Says what the patch named and what was holding it.</summary>
    /// <param name="message">What the tree said, and what this side has.</param>
    internal SwiftTreeDriftException(string message)
        : base(message)
    {
    }
}
