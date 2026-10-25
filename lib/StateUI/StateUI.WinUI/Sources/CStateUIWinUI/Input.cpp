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
#include <unordered_set>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Composition.Interactions.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
using winrt::Windows::Foundation::Point;
namespace input = winrt::Microsoft::UI::Xaml::Input;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;
namespace interactions = winrt::Microsoft::UI::Composition::Interactions;

namespace {
    /// One view's listening: what it listens for, the press it holds, whether the host said that became a drag and
    /// whether the view is yet to hold the pointer, and the handlers hung on its element.
    struct Listening {
        uint32_t hearing = 0;

        uint32_t pointer = 0;
        bool dragging = false;
        bool capturing = false;

        winrt::event_token tapped, doubleTapped, holding, entered, exited, movedToken, pressed, released, lost,
            canceled, started, delta, completed, wheel;

        /// The hand over a layout: the pointers pressed on it, each told to the host, which reads them as one hand
        /// (`HandRecognition`), and where it says the hand stands.
        std::unordered_set<uint32_t> handPointers;
        StateUIHandState handState = StateUIHandLeft;

        /// The pointer pressed with Alt over a view two fingers move, read as two fingers while it is down; -1 none.
        int64_t mirroring = -1;
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

    /// A tap, when - in milliseconds from the relay's first - and where it landed in its element, in DIPs - WinUI
    /// tells a second tap soon after the first as a double tap in its place: Swift counts the run (TapRun).
    void tap(int64_t view, Point point) {
        if (!listener(view, StateUIHearingTaps)) return;
        static ULONGLONG const first = GetTickCount64();
        tell(view, StateUIHeardTap, static_cast<int32_t>(GetTickCount64() - first), point);
    }

    /// The press ends, `phase` saying how: let go or taken away. The host says whether a drag ends with it.
    void letGo(int64_t view, StateUIPressPhase phase) {
        auto found = listening.find(view);
        if (found == listening.end() || !found->second.pointer) return;
        auto &entry = found->second;
        entry.pointer = 0;
        entry.dragging = false;
        entry.capturing = false;
        tell(view, StateUIHeardPress, phase, {});
    }

    void pointer(int64_t view, StateUIHeard what, IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
        if (!listener(view, StateUIHearingPointer)) return;
        auto point = args.GetCurrentPoint(sender.as<xaml::UIElement>());
        // A finger's pointer told apart, 1 in the phase: the host layer hears it hover over nothing.
        bool finger = point.PointerDeviceType() == winrt::Microsoft::UI::Input::PointerDeviceType::Touch;
        tell(view, what, finger ? 1 : 0, point.Position());
    }

    /// When the pointer event happened, in milliseconds on the pointer's clock.
    double when(input::PointerRoutedEventArgs const &args) {
        return static_cast<double>(args.GetCurrentPoint(nullptr).Timestamp()) / 1000.0;
    }

    /// Now, in milliseconds on the pointer's clock - the performance counter's.
    double now() {
        LARGE_INTEGER count, frequency;
        QueryPerformanceCounter(&count);
        QueryPerformanceFrequency(&frequency);
        return static_cast<double>(count.QuadPart) * 1000.0 / static_cast<double>(frequency.QuadPart);
    }

    /// A trackpad's fingers and a wheel over a layout a hand moves, heard as WinUI's own scroller hears them: by an
    /// InteractionTracker the input is redirected to. Its states say the hand - fingers down, how they move, the
    /// lift and its speed - and its resting place how far a wheel's step goes. Nothing is bound to its position:
    /// the layout moves by what the host is told.
    /// Design: docs/design/platforms/winui/input.md#the-hand-over-a-layout
    struct HandTracker : winrt::implements<HandTracker, interactions::IInteractionTrackerOwner> {
        int64_t view;
        bool interacting = false;
        winrt::Windows::Foundation::Numerics::float3 last{}, aim{};
        float aimScale = 1, lastScale = 1;

        explicit HandTracker(int64_t view) : view(view) {}

        void CustomAnimationStateEntered(
            interactions::InteractionTracker const &, interactions::InteractionTrackerCustomAnimationStateEnteredArgs const &) {}

        void IdleStateEntered(
            interactions::InteractionTracker const &tracker, interactions::InteractionTrackerIdleStateEnteredArgs const &) {
            interacting = false;
            last = aim = tracker.Position();
            aimScale = lastScale = tracker.Scale();
        }

        void InteractingStateEntered(
            interactions::InteractionTracker const &tracker, interactions::InteractionTrackerInteractingStateEnteredArgs const &) {
            interacting = true;
            last = aim = tracker.Position();
            aimScale = lastScale = tracker.Scale();
            callbacks.hand(view, StateUIPhaseBegan, NAN, NAN, now(), NAN, NAN);
        }

        void InertiaStateEntered(
            interactions::InteractionTracker const &, interactions::InteractionTrackerInertiaStateEnteredArgs const &args) {
            auto modified = args.ModifiedRestingPosition();
            auto resting = modified ? modified.Value() : args.NaturalRestingPosition();
            if (interacting) {
                // The fingers lifted: the layout throws the run itself, so the tracker's own inertia moves nothing.
                interacting = false;
                auto speed = args.PositionVelocityInPixelsPerSecond();
                callbacks.hand(view, StateUIPhaseEnded, 0, 0, now(), -speed.x, -speed.y);
            } else {
                auto scaled = args.ModifiedRestingScale();
                float scale = scaled ? scaled.Value() : args.NaturalRestingScale();
                if (std::abs(scale - aimScale) > 1e-6f && aimScale > 0) {
                    // The wheel turned with Control: a pinch's step, as far as WinUI scales for it - the move its
                    // scaling about the pointer makes is none of the hand's.
                    tell(view, StateUIHeardWheelScale, 0, Point(0.5f, 0.5f), scale / aimScale);
                } else {
                    // A wheel's step: as far as the platform scrolls for it, from where its last step aimed.
                    callbacks.wheel(view, aim.x - resting.x, aim.y - resting.y);
                }
                aimScale = scale;
            }
            aim = resting;
        }

        void RequestIgnored(
            interactions::InteractionTracker const &, interactions::InteractionTrackerRequestIgnoredArgs const &) {}

        void ValuesChanged(
            interactions::InteractionTracker const &, interactions::InteractionTrackerValuesChangedArgs const &args) {
            auto position = args.Position();
            float scale = args.Scale();
            if (interacting && std::abs(scale - lastScale) > 1e-6f && lastScale > 0) {
                // A touchpad's pinch, as WinUI scales for it: a step of the magnification, the move its scaling
                // about the fingers makes none of the hand's.
                tell(view, StateUIHeardWheelScale, 0, Point(0.5f, 0.5f), scale / lastScale);
            } else if (interacting) {
                callbacks.hand(view, StateUIPhaseChanged, last.x - position.x, last.y - position.y, now(), NAN, NAN);
            }
            last = position;
            lastScale = scale;
        }
    };

    /// The tracker each layout a hand moves hears a trackpad and a wheel by, and the source redirecting them to it.
    struct HandTracking {
        interactions::InteractionTracker tracker{nullptr};
        interactions::VisualInteractionSource source{nullptr};
    };

    std::unordered_map<int64_t, HandTracking> tracking;

    /// The view's tracker taken off: the input goes to the element again.
    void untrack(int64_t view) {
        auto found = tracking.find(view);
        if (found == tracking.end()) return;
        found->second.tracker.InteractionSources().RemoveAll();
        tracking.erase(found);
    }

    /// A finger of the hand let go or taken away, `phase` saying which: the host ends the hand with the last,
    /// whatever it moved - a press that held a view and never moved lets it go.
    void handUp(int64_t view, uint32_t pointer, StateUIPressPhase phase, double time) {
        auto *entry = listener(view, StateUIHearingHand);
        if (!entry || !entry->handPointers.erase(pointer)) return;
        auto state = callbacks.finger(view, phase, pointer, 0, 0, 0, 0, time);
        if (auto *told = listener(view, StateUIHearingHand)) told->handState = state;
    }

    /// Hangs every handler once; each asks what the view listens for as it runs.
    /// A press with Alt over a view two fingers move, at `phase`: told as the press and the view's middle, held from
    /// the view's others - the hand's - while it is down. Whether it was.
    bool mirrored(int64_t view, IInspectable const &sender, input::PointerRoutedEventArgs const &args, StateUIPhase phase) {
        using winrt::Windows::System::VirtualKeyModifiers;
        auto found = listening.find(view);
        if (found == listening.end() || !(found->second.hearing & (StateUIHearingPinches | StateUIHearingRotations)))
            return false;
        auto &entry = found->second;
        auto id = static_cast<int64_t>(args.Pointer().PointerId());
        auto element = sender.as<xaml::FrameworkElement>();
        if (phase == 0) {
            if ((args.KeyModifiers() & VirtualKeyModifiers::Menu) != VirtualKeyModifiers::Menu) return false;
            if (!args.GetCurrentPoint(element).Properties().IsLeftButtonPressed()) return false;
            entry.mirroring = id;
            element.CapturePointer(args.Pointer());
        } else if (entry.mirroring != id) {
            return false;
        }
        if (phase >= 2) entry.mirroring = -1;
        auto at = args.GetCurrentPoint(element).Position();
        args.Handled(true);
        callbacks.mirrored(view, phase, at.X, at.Y, element.ActualWidth() / 2, element.ActualHeight() / 2);
        return true;
    }

    void listen(xaml::UIElement const &element, int64_t view, Listening &entry) {
        entry.tapped = element.Tapped(guarded("handling Tapped",
            [view](IInspectable const &sender, input::TappedRoutedEventArgs const &args) {
            if (!listener(view, StateUIHearingTaps)) return;
            args.Handled(true);
            tap(view, args.GetPosition(sender.as<xaml::UIElement>()));
        }));
        entry.doubleTapped = element.DoubleTapped(
            guarded("handling DoubleTapped",
                [view](IInspectable const &sender, input::DoubleTappedRoutedEventArgs const &args) {
                if (!listener(view, StateUIHearingTaps)) return;
                args.Handled(true);
                tap(view, args.GetPosition(sender.as<xaml::UIElement>()));
            }));
        // A finger or a pen held: WinUI tells a mouse button held as no hold.
        entry.holding = element.Holding(guarded("handling Holding",
            [view](IInspectable const &sender, input::HoldingRoutedEventArgs const &args) {
            if (!listener(view, StateUIHearingHolds)) return;
            if (args.HoldingState() != winrt::Microsoft::UI::Input::HoldingState::Started) return;
            args.Handled(true);
            tell(view, StateUIHeardHold, 0, args.GetPosition(sender.as<xaml::UIElement>()));
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
            // A press with Alt over a view two fingers move is two fingers, mirrored about its middle.
            if (mirrored(view, sender, args, StateUIPhaseBegan)) return;
            if (auto *hand = listener(view, StateUIHearingHand)) {
                auto point = args.GetCurrentPoint(sender.as<xaml::UIElement>());
                bool contact = point.PointerDeviceType() != winrt::Microsoft::UI::Input::PointerDeviceType::Mouse
                    || point.Properties().IsLeftButtonPressed();
                if (contact) {
                    // Told where it went down on the content and in the layout: a press standing still may hold the
                    // view there; a finger joining a hand the layout holds is held with it.
                    hand->handPointers.insert(args.Pointer().PointerId());
                    auto on = onContent(args);
                    auto in = point.Position();
                    auto state = callbacks.finger(
                        view, StateUIPressPhaseDown, args.Pointer().PointerId(), on.X, on.Y, in.X, in.Y, when(args));
                    if (auto *told = listener(view, StateUIHearingHand)) told->handState = state;
                    if (state == StateUIHandTaken) sender.as<xaml::UIElement>().CapturePointer(args.Pointer());
                }
            }
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || !args.GetCurrentPoint(sender.as<xaml::UIElement>()).Properties().IsLeftButtonPressed()) return;
            entry->pointer = args.Pointer().PointerId();
            entry->dragging = false;
            entry->capturing = false;
            tell(view, StateUIHeardPress, StateUIPressPhaseDown, onContent(args));
        }));
        entry.movedToken = element.PointerMoved(guarded("handling PointerMoved",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            pointer(view, StateUIHeardPointerMoved, sender, args);
            if (mirrored(view, sender, args, StateUIPhaseChanged)) return;
            // A finger of a hand that may yet be the layout's, or is: the layout holds the pointer once it takes it.
            auto *hand = listener(view, StateUIHearingHand);
            if (hand && hand->handState != StateUIHandLeft && hand->handPointers.count(args.Pointer().PointerId())) {
                auto was = hand->handState;
                auto on = onContent(args);
                auto in = args.GetCurrentPoint(sender.as<xaml::UIElement>()).Position();
                auto state = callbacks.finger(
                    view, StateUIPressPhaseMoved, args.Pointer().PointerId(), on.X, on.Y, in.X, in.Y, when(args));
                if (auto *told = listener(view, StateUIHearingHand)) told->handState = state;
                if (state == StateUIHandTaken) {
                    if (was != StateUIHandTaken) sender.as<xaml::UIElement>().CapturePointer(args.Pointer());
                    args.Handled(true);
                }
            }
            auto *entry = listener(view, StateUIHearingDrags);
            if (!entry || entry->pointer != args.Pointer().PointerId()) return;
            tell(view, StateUIHeardPress, StateUIPressPhaseMoved, onContent(args));
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
            if (mirrored(view, sender, args, StateUIPhaseEnded)) return;
            handUp(view, args.Pointer().PointerId(), StateUIPressPhaseLetGo, when(args));
            letGo(view, StateUIPressPhaseLetGo);
        }));
        entry.lost = element.PointerCaptureLost(guarded("handling PointerCaptureLost",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            if (mirrored(view, sender, args, StateUIPhaseCancelled)) return;
            handUp(view, args.Pointer().PointerId(), StateUIPressPhaseTakenAway, when(args));
            letGo(view, StateUIPressPhaseTakenAway);
        }));
        entry.canceled = element.PointerCanceled(guarded("handling PointerCanceled",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            if (mirrored(view, sender, args, StateUIPhaseCancelled)) return;
            handUp(view, args.Pointer().PointerId(), StateUIPressPhaseTakenAway, when(args));
            letGo(view, StateUIPressPhaseTakenAway);
        }));
        entry.started = element.ManipulationStarted(
            guarded("handling ManipulationStarted",
                [view](IInspectable const &sender, input::ManipulationStartedRoutedEventArgs const &args) {
                auto at = shares(sender, args.Position());
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, StateUIPhaseBegan, at, 1);
                if (listener(view, StateUIHearingRotations)) tell(view, StateUIHeardRotation, StateUIPhaseBegan, at, 0);
            }));
        entry.delta = element.ManipulationDelta(
            guarded("handling ManipulationDelta",
                [view](IInspectable const &sender, input::ManipulationDeltaRoutedEventArgs const &args) {
                bool pinches = listener(view, StateUIHearingPinches), rotations = listener(view, StateUIHearingRotations);
                if (!pinches && !rotations) return;
                args.Handled(true);
                auto at = shares(sender, args.Position());
                if (pinches) tell(view, StateUIHeardPinch, StateUIPhaseChanged, at, args.Delta().Scale);
                if (rotations) tell(view, StateUIHeardRotation, StateUIPhaseChanged, at, args.Delta().Rotation);
            }));
        // A wheel turned with Control is a pinch: Windows tells a trackpad's pinch so to an application that hears no
        // gesture of it, and Control with a mouse's wheel zooms.
        entry.wheel = element.PointerWheelChanged(guarded("handling PointerWheelChanged",
            [view](IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            using winrt::Windows::System::VirtualKeyModifiers;
            if (!listener(view, StateUIHearingPinches)) return;
            if ((args.KeyModifiers() & VirtualKeyModifiers::Control) != VirtualKeyModifiers::Control) return;
            auto point = args.GetCurrentPoint(sender.as<xaml::UIElement>());
            args.Handled(true);
            tell(view, StateUIHeardWheelPinch, 0, shares(sender, point.Position()),
                point.Properties().MouseWheelDelta() / 120.0);
        }));
        entry.completed = element.ManipulationCompleted(
            guarded("handling ManipulationCompleted",
                [view](IInspectable const &sender, input::ManipulationCompletedRoutedEventArgs const &args) {
                auto at = shares(sender, args.Position());
                if (listener(view, StateUIHearingPinches)) tell(view, StateUIHeardPinch, StateUIPhaseEnded, at, 1);
                if (listener(view, StateUIHearingRotations)) tell(view, StateUIHeardRotation, StateUIPhaseEnded, at, 0);
            }));
        ++hung;
    }

    void unhook(xaml::UIElement const &element, Listening const &entry) {
        element.Tapped(entry.tapped);
        element.DoubleTapped(entry.doubleTapped);
        element.Holding(entry.holding);
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
        element.PointerWheelChanged(entry.wheel);
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
        if (!(hearing & StateUIHearingHand)) untrack(view);
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
        auto modes = input::ManipulationModes::None;
        if (hearing & StateUIHearingPinches) modes |= input::ManipulationModes::Scale;
        if (hearing & StateUIHearingRotations) modes |= input::ManipulationModes::Rotate;
        element.ManipulationMode(modes == input::ManipulationModes::None ? input::ManipulationModes::System : modes);
        holdHitArea(element, view);
    } catch (...) {
        report("listening for the user's input");
    }
}

extern "C" void stateui_winui_hear_hand(StateUIObjectRef handle, int64_t view, StateUIHandAxis axis, int32_t pinches) {
    try {
        if (axis == StateUIHandAxisNone) return untrack(view);
        auto element = as<xaml::UIElement>(handle);
        auto found = tracking.find(view);
        if (found == tracking.end()) {
            auto visual = xaml::Hosting::ElementCompositionPreview::GetElementVisual(element);
            auto tracker = interactions::InteractionTracker::CreateWithOwner(visual.Compositor(), winrt::make<HandTracker>(view));
            auto source = interactions::VisualInteractionSource::Create(visual);
            source.ManipulationRedirectionMode(interactions::VisualInteractionSourceRedirectionMode::CapableTouchpadAndPointerWheel);
            source.ScaleSourceMode(interactions::InteractionSourceMode::Disabled);
            tracker.InteractionSources().Add(source);
            // Room enough never to reach an end: the run has its own, or none.
            float room = 1e6f;
            tracker.MinPosition({-room, -room, 0});
            tracker.MaxPosition({room, room, 0});
            tracker.MinScale(1e-4f);
            tracker.MaxScale(1e4f);
            found = tracking.emplace(view, HandTracking{tracker, source}).first;
        }
        // The layout's axis alone - a hand across it goes on to whatever holds the layout - or, a pan's, both.
        auto &source = found->second.source;
        bool across = axis == StateUIHandAxisHorizontal || axis == StateUIHandAxisEveryWay;
        bool down = axis == StateUIHandAxisVertical || axis == StateUIHandAxisEveryWay;
        auto on = interactions::InteractionSourceMode::EnabledWithInertia, off = interactions::InteractionSourceMode::Disabled;
        source.PositionXSourceMode(across ? on : off);
        source.PositionYSourceMode(down ? on : off);
        auto wheelOn = interactions::InteractionSourceRedirectionMode::Enabled;
        auto wheelOff = interactions::InteractionSourceRedirectionMode::Disabled;
        source.PointerWheelConfig().PositionXSourceMode(across ? wheelOn : wheelOff);
        source.PointerWheelConfig().PositionYSourceMode(down ? wheelOn : wheelOff);
        // A touchpad's pinch and the wheel turned with Control scale where the layout magnifies: WinUI's own zoom,
        // never a scroll - the wheel's scale is redirected only where the source's own is on.
        source.ScaleSourceMode(pinches ? on : off);
        source.PointerWheelConfig().ScaleSourceMode(pinches ? wheelOn : wheelOff);
    } catch (...) {
        report("hearing the hand over a layout");
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

extern "C" void stateui_winui_double_tap(double *tap) {
    try {
        tap[0] = GetDoubleClickTime() / 1000.0;
        tap[1] = GetSystemMetricsForDpi(SM_CXDOUBLECLK, USER_DEFAULT_SCREEN_DPI) / 2.0;
    } catch (...) {
        report("reading the double click");
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

extern "C" bool stateui_winui_is_loaded(StateUIObjectRef handle) {
    try {
        return as<xaml::FrameworkElement>(handle).IsLoaded();
    } catch (...) {
        report("reading whether an element is loaded");
        return false;
    }
}
