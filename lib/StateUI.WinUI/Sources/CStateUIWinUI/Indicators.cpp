// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What shows work: a progress bar, how far along from 0 to 1, and a spinner,
// WinUI's ProgressRing, turning while its work runs.

#include "Relay.h"

using namespace stateui;

extern "C" StateUIObjectRef stateui_winui_progress_bar_make(void) {
    try {
        controls::ProgressBar bar;
        bar.Minimum(0);
        bar.Maximum(1);
        return detach(bar);
    } catch (...) {
        report("making a progress bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_progress_bar_set(StateUIObjectRef handle, double progress) {
    try {
        borrow<controls::ProgressBar>(handle).Value(progress);
    } catch (...) {
        report("moving a progress bar");
    }
}

extern "C" StateUIObjectRef stateui_winui_progress_ring_make(void) {
    try {
        controls::ProgressRing ring;
        ring.IsActive(false);
        return detach(ring);
    } catch (...) {
        report("making a spinner");
        return nullptr;
    }
}

extern "C" void stateui_winui_progress_ring_set_running(StateUIObjectRef handle, bool running) {
    try {
        borrow<controls::ProgressRing>(handle).IsActive(running);
    } catch (...) {
        report("turning a spinner");
    }
}

extern "C" double stateui_winui_progress_bar_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::ProgressBar>(handle).Value();
    } catch (...) {
        report("reading how far along");
        return 0;
    }
}

extern "C" bool stateui_winui_progress_ring_running(StateUIObjectRef handle) {
    try {
        return borrow<controls::ProgressRing>(handle).IsActive();
    } catch (...) {
        report("reading whether a spinner turns");
        return false;
    }
}
