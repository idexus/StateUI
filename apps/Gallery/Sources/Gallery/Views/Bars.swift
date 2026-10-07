// The bars a gallery wears.

import StateUI

extension BarElement where Modified == Self {
    /// The bars as `look` says, in `accent` - the system's accent being
    /// `system`: the platform's own leaves them unwritten, which follows the
    /// system's look and its accent.
    func bars(_ look: BarLook, in accent: AccentChoice, system: Color) -> Self {
        switch look {
        case .platform: return self
        case .clear: return barBackgroundColor(.transparent).barForegroundColor(Palette.text)
        case .tinted:
            return barBackgroundColor(accent.translucentColor(system: system)).barForegroundColor(Palette.text)
        case .colour: return barBackgroundColor(accent.color(system: system)).barForegroundColor(Palette.onBrand)
        }
    }
}
