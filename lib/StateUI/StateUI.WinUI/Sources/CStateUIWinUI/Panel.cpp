// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The panel every StateUI layout is: WinUI asks it to measure and arrange, and
// the host answers with the host layer's arithmetic.
// Design: docs/design/platforms/winui/layout.md#a-layout-is-a-panel

#include "Relay.h"
#include <algorithm>

#include <vector>

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>

using namespace stateui;
using winrt::Windows::Foundation::Size;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    struct StateUIPanel;

    /// What assistive technology reads of a panel: one it can press, as a tap, while its view listens for taps; the
    /// kind and the value its element says; and none of what stands in it while it is left out with its children.
    /// Design: docs/design/platforms/winui/input.md#pressed-by-assistive-technology
    struct StateUIPanelPeer
        : peers::FrameworkElementAutomationPeerT<StateUIPanelPeer, provider::IInvokeProvider, provider::IValueProvider> {
        using Base =
            peers::FrameworkElementAutomationPeerT<StateUIPanelPeer, provider::IInvokeProvider, provider::IValueProvider>;

        StateUIPanelPeer(xaml::FrameworkElement const &owner, int64_t view) : Base(owner), view(view) {}

        IInspectable GetPatternCore(peers::PatternInterface const &pattern);
        peers::AutomationControlType GetAutomationControlTypeCore();

        winrt::hstring Value();
        bool IsReadOnly() { return true; }
        void SetValue(winrt::hstring const &) {}

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

        /// The control type its element says it is - -1 for a panel's own - and the value it says.
        int32_t controlType = -1;
        bool valued = false;
        winrt::hstring value;
    };

    /// The panel a handle or a peer's owner holds, reached through an interface the panel implements itself: the
    /// panel it is made on answers the rest.
    StateUIPanel *panel(xaml::UIElement const &element) {
        return winrt::get_self<StateUIPanel>(element.as<xaml::IFrameworkElementOverrides>());
    }

    IInspectable StateUIPanelPeer::GetPatternCore(peers::PatternInterface const &pattern) {
        if (pattern == peers::PatternInterface::Invoke && hearsTaps(view)) return *this;
        if (pattern == peers::PatternInterface::Value && panel(Owner())->valued) return *this;
        return Base::GetPatternCore(pattern);
    }

    /// The control type the panel's element says it is, else a panel's own.
    peers::AutomationControlType StateUIPanelPeer::GetAutomationControlTypeCore() {
        auto said = panel(Owner())->controlType;
        return said < 0 ? Base::GetAutomationControlTypeCore() : static_cast<peers::AutomationControlType>(said);
    }

    winrt::hstring StateUIPanelPeer::Value() {
        return panel(Owner())->value;
    }

    winrt::Windows::Foundation::Collections::IVector<peers::AutomationPeer> StateUIPanelPeer::GetChildrenCore() {
        if (panel(Owner())->childrenHidden) return winrt::single_threaded_vector<peers::AutomationPeer>();
        return Base::GetChildrenCore();
    }
}

extern "C" StateUIObjectRef stateui_winui_panel_make(int64_t view) {
    try {
        return detach(winrt::make<StateUIPanel>(view).as<controls::Panel>());
    } catch (...) {
        report("making a panel");
        return nullptr;
    }
}

extern "C" void stateui_winui_panel_set_children(
    StateUIObjectRef panel, StateUIObjectRef const *children, int32_t count
) {
    try {
        // A child that stays is moved, never taken out, so it keeps the keyboard.
        auto items = borrow<controls::Panel>(panel).Children();
        std::vector<xaml::UIElement> held;
        held.reserve(count);
        for (int32_t index = 0; index < count; ++index) held.push_back(as<xaml::UIElement>(children[index]));
        for (uint32_t index = items.Size(); index-- > 0;) {
            if (std::find(held.begin(), held.end(), items.GetAt(index)) == held.end()) items.RemoveAt(index);
        }
        for (uint32_t index = 0; index < held.size(); ++index) {
            if (index < items.Size() && items.GetAt(index) == held[index]) continue;
            uint32_t standing = 0;
            if (items.IndexOf(held[index], standing)) {
                items.Move(standing, index);
            } else {
                items.InsertAt(index, held[index]);
            }
        }
    } catch (...) {
        report("holding a panel's children");
    }
}

extern "C" void stateui_winui_panel_set_entrance(StateUIObjectRef handle, double offset) {
    try {
        auto held = borrow<controls::Panel>(handle);
        if (offset == 0) {
            held.ChildrenTransitions(nullptr);
            return;
        }
        winrt::Microsoft::UI::Xaml::Media::Animation::EntranceThemeTransition entrance;
        entrance.FromHorizontalOffset(offset);
        entrance.FromVerticalOffset(0);
        entrance.IsStaggeringEnabled(false);
        winrt::Microsoft::UI::Xaml::Media::Animation::TransitionCollection transitions;
        transitions.Append(entrance);
        held.ChildrenTransitions(transitions);
    } catch (...) {
        report("setting how a panel's children enter");
    }
}

extern "C" void stateui_winui_panel_hide_children(StateUIObjectRef handle, bool hidden) {
    try {
        panel(as<xaml::UIElement>(handle))->childrenHidden = hidden;
    } catch (...) {
        report("hiding a panel's children from assistive technology");
    }
}

extern "C" void stateui_winui_panel_set_kind(StateUIObjectRef handle, int32_t controlType, char const *value) {
    try {
        auto made = panel(as<xaml::UIElement>(handle));
        made->controlType = controlType;
        made->valued = value != nullptr;
        made->value = value ? winrt::to_hstring(value) : winrt::hstring();
    } catch (...) {
        report("telling assistive technology a panel's kind");
    }
}
