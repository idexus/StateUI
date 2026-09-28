// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A figure: the relay's panel for what WinUI gives no automation peer - a
// shape's Path, a colour box - and the peer assistive technology meets it and a
// canvas by.
// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets
#pragma once

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

namespace stateui {
    /// A figure for the view numbered `view`: it puts what it holds as far as that reaches from its corner, and
    /// is met as an image.
    controls::Grid figure(int64_t view);

    /// The peer assistive technology meets a figure or a canvas by, as an image.
    winrt::Microsoft::UI::Xaml::Automation::Peers::AutomationPeer figurePeer(
        xaml::FrameworkElement const &owner, int64_t view);

    /// The shape `object` is, or the one its figure holds; null for none.
    winrt::Microsoft::UI::Xaml::Shapes::Shape figureShape(IInspectable const &object);
}
