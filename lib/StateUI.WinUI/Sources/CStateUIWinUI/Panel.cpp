// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The panel every StateUI layout is: WinUI asks it to measure and arrange, and
// the host answers with the core's arithmetic.
// Design: docs/design/platforms/winui/layout.md#a-layout-is-a-panel

#include "Relay.h"

#include <vector>

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>

using namespace stateui;
using winrt::Windows::Foundation::Size;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    struct StateUIPanel;

    /// What assistive technology reads of a panel: one it can press, as a tap, while its view listens for taps, and
    /// none of what stands in it while it is left out with its children.
    /// Design: docs/design/platforms/winui/input.md#pressed-by-assistive-technology
    struct StateUIPanelPeer : peers::FrameworkElementAutomationPeerT<StateUIPanelPeer, provider::IInvokeProvider> {
        using Base = peers::FrameworkElementAutomationPeerT<StateUIPanelPeer, provider::IInvokeProvider>;

        StateUIPanelPeer(xaml::FrameworkElement const &owner, int64_t view) : Base(owner), view(view) {}

        IInspectable GetPatternCore(peers::PatternInterface const &pattern) {
            if (pattern == peers::PatternInterface::Invoke && hearsTaps(view)) return *this;
            return Base::GetPatternCore(pattern);
        }

        void Invoke() {
            press(view);
        }

        winrt::Windows::Foundation::Collections::IVector<peers::AutomationPeer> GetChildrenCore();

        int64_t view;
    };

    struct StateUIPanel : controls::PanelT<StateUIPanel> {
        explicit StateUIPanel(int64_t view) : view(view) {}

        peers::AutomationPeer OnCreateAutomationPeer() {
            IInspectable self = *this;
            return winrt::make<StateUIPanelPeer>(self.as<xaml::FrameworkElement>(), view);
        }

        Size MeasureOverride(Size available) {
            double size[2] = {0, 0};
            callbacks.measure(view, available.Width, available.Height, size);
            return Size(static_cast<float>(size[0]), static_cast<float>(size[1]));
        }

        Size ArrangeOverride(Size final) {
            callbacks.arrange(view, final.Width, final.Height);
            return final;
        }

        int64_t view;

        /// Whether assistive technology meets none of what stands in the panel.
        bool childrenHidden = false;
    };

    /// The panel a handle or a peer's owner holds, reached through an interface the panel implements itself: the
    /// panel it is made on answers the rest.
    StateUIPanel *panel(xaml::UIElement const &element) {
        return winrt::get_self<StateUIPanel>(element.as<xaml::IFrameworkElementOverrides>());
    }

    winrt::Windows::Foundation::Collections::IVector<peers::AutomationPeer> StateUIPanelPeer::GetChildrenCore() {
        if (panel(Owner())->childrenHidden) return winrt::single_threaded_vector<peers::AutomationPeer>();
        return Base::GetChildrenCore();
    }
}

extern "C" StateUIObjectRef stateui_winui_panel_make(int64_t view) {
    try {
        return detach(winrt::make<StateUIPanel>(view).as<controls::Panel>());
    } catch (winrt::hresult_error const &error) {
        report(error, "making a panel");
        return nullptr;
    }
}

extern "C" void stateui_winui_panel_set_children(
    StateUIObjectRef panel, StateUIObjectRef const *children, int32_t count
) {
    try {
        auto items = borrow<controls::Panel>(panel).Children();
        std::vector<xaml::UIElement> held;
        held.reserve(count);
        for (int32_t index = 0; index < count; ++index) held.push_back(as<xaml::UIElement>(children[index]));
        items.ReplaceAll(held);
    } catch (winrt::hresult_error const &error) {
        report(error, "holding a panel's children");
    }
}

extern "C" void stateui_winui_panel_hide_children(StateUIObjectRef handle, bool hidden) {
    try {
        panel(as<xaml::UIElement>(handle))->childrenHidden = hidden;
    } catch (winrt::hresult_error const &error) {
        report(error, "hiding a panel's children from assistive technology");
    }
}
