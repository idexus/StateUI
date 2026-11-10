// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.view.Menu;

/**
 * The window the conformance families show their pages in: a page stands in a window as an application's does, laid
 * out by the window's traversal, which tells its global layout and places it in the window.
 */
public final class TestActivity extends Activity {
    /** Android closed the context menu over the activity: none stands open now. */
    @Override
    public void onContextMenuClosed(Menu menu) {
        TestMenus.contextMenuClosed();
        super.onContextMenuClosed(menu);
    }
}
