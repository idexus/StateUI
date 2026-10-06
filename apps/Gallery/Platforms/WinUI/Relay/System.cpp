// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: InteropActsSample.WinUI.cpp, InteropEventsSample.WinUI.cpp
// The battery as Windows knows it: the power status every desktop reads, and the notices Windows sends as the
// battery's charge or the power source changes.
// listing: end

#include "Relay.h"

#include <powersetting.h>
#include <powrprof.h>

using namespace gallery;

// listing: InteropEventsSample.WinUI.cpp
namespace {
    /// Windows' names for the battery's charge and for the power source.
    constexpr GUID batteryPercentage = {0xa7ad8041, 0xb45a, 0x4cae, {0x87, 0xa3, 0xee, 0xcb, 0xb4, 0x68, 0xa9, 0xe1}};
    constexpr GUID powerSource = {0x5d3e9a59, 0xe9d5, 0x4b00, {0xa6, 0xbd, 0xff, 0x34, 0xff, 0x51, 0x65, 0x48}};

    // The function the Swift half handed over: each notice is passed on to it, on a thread of Windows' own.
    void (*told)(void) = nullptr;

    ULONG CALLBACK changed(PVOID, ULONG, PVOID) {
        if (told) told();
        return 0;
    }

    DEVICE_NOTIFY_SUBSCRIBE_PARAMETERS subscription{changed, nullptr};
}
// listing: end

// listing: InteropActsSample.WinUI.cpp, InteropEventsSample.WinUI.cpp
// The reading GalleryPower.battery() in the Swift half calls: for the battery act, and after each notice.
extern "C" void gallery_battery(double *level, bool *charging) {
    try {
        *level = 0;
        *charging = false;
        SYSTEM_POWER_STATUS status{};
        // No system battery, or a charge Windows does not know: nothing to say.
        if (!GetSystemPowerStatus(&status) || (status.BatteryFlag & 128) || status.BatteryLifePercent > 100) return;
        *level = status.BatteryLifePercent / 100.0;
        *charging = status.ACLineStatus == 1;
    } catch (...) {
        report("reading the battery");
    }
}
// listing: end

// listing: InteropEventsSample.WinUI.cpp
extern "C" void gallery_battery_watch(void (*changedTold)(void)) {
    try {
        told = changedTold;
        for (auto setting : {&batteryPercentage, &powerSource}) {
            HPOWERNOTIFY handle = nullptr;
            PowerSettingRegisterNotification(setting, DEVICE_NOTIFY_CALLBACK, &subscription, &handle);
        }
    } catch (...) {
        report("watching the battery");
    }
}
// listing: end
