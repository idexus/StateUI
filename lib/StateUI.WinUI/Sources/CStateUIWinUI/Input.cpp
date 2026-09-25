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
    /// One view's listening: what it listens for, the run of taps it heard, the press it holds and whether that
    /// became a drag, and the handlers hung on its element.
    struct Listening {
        uint32_t hearing = 0;

        int32_t run = 0;
        ULONGLONG lastTap = 0;

        uint32_t pointer = 0;
        bool dragging = false;
        Point from{};
        Point moved{};

        winrt::event_token tapped, doubleTapped, entered, exited, movedToken, pressed, released, lost, canceled,
            started, delta, completed;
    };

    std::unordered_map<int64_t, Listening> listening;

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

    /// The press ends: a drag it became ends with it, `phase` saying how.
    void letGo(int64_t view, int32_t phase) {
        auto found = listening.find(view);
        if (found == listening.end() || !found->second.pointer) return;
        auto &entry = found->second;
        entry.pointer = 0;
        if (!entry.dragging) return;
        entry.dragging = false;
        tell(view, StateUIHeardDrag, phase, entry.moved);
    }

    void pointer(int64_t view, StateUIHeard what, IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
        if (listener(view, StateUIHearingPointer))
            tell(view, what, 0, args.GetCurrentPoint(sender.as<xaml::UIElement>()).Position());
    }

    /// Hangs every handler once; each asks what the view listens for as it runs.
    void listen(xaml::UIElement const &element, int64_t view, Listening &entry) {
        entry.tapped = element.Tapped([view](IInspectable const &sender, input::TappedRoutedEventArgs const &args) {
            if (!listener(view, StateUIHearingTaps)) return;
            args.Handled(true);
            tap(view, args.GetPosition(sender.as<xaml::UIElement>()), false);
        });
        entry.doubleTapped = element.DoubleTapped(
            [view](IInspectable const &sender, input::DoubleTappedRoutedEventArgs const &args) {
                if (!listener(view, StateUIHearingTaps)) return;
                args.Handled(true);
                tap(view, args.GetPosition(sender.as<xaml::UIElement>()), true);
            });
        entry.entered = element.PointerEntered([view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerEntered, sender, args);
        });
        entry.exited = element.PointerExited([view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerExited, sender, args);
        });
        entry.pressed = element.PointerPressed([view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerPressed, sender, args);
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || !args.GetCurrentPoint(sender.as<xaml::UIElement>()).Properties().IsLeftButtonPressed()) return;
            entry->pointer = args.Pointer().PointerId();
            entry->dragging = false;
            entry->from = onContent(args);
            entry->moved = {};
        });
        entry.movedToken = element.PointerMoved([view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerMoved, sender, args);
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || entry->pointer != args.Pointer().PointerId()) return;
            auto now = onContent(args);
            entry->moved = {now.X - entry->from.X, now.Y - entry->from.Y};
            if (!entry->dragging) {
                // A press becomes a drag past the system's drag distance, and holds the pointer from there.
                if (std::abs(entry->moved.X) < GetSystemMetrics(SM_CXDRAG)
                    && std::abs(entry->moved.Y) < GetSystemMetrics(SM_CYDRAG)) return;
                entry->dragging = true;
                sender.as<xaml::UIElement>().CapturePointer(args.Pointer());
                tell(view, StateUIHeardDrag, 0, {});
            }
            args.Handled(true);
            tell(view, StateUIHeardDrag, 1, entry->moved);
        });
        entry.released = element.PointerReleased([view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerReleased, sender, args);
            letGo(view, 2);
        });
        entry.lost = element.PointerCaptureLost([view](IInspectable const &, input::PointerRoutedEventArgs const &) {
            letGo(view, 3);
        });
        entry.canceled = element.PointerCanceled([view](IInspectable const &, input::PointerRoutedEventArgs const &) {
            letGo(view, 3);
        });
        entry.started = element.ManipulationStarted(
            [view](IInspectable const &sender, input::ManipulationStartedRoutedEventArgs const &args) {
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, 0, shares(sender, args.Position()), 1);
            });
        entry.delta = element.ManipulationDelta(
            [view](IInspectable const &sender, input::ManipulationDeltaRoutedEventArgs const &args) {
                if (!listener(view, StateUIHearingPinches)) return;
                args.Handled(true);
                tell(view, StateUIHeardPinch, 1, shares(sender, args.Position()), args.Delta().Scale);
            });
        entry.completed = element.ManipulationCompleted(
            [view](IInspectable const &sender, input::ManipulationCompletedRoutedEventArgs const &args) {
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, 2, shares(sender, args.Position()), 1);
            });
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
        element.ManipulationMode(input::ManipulationModes::System);
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
        auto found = listening.find(view);
        if (!hearing) {
            if (found == listening.end()) return;
            unhook(element, found->second);
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
    } catch (winrt::hresult_error const &error) {
        report(error, "listening for the user's input");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "pressing an element");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "finding what a click hits");
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
        entry.got = element.GotFocus([view](IInspectable const &, xaml::RoutedEventArgs const &) { tellFocus(view, true); });
        entry.lost = element.LostFocus([view](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            tellFocus(view, holdsFocus(sender.as<xaml::UIElement>()));
        });
    } catch (winrt::hresult_error const &error) {
        report(error, "hearing an element's focus");
    }
}

extern "C" int32_t stateui_winui_listeners(void) {
    return static_cast<int32_t>(listening.size());
}
