// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the standard environment tells the Swift providers, and when.

using Microsoft.Maui.Devices;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class StateUIEnvironmentTests
{
    /// <summary>
    /// Every value the display carries is news worth a push: a turn to the
    /// other landscape keeps the orientation and the size, and a new refresh
    /// rate keeps everything else, yet a view reading the display reads each.
    /// </summary>
    [Fact]
    public void EveryValueTheDisplayCarriesIsNews()
    {
        var left = new DisplayInfo(2400, 1080, 3, DisplayOrientation.Landscape, DisplayRotation.Rotation90, 60);

        StateUIEnvironment.Changed(left);
        Assert.False(StateUIEnvironment.Changed(left), "the same display again is no news");

        var right = new DisplayInfo(2400, 1080, 3, DisplayOrientation.Landscape, DisplayRotation.Rotation270, 60);
        Assert.True(StateUIEnvironment.Changed(right), "a turn to the other landscape");

        var faster = new DisplayInfo(2400, 1080, 3, DisplayOrientation.Landscape, DisplayRotation.Rotation270, 120);
        Assert.True(StateUIEnvironment.Changed(faster), "a new refresh rate");

        var wider = new DisplayInfo(2560, 1080, 3, DisplayOrientation.Landscape, DisplayRotation.Rotation270, 120);
        Assert.True(StateUIEnvironment.Changed(wider), "a new size");
    }
}
