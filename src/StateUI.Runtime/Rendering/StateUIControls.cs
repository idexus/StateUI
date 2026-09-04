// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Reports an event of a registered control to the Swift side - the delegate a
/// control's <c>create</c> receives, so its events can be wired ONCE, where
/// the control is made, the rule every built-in follows.
/// </summary>
/// <param name="sender">The control whose event fired.</param>
/// <param name="eventName">The event's name, as the Swift side listens for it.</param>
/// <param name="payload">
/// One typed value per interesting fact, in a fixed order - what the Swift
/// handler reads with <c>payload.value(…)</c>. Empty for an event with
/// nothing to say.
/// </param>
public delegate void StateUIRaise(
    BindableObject sender, string eventName, params SwiftWireValue[] payload);

/// <summary>
/// The application's own controls: a factory and an applier registered under a
/// node type name, consulted by the renderer before it draws the
/// unknown-control marker.
/// </summary>
/// <remarks>
/// <para>
/// Register at startup, in <c>MauiProgram.CreateMauiApp</c>, then describe the
/// control from Swift like any other - a struct wrapping a node of the same
/// type name, its properties written with <c>setValue</c>, its events heard
/// with <c>onEvent</c>:
/// </para>
/// <code>
/// // C#, MauiProgram.CreateMauiApp:
/// StateUIControls.Add("Gallery.TrafficLight",
///     create: raise =>
///     {
///         var light = new TrafficLight();
///         light.LightTapped += (_, index) =>
///             raise(light, "lightTapped", SwiftWireValue.Of(index));
///         return light;
///     },
///     apply: (light, node) =>
///     {
///         if (node.GetString("state") is string state)
///         {
///             light.State = state;
///         }
///     });
///
/// // Swift, anywhere:
/// extension NodeType { static let trafficLight = NodeType("Gallery.TrafficLight") }
///
/// struct TrafficLight: View {
///     var node = Node(type: .trafficLight)
/// }
/// </code>
/// <para>
/// The renderer gives a registered control everything a built-in gets: it is
/// KEPT between renders and found again by identity, the shared tier - margins,
/// opacity, sizing, gestures, lifecycle events - is applied around the
/// registration's own <c>apply</c>, and an event reported through
/// <see cref="StateUIRaise"/> finds its Swift handler by the id the tree
/// carried. <c>apply</c> runs on every message that touches the control and
/// reads only what arrived - an absent property did not change, the rule the
/// whole wire follows.
/// </para>
/// <para>
/// A property backed by a <see cref="BindableProperty"/> can be DECLARED
/// instead of applied by hand: pass it in <c>properties</c> and the renderer
/// assigns it whenever a message carries it - and, because the declaration
/// joins the same table a walk resolves its target through, the property
/// becomes WALKABLE: an application arms it with a binding of its own -
/// <c>func rating(_ value: Binding&lt;Double&gt;) -&gt; Modified</c> - and
/// <c>$stars.animateTo(5, …)</c> moves a registered control exactly as it
/// moves a Label's opacity. <c>apply</c> stays the imperative escape for
/// anything a BindableProperty does not back.
/// </para>
/// <para>
/// A registration can hold Swift-described CONTENT: pass <c>content</c>, a
/// setter for the control's one slot, and the renderer reconciles the node's
/// child into it - created, patched and kept by identity like any other view,
/// the way a Border's content is. One slot on purpose: MAUI's own
/// single-content controls hold one view, and a layout inside it holds the
/// rest.
/// </para>
/// <para>
/// A Swift <c>Style</c> can target it, and nothing here is asked about that: a
/// style is resolved on the Swift side, so conforming the Swift struct to
/// <c>StyleTarget</c> is the whole of it, and what arrives is a node already
/// carrying the style's values among its own.
/// </para>
/// <para>
/// Prefix type names with the application's own (<c>"Gallery."</c>) so they
/// can never meet a control this library adds later.
/// </para>
/// </remarks>
public static class StateUIControls
{
    private static readonly Lock Guard = new();
    private static readonly Dictionary<string, Registration> Registered = [];

    /// <summary>A registered control's parts, the control type erased -
    /// <see cref="Add{TControl}"/> is where the casts live.</summary>
    internal sealed record Registration(
        Func<StateUIRaise, View> Create,
        Action<View, SwiftNode>? Apply,
        IReadOnlyDictionary<string, BindableProperty>? Properties,
        Action<View, View?>? Content);

    /// <summary>
    /// Registers a control under a node type name. Registering the same name
    /// again replaces the registration.
    /// </summary>
    /// <typeparam name="TControl">
    /// The control's own class - inferred from <paramref name="create"/>, so
    /// that <paramref name="apply"/> and <paramref name="content"/> are written
    /// against the real type rather than against <see cref="View"/>.
    /// </typeparam>
    /// <param name="type">
    /// The node type the Swift side describes, e.g. <c>"Gallery.TrafficLight"</c>.
    /// </param>
    /// <param name="create">
    /// Makes the control - called once per element, where its events are
    /// wired through the <see cref="StateUIRaise"/> it receives.
    /// </param>
    /// <param name="apply">
    /// Assigns the node's properties to the control - called on every message
    /// that touches it, after the declared <paramref name="properties"/>.
    /// Null for a control whose properties are all declared; the shared tier
    /// is applied either way.
    /// </param>
    /// <param name="properties">
    /// The control's own properties, by wire name - assigned by the renderer
    /// whenever a message carries one, and reachable by an animation and a
    /// style, which resolve through the same table the library's own
    /// properties sit in.
    /// </param>
    /// <param name="content">
    /// Places the reconciled child view into the control - the one slot a
    /// registered container has. Called only when the slot changes hands;
    /// null for a control that holds no described content.
    /// </param>
    public static void Add<TControl>(
        string type,
        Func<StateUIRaise, TControl> create,
        Action<TControl, SwiftNode>? apply = null,
        IReadOnlyDictionary<string, BindableProperty>? properties = null,
        Action<TControl, View?>? content = null)
        where TControl : View
    {
        lock (Guard)
        {
            Registered[type] = new Registration(
                raise => create(raise),
                apply is null ? null : (view, node) => apply((TControl)view, node),
                properties,
                content is null ? null : (view, inner) => content((TControl)view, inner));
        }
    }

    /// <summary>The registration for a type, or null - consulted by the
    /// renderer before the unknown-control marker.</summary>
    internal static Registration? Find(string type)
    {
        lock (Guard)
        {
            return Registered.GetValueOrDefault(type);
        }
    }

    /// <summary>
    /// A declared property of a registered type, or null - the registry's arm
    /// of <c>SwiftStyles.Property</c>, which is what lets an animation walk
    /// an application control's own property.
    /// </summary>
    internal static BindableProperty? PropertyOf(string type, string name)
    {
        lock (Guard)
        {
            return Registered.GetValueOrDefault(type)?.Properties?.GetValueOrDefault(name);
        }
    }

}
