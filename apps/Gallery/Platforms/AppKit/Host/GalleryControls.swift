// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import GalleryUI
import StateUIAppKit

/// The gallery's own controls, as this host realizes them.
///
/// The contracts and the Swift halves are shared by every host - see
/// Sources/Samples/Interop - and this is the half that says what each one IS
/// on screen: `create` makes the view once per element and wires what it
/// reports, and each `property` puts a described value on it. What every view
/// shares - margins, alignment, opacity, gestures - the host applies around
/// them.
enum GalleryControls {
    /// Registers every control this host realizes. Said once, before the
    /// application runs.
    @MainActor
    static func register() {
        StateUIAppKit.realizes(TrafficLightContract.self, create: { reports -> TrafficLightView in
            let light = TrafficLightView()
            light.onLampTapped = { index in
                reports.raise(TrafficLightContract.lampTapped, index)
            }
            return light
        }) { light in
            light.property(TrafficLightContract.signal) { view, signal in
                view.signal = (signal ?? .stop).rawValue
            }
            light.raises(TrafficLightContract.lampTapped)
        }

        StateUIAppKit.realizes(RatingBarContract.self, create: { reports -> RatingBarView in
            let bar = RatingBarView()

            // A tapped star is the READER's change: it lands on the state the
            // value is carried in, and raises the event with it - so an
            // application hears it once, whether it holds the rating in a
            // state or in a handler.
            bar.onRatingChanged = { rating in
                reports.report(
                    RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            bar.property(RatingBarContract.rating) { view, rating in
                view.rating = rating ?? 0
            }
            bar.raises(RatingBarContract.ratingChanged)
        }
    }
}
