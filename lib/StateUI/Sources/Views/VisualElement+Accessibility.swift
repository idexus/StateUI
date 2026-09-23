// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the view says about itself.
// Design: docs/design/views/modifiers.md#accessibility-and-automation

extension VisualElementProperties {
    /// What a screen reader says this view is.
    ///
    ///     Button(icon: "bin.png").accessibilityLabel("Delete")
    ///
    /// For a control whose meaning is carried by a picture, a colour or where
    /// it sits. On a control that shows its own words it replaces them.
    public func accessibilityLabel(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityLabel, value) }

    /// What a screen reader says using the view does, after saying what it is.
    ///
    ///     Switch($lit)
    ///         .accessibilityLabel("Ceiling light")
    ///         .accessibilityHint("Turns the light on and off")
    ///
    /// Only for a view the user can act on.
    public func accessibilityHint(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityHint, value) }

    /// Whether a screen reader skips this view.
    ///
    ///     ColorBox(.silver).isAccessibilityHidden(true)
    ///
    /// For decoration: a rule, a shadow, a picture repeating the words beside
    /// it. Left unsaid, the platform decides, which is nearly always right; say
    /// `false` where a platform left something out, and never hide a view the
    /// user has to act on.
    public func isAccessibilityHidden(_ value: Bool) -> Modified { setValue(VisualElementContract.isAccessibilityHidden, value) }

    /// Whether a screen reader skips this view and everything inside it.
    ///
    ///     VStack { … }.automationExcludedWithChildren(true)
    ///
    /// For a panel on screen that is not the user's business - a decorative
    /// header, a card standing behind the one in front.
    public func automationExcludedWithChildren(_ value: Bool) -> Modified { setValue(VisualElementContract.automationExcludedWithChildren, value) }

    /// That this view is a heading, and how deep.
    ///
    ///     Label("Settings").fontSize(24).accessibilityHeadingLevel(.level1)
    ///
    /// A screen-reader user moves through a long page by its headings; a Label
    /// drawn big is not one until this says so.
    public func accessibilityHeadingLevel(_ value: HeadingLevel) -> Modified { setValue(VisualElementContract.accessibilityHeadingLevel, value) }
}
