// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control's UI Automation pattern, asked of its peer as an automation client
// asks: how a test works a control as the user's assistive technology does.
#pragma once

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>

namespace stateui {
    namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;
    using winrt::Microsoft::UI::Xaml::Automation::Peers::PatternInterface;

    template <typename Provider>
    Provider pattern(xaml::UIElement const &control, PatternInterface which) {
        auto peer = xaml::Automation::Peers::FrameworkElementAutomationPeer::CreatePeerForElement(control);
        return peer.GetPattern(which).as<Provider>();
    }
}
