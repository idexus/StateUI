// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Does every member the host REPORTS survive the trip onto our numbering?
//
// A member of a closed vocabulary crosses this wire as THIS REPOSITORY's number
// for it, in both directions, and a report the host raises is translated onto
// the mirrors in Protocol/SwiftWireEnums.cs by a switch naming the MAUI member
// literally - StateUIEnvironment.Member and StateUIRenderer.Member. What
// MAUI numbers its own members with never reaches the wire, which is what keeps
// a MAUI release free to renumber them; WireEnumTests holds the mirrors against
// the Swift declarations, member for member and number for number.
//
// A switch is exactly the shape that loses a member quietly, and nothing else
// catches it: the compiler is happy with a default arm swallowing a member MAUI
// declares, and just as happy with a mirror member nothing over here can
// produce. So both halves of being TOTAL are read here - every MAUI member
// reaches a defined member of the mirror, and every member of the mirror is
// reached by some MAUI member - out of Enum.GetValues rather than a
// hand-written list, which would go stale in the same commit that broke the
// translation.
//
// The exemptions are named one by one with the reason, and there are only two
// kinds: a mirror member that says ABSENCE, which no MAUI member means, and a
// bit set's composite, which is not a member anything reports.

using Microsoft.Maui.Devices;
using Microsoft.Maui.Networking;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class MauiNumbersTests
{
    [Fact]
    public void EveryMauiMemberTheHostReportsReachesOneOfOurs()
    {
        List<string> lost =
        [
            .. Untranslated<BatteryState, SwiftBatteryState>(StateUIEnvironment.Member),
            .. Untranslated<BatteryPowerSource, SwiftBatteryPowerSource>(StateUIEnvironment.Member),
            .. Untranslated<EnergySaverStatus, SwiftEnergySaverStatus>(StateUIEnvironment.Member),
            .. Untranslated<NetworkAccess, SwiftNetworkAccess>(StateUIEnvironment.Member),
            .. Untranslated<ConnectionProfile, SwiftConnectionProfile>(StateUIEnvironment.Member),
            .. Untranslated<DisplayOrientation, SwiftDisplayOrientation>(StateUIEnvironment.Member),
            .. Untranslated<DisplayRotation, SwiftDisplayRotation>(StateUIEnvironment.Member),
            .. Untranslated<Microsoft.Maui.ApplicationModel.AppTheme, SwiftAppTheme>(
                StateUIEnvironment.Member),
            .. Untranslated<DeviceType, SwiftDeviceType>(StateUIEnvironment.Member),
            .. Untranslated<DayOfWeek, SwiftWeekday>(StateUIEnvironment.Member),
            .. Untranslated<GestureStatus, SwiftGestureStatus>(StateUIRenderer.Member),
            .. Untranslated<SwipeDirection, SwiftSwipeDirection>(StateUIRenderer.Member),
            .. Untranslated<WebNavigationEvent, SwiftWebNavigationEvent>(StateUIRenderer.Member),
            .. Untranslated<WebNavigationResult, SwiftWebNavigationResult>(StateUIRenderer.Member),
        ];

        Assert.Equal([], lost);
    }

    [Fact]
    public void EveryMemberOfAMirrorIsOneSomeMauiMemberReaches()
    {
        List<string> orphaned =
        [
            .. Unreachable<BatteryState, SwiftBatteryState>(StateUIEnvironment.Member),
            .. Unreachable<BatteryPowerSource, SwiftBatteryPowerSource>(StateUIEnvironment.Member),
            .. Unreachable<EnergySaverStatus, SwiftEnergySaverStatus>(StateUIEnvironment.Member),
            .. Unreachable<NetworkAccess, SwiftNetworkAccess>(StateUIEnvironment.Member),
            .. Unreachable<ConnectionProfile, SwiftConnectionProfile>(StateUIEnvironment.Member),
            .. Unreachable<DisplayOrientation, SwiftDisplayOrientation>(StateUIEnvironment.Member),
            .. Unreachable<DisplayRotation, SwiftDisplayRotation>(StateUIEnvironment.Member),
            .. Unreachable<Microsoft.Maui.ApplicationModel.AppTheme, SwiftAppTheme>(
                StateUIEnvironment.Member),
            .. Unreachable<DeviceType, SwiftDeviceType>(StateUIEnvironment.Member),
            .. Unreachable<DayOfWeek, SwiftWeekday>(StateUIEnvironment.Member),
            .. Unreachable<GestureStatus, SwiftGestureStatus>(StateUIRenderer.Member),

            // `All` is the four bits together - a set an author writes to say
            // which ways a view LISTENS, never a direction a swipe went. One
            // recognizer per direction is what makes a report a single bit.
            .. Unreachable<SwipeDirection, SwiftSwipeDirection>(
                StateUIRenderer.Member, SwiftSwipeDirection.All),

            // MAUI names no "unknown" reason and no "unknown" outcome. Ours
            // exist because a report has to be readable even when the platform
            // says something neither side has a name for - Windows sends a
            // navigation for a view's first source before its browser exists -
            // so they are what the default arm answers and nothing MAUI has
            // reaches them.
            .. Unreachable<WebNavigationEvent, SwiftWebNavigationEvent>(
                StateUIRenderer.Member, SwiftWebNavigationEvent.Unknown),
            .. Unreachable<WebNavigationResult, SwiftWebNavigationResult>(
                StateUIRenderer.Member, SwiftWebNavigationResult.Unknown),
        ];

        Assert.Equal([], orphaned);
    }

    /// <summary>
    /// The scan finds what it is supposed to find. Both facts above pass
    /// trivially on an empty enumeration, so a vocabulary that somehow read as
    /// having no members would otherwise be a green test.
    /// </summary>
    [Fact]
    public void TheVocabulariesAreActuallyBeingRead()
    {
        Assert.Equal(6, Enum.GetValues<SwiftBatteryState>().Length);
        Assert.Equal(7, Enum.GetValues<DayOfWeek>().Length);
        Assert.Equal(4, Enum.GetValues<GestureStatus>().Length);
        Assert.Equal(5, Enum.GetValues<SwiftWebNavigationResult>().Length);
    }

    /// <summary>
    /// Every MAUI member that translates to a number no mirror member has -
    /// which is a report the Swift side cannot read, and the exact thing a
    /// default arm hides.
    /// </summary>
    private static List<string> Untranslated<TMaui, TMine>(Func<TMaui, TMine> translate)
        where TMaui : struct, Enum
        where TMine : struct, Enum
    {
        return
        [
            .. Enum.GetValues<TMaui>()
                .Where(member => !Enum.IsDefined(translate(member)))
                .Select(member =>
                    $"{typeof(TMaui).Name}.{member} translates to {Convert.ToInt32(translate(member))}, "
                    + $"which is no member of {typeof(TMine).Name}"),
        ];
    }

    /// <summary>
    /// Every mirror member no MAUI member translates to - a number nothing can
    /// ever send, and a case the Swift side answers for anyway.
    /// </summary>
    /// <param name="translate">The switch under test.</param>
    /// <param name="exempt">
    /// The members that are deliberately unreachable, each named at the call
    /// site with its reason.
    /// </param>
    private static List<string> Unreachable<TMaui, TMine>(
        Func<TMaui, TMine> translate,
        params TMine[] exempt)
        where TMaui : struct, Enum
        where TMine : struct, Enum
    {
        HashSet<TMine> reached = [.. Enum.GetValues<TMaui>().Select(translate), .. exempt];

        return
        [
            .. Enum.GetValues<TMine>()
                .Where(mine => !reached.Contains(mine))
                .Select(mine =>
                    $"{typeof(TMine).Name}.{mine} is reached by no member of {typeof(TMaui).Name}"),
        ];
    }
}
