// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One view's way in a shared transition drawn by both views - the entering one onto its place, the one leaving onto
/// where the entering one lands - and what each frame works out of how far it has got: the corner of the view rounded
/// on it, drawn from the one partner's to the other's, and its opacity as the two cross over near the smaller.
/// Design: docs/design/host/motion.md#a-shared-transition-drawn-by-both
struct SharedWay {
    /// Each number the way moves: where it set out and where it lands.
    var spans: [Prop: (from: Double, to: Double)]

    /// The view whose corner is rounded on the way - the one traveling, or the one the leaving view holds - and
    /// its corner as drawn at the way's start and at its end.
    weak var rounded: MountedElement?
    var corner: (from: Double, to: Double)?

    /// Whether the view fades in as the two cross over, or out; nil where no partner is drawn to cross with.
    var comes: Bool?

    /// The part of the way the two views cross over in.
    var crossing: ClosedRange<Double>

    /// The numbers a way moves, and those a frame works out of it.
    static let moved: Set<Prop> = [.translationX, .translationY, .scaleX, .scaleY]

    /// How far the way has got, from 0 to 1, as `standing` says where a number stands: read off the scale that
    /// moves most, else the move that does; at its end where nothing moves.
    func progress(_ standing: (Prop) -> Double?) -> Double {
        var lead: (property: Prop, span: (from: Double, to: Double))?
        for (properties, least) in [([Prop.scaleX, .scaleY], 0.01), ([Prop.translationX, .translationY], 0.5)] {
            for property in properties {
                guard let span = spans[property], abs(span.to - span.from) > least,
                      abs(span.to - span.from) > abs((lead?.span.to ?? 0) - (lead?.span.from ?? 0))
                else { continue }
                lead = (property, span)
            }
            if lead != nil { break }
        }
        guard let lead else { return 1 }

        let now = standing(lead.property) ?? lead.span.to
        return min(max((now - lead.span.from) / (lead.span.to - lead.span.from), 0), 1)
    }

    /// How opaque the view is drawn at `progress`, of its own opacity: crossing over smoothly in `crossing`.
    func opacity(at progress: Double) -> Double {
        guard let comes else { return 1 }

        let length = crossing.upperBound - crossing.lowerBound
        let part = length > 0 ? min(max((progress - crossing.lowerBound) / length, 0), 1) : progress < 1 ? 0 : 1
        let crossed = part * part * (3 - 2 * part)
        return comes ? crossed : 1 - crossed
    }

    /// The corner drawn at `progress`, straight from the one partner's to the other's; nil where none is carried.
    func drawnCorner(at progress: Double) -> Double? {
        corner.map { $0.from + ($0.to - $0.from) * progress }
    }

    /// Where two partners cross over: in the part of the way nearest the smaller - early as the view grows from
    /// `source` to `destination`, late as it shrinks, midway between two of a size.
    static func crossing(from source: Rect, to destination: Rect) -> ClosedRange<Double> {
        let grows = destination.width * destination.height / max(source.width * source.height, 1)
        return grows > 1.25 ? 0...0.45 : grows < 0.8 ? 0.55...1 : 0.25...0.75
    }
}
