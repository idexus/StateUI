using System.Reflection;
using System.Runtime.InteropServices;

namespace Gallery;

/// <summary>
/// Keeps a transformed view from freeing its graphene point twice.
/// </summary>
/// <remarks>
/// <para>
/// The backend's <c>ApplyTransform</c> allocates a graphene point through the
/// bindings and calls <c>graphene_point_free</c> on it by hand - but the
/// wrapper it allocated THROUGH owns the point too, and frees it again when
/// the garbage collector reaches it. Every view wearing a <c>Scale</c>,
/// <c>Rotation</c> or translation frees its point twice, and the process dies
/// on a corrupted heap at the collection after the first press of a card that
/// dips - deterministically, with nothing said.
/// </para>
/// <para>
/// The pair cannot be separated from C#: both frees are the backend's and the
/// bindings' own. What can be done is to make the EXPLICIT one say nothing:
/// <c>graphene-shim.c</c> builds into a library defining that one symbol as a
/// no-op with the real libgraphene as its dependency, and this hands the
/// bindings that library instead of the real one - their resolver caches
/// whatever handle its <c>TargetLibraryPointer</c> field holds, so seeding
/// the field is the whole install. Every other graphene call falls through
/// the shim's dependency to the real thing, and the collector's free - which
/// runs inside GLib, not through the bindings' imports - stays real and
/// becomes the only one.
/// </para>
/// <para>
/// A shim that is missing, cannot load, or no longer reaches the real
/// library, and a field a future release renames, each leave the bindings
/// untouched - the backend then behaves as it does alone.
/// </para>
/// </remarks>
internal static class LinuxTransforms
{
    /// <summary>Arms it, before anything touches graphene.</summary>
    internal static void Install()
    {
        string shim = Path.Combine(AppContext.BaseDirectory, "libgraphene-shim.so");

        if (!File.Exists(shim) || !NativeLibrary.TryLoad(shim, out nint handle))
        {
            return;
        }

        // The shim must forward what it does not define, or every graphene
        // call in the process would fail instead of one going quiet.
        if (!NativeLibrary.TryGetExport(handle, "graphene_point_alloc", out _))
        {
            return;
        }

        typeof(Graphene.Point).Assembly
            .GetType("Graphene.Internal.ImportResolver")
            ?.GetField("TargetLibraryPointer", BindingFlags.Static | BindingFlags.NonPublic)
            ?.SetValue(null, handle);
    }
}
