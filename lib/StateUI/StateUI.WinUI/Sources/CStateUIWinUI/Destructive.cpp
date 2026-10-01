// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An entry whose choice destroys something - a menu's item, a bar's action -
// says so in the theme's critical colour: its words' brushes, named in its
// own resources for the light theme and the dark, each drawn in the colour
// that theme gives `SystemFillColorCritical`.
// Design: docs/design/platforms/winui/pages.md#a-destructive-entry

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Markup.h>

using namespace stateui;

void stateui::markDestructive(xaml::FrameworkElement const &entry, std::vector<std::wstring> const &names) {
    std::wstring brushes;
    for (auto const &name : names)
        brushes += L"<SolidColorBrush x:Key=\"" + name + L"\" Color=\"{ThemeResource SystemFillColorCritical}\"/>";
    std::wstring written = L"<ResourceDictionary"
                           L" xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
                           L" xmlns:x=\"http://schemas.microsoft.com/winfx/2006/xaml\">"
                           L"<ResourceDictionary.ThemeDictionaries>";
    for (auto theme : {L"Light", L"Dark"})
        written += std::wstring(L"<ResourceDictionary x:Key=\"") + theme + L"\">" + brushes + L"</ResourceDictionary>";
    written += L"</ResourceDictionary.ThemeDictionaries></ResourceDictionary>";
    auto themed = xaml::Markup::XamlReader::Load(written).as<xaml::ResourceDictionary>();
    entry.Resources().MergedDictionaries().Append(themed);
}

bool stateui::isDestructive(xaml::FrameworkElement const &entry, wchar_t const *name) {
    for (auto const &merged : entry.Resources().MergedDictionaries())
        for (auto const &theme : merged.ThemeDictionaries())
            if (auto dictionary = theme.Value().try_as<xaml::ResourceDictionary>();
                dictionary && ownBrush(dictionary, name))
                return true;
    return false;
}
