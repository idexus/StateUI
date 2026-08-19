namespace StateUI.Runtime.Protocol;

/// <summary>
/// A key into a node's properties, in whichever of the two vocabularies it
/// belongs to: a <see cref="SwiftProp"/> for one of the library's, a NAME for
/// one an application declared on a control of its own.
/// </summary>
/// <remarks>
/// <para>
/// The two cannot share a bag - every app-declared name resolves to
/// <see cref="SwiftProp.None"/>, so a control with two of its own would lose
/// one to the other as a duplicate key - so a node carries
/// <c>Props</c> and <c>OwnProps</c>, and this is what reads either. It is the
/// same shape <see cref="SwiftId"/> has for identity: the kind travels with
/// the value, and nothing has to ask which bag a key came from.
/// </para>
/// <para>
/// Almost nothing builds one by hand. A call site names a member -
/// <c>node.GetString(SwiftProp.Text)</c> - and the implicit conversion makes
/// that a key with no name, which is a lookup in the library's bag and no
/// string hashed anywhere. Three places must serve an application's own
/// property and so build one with a name: <c>SwiftStyles.AddSetters</c>,
/// <c>SwiftFlights</c> and <c>StateUIRenderer.ReconcileRegistered</c>.
/// </para>
/// <para>
/// A named key carries its member as well, when the spelling happens to be one
/// the library also has - <c>value</c>, <c>text</c>. Such a property arrives in
/// the LIBRARY's bag, the reader having no way to tell whose it was, so a key
/// that looks in both is what keeps an application free to name its own
/// properties whatever MAUI would.
/// </para>
/// </remarks>
internal readonly struct SwiftKey
{
    /// <summary>One of the library's properties, by member.</summary>
    private SwiftKey(SwiftProp prop) => Prop = prop;

    /// <summary>One key under both forms a name can have reached this side in.</summary>
    private SwiftKey(SwiftProp prop, string name)
    {
        Prop = prop;
        Name = name;
    }

    /// <summary>
    /// The library's member for this key, or <see cref="SwiftProp.None"/> for a
    /// name the library has none for.
    /// </summary>
    internal SwiftProp Prop { get; }

    /// <summary>
    /// The spelling, for a key that came from an application - null for one the
    /// renderer named by member, which is every key on the hot path.
    /// </summary>
    internal string? Name { get; }

    /// <summary>
    /// A key an application wrote, by the only form it has: its spelling. The
    /// member is resolved with it, since a name the library also knows arrives
    /// in the library's bag.
    /// </summary>
    /// <param name="name">The property's name, as the application declared it.</param>
    internal static SwiftKey Own(string name) =>
        new(SwiftTokenNames<SwiftProp>.Parse(name), name);

    /// <summary>
    /// A key under both forms - what a node's own property list answers, having
    /// read the member off the wire and derived the spelling from it.
    /// </summary>
    /// <param name="prop">The member, or <see cref="SwiftProp.None"/>.</param>
    /// <param name="name">The spelling.</param>
    internal static SwiftKey Of(SwiftProp prop, string name) => new(prop, name);

    /// <summary>
    /// One of the library's properties, which is what the renderer asks for -
    /// implicit so that <c>node.GetString(SwiftProp.Text)</c> is what a call
    /// site reads as.
    /// </summary>
    /// <param name="prop">The member.</param>
    public static implicit operator SwiftKey(SwiftProp prop) => new(prop);
}
