// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a window stands in its life, as state a view reads. Every host maps
/// its native window lifecycle onto the same sequence.
public enum WindowPhase: Sendable {
    /// The platform has made the window, and nothing has happened to it
    /// since.
    case created

    /// The window is in front and receiving input.
    case activated

    /// The window is showing and is not the one in use - on its way to the
    /// background, or with another in front.
    case deactivated

    /// The window cannot be seen: it is minimized, hidden with its scene, or
    /// its application is hidden or in the background. The place to save -
    /// nothing promises the process comes back.
    case stopped

    /// The window has come back after `stopped`, on its way to `activated`.
    case resumed

    /// The window is going away - the last word before it has gone, whoever
    /// took it.
    case destroying
}
