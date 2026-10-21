// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.graphics.Typeface;

/** A Picker as Android shows it - a dropdown spinner, or a radio group of its values - written alike. */
interface StateUIChoosing {
    /**
     * The options - null where they stay - the title shown while nothing is chosen, and, where `writesChoice`,
     * the chosen index, -1 for none.
     */
    void setChoices(String[] options, String title, int chosen, boolean writesChoice);

    /**
     * The words' size in points - 0 for the theme's - and their unit, their color - 0 for the theme's - their face,
     * and where they stand.
     */
    void setLook(float size, int unit, int color, Typeface face, int alignment);
}
