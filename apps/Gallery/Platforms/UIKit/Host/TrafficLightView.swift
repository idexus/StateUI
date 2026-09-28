// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import UIKit

/// Three lamps in a housing, one lit at a time - an ordinary `UIView` that
/// knows nothing of StateUI.
///
/// `register()`, at the end of this file, adds it for `TrafficLightContract`,
/// and that registration is the whole bridge. The Swift half is
/// Sources/Samples/Interop/TrafficLight.swift.
final class TrafficLightView: UIView {
    /// A lamp was tapped; the argument is its index, top to bottom.
    ///
    /// The control does not switch itself: it reports, and whoever owns the
    /// state decides.
    var onLampTapped: ((Int) -> Void)?

    /// Which lamp is lit, as the member number the Swift side sends: stop 0,
    /// caution 1, go 2. Anything else - the initial -1 included - lights
    /// nothing.
    var signal: Int32 = -1 {
        didSet { if signal != oldValue { repaint() } }
    }

    private static let lampColors = [
        UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1),
        UIColor(red: 0.961, green: 0.710, blue: 0.275, alpha: 1),
        UIColor(red: 0.275, green: 0.706, blue: 0.373, alpha: 1),
    ]

    private static let lampSide: CGFloat = 44
    private static let spacing: CGFloat = 10
    private static let padding: CGFloat = 12

    private var lamps: [UIView] = []

    /// The housing and its three lamps, wired once.
    init() {
        super.init(frame: .zero)

        backgroundColor = UIColor(red: 0.102, green: 0.090, blue: 0.145, alpha: 1)
        layer.cornerRadius = 18

        for _ in 0..<3 {
            let lamp = UIView()
            lamp.layer.cornerRadius = Self.lampSide / 2
            lamp.isUserInteractionEnabled = false
            addSubview(lamp)
            lamps.append(lamp)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        repaint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TrafficLightView is created in code")
    }

    /// As tall as its three lamps and their padding, and as wide as one.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(
            width: Self.padding * 2 + Self.lampSide,
            height: Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for (index, lamp) in lamps.enumerated() {
            lamp.frame = CGRect(
                x: (bounds.width - Self.lampSide) / 2,
                y: Self.padding + CGFloat(index) * (Self.lampSide + Self.spacing),
                width: Self.lampSide,
                height: Self.lampSide)
        }
    }

    /// Which lamp the tap landed on, reported - the state decides what is
    /// lit next.
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let at = recognizer.location(in: self)

        for (index, lamp) in lamps.enumerated() where lamp.frame.contains(at) {
            onLampTapped?(index)
            return
        }
    }

    /// The lit lamp at full colour, the others dimmed to embers.
    private func repaint() {
        for (index, lamp) in lamps.enumerated() {
            let colour = Self.lampColors[index]
            lamp.backgroundColor = Int32(index) == signal ? colour : colour.withAlphaComponent(0.18)
        }
    }
}

// MARK: - Registration

extension TrafficLightView {
    /// Adds the light for `TrafficLightContract`: `create` makes the view once
    /// per element and wires the tap it reports, and `property` puts the
    /// described signal on it. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
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
    }
}
