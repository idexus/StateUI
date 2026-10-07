// The bars a gallery wears.

import StateUI

extension BarElement where Modified == Self {
    /// The bars painted in `colour`, their words white on it; nil leaves the
    /// platform's own bars, which follow the system's look and its accent.
    func paintedBars(_ colour: Color?) -> Self {
        guard let colour else { return self }
        return barBackgroundColor(colour).barForegroundColor(Palette.onBrand)
    }
}
