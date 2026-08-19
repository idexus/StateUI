namespace StateUI.Runtime.Protocol;

/// <summary>
/// The one place a token's NAME meets its member, for all four vocabularies -
/// consulted once per name per session, as the announcement is read, and never
/// again.
/// </summary>
/// <remarks>
/// <para>
/// DERIVED from the enum rather than written out. A token's spelling IS its
/// member's name: camelCased for a property, an event and an act, and left
/// capitalized for a node type, which names a CLASS rather than a member. That
/// is the whole naming rule this library has - <c>Core/Tokens.swift</c>
/// declares the same pairing on the other side and
/// <c>testEveryTokenIsSpelledLikeItsMember</c> holds it there - so the member
/// IS the registration here too, with no second list to fall out of step.
/// </para>
/// <para>
/// The failure a hand-written table invites is not a crash: it is a name
/// reaching no member, which reads as a property that is quietly ignored or an
/// act that does nothing. <c>testEveryTokenHasAMemberOnTheOtherSide</c> reads
/// both languages because nothing else can - a token leaves Swift as a number
/// with a spelling behind it and arrives here as a lookup, so a missing member
/// fails to compile NOWHERE.
/// </para>
/// </remarks>
/// <typeparam name="TToken">
/// One of <see cref="SwiftNodeType"/>, <see cref="SwiftProp"/>,
/// <see cref="SwiftEvent"/> or <see cref="SwiftAct"/>. Each declares
/// <c>None = 0</c> for a name this runtime has no member for - an
/// application's own, or one from a Swift side newer than this host.
/// </typeparam>
internal static class SwiftTokenNames<TToken>
    where TToken : struct, Enum
{
    private static readonly Dictionary<string, TToken> Names = Build();

    private static readonly Dictionary<TToken, string> Spellings =
        Names.ToDictionary(pair => pair.Value, pair => pair.Key);

    /// <summary>
    /// The member for a name, or <c>None</c> for one this runtime has no
    /// member for. The caller keeps the spelling either way: an application's
    /// own control is found in the registry by it, and an unknown type is
    /// named in the marker by it.
    /// </summary>
    internal static TToken Parse(string name) => Names.GetValueOrDefault(name);

    /// <summary>
    /// A member's spelling - the wire's, and MAUI's. Empty for <c>None</c>,
    /// which stands for a name this runtime has no member for and therefore
    /// has no spelling of its own.
    /// </summary>
    /// <remarks>
    /// The reverse of <see cref="Parse"/>, built once beside it, for the two
    /// places that need a name back out of a member: the order a visual
    /// state's setters go in - which is by NAME and load-bearing, see
    /// <c>SwiftStyles.AddSetters</c> - and a node built by this side rather
    /// than read off the wire, whose <c>TypeName</c> is derived from its type.
    /// </remarks>
    internal static string Spelling(TToken token) => Spellings.GetValueOrDefault(token, "");

    /// <summary>Every member but <c>None</c>, spelled as the wire spells it.</summary>
    private static Dictionary<string, TToken> Build()
    {
        // A node type is the one vocabulary whose spelling is the member
        // VERBATIM, because it names a MAUI class - `Label`, not `label`.
        bool capitalized = typeof(TToken) == typeof(SwiftNodeType);

        Dictionary<string, TToken> names = [];

        foreach (TToken token in Enum.GetValues<TToken>())
        {
            string member = token.ToString();

            if (member == "None")
            {
                continue;
            }

            names[capitalized ? member : char.ToLowerInvariant(member[0]) + member[1..]] = token;
        }

        return names;
    }
}
