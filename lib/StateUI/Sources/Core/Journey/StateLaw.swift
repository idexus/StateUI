// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a law lies on the image: three lanes, the first saying which kind.
/// Design: docs/design/core/journeys.md#the-law-on-the-image
enum StateLaw {
    /// How many lanes a law takes.
    static let lanes = 3

    /// The first lane of the element's own law, resolved as the host reads it.
    static let inherited: Double = 1

    /// The first lane where an engine on this side animates the value; the host never
    /// sees it.
    static let custom: Double = 4

    /// Where a law's three lanes start for a value going through this door: five
    /// lanes from the end of a journey, last in a placement run, nowhere for text, a
    /// feed or a plain value.
    static func within(_ door: StateKind, lanes: Int) -> Int? {
        switch door {
        case .property: return lanes >= 8 ? lanes - 5 : nil
        case .placement: return lanes >= StateLaw.lanes ? lanes - StateLaw.lanes : nil
        case .text, .feed, .plain: return nil
        }
    }

    /// A law as its lanes.
    static func lanes(of motion: Motion) -> [Double] {
        if motion.isInherited { return [StateLaw.inherited, 0, 0] }
        if motion.isCustom { return [StateLaw.custom, 0, 0] }
        if motion.millis == 0 && motion.law == .eased { return [0, 0, 0] }

        return motion.law == .spring
            ? [3, Double(motion.millis), motion.factor]
            : [2, Double(motion.millis), Double(motion.curve.rawValue)]
    }

    /// And back.
    static func motion(of lanes: [Double]) -> Motion {
        switch lanes.first ?? 0 {
        case 1: return .inherited
        case 2: return .eased(UInt(max(lanes[1], 0)), Easing(rawValue: Int32(lanes[2])) ?? .cubicOut)
        case 3: return .spring(response: UInt(max(lanes[1], 0)), damping: lanes[2])
        case 4: return .custom
        default: return Motion.none
        }
    }
}
