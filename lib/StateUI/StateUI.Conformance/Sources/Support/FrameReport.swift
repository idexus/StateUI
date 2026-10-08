// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers a view's frame report carries, read as a case compares them: in whole points, which every host's
/// layout gives alike.
public enum FrameReport {
    /// Where the view stands in its parent: x, y, width, height.
    public static func place(_ numbers: [Double]) -> [Double] {
        numbers.prefix(4).map { $0.rounded() }
    }

    /// The view's size: width, height.
    public static func size(_ numbers: [Double]) -> [Double] {
        Array(place(numbers).dropFirst(2))
    }

    /// Where the view's corner stands in its window: x, y.
    public static func inWindow(_ numbers: [Double]) -> [Double] {
        numbers.count >= 6 ? [numbers[4].rounded(), numbers[5].rounded()] : []
    }

    /// Where the view's corner stands in its window once it moved `up` points higher: moved first, then rounded,
    /// as the report standing there is read - a corner at half a point rounds away from nought, up at 53.5 and down
    /// at -146.5, so a rounded corner moved would stand a point off.
    public static func inWindow(_ numbers: [Double], movedUp up: Double) -> [Double] {
        var moved = numbers
        if moved.count >= 6 { moved[5] -= up }
        return inWindow(moved)
    }

    /// Where the view's corner stands from the corner of its window's content, clear of the chrome: x, y.
    public static func inContent(_ numbers: [Double]) -> [Double] {
        numbers.count >= 8 ? [numbers[6].rounded(), numbers[7].rounded()] : []
    }
}
