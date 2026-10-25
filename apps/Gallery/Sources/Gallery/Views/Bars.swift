// The bars a gallery wears.

import StateUI

extension BarElement where Modified == Self {
    /// The bars as the gallery's looks say in each theme - the system's
    /// accent being `system`: what they are made of and the words on them.
    /// The platform's own in both themes leaves them unwritten, which follows
    /// the system's look and its accent.
    func barLook(light: SurfaceLook, dark: SurfaceLook, system: Color) -> Self {
        guard light.material != .platform || dark.material != .platform else { return self }
        let (made, otherwise) = (light.material(system: system, for: .bar), dark.material(system: system, for: .bar))
        let (words, other) = (light.barWords ?? Palette.text, dark.barWords ?? Palette.text)
        // One look in both themes is one value; two are a pair.
        return barBackground(made == otherwise ? made ?? Material(light: nil, dark: nil)
                                               : Material(light: made, dark: otherwise))
            .barForegroundColor(words == other ? words : Color(light: words, dark: other))
    }

    /// The bars' buttons standing as `style` says, on the accent's tint where
    /// `tinted`.
    func barButtons(_ style: ToolbarStyle, tinted: Bool) -> Self {
        let styled = toolbarStyle(style)
        return tinted ? styled.barButtonBackgroundColor(Color.accent.opacity(0.25)) : styled
    }
}
