// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A ScrollView's scroller: WinUI's ScrollViewer around the document the host
// lays out, saying where its view stands and when the user holds it.
// Design: docs/design/platforms/winui/layout.md#scrolling

#include "Relay.h"

#include <winrt/Windows.Foundation.h>

using namespace stateui;

namespace {
    controls::ScrollBarVisibility visibility(bool scrolls, int32_t bar) {
        if (!scrolls) return controls::ScrollBarVisibility::Disabled;
        switch (bar) {
        case 1: return controls::ScrollBarVisibility::Visible;
        case 2: return controls::ScrollBarVisibility::Hidden;
        default: return controls::ScrollBarVisibility::Auto;
        }
    }
}

extern "C" StateUIObjectRef stateui_winui_scroller_make(int64_t view) {
    try {
        controls::ScrollViewer scroller;
        scroller.ViewChanged([view](IInspectable const &sender, controls::ScrollViewerViewChangedEventArgs const &) {
            auto scroller = sender.as<controls::ScrollViewer>();
            callbacks.scrolled(view, scroller.HorizontalOffset(), scroller.VerticalOffset());
        });
        scroller.DirectManipulationStarted([view](IInspectable const &, IInspectable const &) {
            callbacks.held(view, true);
        });
        scroller.DirectManipulationCompleted([view](IInspectable const &, IInspectable const &) {
            callbacks.held(view, false);
        });
        return detach(scroller);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a scroller");
        return nullptr;
    }
}

extern "C" void stateui_winui_scroller_set(
    StateUIObjectRef handle, StateUIObjectRef content, int32_t orientation, int32_t verticalBar, int32_t horizontalBar
) {
    try {
        auto scroller = borrow<controls::ScrollViewer>(handle);
        auto down = orientation == 0 || orientation == 2;
        auto across = orientation == 1 || orientation == 2;
        scroller.VerticalScrollMode(down ? controls::ScrollMode::Enabled : controls::ScrollMode::Disabled);
        scroller.HorizontalScrollMode(across ? controls::ScrollMode::Enabled : controls::ScrollMode::Disabled);
        scroller.VerticalScrollBarVisibility(visibility(down, verticalBar));
        scroller.HorizontalScrollBarVisibility(visibility(across, horizontalBar));
        auto element = content ? as<xaml::UIElement>(content) : xaml::UIElement{nullptr};
        if (scroller.Content() != element) scroller.Content(element);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a scroller");
    }
}

extern "C" void stateui_winui_scroller_move(StateUIObjectRef handle, double x, double y) {
    try {
        borrow<controls::ScrollViewer>(handle).ChangeView(
            winrt::box_value(x).as<winrt::Windows::Foundation::IReference<double>>(),
            winrt::box_value(y).as<winrt::Windows::Foundation::IReference<double>>(), nullptr, true);
    } catch (winrt::hresult_error const &error) {
        report(error, "moving a scroller");
    }
}

extern "C" void stateui_winui_scroller_offset(StateUIObjectRef handle, double *offset) {
    try {
        auto scroller = borrow<controls::ScrollViewer>(handle);
        offset[0] = scroller.HorizontalOffset();
        offset[1] = scroller.VerticalOffset();
        offset[2] = scroller.ScrollableWidth();
        offset[3] = scroller.ScrollableHeight();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a scroller");
    }
}
