// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What stands in a stack beside its controls: a separator, a panel holding a
// line in the theme's divider stroke, one pixel thick both ways - the stack
// stretches it across. Assistive technology meets it as a separator.
// Design: docs/design/host/layout.md#a-separator-in-a-stack

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    struct StateUIStackPartPeer : peers::FrameworkElementAutomationPeerT<StateUIStackPartPeer> {
        explicit StateUIStackPartPeer(xaml::FrameworkElement const &owner) : FrameworkElementAutomationPeerT(owner) {}

        peers::AutomationControlType GetAutomationControlTypeCore() {
            return peers::AutomationControlType::Separator;
        }
    };

    struct StateUIStackPart : controls::GridT<StateUIStackPart> {
        peers::AutomationPeer OnCreateAutomationPeer() {
            IInspectable self = *this;
            return winrt::make<StateUIStackPartPeer>(self.as<xaml::FrameworkElement>());
        }
    };
}

extern "C" StateUIObjectRef stateui_winui_separator_make(void) {
    try {
        auto separator = winrt::make<StateUIStackPart>().as<controls::Grid>();
        separator.Children().Append(xaml::Markup::XamlReader::Load(
            L"<Rectangle xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
            L" MinWidth=\"1\" MinHeight=\"1\" Fill=\"{ThemeResource DividerStrokeColorDefaultBrush}\"/>")
            .as<shapes::Rectangle>());
        return detach(separator);
    } catch (...) {
        report("making a separator");
        return nullptr;
    }
}
