// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Brushes an element names in its own resources for the light theme and the
// dark, each in a color the theme gives: the names a control's template reads,
// as WinUI's lightweight styling offers them.
// Design: docs/design/platforms/winui/pages.md#a-bars-buttons

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Markup.h>

using namespace stateui;

void stateui::nameThemedBrushes(
    xaml::FrameworkElement const &entry, std::vector<std::pair<std::wstring, std::wstring>> const &brushes
) {
    std::wstring named;
    for (auto const &[name, color] : brushes)
        named += L"<SolidColorBrush x:Key=\"" + name + L"\" Color=\"" + color + L"\"/>";
    std::wstring written = L"<ResourceDictionary"
                           L" xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
                           L" xmlns:x=\"http://schemas.microsoft.com/winfx/2006/xaml\">"
                           L"<ResourceDictionary.ThemeDictionaries>";
    for (auto theme : {L"Light", L"Dark"})
        written += std::wstring(L"<ResourceDictionary x:Key=\"") + theme + L"\">" + named + L"</ResourceDictionary>";
    written += L"</ResourceDictionary.ThemeDictionaries></ResourceDictionary>";
    auto themed = xaml::Markup::XamlReader::Load(written).as<xaml::ResourceDictionary>();
    entry.Resources().MergedDictionaries().Append(themed);
}

bool stateui::namesThemedBrush(xaml::FrameworkElement const &entry, wchar_t const *name) {
    for (auto const &merged : entry.Resources().MergedDictionaries())
        for (auto const &theme : merged.ThemeDictionaries())
            if (auto dictionary = theme.Value().try_as<xaml::ResourceDictionary>();
                dictionary && ownBrush(dictionary, name))
                return true;
    return false;
}
