// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gallery's traffic light and rating bar as WinUI elements that know nothing of StateUI: a housing of three
// lamps drawn with XAML's shapes, and WinUI's own RatingControl.

#include "Relay.h"

#include <algorithm>
#include <chrono>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace gallery;
namespace animation = winrt::Microsoft::UI::Xaml::Media::Animation;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

GalleryWinUICallbacks gallery::callbacks{};

namespace {
    /// The lamps' colours, top to bottom: red, amber, green.
    constexpr uint8_t lampColors[3][3] = {{229, 72, 77}, {245, 181, 70}, {70, 180, 95}};
    constexpr wchar_t const *lampNames[3] = {L"Red lamp", L"Amber lamp", L"Green lamp"};

    /// Whether the relay itself writes a rating, which the control then tells no one.
    bool writingRating = false;
}

extern "C" void gallery_winui_set_callbacks(GalleryWinUICallbacks const *given) {
    try {
        callbacks = *given;
    } catch (...) {
        report("taking the callbacks");
    }
}

extern "C" void gallery_winui_release(GalleryObjectRef object) {
    try {
        if (object) reinterpret_cast<::IUnknown *>(object)->Release();
    } catch (...) {
        report("letting go of an element");
    }
}

extern "C" GalleryObjectRef gallery_traffic_light_make(int64_t control) {
    try {
        controls::Border housing;
        housing.Background(brush(26, 23, 37));
        housing.CornerRadius(xaml::CornerRadius{18, 18, 18, 18});
        housing.Padding(xaml::Thickness{12, 12, 12, 12});
        housing.HorizontalAlignment(xaml::HorizontalAlignment::Center);
        controls::StackPanel lamps;
        lamps.Spacing(10);
        for (int32_t lamp = 0; lamp < 3; ++lamp) {
            shapes::Ellipse ellipse;
            ellipse.Width(44);
            ellipse.Height(44);
            ellipse.Fill(brush(lampColors[lamp][0], lampColors[lamp][1], lampColors[lamp][2]));
            ellipse.Opacity(lamp == 0 ? 1 : 0.18);
            xaml::Automation::AutomationProperties::SetName(ellipse, lampNames[lamp]);
            // The light does not switch itself: it reports, and whoever owns the state decides.
            ellipse.Tapped([control, lamp](auto const &, xaml::Input::TappedRoutedEventArgs const &args) {
                args.Handled(true);
                if (callbacks.lampTapped) callbacks.lampTapped(control, lamp);
            });
            lamps.Children().Append(ellipse);
        }
        housing.Child(lamps);
        return detach(housing);
    } catch (...) {
        report("making a traffic light");
        return nullptr;
    }
}

extern "C" void gallery_traffic_light_set_signal(GalleryObjectRef light, int32_t signal) {
    try {
        auto lamps = as<controls::Border>(light).Child().as<controls::StackPanel>().Children();
        for (uint32_t lamp = 0; lamp < lamps.Size(); ++lamp) {
            lamps.GetAt(lamp).as<xaml::UIElement>().Opacity(static_cast<int32_t>(lamp) == signal ? 1 : 0.18);
        }
    } catch (...) {
        report("lighting a lamp");
    }
}

extern "C" GalleryObjectRef gallery_rating_bar_make(int64_t control) {
    try {
        controls::RatingControl rating;
        rating.MaxRating(5);
        rating.IsClearEnabled(false);
        rating.ValueChanged([control](controls::RatingControl const &sender, auto const &) {
            if (writingRating || !callbacks.rated) return;
            callbacks.rated(control, std::max(sender.Value(), 0.0));
        });
        return detach(rating);
    } catch (...) {
        report("making a rating bar");
        return nullptr;
    }
}

extern "C" void gallery_rating_bar_set_rating(GalleryObjectRef bar, double value) {
    try {
        auto rating = as<controls::RatingControl>(bar);
        // WinUI's rating says "none" as -1.
        auto shown = value > 0 ? value : -1.0;
        if (rating.Value() == shown) return;
        writingRating = true;
        rating.Value(shown);
        writingRating = false;
    } catch (...) {
        writingRating = false;
        report("rating");
    }
}

extern "C" void gallery_rating_bar_flash(GalleryObjectRef bar) {
    try {
        auto rating = as<controls::RatingControl>(bar);
        animation::DoubleAnimation fade;
        fade.From(1.0);
        fade.To(0.25);
        fade.Duration(xaml::DurationHelper::FromTimeSpan(std::chrono::milliseconds(120)));
        fade.AutoReverse(true);
        fade.RepeatBehavior(animation::RepeatBehaviorHelper::FromCount(2));
        // Stopped, the opacity is the host's again.
        fade.FillBehavior(animation::FillBehavior::Stop);
        animation::Storyboard::SetTarget(fade, rating);
        animation::Storyboard::SetTargetProperty(fade, L"Opacity");
        animation::Storyboard flash;
        flash.Children().Append(fade);
        flash.Begin();
    } catch (...) {
        report("flashing a rating bar");
    }
}
