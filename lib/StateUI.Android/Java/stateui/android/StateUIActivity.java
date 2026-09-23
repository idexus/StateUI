// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.widget.FrameLayout;

/**
 * The activity an application's Android head declares. It loads the head's
 * library, named by the manifest's {@code stateui.library}, and starts the
 * Swift host in an empty root that keeps out of the system bars.
 */
public class StateUIActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        System.loadLibrary(library());

        FrameLayout root = new FrameLayout(this);
        root.setFitsSystemWindows(true);
        setContentView(root);

        StateUIHost.start(this, root, getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onResume() {
        super.onResume();
        StateUIHost.phase(StateUIHost.ACTIVE);
    }

    @Override
    protected void onPause() {
        super.onPause();
        StateUIHost.phase(StateUIHost.INACTIVE);
    }

    @Override
    protected void onStop() {
        super.onStop();
        StateUIHost.phase(StateUIHost.BACKGROUND);
    }

    /** The head's library, as the manifest names it on this activity. */
    private String library() {
        try {
            ActivityInfo info = getPackageManager()
                .getActivityInfo(getComponentName(), PackageManager.GET_META_DATA);
            String library = info.metaData == null ? null : info.metaData.getString("stateui.library");
            if (library == null) {
                throw new IllegalStateException("the manifest names no stateui.library on " + getComponentName());
            }
            return library;
        } catch (PackageManager.NameNotFoundException missing) {
            throw new IllegalStateException(missing);
        }
    }
}
