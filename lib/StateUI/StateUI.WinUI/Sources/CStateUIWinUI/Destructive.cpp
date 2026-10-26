// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An entry whose choice destroys something - a menu's item, a bar's action - draws its words in the theme's
// critical color, named in its own resources for the light theme and the dark.
// Design: docs/design/platforms/winui/pages.md#a-destructive-entry

#include "Relay.h"

using namespace stateui;

void stateui::markDestructive(xaml::FrameworkElement const &entry, std::vector<std::wstring> const &names) {
    std::vector<std::pair<std::wstring, std::wstring>> brushes;
    for (auto const &name : names) brushes.emplace_back(name, L"{ThemeResource SystemFillColorCritical}");
    nameThemedBrushes(entry, brushes);
}

bool stateui::isDestructive(xaml::FrameworkElement const &entry, wchar_t const *name) {
    return namesThemedBrush(entry, name);
}
