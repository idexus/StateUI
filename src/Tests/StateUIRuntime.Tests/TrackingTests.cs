// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Finding the control an act names.
//
// An act carries an IDENTITY, never an object: the Swift side holds a
// description rebuilt on every render, so what it can name is a name the author
// wrote or a number the renderer assigned. This pins both maps - which control
// each answers with, and what happens when a control is replaced under one.
//
// Focus, scrolling, the WebView and the Map all aim through these two maps,
// which is why the resolution deserves tests of its own.

using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class TrackingTests
{
    private static SwiftWireValue Value(string json) => Host.Value(json);

    // ---- Finding the view ---------------------------------------------------

    [Fact]
    public void AControlTheAuthorNamedIsFoundByThatName()
    {
        var host = new Host();

        var label = (Label)host.Apply("""{"id":"caption","type":"Label","props":{"text":"Hi"}}""");

        Assert.Equal((label, "Label"), host.Renderer.Named("caption"));
    }

    /// <summary>
    /// The type comes back with the control because what can be done to it
    /// depends on it - a Label has a TextColor and a BoxView has not.
    /// </summary>
    [Fact]
    public void TheNameCarriesTheClassTheControlWasBuiltFor()
    {
        var host = new Host();

        host.Apply("""{"id":"swatch","type":"BoxView","props":{"color":"#FF0000"}}""");

        Assert.Equal("BoxView", host.Renderer.Named("swatch")?.Type);
    }

    [Fact]
    public void AnIdNobodyWroteCannotBeAskedForByName()
    {
        var host = new Host();

        // Numeric: the Swift renderer's own. A ControlState reaches it
        // through Tracked; the name map never hears of it, which is what keeps
        // the two namespaces from colliding when an author names a view "7".
        host.Apply("""{"id":7,"type":"Label","props":{"text":"Hi"}}""");

        Assert.Null(host.Renderer.Named("7"));
        Assert.Null(host.Renderer.Named("nobody"));
    }

    /// <summary>
    /// The identity map behind an act AIMED WITH A CONTROL STATE: an element
    /// the author did not name is reachable by the identity Swift assigned,
    /// resolved through <see cref="StateUIRenderer.Tracked"/> exactly as a
    /// name resolves through <c>Named</c>. See <c>Core/ControlState.swift</c>.
    /// </summary>
    [Fact]
    public void AnUnnamedControlIsTrackedByItsIdentity()
    {
        var host = new Host();

        var label = (Label)host.Apply("""{"id":7,"type":"Label","props":{"text":"Hi"}}""");

        Assert.Equal((label, "Label"), host.Renderer.Tracked("7"));
        Assert.Null(host.Renderer.Tracked("9"));
    }

    /// <summary>
    /// A NAMED element's acts arrive through the name - the Swift side sends
    /// the string whenever the element has one - so the identity map keeps
    /// only the numeric namespace, and an author naming a view "7" collides
    /// with nothing.
    /// </summary>
    [Fact]
    public void ANamedControlStaysOutOfTheIdentityMap()
    {
        var host = new Host();

        host.Apply("""{"id":"7","type":"Label","props":{"text":"Hi"}}""");

        Assert.Null(host.Renderer.Tracked("7"));
        Assert.NotNull(host.Renderer.Named("7"));
    }

    /// <summary>
    /// The identity follows the ELEMENT, so a replace - same identity, new
    /// control - leaves the handle aiming at what is actually on screen.
    /// </summary>
    [Fact]
    public void TheIdentityFollowsAReplacedControl()
    {
        var host = new Host();

        var first = host.Apply("""{"id":7,"type":"Label","props":{"text":"one"}}""");
        var second = host.Apply("""{"id":7,"type":"Label","replace":true,"props":{"text":"one"}}""");

        Assert.NotSame(first, second);
        Assert.Same(second, host.Renderer.Tracked("7")?.View);
    }

    /// <summary>
    /// The control is found after it has been patched, not only after it was
    /// built - the name follows the element, which is the point of an id.
    /// </summary>
    [Fact]
    public void ANameSurvivesTheControlBeingPatched()
    {
        var host = new Host();

        var label = (Label)host.Apply("""
            {"id":"caption","type":"Label","props":{"text":"one"}}
            """);

        host.Apply("""{"id":"caption","type":"Label","props":{"text":"two"}}""");

        Assert.Same(label, host.Renderer.Named("caption")?.View);
    }

    [Fact]
    public void ANameFollowsTheControlThatReplacedTheOldOne()
    {
        var host = new Host();

        var label = (Label)host.Apply("""{"id":"slot","type":"Label","props":{"text":"one"}}""");
        var button = (Button)host.Apply("""{"id":"slot","type":"Button","props":{"text":"two"}}""");

        Assert.NotSame(label, button);
        Assert.Equal((button, "Button"), host.Renderer.Named("slot"));
    }

    // ---- Which property, and whether it can be walked to --------------------
}
