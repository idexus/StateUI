// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A scroller's pull to refresh: WinUI's RefreshContainer around its ScrollViewer while the pull is offered. A pull is
// told to the host and held - its deferral - until the element's refresh ends; one the program asks for, unheard.
// Design: docs/design/platforms/winui/layout.md#the-pull-to-refresh

#include "Relay.h"

#include <utility>

using namespace stateui;

namespace {
    /// What the relay keeps of one container: the deferral of the refresh under way, and whether the program is
    /// asking for the refresh coming.
    struct Pull : winrt::implements<Pull, winrt::Windows::Foundation::IInspectable> {
        winrt::Windows::Foundation::Deferral deferral{nullptr};
        bool programs = false;
    };

    winrt::com_ptr<Pull> pull(controls::RefreshContainer const &container) {
        winrt::com_ptr<Pull> pull;
        pull.copy_from(winrt::get_self<Pull>(container.Tag()));
        return pull;
    }

    /// Ends the refresh under way, where one is.
    void end(Pull &pull) {
        if (auto deferral = std::exchange(pull.deferral, nullptr)) deferral.Complete();
    }
}

extern "C" StateUIObjectRef stateui_winui_refresh_make(int64_t view) {
    try {
        controls::RefreshContainer container;
        container.Tag(winrt::make<Pull>());
        container.RefreshRequested(guarded("handling RefreshRequested",
            [view](controls::RefreshContainer const &sender, controls::RefreshRequestedEventArgs const &arguments) {
            auto held = pull(sender);
            end(*held);
            held->deferral = arguments.GetDeferral();
            if (!held->programs && !callbacks.refreshPulled(view)) end(*held);
        }));
        return detach(container);
    } catch (...) {
        report("making a pull to refresh");
        return nullptr;
    }
}

extern "C" void stateui_winui_refresh_set(StateUIObjectRef handle, StateUIObjectRef content, bool refreshing) {
    try {
        auto container = borrow<controls::RefreshContainer>(handle);
        auto element = content ? as<xaml::UIElement>(content) : xaml::UIElement{nullptr};
        if (container.Content() != element) container.Content(element);
        auto held = pull(container);
        if (!refreshing) return end(*held);
        if (held->deferral || !element) return;
        // WinUI raises RefreshRequested within RequestRefresh: the program's own, heard by nobody.
        held->programs = true;
        container.RequestRefresh();
        held->programs = false;
    } catch (...) {
        report("setting a pull to refresh");
    }
}

extern "C" bool stateui_winui_refresh_holds(StateUIObjectRef handle) {
    try {
        return borrow<controls::RefreshContainer>(handle).Content() != nullptr;
    } catch (...) {
        report("reading what a pull to refresh holds");
        return false;
    }
}

extern "C" bool stateui_winui_refresh_refreshing(StateUIObjectRef handle) {
    try {
        auto visualizer = borrow<controls::RefreshContainer>(handle).Visualizer();
        return visualizer && visualizer.State() == controls::RefreshVisualizerState::Refreshing;
    } catch (...) {
        report("reading a pull to refresh");
        return false;
    }
}

extern "C" void stateui_winui_refresh_request(StateUIObjectRef handle) {
    try {
        borrow<controls::RefreshContainer>(handle).RequestRefresh();
    } catch (...) {
        report("asking for a refresh");
    }
}
