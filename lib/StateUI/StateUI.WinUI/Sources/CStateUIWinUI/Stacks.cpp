// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What stands in a stack beside its controls: a spacer, an empty panel which
// asks for no room, and a divider, a panel holding a line in the theme's
// divider stroke, one pixel thick both ways - the stack stretches it across.
// Assistive technology meets each as a layout's panel is met, a divider as a
// separator.
// Design: docs/design/host/layout.md#a-divider-in-a-stack

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    struct StateUIStackPartPeer : peers::FrameworkElementAutomationPeerT<StateUIStackPartPeer> {
        StateUIStackPartPeer(xaml::FrameworkElement const &owner, bool line)
            : FrameworkElementAutomationPeerT(owner), line(line) {}

        peers::AutomationControlType GetAutomationControlTypeCore() {
            return line ? peers::AutomationControlType::Separator : peers::AutomationControlType::Custom;
        }

        bool line;
    };

    struct StateUIStackPart : controls::GridT<StateUIStackPart> {
        explicit StateUIStackPart(bool line) : line(line) {}

        peers::AutomationPeer OnCreateAutomationPeer() {
            IInspectable self = *this;
            return winrt::make<StateUIStackPartPeer>(self.as<xaml::FrameworkElement>(), line);
        }

        bool line;
    };
}

extern "C" StateUIObjectRef stateui_winui_spacer_make(void) {
    try {
        return detach(winrt::make<StateUIStackPart>(false).as<controls::Grid>());
    } catch (...) {
        report("making a spacer");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_divider_make(void) {
    try {
        auto divider = winrt::make<StateUIStackPart>(true).as<controls::Grid>();
        divider.Children().Append(xaml::Markup::XamlReader::Load(
            L"<Rectangle xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
            L" MinWidth=\"1\" MinHeight=\"1\" Fill=\"{ThemeResource DividerStrokeColorDefaultBrush}\"/>")
            .as<shapes::Rectangle>());
        return detach(divider);
    } catch (...) {
        report("making a divider");
        return nullptr;
    }
}
