// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the environment is - the device, the application, the user's locale,
// the battery, the network, the theme and the screen - read in groups for the
// host, and the changes it hears of, posted to the UI thread.
// Design: docs/design/platforms/winui/runtime.md#the-environment

#include "Relay.h"

#include <cstring>
#include <string>

#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Networking.Connectivity.h>
#include <winrt/Windows.Security.ExchangeActiveSyncProvisioning.h>
#include <winrt/Windows.System.Power.h>
#include <winrt/Windows.System.Profile.h>
#include <winrt/Windows.UI.ViewManagement.h>
#include <winrt/Microsoft.UI.Windowing.h>

using namespace stateui;
namespace connectivity = winrt::Windows::Networking::Connectivity;
namespace power = winrt::Windows::System::Power;

namespace {
    /// Facts as the host reads them: each ended by the unit separator.
    struct Facts {
        std::string text;

        Facts &operator<<(std::string const &fact) {
            text += fact;
            text += '\x1f';
            return *this;
        }
        Facts &operator<<(winrt::hstring const &fact) { return *this << winrt::to_string(fact); }
        Facts &operator<<(double fact) { return *this << std::to_string(fact); }
        Facts &operator<<(bool fact) { return *this << std::string(fact ? "1" : "0"); }
    };

    std::string localeInfo(LCTYPE type) {
        wchar_t value[128] = {};
        GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, type, value, 128);
        return winrt::to_string(value);
    }

    void device(Facts &facts) {
        winrt::Windows::Security::ExchangeActiveSyncProvisioning::EasClientDeviceInformation information;
        auto family = winrt::Windows::System::Profile::AnalyticsInfo::VersionInfo().DeviceFamilyVersion();
        auto packed = std::stoull(winrt::to_string(family));
        auto version = std::to_string(packed >> 48) + "." + std::to_string((packed >> 32) & 0xFFFF) + "."
            + std::to_string((packed >> 16) & 0xFFFF) + "." + std::to_string(packed & 0xFFFF);
        auto product = winrt::to_string(information.SystemProductName());
        facts << product << information.SystemManufacturer() << information.FriendlyName() << version
              << (product.find("Virtual") != std::string::npos);
    }

    void application(Facts &facts) {
        wchar_t path[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        std::wstring name(path);
        name = name.substr(name.find_last_of(L"\\/") + 1);
        name = name.substr(0, name.find_last_of(L'.'));
        facts << winrt::to_string(name) << std::string() << std::string() << std::string();
    }

    void locale(Facts &facts) {
        wchar_t name[LOCALE_NAME_MAX_LENGTH] = {};
        GetUserDefaultLocaleName(name, LOCALE_NAME_MAX_LENGTH);
        auto full = winrt::to_string(name);
        auto dash = full.find('-');
        auto firstDay = std::stoi(localeInfo(LOCALE_IFIRSTDAYOFWEEK));
        facts << full.substr(0, dash) << (dash == std::string::npos ? std::string() : full.substr(dash + 1)) << full
              << winrt::Windows::Globalization::Calendar().GetTimeZone()
              << (localeInfo(LOCALE_STIMEFORMAT).find('H') != std::string::npos)
              << static_cast<double>((firstDay + 1) % 7) << (localeInfo(LOCALE_IMEASURE) == "0")
              << (localeInfo(LOCALE_IREADINGLAYOUT) == "1");
    }

    void battery(Facts &facts) {
        SYSTEM_POWER_STATUS status{};
        GetSystemPowerStatus(&status);
        bool present = status.BatteryFlag != 128 && status.BatteryFlag != 255;
        double level = status.BatteryLifePercent <= 100 ? status.BatteryLifePercent / 100.0 : 1;
        facts << present << level << ((status.BatteryFlag & 8) != 0) << (status.ACLineStatus == 1)
              << (status.SystemStatusFlag == 1);
    }

    void network(Facts &facts) {
        auto profile = connectivity::NetworkInformation::GetInternetConnectionProfile();
        if (!profile) {
            facts << 1.0 << 0.0;
            return;
        }
        double access = 0;
        switch (profile.GetNetworkConnectivityLevel()) {
        case connectivity::NetworkConnectivityLevel::None: access = 1; break;
        case connectivity::NetworkConnectivityLevel::LocalAccess: access = 2; break;
        case connectivity::NetworkConnectivityLevel::ConstrainedInternetAccess: access = 3; break;
        case connectivity::NetworkConnectivityLevel::InternetAccess: access = 4; break;
        }
        int kinds = 0;
        if (profile.IsWwanConnectionProfile()) kinds |= 2;
        if (profile.IsWlanConnectionProfile()) kinds |= 8;
        if (auto adapter = profile.NetworkAdapter(); adapter && adapter.IanaInterfaceType() == 6) kinds |= 4;
        facts << access << static_cast<double>(kinds);
    }

    void theme(Facts &facts) {
        winrt::Windows::UI::ViewManagement::UISettings settings;
        auto background = settings.GetColorValue(winrt::Windows::UI::ViewManagement::UIColorType::Background);
        facts << (0.299 * background.R + 0.587 * background.G + 0.114 * background.B < 128);
    }

    void display(Facts &facts, StateUIObjectRef handle) {
        double width = GetSystemMetrics(SM_CXSCREEN), height = GetSystemMetrics(SM_CYSCREEN);
        if (handle) {
            auto area = winrt::Microsoft::UI::Windowing::DisplayArea::GetFromWindowId(
                borrow<xaml::Window>(handle).AppWindow().Id(), winrt::Microsoft::UI::Windowing::DisplayAreaFallback::Primary);
            width = area.OuterBounds().Width;
            height = area.OuterBounds().Height;
        }
        // The system's scale: the main screen's, which a window on another screen may not share.
        double density = GetDpiForSystem() / 96.0;
        DEVMODEW mode{};
        mode.dmSize = sizeof mode;
        EnumDisplaySettingsW(nullptr, ENUM_CURRENT_SETTINGS, &mode);
        facts << width << height << density << static_cast<double>(mode.dmDisplayFrequency);
    }

    void changed() {
        post([] { callbacks.environmentChanged(); });
    }
}

extern "C" int32_t stateui_winui_facts(StateUIFacts kind, StateUIObjectRef window, char *utf8, int32_t capacity) {
    try {
        Facts facts;
        switch (kind) {
        case StateUIFactsDevice: device(facts); break;
        case StateUIFactsApplication: application(facts); break;
        case StateUIFactsLocale: locale(facts); break;
        case StateUIFactsBattery: battery(facts); break;
        case StateUIFactsConnectivity: network(facts); break;
        case StateUIFactsTheme: theme(facts); break;
        case StateUIFactsDisplay: display(facts, window); break;
        }
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(facts.text.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, facts.text.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(facts.text.size());
    } catch (...) {
        report("reading the environment");
        return 0;
    }
}

extern "C" void stateui_winui_watch_environment(void) {
    static bool watching = false;
    if (watching) return;
    watching = true;
    try {
        // Kept for the process: an event handler lives as long as the object that raises it.
        static winrt::Windows::UI::ViewManagement::UISettings settings;
        settings.ColorValuesChanged([](auto const &, auto const &) { changed(); });
        power::PowerManager::BatteryStatusChanged([](auto const &, auto const &) { changed(); });
        power::PowerManager::PowerSupplyStatusChanged([](auto const &, auto const &) { changed(); });
        power::PowerManager::RemainingChargePercentChanged([](auto const &, auto const &) { changed(); });
        power::PowerManager::EnergySaverStatusChanged([](auto const &, auto const &) { changed(); });
        connectivity::NetworkInformation::NetworkStatusChanged([](auto const &) { changed(); });
    } catch (...) {
        report("watching the environment");
    }
}
