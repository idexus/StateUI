// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The push half of the interop surface on this side: StateUIEvents.Raise,
// the application's way of speaking first. The bytes it writes are pinned by
// PayloadFixtureTests; what is pinned here is the promise around them.

using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StateUIEventsTests
{
    /// <summary>
    /// A raise made before any interface exists is dropped, not an error: a
    /// subscription is written by a Swift handler, a handler needs a rendered
    /// tree, so there was nobody the raise could have reached. This is what
    /// lets an application wire its sources unconditionally at startup.
    /// </summary>
    [Fact]
    public void ARaiseBeforeAnyInterfaceExistsIsDropped()
    {
        StateUISession? had = StateUIEvents.Session;
        StateUIEvents.Session = null;

        try
        {
            StateUIEvents.Raise("Test.Nobody", SwiftWireValue.Of(1.0));
        }
        finally
        {
            StateUIEvents.Session = had;
        }
    }
}
