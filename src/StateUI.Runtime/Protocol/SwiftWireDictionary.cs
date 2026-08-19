namespace StateUI.Runtime.Protocol;

/// <summary>
/// One session's numbering of every name the wire carries - node types,
/// property keys, event names, act methods, easings, style keys, one id space
/// for all of them.
/// </summary>
/// <remarks>
/// <para>
/// The Swift side assigns a name the next number the first time a message
/// uses it, and that message ANNOUNCES the pair in its head - so this side
/// learns the dictionary exactly as fast as it needs it, and an application's
/// own names ride numbers the same way the library's do. There is no static
/// table to be out of step with: every message teaches its reader.
/// </para>
/// <para>
/// Announcements sit at the HEAD of a message, before anything that could
/// refer to them - so a batch that fails later in its bytes has still taught
/// this side its names, and the session's numbering can never drift on a
/// failure. An id that was never announced is a protocol error and the reader
/// throws, which the callers turn into the causal failure paths - the tree's
/// error page, the act batch's receipt.
/// </para>
/// <para>
/// A name is resolved to its MEMBER here, once, as the announcement is read -
/// not at each use. Everything downstream then dispatches on an enum: the
/// renderer switches on a node type, a property is found under a
/// <see cref="SwiftProp"/> key, an event fires from a
/// <see cref="SwiftEvent"/>. The spelling is kept beside them because two
/// things still need it - an application's own control, which has no member
/// and is found in the registry by name, and every diagnostic that has to say
/// WHICH type or property it could not make sense of.
/// </para>
/// </remarks>
internal sealed class SwiftWireDictionary
{
    // The index IS the id. Slot 0 stays null - the writer never assigns 0.
    private readonly List<Entry?> _names = [null];

    /// <summary>Learns one announced pair, resolving it to a member of each
    /// vocabulary as it goes.</summary>
    /// <remarks>
    /// Three lookups for a name that can only belong to one vocabulary, and
    /// they are three lookups ONCE PER SESSION - against a name that would
    /// otherwise be hashed on every property of every render. Nothing on the
    /// wire says which vocabulary a name belongs to, and nothing needs to:
    /// the spellings do not collide, because a node type is capitalized and
    /// no property is spelled like an event.
    /// </remarks>
    internal void Set(ushort id, string name)
    {
        while (_names.Count <= id)
        {
            _names.Add(null);
        }

        _names[id] = new Entry(
            name,
            SwiftTokenNames<SwiftNodeType>.Parse(name),
            SwiftTokenNames<SwiftProp>.Parse(name),
            SwiftTokenNames<SwiftEvent>.Parse(name));
    }

    /// <summary>
    /// The name an id stands for, or null for one never announced.
    /// </summary>
    internal string? Resolve(ushort id) => At(id)?.Name;

    /// <summary>
    /// Everything an id stands for - its spelling and its member in each
    /// vocabulary - or null for one never announced.
    /// </summary>
    internal Entry? At(ushort id) => id < _names.Count ? _names[id] : null;

    /// <summary>One announced name, and what it means to each vocabulary.</summary>
    /// <param name="Name">The spelling, which the registry and the
    /// diagnostics still need.</param>
    /// <param name="NodeType">Its element type, or <c>None</c>.</param>
    /// <param name="Prop">Its property key, or <c>None</c>.</param>
    /// <param name="Event">Its event, or <c>None</c>.</param>
    internal readonly record struct Entry(
        string Name,
        SwiftNodeType NodeType,
        SwiftProp Prop,
        SwiftEvent Event);
}
