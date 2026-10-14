// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A picture from the platform's own icons: each platform draws its own for each - SF Symbols on Apple platforms,
/// Segoe Fluent Icons on Windows, the icon theme on GNOME, Android's own drawables, and StateUI's on the Web.
///
///     Image(.icon(.share))
///     Button("Delete").icon(.icon(.delete))
///
/// An icon a platform has none of shows nothing there, as its platform's marks say.
public enum Icon: Int32, Sendable, CaseIterable {
    /// Adds something: a plus.
    case add = 0

    /// Takes something away: a minus.
    case remove = 1

    /// Closes or dismisses: a cross.
    case close = 2

    /// Done or chosen: a tick.
    case checkmark = 3

    /// Searches: a magnifying glass.
    case search = 4

    /// Shares with others.
    case share = 5

    /// Edits: a pencil.
    case edit = 6

    /// Deletes: a bin.
    case delete = 7

    /// Settings: a gear, or the platform's own sign for them.
    case settings = 8

    /// Tells more: an i in a circle.
    case info = 9

    /// Warns: an exclamation mark in a triangle.
    case warning = 10

    /// Goes home: a house.
    case home = 11

    /// Goes back: a chevron to the leading side.
    case back = 12

    /// Goes forward: a chevron to the trailing side.
    case forward = 13

    /// Up: a chevron upward.
    case up = 14

    /// Down: a chevron downward.
    case down = 15

    /// Opens a menu: three lines.
    case menu = 16

    /// More actions: three dots.
    case more = 17

    /// Loads again: a circling arrow.
    case refresh = 18

    /// Downloads: an arrow down.
    case download = 19

    /// Uploads: an arrow up.
    case upload = 20

    /// Copies: two sheets.
    case copy = 21

    /// A favourite: a star.
    case star = 22

    /// Liked: a heart.
    case heart = 23

    /// A person: a figure.
    case person = 24

    /// Mail: an envelope.
    case mail = 25

    /// A date: a calendar.
    case calendar = 26

    /// A time: a clock.
    case clock = 27

    /// Locked: a padlock.
    case lock = 28

    /// Plays: a triangle.
    case play = 29

    /// Pauses: two bars.
    case pause = 30

    /// A link: two links of a chain.
    case link = 31
}

extension Icon: HostRepresentable {}
