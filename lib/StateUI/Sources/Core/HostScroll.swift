// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Deterministic scroll arithmetic shared by native StateUI hosts.
///
/// A platform still supplies its native gesture and inertial destination. This
/// type defines what StateUI does with that destination when an application
/// asks for momentum scaling, a grid or a maximum number of grid points.
@_spi(Host) public enum HostScrollMath {
    /// The nearest point of a grid. An exact halfway value belongs to the next
    /// point in its direction, identically on every host.
    public static func snapPoint(
        _ offset: Double,
        interval: Double,
        from origin: Double
    ) -> Double {
        guard offset.isFinite, interval.isFinite, origin.isFinite, interval > 0 else {
            return offset
        }
        let item = ((offset - origin) / interval)
            .rounded(.toNearestOrAwayFromZero)
        return origin + item * interval
    }

    /// The grid item nearest an offset.
    public static func nearestItem(
        _ offset: Double,
        interval: Double,
        from origin: Double
    ) -> Int {
        guard offset.isFinite, interval.isFinite, origin.isFinite, interval > 0 else {
            return 0
        }
        return Int(((offset - origin) / interval)
            .rounded(.toNearestOrAwayFromZero))
    }

    /// Scales a platform's inertial destination from where the reader began.
    public static func projectedDestination(
        start: Double,
        nativeDestination: Double,
        momentum: Double
    ) -> Double {
        guard start.isFinite, nativeDestination.isFinite else { return start }
        let fraction = momentum.isFinite ? max(0, momentum) : 1
        return start + ((nativeDestination - start) * fraction)
    }

    /// Holds a destination to at most `limit` grid points from the movement's
    /// start. A non-positive limit or interval leaves it unchanged.
    public static func heldDestination(
        _ destination: Double,
        movementStart: Double,
        interval: Double,
        from origin: Double,
        atMost limit: Int
    ) -> Double {
        guard destination.isFinite, movementStart.isFinite, interval.isFinite,
              origin.isFinite, interval > 0, limit > 0 else {
            return destination
        }
        let started = nearestItem(movementStart, interval: interval, from: origin)
        let wanted = nearestItem(destination, interval: interval, from: origin)
        let held = min(max(wanted, started - limit), started + limit)
        return origin + Double(held) * interval
    }

    /// The next grid point in the direction of a discrete input such as one
    /// mouse-wheel notch. Unlike nearest-point settling, even a small input
    /// advances instead of falling back to the point it started from.
    public static func steppedGridDestination(
        from offset: Double,
        direction: Double,
        interval: Double,
        origin: Double
    ) -> Double {
        guard offset.isFinite, direction.isFinite, interval.isFinite,
              origin.isFinite, direction != 0, interval > 0 else {
            return offset
        }

        let position = (offset - origin) / interval
        let tolerance = 0.000_000_001
        let item = direction > 0
            ? (position + tolerance).rounded(.down) + 1
            : (position - tolerance).rounded(.up) - 1
        return origin + item * interval
    }

    /// An offset inside measured content. Before either extent is known only
    /// the leading edge can be enforced without discarding a pending offset.
    public static func reachable(
        _ offset: Double,
        content: Double,
        viewport: Double
    ) -> Double {
        let leading = max(0, offset.isFinite ? offset : 0)
        guard content.isFinite, viewport.isFinite, content > 0, viewport > 0 else {
            return leading
        }
        return min(leading, max(0, content - viewport))
    }
}
