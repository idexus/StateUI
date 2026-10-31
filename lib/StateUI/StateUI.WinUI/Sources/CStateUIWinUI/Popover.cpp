// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's popover: WinUI's Flyout holding the popover's view by its anchor. A closing the program did not ask for -
// a click beside it, Escape - is told to the host as the view's presentation closed.
// Design: docs/design/platforms/winui/pages.md#a-popover

#include "Relay.h"

#include <memory>

using namespace stateui;

namespace {
    /// WinUI's Flyout keeping whether the program wants it shown: a closing while it does is the user's.
    struct StateUIPopover : controls::FlyoutT<StateUIPopover> {
        explicit StateUIPopover(int64_t view) : view(view) {}

        int64_t view;
        bool wanted = false;
        /// Shown at a new target - its view made anew: the closing at the old one is nobody's.
        bool moving = false;
    };

    /// The popover a flyout is, reached through an interface the popover implements itself.
    StateUIPopover *popover(controls::Flyout const &flyout) {
        return winrt::get_self<StateUIPopover>(flyout.as<controls::Primitives::IFlyoutBaseOverrides>());
    }
}

extern "C" StateUIObjectRef stateui_winui_popover_make(int64_t view, StateUIObjectRef content) {
    try {
        auto flyout = winrt::make<StateUIPopover>(view).as<controls::Flyout>();
        flyout.Content(as<xaml::UIElement>(content));
        flyout.Closed(guarded("handling a popover's Closed", [](IInspectable const &sender, IInspectable const &) {
            auto closed = popover(sender.as<controls::Flyout>());
            if (!closed->wanted || closed->moving) return;
            closed->wanted = false;
            callbacks.presented(closed->view, false);
        }));
        flyout.Opened(guarded("handling a popover's Opened", [](IInspectable const &sender, IInspectable const &) {
            popover(sender.as<controls::Flyout>())->moving = false;
        }));
        return detach(flyout);
    } catch (...) {
        report("making a popover");
        return nullptr;
    }
}

extern "C" void stateui_winui_popover_show(StateUIObjectRef handle, StateUIObjectRef anchorHandle) {
    try {
        auto flyout = borrow<controls::Flyout>(handle);
        auto anchor = as<xaml::FrameworkElement>(anchorHandle);
        popover(flyout)->wanted = true;
        if (flyout.IsOpen()) {
            // Shown by a view made anew - its branch flipped: it stands by the new one.
            if (flyout.Target() != anchor && anchor.IsLoaded()) {
                popover(flyout)->moving = true;
                flyout.ShowAt(anchor);
            }
            return;
        }
        if (anchor.IsLoaded()) return flyout.ShowAt(anchor);
        // An anchor not loaded yet has no root to show over: the popover shows once it is, if still wanted.
        auto token = std::make_shared<winrt::event_token>();
        *token = anchor.Loaded(guarded("handling Loaded",
            [weak = winrt::make_weak(flyout), token](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            auto loaded = sender.as<xaml::FrameworkElement>();
            loaded.Loaded(*token);
            auto flyout = weak.get();
            if (flyout && popover(flyout)->wanted && !flyout.IsOpen()) flyout.ShowAt(loaded);
        }));
    } catch (...) {
        report("showing a popover");
    }
}

extern "C" void stateui_winui_popover_close(StateUIObjectRef handle) {
    try {
        auto flyout = borrow<controls::Flyout>(handle);
        popover(flyout)->wanted = false;
        flyout.Hide();
    } catch (...) {
        report("closing a popover");
    }
}

extern "C" bool stateui_winui_popover_is_open(StateUIObjectRef handle) {
    try {
        return borrow<controls::Flyout>(handle).IsOpen();
    } catch (...) {
        report("reading a popover");
        return false;
    }
}

extern "C" void stateui_winui_popover_hide(StateUIObjectRef handle) {
    try {
        borrow<controls::Flyout>(handle).Hide();
    } catch (...) {
        report("hiding a popover");
    }
}
