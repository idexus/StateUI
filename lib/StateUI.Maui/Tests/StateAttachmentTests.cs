// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class StateAttachmentTests
{
    /// <summary>
    /// One attachment per door: every kind a state's value can go through is a
    /// type of its own, and the kind IS the type - no attachment carries a kind
    /// to be asked instead, so a path that needs a walked value, a text or a
    /// plain value says so in the type it takes.
    /// </summary>
    [Fact]
    public void EveryDoorIsAnAttachmentOfItsOwn()
    {
        Type attachment = typeof(StateAttachment);
        List<string> missing = [];

        foreach (HostStateKind kind in Enum.GetValues<HostStateKind>())
        {
            Type? type = attachment.Assembly.GetType($"StateUI.Maui.Rendering.{kind}Attachment");

            if (type is null || !type.IsSealed || type.BaseType != attachment)
            {
                missing.Add(kind.ToString());
            }
        }

        Assert.True(missing.Count == 0, "a door with no attachment of its own: " + string.Join(", ", missing));
        Assert.True(attachment.IsAbstract, "an attachment is always one of the doors");
        Assert.Null(attachment.GetProperty(
            "Kind", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic));
    }
}
