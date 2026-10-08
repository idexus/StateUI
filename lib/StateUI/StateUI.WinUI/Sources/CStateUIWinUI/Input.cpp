// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the user does to any element - taps, the pointer, a press dragged, a
// pinch, the keyboard coming in - heard where a view listens for it. Each
// handler names its view by number and holds nothing of the element it hangs
// on.
// Design: docs/design/platforms/winui/input.md

#include "Relay.h"

#include <cmath>
#include <optional>
#include <unordered_map>

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::Foundation::Point;
namespace input = winrt::Microsoft::UI::Xaml::Input;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    /// One view's listening: what it listens for, the run of taps it heard, the press it holds, whether the host
    /// said that became a drag and whether the view is yet to hold the pointer, and the handlers hung on its element.
    struct Listening {
        uint32_t hearing = 0;

        int32_t run = 0;
        ULONGLONG lastTap = 0;

        uint32_t pointer = 0;
        bool dragging = false;
        bool capturing = false;

        winrt::event_token tapped, doubleTapped, entered, exited, movedToken, pressed, released, lost, canceled,
            started, delta, completed;
    };

    std::unordered_map<int64_t, Listening> listening;

    /// How many sets of handlers hang on elements: each listening view's, and a view's that stopped listening, until
    /// they come off.
    int32_t hung = 0;

    Listening *listener(int64_t view, uint32_t what) {
        auto found = listening.find(view);
        return found != listening.end() && (found->second.hearing & what) ? &found->second : nullptr;
    }

    void tell(int64_t view, StateUIHeard what, int32_t phase, Point point, double scale = 0) {
        callbacks.heard(view, what, phase, point.X, point.Y, scale);
    }

    /// Where the pointer is on the window's content: a drag measured there is not moved by the view it moves.
    Point onContent(input::PointerRoutedEventArgs const &args) {
        return args.GetCurrentPoint(nullptr).Position();
    }

    /// A point of `sender` as shares of its size.
    Point shares(IInspectable const &sender, Point point) {
        auto element = sender.as<xaml::FrameworkElement>();
        auto width = element.ActualWidth(), height = element.ActualHeight();
        return {width > 0 ? static_cast<float>(point.X / width) : 0.5f,
                height > 0 ? static_cast<float>(point.Y / height) : 0.5f};
    }

    /// A tap, its place in a quick run: a tap soon after the last continues the run, and WinUI tells a second tap
    /// as a double tap in place of a tap.
    void tap(int64_t view, Point point, bool second) {
        auto *entry = listener(view, StateUIHearingTaps);
        if (!entry) return;
        auto now = GetTickCount64();
        entry->run = second || now - entry->lastTap <= GetDoubleClickTime() ? entry->run + 1 : 1;
        entry->lastTap = now;
        tell(view, StateUIHeardTap, entry->run, point);
    }

    /// The press ends, `phase` saying how: 2 let go, 3 taken away. The host says whether a drag ends with it.
    void letGo(int64_t view, int32_t phase) {
        auto found = listening.find(view);
        if (found == listening.end() || !found->second.pointer) return;
        auto &entry = found->second;
        entry.pointer = 0;
        entry.dragging = false;
        entry.capturing = false;
        tell(view, StateUIHeardPress, phase, {});
    }

    void pointer(int64_t view, StateUIHeard what, IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
        if (listener(view, StateUIHearingPointer))
            tell(view, what, 0, args.GetCurrentPoint(sender.as<xaml::UIElement>()).Position());
    }

    /// Hangs every handler once; each asks what the view listens for as it runs.
    void listen(xaml::UIElement const &element, int64_t view, Listening &entry) {
        entry.tapped = element.Tapped(guarded("handling Tapped",
            [view](IInspectable const &sender, input::TappedRoutedEventArgs const &args) {
            if (!listener(view, StateUIHearingTaps)) return;
            args.Handled(true);
            tap(view, args.GetPosition(sender.as<xaml::UIElement>()), false);
        }));
        entry.doubleTapped = element.DoubleTapped(
            guarded("handling DoubleTapped",
                [view](IInspectable const &sender, input::DoubleTappedRoutedEventArgs const &args) {
                if (!listener(view, StateUIHearingTaps)) return;
                args.Handled(true);
                tap(view, args.GetPosition(sender.as<xaml::UIElement>()), true);
            }));
        entry.entered = element.PointerEntered(guarded("handling PointerEntered",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerEntered, sender, args);
        }));
        entry.exited = element.PointerExited(guarded("handling PointerExited",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerExited, sender, args);
        }));
        entry.pressed = element.PointerPressed(guarded("handling PointerPressed",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerPressed, sender, args);
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || !args.GetCurrentPoint(sender.as<xaml::UIElement>()).Properties().IsLeftButtonPressed()) return;
            entry->pointer = args.Pointer().PointerId();
            entry->dragging = false;
            entry->capturing = false;
            tell(view, StateUIHeardPress, 0, onContent(args));
        }));
        entry.movedToken = element.PointerMoved(guarded("handling PointerMoved",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerMoved, sender, args);
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || entry->pointer != args.Pointer().PointerId()) return;
            tell(view, StateUIHeardPress, 1, onContent(args));
            // The host said, as it heard the move, whether the press is a drag: the view holds the pointer from there.
            entry = listener(view, StateUIHearingDrags);
            if (!entry || !entry->dragging) return;
            if (entry->capturing) {
                entry->capturing = false;
                sender.as<xaml::UIElement>().CapturePointer(args.Pointer());
            }
            args.Handled(true);
        }));
        entry.released = element.PointerReleased(guarded("handling PointerReleased",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerReleased, sender, args);
            letGo(view, 2);
        }));
        entry.lost = element.PointerCaptureLost(guarded("handling PointerCaptureLost",
            [view](IInspectable const &, input::PointerRoutedEventArgs const &) {
            letGo(view, 3);
        }));
        entry.canceled = element.PointerCanceled(guarded("handling PointerCanceled",
            [view](IInspectable const &, input::PointerRoutedEventArgs const &) {
            letGo(view, 3);
        }));
        entry.started = element.ManipulationStarted(
            guarded("handling ManipulationStarted",
                [view](IInspectable const &sender, input::ManipulationStartedRoutedEventArgs const &args) {
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, 0, shares(sender, args.Position()), 1);
            }));
        entry.delta = element.ManipulationDelta(
            guarded("handling ManipulationDelta",
                [view](IInspectable const &sender, input::ManipulationDeltaRoutedEventArgs const &args) {
                if (!listener(view, StateUIHearingPinches)) return;
                args.Handled(true);
                tell(view, StateUIHeardPinch, 1, shares(sender, args.Position()), args.Delta().Scale);
            }));
        entry.completed = element.ManipulationCompleted(
            guarded("handling ManipulationCompleted",
                [view](IInspectable const &sender, input::ManipulationCompletedRoutedEventArgs const &args) {
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, 2, shares(sender, args.Position()), 1);
            }));
        ++hung;
    }

    void unhook(xaml::UIElement const &element, Listening const &entry) {
        element.Tapped(entry.tapped);
        element.DoubleTapped(entry.doubleTapped);
        element.PointerEntered(entry.entered);
        element.PointerExited(entry.exited);
        element.PointerPressed(entry.pressed);
        element.PointerMoved(entry.movedToken);
        element.PointerReleased(entry.released);
        element.PointerCaptureLost(entry.lost);
        element.PointerCanceled(entry.canceled);
        element.ManipulationStarted(entry.started);
        element.ManipulationDelta(entry.delta);
        element.ManipulationCompleted(entry.completed);
        --hung;
    }

    /// Takes a view's handlers off its element once the event running now is over: WinUI raising a routed event
    /// reads the element's list of handlers after each one returns, and a list shortened inside one - a tap that
    /// closes what was tapped - is read past its end. Until then each asks what the view listens for, and answers
    /// nothing.
    /// Design: docs/design/platforms/winui/input.md#listening
    void unhookLater(xaml::UIElement const &element, Listening const &entry) {
        element.ManipulationMode(input::ManipulationModes::System);
        auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
        queue.TryEnqueue(guarded("handling TryEnqueue", [element, entry] { unhook(element, entry); }));
    }

    /// The clear brush a panel is painted with to be hit, told from an author's by being this one.
    xaml::Media::SolidColorBrush const &clear() {
        // Kept for the process's life: no XAML object is let go of after XAML has shut down.
        static auto const *brush = new std::optional(xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
        return **brush;
    }
}

namespace stateui {
    bool hearsTaps(int64_t view) {
        return listener(view, StateUIHearingTaps) != nullptr;
    }

    void press(int64_t view) {
        if (hearsTaps(view)) tell(view, StateUIHeardTap, 0, {});
    }

    void holdHitArea(xaml::UIElement const &element, int64_t view) {
        auto panel = element.try_as<controls::Panel>();
        if (!panel) return;
        bool wanted = listening.count(view) || element.ContextFlyout();
        auto background = panel.Background();
        if (wanted && !background) panel.Background(clear());
        else if (!wanted && background == clear()) panel.Background(nullptr);
    }
}

extern "C" void stateui_winui_hear(StateUIObjectRef handle, int64_t view, uint32_t hearing) {
    try {
        auto element = as<xaml::UIElement>(handle);
        // A web view's page takes the user's hand: WebView2 ends the process (fail-fast) once it is listened to.
        if (element.try_as<controls::WebView2>()) return;
        auto found = listening.find(view);
        if (!hearing) {
            if (found == listening.end()) return;
            unhookLater(element, found->second);
            listening.erase(found);
            holdHitArea(element, view);
            return;
        }
        if (found == listening.end()) {
            found = listening.emplace(view, Listening{}).first;
            listen(element, view, found->second);
        }
        auto &entry = found->second;
        entry.hearing = hearing;
        element.ManipulationMode(
            hearing & StateUIHearingPinches ? input::ManipulationModes::Scale : input::ManipulationModes::System);
        holdHitArea(element, view);
    } catch (...) {
        report("listening for the user's input");
    }
}

extern "C" void stateui_winui_press_dragged(int64_t view) {
    try {
        auto found = listening.find(view);
        if (found == listening.end() || !found->second.pointer) return;
        found->second.dragging = true;
        found->second.capturing = true;
    } catch (...) {
        report("holding a dragged press");
    }
}

extern "C" void stateui_winui_drag_distance(double *distance) {
    try {
        distance[0] = GetSystemMetricsForDpi(SM_CXDRAG, USER_DEFAULT_SCREEN_DPI);
        distance[1] = GetSystemMetricsForDpi(SM_CYDRAG, USER_DEFAULT_SCREEN_DPI);
    } catch (...) {
        report("reading the drag distance");
    }
}

extern "C" bool stateui_winui_press(StateUIObjectRef handle) {
    try {
        auto peer = peers::FrameworkElementAutomationPeer::CreatePeerForElement(as<xaml::UIElement>(handle));
        auto pattern = peer ? peer.GetPattern(peers::PatternInterface::Invoke) : nullptr;
        auto invoke = pattern ? pattern.try_as<provider::IInvokeProvider>() : nullptr;
        if (!invoke) return false;
        invoke.Invoke();
        return true;
    } catch (...) {
        report("pressing an element");
        return false;
    }
}

extern "C" bool stateui_winui_hits(StateUIObjectRef handle, double x, double y) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto point = element.TransformToVisual(nullptr).TransformPoint(
            Point(static_cast<float>(x), static_cast<float>(y)));
        for (auto const &hit : xaml::Media::VisualTreeHelper::FindElementsInHostCoordinates(point, element))
            if (hit == element) return true;
        return false;
    } catch (...) {
        report("finding what a click hits");
        return false;
    }
}

extern "C" bool stateui_winui_reaches(StateUIObjectRef handle, double x, double y) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto point = element.TransformToVisual(nullptr).TransformPoint(
            Point(static_cast<float>(x), static_cast<float>(y)));
        // What the window holds at the point, the top first: the click is the top one's, or an element's it stands in.
        for (auto const &hit : xaml::Media::VisualTreeHelper::FindElementsInHostCoordinates(point, element.XamlRoot().Content())) {
            for (xaml::DependencyObject at = hit; at; at = xaml::Media::VisualTreeHelper::GetParent(at))
                if (at == element) return true;
            return false;
        }
        return false;
    } catch (...) {
        report("finding what a click reaches");
        return false;
    }
}

extern "C" bool stateui_winui_drawn_place(StateUIObjectRef panelHandle, StateUIObjectRef childHandle, int32_t *depth,
                                          int32_t *place) {
    try {
        auto panel = as<xaml::DependencyObject>(panelHandle);
        xaml::DependencyObject at = as<xaml::DependencyObject>(childHandle);
        while (at) {
            auto above = xaml::Media::VisualTreeHelper::GetParent(at);
            if (above == panel) break;
            at = above;
        }
        if (!at) return false;
        auto count = xaml::Media::VisualTreeHelper::GetChildrenCount(panel);
        for (int32_t index = 0; index < count; ++index) {
            if (xaml::Media::VisualTreeHelper::GetChild(panel, index) != at) continue;
            auto element = at.try_as<xaml::UIElement>();
            *depth = element ? xaml::Controls::Canvas::GetZIndex(element) : 0;
            *place = index;
            return true;
        }
        return false;
    } catch (...) {
        report("reading where a child is drawn");
        return false;
    }
}

namespace {
    /// One view's focus heard: whether the keyboard is in it, and the handlers hung on its element.
    struct Focus {
        bool within = false;
        winrt::event_token got, lost;
    };

    std::unordered_map<int64_t, Focus> focusing;

    void tellFocus(int64_t view, bool within) {
        auto found = focusing.find(view);
        if (found == focusing.end() || found->second.within == within) return;
        found->second.within = within;
        callbacks.focused(view, within);
    }
}

extern "C" void stateui_winui_hear_focus(StateUIObjectRef handle, int64_t view, bool hearing) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto found = focusing.find(view);
        if (!hearing) {
            if (found == focusing.end()) return;
            element.GotFocus(found->second.got);
            element.LostFocus(found->second.lost);
            focusing.erase(found);
            return;
        }
        if (found != focusing.end()) return;

        // Both events bubble from what stands in the element, so the keyboard is asked where it is now.
        auto &entry = focusing.emplace(view, Focus{}).first->second;
        entry.got = element.GotFocus(guarded("handling GotFocus",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { tellFocus(view, true); }));
        entry.lost = element.LostFocus(guarded("handling LostFocus",
            [view](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            tellFocus(view, holdsFocus(sender.as<xaml::UIElement>()));
        }));
    } catch (...) {
        report("hearing an element's focus");
    }
}

extern "C" int32_t stateui_winui_hung_handlers(void) {
    try {
        return hung;
    } catch (...) {
        report("counting the handlers hung");
        return 0;
    }
}

extern "C" int32_t stateui_winui_listeners(void) {
    try {
        return static_cast<int32_t>(listening.size());
    } catch (...) {
        report("counting the listeners");
        return 0;
    }
}
