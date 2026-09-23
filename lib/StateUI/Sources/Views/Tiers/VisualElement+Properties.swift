// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElementProperties {
    /// Whether the view is shown.
    ///
    /// Showing and hiding animate: a view being hidden fades out before it
    /// goes, one being shown fades in, so two views swapped in one place
    /// cross-fade. A view on its way out answers no touch. A view described for
    /// the first time is simply shown or not; `.motion(.none)` makes the change
    /// immediate.
    public func isVisible(_ value: Bool) -> Modified { setValue(VisualElementContract.isVisible, value) }

    /// Whether the view responds to the user. Disabling a container disables
    /// everything in it.
    public func isEnabled(_ value: Bool) -> Modified { setValue(VisualElementContract.isEnabled, value) }

    /// Whether the view and everything in it ignore input: a tap or a click
    /// goes through to whatever is behind it. Not the same as disabled - a
    /// disabled view still takes the touch and does nothing with it. A layout
    /// whose children should still answer says `letsInputThrough` instead.
    public func ignoresInput(_ value: Bool) -> Modified { setValue(VisualElementContract.ignoresInput, value) }

    /// Which way the view lays its content out - and, for a language written
    /// right to left, the edge everything starts from.
    ///
    ///     VStack { … }.layoutDirection(.rightToLeft)
    ///
    /// It is INHERITED: a view left at `.inherited` takes whatever the view
    /// above it has, so an application usually says it once at the top.
    public func layoutDirection(_ value: LayoutDirection) -> Modified { setValue(VisualElementContract.layoutDirection, value) }

    /// How opaque the view is, from 0 to 1.
    public func opacity(_ value: Double) -> Modified { setValue(VisualElementContract.opacity, value) }

    /// What is drawn behind the view. A view's own background replaces its
    /// style's, and a `Color(light:dark:)` follows the system theme.
    public func background(_ value: Color) -> Modified { setValue(VisualElementContract.background, .color(value)) }

    /// What is drawn behind the view, when one colour will not do.
    ///
    ///     VStack { … }.background(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    ///
    /// The same property as a colour background: the one written last wins.
    public func background(_ value: Brush) -> Modified { setValue(VisualElementContract.background, .brush(value)) }

    /// How wide the view asks to be, in device units. A request: the layout has
    /// the last word.
    public func width(_ value: Double) -> Modified { setValue(VisualElementContract.width, value) }

    /// How tall the view asks to be.
    public func height(_ value: Double) -> Modified { setValue(VisualElementContract.height, value) }

    /// The width below which the view asks not to be squeezed.
    public func minimumWidth(_ value: Double) -> Modified { setValue(VisualElementContract.minimumWidth, value) }

    /// The height below which the view asks not to be squeezed.
    public func minimumHeight(_ value: Double) -> Modified { setValue(VisualElementContract.minimumHeight, value) }

    /// The width above which the view asks not to be stretched.
    public func maximumWidth(_ value: Double) -> Modified { setValue(VisualElementContract.maximumWidth, value) }

    /// The height above which the view asks not to be stretched.
    public func maximumHeight(_ value: Double) -> Modified { setValue(VisualElementContract.maximumHeight, value) }

    /// Turns the view, in degrees clockwise, about its pivot.
    public func rotation(_ value: Double) -> Modified { setValue(VisualElementContract.rotation, value) }

    /// How this view is moved, turned and sized: one transform about the view's
    /// own centre, the same picture on every platform.
    ///
    ///     Card(item).transform(.rotate(14).scale(0.9).translate(100, 200))
    ///
    /// The parts apply in the order written, each to what the parts before it
    /// made; see `ViewTransform`. It writes `translationX`, `translationY`,
    /// `rotation`, `scaleX` and `scaleY`, so use it or those five, not both.
    ///
    /// - Parameter transform: how the view is moved, turned and sized - a value
    ///   that can be held in `@State`.
    /// - Returns: the view, transformed.
    public func transform(_ transform: ViewTransform) -> Modified {
        modified {
            $0.write(VisualElementContract.translationX, transform.x)
            $0.write(VisualElementContract.translationY, transform.y)
            $0.write(VisualElementContract.rotation, transform.rotation)
            $0.write(VisualElementContract.scaleX, transform.width)
            $0.write(VisualElementContract.scaleY, transform.height)
        }
    }

    /// Tips the view about its horizontal axis, in degrees - the top going away
    /// as the bottom comes forward.
    ///
    /// Each platform projects a turn out of the screen's plane through its own
    /// camera, so the same angle draws differently; for the same picture
    /// everywhere, write a `scaleY` of `cos(angle)` instead.
    public func rotationX(_ value: Double) -> Modified { setValue(VisualElementContract.rotationX, value) }

    /// Turns the view about its vertical axis, in degrees - one side going away
    /// as the other comes forward.
    ///
    /// Each platform projects a turn out of the screen's plane through its own
    /// camera, so the same angle draws differently; for the same picture
    /// everywhere, write a `scaleX` of `cos(angle)` instead.
    public func rotationY(_ value: Double) -> Modified { setValue(VisualElementContract.rotationY, value) }

    /// Resizes the view about its pivot, 1 being its natural size. Drawing
    /// only: the space the layout gave it does not change.
    public func scale(_ value: Double) -> Modified { setValue(VisualElementContract.scale, value) }

    /// Scales the view sideways only.
    public func scaleX(_ value: Double) -> Modified { setValue(VisualElementContract.scaleX, value) }

    /// Scales the view up and down only.
    public func scaleY(_ value: Double) -> Modified { setValue(VisualElementContract.scaleY, value) }

    /// Moves the view sideways from where the layout put it, in device units.
    public func translationX(_ value: Double) -> Modified { setValue(VisualElementContract.translationX, value) }

    /// Moves the view up or down from where the layout put it.
    public func translationY(_ value: Double) -> Modified { setValue(VisualElementContract.translationY, value) }

    /// Where rotation and scaling pivot, sideways: 0 the left edge, 1 the right,
    /// 0.5 the middle.
    public func pivotX(_ value: Double) -> Modified { setValue(VisualElementContract.pivotX, value) }

    /// The same, vertically: 0 the top edge, 1 the bottom.
    public func pivotY(_ value: Double) -> Modified { setValue(VisualElementContract.pivotY, value) }

    /// Who is drawn on top where views overlap, higher being nearer the front.
    public func zIndex(_ value: Int) -> Modified { setValue(VisualElementContract.zIndex, value) }
}

extension VisualElement {
    /// `pivotX` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func pivotX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.pivotX, by: state)
    }

    /// `pivotY` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func pivotY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.pivotY, by: state)
    }

    /// `background` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func background(_ state: Binding<Color>) -> Modified {
        journey(VisualElementContract.background.token, by: state)
    }

    /// `layoutDirection` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func layoutDirection(_ state: Binding<LayoutDirection>) -> Modified {
        plain(VisualElementContract.layoutDirection, by: state)
    }

    /// `height` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func height(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.height, by: state)
    }

    /// `ignoresInput` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func ignoresInput(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.ignoresInput, by: state)
    }

    /// `isEnabled` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isEnabled(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.isEnabled, by: state)
    }

    /// `isVisible` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isVisible(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.isVisible, by: state)
    }

    /// `maximumHeight` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func maximumHeight(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.maximumHeight, by: state)
    }

    /// `maximumWidth` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func maximumWidth(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.maximumWidth, by: state)
    }

    /// `minimumHeight` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func minimumHeight(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.minimumHeight, by: state)
    }

    /// `minimumWidth` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func minimumWidth(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.minimumWidth, by: state)
    }

    /// `opacity` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func opacity(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.opacity, by: state)
    }

    /// `rotation` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotation(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotation, by: state)
    }

    /// `rotationX` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotationX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotationX, by: state)
    }

    /// `rotationY` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotationY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotationY, by: state)
    }

    /// `scale` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scale(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scale, by: state)
    }

    /// `scaleX` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scaleX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scaleX, by: state)
    }

    /// `scaleY` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scaleY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scaleY, by: state)
    }

    /// `translationX` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func translationX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.translationX, by: state)
    }

    /// `translationY` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func translationY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.translationY, by: state)
    }

    /// `width` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func width(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.width, by: state)
    }

    /// `zIndex` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func zIndex(_ state: Binding<Int>) -> Modified {
        plain(VisualElementContract.zIndex, by: state)
    }
}
