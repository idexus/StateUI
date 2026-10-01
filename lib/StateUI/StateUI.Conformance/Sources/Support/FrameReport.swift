// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers a view's frame report carries, read as a case compares them: in whole pixels, which every host's
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

    /// Where the view's corner stands from the corner of its window's content, clear of the chrome: x, y.
    public static func inContent(_ numbers: [Double]) -> [Double] {
        numbers.count >= 8 ? [numbers[6].rounded(), numbers[7].rounded()] : []
    }
}
