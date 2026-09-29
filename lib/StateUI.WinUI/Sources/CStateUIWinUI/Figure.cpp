// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A figure measures what it holds with no bound and puts it as far as it
// reaches, so a lean or a cap past the room is drawn whole; its peer is an
// image, pressed as a tap while its view listens for taps, and met by itself
// only while it is named - a decoration says nothing unless it says it is met.
// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets

#include "Figure.h"

#include <algorithm>
#include <cmath>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>

using namespace stateui;
using winrt::Windows::Foundation::Size;
namespace automation = winrt::Microsoft::UI::Xaml::Automation;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    struct StateUIFigurePeer : peers::FrameworkElementAutomationPeerT<StateUIFigurePeer, provider::IInvokeProvider> {
        using Base = peers::FrameworkElementAutomationPeerT<StateUIFigurePeer, provider::IInvokeProvider>;

        StateUIFigurePeer(xaml::FrameworkElement const &owner, int64_t view) : Base(owner), view(view) {}

        IInspectable GetPatternCore(peers::PatternInterface const &pattern) {
            if (pattern == peers::PatternInterface::Invoke && hearsTaps(view)) return *this;
            return Base::GetPatternCore(pattern);
        }

        void Invoke() {
            press(view);
        }

        peers::AutomationControlType GetAutomationControlTypeCore() {
            return peers::AutomationControlType::Image;
        }

        bool IsControlElementCore() {
            return met();
        }

        bool IsContentElementCore() {
            return met();
        }

        winrt::Windows::Foundation::Collections::IVector<peers::AutomationPeer> GetChildrenCore() {
            return winrt::single_threaded_vector<peers::AutomationPeer>();
        }

        /// Met where the element says whether it is, and otherwise while it has a name.
        bool met() {
            auto owner = Owner();
            auto view = automation::AutomationProperties::AccessibilityViewProperty();
            if (owner.ReadLocalValue(view) != xaml::DependencyProperty::UnsetValue()) {
                return automation::AutomationProperties::GetAccessibilityView(owner) != peers::AccessibilityView::Raw;
            }
            return !automation::AutomationProperties::GetName(owner).empty();
        }

        int64_t view;
    };

    struct StateUIFigure : controls::GridT<StateUIFigure> {
        explicit StateUIFigure(int64_t view) : view(view) {}

        peers::AutomationPeer OnCreateAutomationPeer() {
            IInspectable self = *this;
            return winrt::make<StateUIFigurePeer>(self.as<xaml::FrameworkElement>(), view);
        }

        Size MeasureOverride(Size) {
            for (auto const &child : Children()) child.Measure({INFINITY, INFINITY});
            return {0, 0};
        }

        Size ArrangeOverride(Size final) {
            for (auto const &child : Children()) {
                auto wanted = child.DesiredSize();
                child.Arrange({0, 0, std::max(final.Width, wanted.Width), std::max(final.Height, wanted.Height)});
            }
            return final;
        }

        int64_t view;
    };
}

namespace stateui {
    controls::Grid figure(int64_t view) {
        return winrt::make<StateUIFigure>(view).as<controls::Grid>();
    }

    peers::AutomationPeer figurePeer(xaml::FrameworkElement const &owner, int64_t view) {
        return winrt::make<StateUIFigurePeer>(owner, view);
    }

    shapes::Shape figureShape(IInspectable const &object) {
        if (auto shape = object.try_as<shapes::Shape>()) return shape;
        auto held = object.try_as<controls::Grid>();
        if (!held || held.Children().Size() == 0) return nullptr;
        return held.Children().GetAt(0).try_as<shapes::Shape>();
    }
}
