// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the application asks of the platform: the time of day, a zone's
// distance from UTC, a word to a screen reader, the keyboard's focus, and the
// store the application's kept values stand in.
// Design: docs/design/platforms/winui/runtime.md#acts

#include "Relay.h"

#include <icu.h>
#include <shlobj.h>

#include <algorithm>
#include <cstring>
#include <string>

#include <winrt/Windows.Globalization.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>

using namespace stateui;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace input = winrt::Microsoft::UI::Xaml::Input;

namespace {
    /// The folder the kept values stand in; empty for the application's own under the user's local data.
    std::wstring storeFolder;

    std::wstring storePath() {
        auto folder = storeFolder;
        if (folder.empty()) {
            PWSTR local = nullptr;
            if (SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local) == S_OK) folder = local;
            CoTaskMemFree(local);
            wchar_t executable[MAX_PATH] = {};
            GetModuleFileNameW(nullptr, executable, MAX_PATH);
            std::wstring name(executable);
            name = name.substr(name.find_last_of(L"\\/") + 1);
            folder += L"\\" + name.substr(0, name.find_last_of(L'.'));
        }
        CreateDirectoryW(folder.c_str(), nullptr);
        return folder + L"\\kept values.txt";
    }

    /// Copies `text` into the caller's buffer as far as it reaches; answers the whole length.
    int32_t hand(std::string const &text, char *utf8, int32_t capacity) {
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(text.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, text.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(text.size());
    }

    /// The element holding the keyboard's focus in `element`'s window; null for none.
    xaml::DependencyObject focused(xaml::UIElement const &element) {
        auto root = element.XamlRoot();
        return root ? input::FocusManager::GetFocusedElement(root).try_as<xaml::DependencyObject>() : nullptr;
    }

    /// Whether `inner` is `outer` or stands inside it.
    bool within(xaml::DependencyObject inner, xaml::DependencyObject const &outer) {
        for (; inner; inner = xaml::Media::VisualTreeHelper::GetParent(inner))
            if (inner == outer) return true;
        return false;
    }

    /// Takes the focus off whatever holds it in `element`'s window: its content takes it for a moment, as no
    /// control; whether anything held it.
    bool letGoOfFocus(xaml::UIElement const &element) {
        auto root = element.XamlRoot();
        auto content = root ? root.Content() : nullptr;
        if (!content || !focused(element)) return false;
        auto stop = content.IsTabStop();
        content.IsTabStop(true);
        content.Focus(xaml::FocusState::Programmatic);
        content.IsTabStop(stop);
        return true;
    }
}

extern "C" void stateui_winui_clock(int32_t *time) {
    SYSTEMTIME now;
    GetLocalTime(&now);
    time[0] = now.wHour;
    time[1] = now.wMinute;
    time[2] = now.wSecond;
    time[3] = now.wMilliseconds;
}

extern "C" int32_t stateui_winui_time_zone(char *utf8, int32_t capacity) {
    try {
        return hand(winrt::to_string(winrt::Windows::Globalization::Calendar().GetTimeZone()), utf8, capacity);
    } catch (winrt::hresult_error const &error) {
        report(error, "reading the time zone");
        return hand({}, utf8, capacity);
    }
}

extern "C" bool stateui_winui_utc_offset(char const *zone, int32_t year, int32_t month, int32_t day, int32_t *minutes) {
    auto name = zone ? winrt::to_hstring(std::string_view(zone)) : winrt::hstring();
    UErrorCode status = U_ZERO_ERROR;
    if (zone) {
        UBool system = false;
        UChar canonical[128];
        ucal_getCanonicalTimeZoneID(reinterpret_cast<UChar const *>(name.c_str()), static_cast<int32_t>(name.size()),
                                    canonical, 128, &system, &status);
        if (U_FAILURE(status) || !system) return false;
    }
    auto calendar = ucal_open(zone ? reinterpret_cast<UChar const *>(name.c_str()) : nullptr,
                              zone ? static_cast<int32_t>(name.size()) : 0, nullptr, UCAL_GREGORIAN, &status);
    if (U_FAILURE(status)) return false;
    // The day's noon: a day's offset is its own, whatever hour its summer time begins or ends at.
    if (year > 0) ucal_setDateTime(calendar, year, month - 1, day, 12, 0, 0, &status);
    auto offset = ucal_get(calendar, UCAL_ZONE_OFFSET, &status) + ucal_get(calendar, UCAL_DST_OFFSET, &status);
    ucal_close(calendar);
    if (U_FAILURE(status)) return false;
    *minutes = offset / 60000;
    return true;
}

extern "C" void stateui_winui_announce(StateUIObjectRef handle, char const *utf8) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto peer = peers::FrameworkElementAutomationPeer::FromElement(element);
        if (!peer) peer = peers::FrameworkElementAutomationPeer::CreatePeerForElement(element);
        if (peer) {
            peer.RaiseNotificationEvent(peers::AutomationNotificationKind::Other,
                                        peers::AutomationNotificationProcessing::ImportantMostRecent,
                                        text(utf8), L"StateUI");
            announced(utf8 ? utf8 : "");
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "announcing");
    }
}

extern "C" bool stateui_winui_focus(StateUIObjectRef handle, bool focus) {
    try {
        auto element = as<xaml::UIElement>(handle);
        if (!focus) return within(focused(element), element) && letGoOfFocus(element);
        auto target = element.try_as<controls::Control>()
            ? element.as<xaml::DependencyObject>() : input::FocusManager::FindFirstFocusableElement(element);
        auto takes = target ? target.try_as<xaml::UIElement>() : nullptr;
        return takes && takes.Focus(xaml::FocusState::Programmatic);
    } catch (winrt::hresult_error const &error) {
        report(error, "moving the keyboard's focus");
        return false;
    }
}

bool stateui::holdsFocus(xaml::UIElement const &element) {
    return within(focused(element), element);
}

extern "C" bool stateui_winui_focused(StateUIObjectRef handle) {
    try {
        return holdsFocus(as<xaml::UIElement>(handle));
    } catch (winrt::hresult_error const &error) {
        report(error, "reading the keyboard's focus");
        return false;
    }
}

extern "C" bool stateui_winui_hide_keyboard(StateUIObjectRef handle) {
    try {
        auto held = focused(as<xaml::UIElement>(handle));
        bool typing = held && (held.try_as<controls::TextBox>() || held.try_as<controls::PasswordBox>());
        return typing && letGoOfFocus(as<xaml::UIElement>(handle));
    } catch (winrt::hresult_error const &error) {
        report(error, "taking the keyboard down");
        return false;
    }
}

extern "C" void stateui_winui_set_store(char const *utf8) {
    storeFolder = winrt::to_hstring(std::string_view(utf8 ? utf8 : "")).c_str();
}

extern "C" int32_t stateui_winui_stored(char *utf8, int32_t capacity) {
    std::string text;
    FILE *file = nullptr;
    if (_wfopen_s(&file, storePath().c_str(), L"rb") == 0 && file) {
        char buffer[4096];
        for (size_t read; (read = std::fread(buffer, 1, sizeof buffer, file)) > 0;) text.append(buffer, read);
        std::fclose(file);
    }
    return hand(text, utf8, capacity);
}

extern "C" bool stateui_winui_store(char const *utf8) {
    auto path = storePath();
    auto writing = path + L".writing";
    FILE *file = nullptr;
    if (_wfopen_s(&file, writing.c_str(), L"wb") != 0 || !file) return false;
    auto length = std::strlen(utf8 ? utf8 : "");
    bool written = std::fwrite(utf8 ? utf8 : "", 1, length, file) == length;
    written = std::fclose(file) == 0 && written;
    // The whole store is written aside and then takes the old one's place, so a failed write keeps the old.
    return written && MoveFileExW(writing.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING);
}
