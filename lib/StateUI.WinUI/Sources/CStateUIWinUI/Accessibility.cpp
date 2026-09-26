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
#include <unordered_map>
#include <utility>
#include <vector>

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

    /// A control left out with its parts - what its own template draws - each part with the view it had, so it
    /// comes back as it was; and its loading heard, which draws parts anew.
    struct LeftOut {
        winrt::weak_ref<xaml::FrameworkElement> control;
        std::vector<std::pair<winrt::weak_ref<xaml::UIElement>, IInspectable>> parts;
        winrt::event_token loaded{};
    };

    std::unordered_map<void *, LeftOut> leftOut;

    /// Leaves out every part of `element` not left out yet.
    void leaveOutParts(xaml::DependencyObject const &element, LeftOut &record) {
        auto count = xaml::Media::VisualTreeHelper::GetChildrenCount(element);
        for (int32_t index = 0; index < count; ++index) {
            auto child = xaml::Media::VisualTreeHelper::GetChild(element, index);
            if (auto part = child.try_as<xaml::UIElement>()) {
                auto known = std::any_of(record.parts.begin(), record.parts.end(),
                                         [&](auto const &each) { return each.first.get() == part; });
                if (!known) {
                    record.parts.emplace_back(winrt::make_weak(part), part.ReadLocalValue(Properties::AccessibilityViewProperty()));
                    Properties::SetAccessibilityView(part, peers::AccessibilityView::Raw);
                }
            }
            leaveOutParts(child, record);
        }
    }

    /// Brings back the parts of the control `key` names, each with the view it had.
    void bringBackParts(void *key) {
        auto found = leftOut.find(key);
        if (found == leftOut.end()) return;
        if (auto control = found->second.control.get()) control.Loaded(found->second.loaded);
        for (auto const &[weak, before] : found->second.parts) {
            auto part = weak.get();
            if (!part) continue;
            if (before == xaml::DependencyProperty::UnsetValue()) part.ClearValue(Properties::AccessibilityViewProperty());
            else part.SetValue(Properties::AccessibilityViewProperty(), before);
        }
        leftOut.erase(found);
    }

    /// Forgets the controls gone since.
    void forgetGone() {
        for (auto each = leftOut.begin(); each != leftOut.end();) {
            each = each->second.control.get() ? std::next(each) : leftOut.erase(each);
        }
    }

    /// How many of what stands in `peer` assistive technology meets, to the deepest part.
    int32_t metWithin(peers::AutomationPeer const &peer) {
        int32_t count = 0;
        auto children = peer.GetChildren();
        if (!children) return 0;
        for (auto const &child : children) {
            if (child.IsControlElement() || child.IsContentElement()) ++count;
            count += metWithin(child);
        }
        return count;
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

        // A control left out with its children leaves out its template's parts, now and as it draws them anew.
        auto key = winrt::get_abi(element);
        forgetGone();
        if (presence != 3) return bringBackParts(key);
        auto &record = leftOut[key];
        if (!record.control.get()) {
            auto control = element.as<xaml::FrameworkElement>();
            record.control = winrt::make_weak(control);
            record.loaded = control.Loaded([key](IInspectable const &, xaml::RoutedEventArgs const &) {
                auto found = leftOut.find(key);
                if (found == leftOut.end()) return;
                if (auto control = found->second.control.get()) leaveOutParts(control, found->second);
            });
        }
        leaveOutParts(element, record);
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
            read[0] = static_cast<int32_t>(met.GetHeadingLevel());
            read[1] = met.IsControlElement();
            read[2] = met.IsContentElement();
            read[3] = metWithin(met);
        }
        std::memcpy(facts, read, sizeof read);
    } catch (winrt::hresult_error const &error) {
        report(error, "reading what assistive technology meets");
    }
}
