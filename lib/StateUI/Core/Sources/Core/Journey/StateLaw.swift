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
    /// lanes from the end of a journey, nowhere for a placement run, text, a feed or
    /// a plain value.
    static func within(_ door: StateKind, lanes: Int) -> Int? {
        switch door {
        case .property: return lanes >= 8 ? lanes - 5 : nil
        case .placement, .text, .feed, .plain: return nil
        }
    }

    /// A law as its lanes.
    static func lanes(of motion: Motion) -> [Double] {
        if motion.isInherited { return [StateLaw.inherited, 0, 0] }
        if motion.isCustom { return [StateLaw.custom, 0, 0] }
        if motion.milliseconds == 0 && motion.law == .eased { return [0, 0, 0] }

        return motion.law == .spring
            ? [3, Double(motion.milliseconds), motion.factor]
            : [2, Double(motion.milliseconds), Double(motion.curve.rawValue)]
    }

    /// And back.
    /// Lanes that say no law - too few, or numbers no whole one is near - read as the plainest, never a trap.
    static func motion(of lanes: [Double]) -> Motion {
        let length = lanes.count > 1 ? Int(nearest: lanes[1]).map { max($0, 0) } ?? 0 : 0
        let third = lanes.count > 2 ? lanes[2] : 0

        switch lanes.first ?? 0 {
        case 1: return .inherited
        case 2 where lanes.count > 2:
            let curve = Int(nearest: third).flatMap { Int32(exactly: $0) }.flatMap(Easing.init(rawValue:))
            return .eased(.milliseconds(length), curve ?? .cubicOut)
        case 3 where lanes.count > 2: return .spring(response: .milliseconds(length), damping: third)
        case 4: return .custom
        default: return Motion.none
        }
    }
}
