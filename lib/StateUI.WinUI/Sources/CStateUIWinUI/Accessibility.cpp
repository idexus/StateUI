// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What assistive technology meets of an element: its automation id, name,
// help text and heading level, and whether it meets the element at all -
// WinUI's AutomationProperties, each cleared back to the control's own where
// the element says nothing.
// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets

#include "Relay.h"

#include <algorithm>
#include <cstring>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>

using namespace stateui;
namespace automation = winrt::Microsoft::UI::Xaml::Automation;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;

namespace {
    using Properties = automation::AutomationProperties;

    /// Writes `utf8` to `property`, or clears it for null.
    void words(xaml::UIElement const &element, xaml::DependencyProperty const &property, char const *utf8) {
        if (utf8) element.SetValue(property, winrt::box_value(text(utf8)));
        else element.ClearValue(property);
    }

    /// The peer assistive technology meets for `handle`; null for an element WinUI gives none.
    peers::AutomationPeer peer(StateUIObjectRef handle) {
        return peers::FrameworkElementAutomationPeer::CreatePeerForElement(as<xaml::UIElement>(handle));
    }
}

extern "C" void stateui_winui_set_accessibility(
    StateUIObjectRef handle, char const *identifier, char const *label, char const *hint, int32_t heading,
    int32_t presence
) {
    try {
        auto element = as<xaml::UIElement>(handle);
        words(element, Properties::AutomationIdProperty(), identifier);
        words(element, Properties::NameProperty(), label);
        words(element, Properties::HelpTextProperty(), hint);
        if (heading > 0) Properties::SetHeadingLevel(element, static_cast<peers::AutomationHeadingLevel>(std::min(heading, 9)));
        else element.ClearValue(Properties::HeadingLevelProperty());
        if (presence == 0) element.ClearValue(Properties::AccessibilityViewProperty());
        else Properties::SetAccessibilityView(element, presence == 1 ? peers::AccessibilityView::Content : peers::AccessibilityView::Raw);
    } catch (winrt::hresult_error const &error) {
        report(error, "telling assistive technology of an element");
    }
}

extern "C" int32_t stateui_winui_automation_words(StateUIObjectRef handle, int32_t what, char *utf8, int32_t capacity) {
    try {
        auto met = peer(handle);
        if (!met) return 0;
        auto read = winrt::to_string(what == 0 ? met.GetName() : what == 1 ? met.GetHelpText() : met.GetAutomationId());
        if (utf8 && capacity > 0) {
            auto count = std::min(static_cast<int32_t>(read.size()), capacity - 1);
            std::memcpy(utf8, read.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(read.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading what assistive technology meets");
        return 0;
    }
}

extern "C" void stateui_winui_automation_facts(StateUIObjectRef handle, int32_t *facts) {
    try {
        int32_t read[] = {0, 0, 0, 0};
        if (auto met = peer(handle)) {
            auto children = met.GetChildren();
            read[0] = static_cast<int32_t>(met.GetHeadingLevel());
            read[1] = met.IsControlElement();
            read[2] = met.IsContentElement();
            read[3] = children ? static_cast<int32_t>(children.Size()) : 0;
        }
        std::memcpy(facts, read, sizeof read);
    } catch (winrt::hresult_error const &error) {
        report(error, "reading what assistive technology meets");
    }
}
