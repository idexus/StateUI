// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Build;
import android.os.Bundle;
import android.widget.FrameLayout;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

/**
 * The activity an application's Android head declares. It loads the head's
 * library, named by the manifest's {@code stateui.library}, and starts the
 * Swift host in an empty root that keeps out of the system bars, in the
 * system's light or dark theme.
 */
public class StateUIActivity extends Activity {
    /** The way back the Swift host takes while it has one; made only where the system has the type. */
    private Object backCallback;
    private boolean handlesBack;

    @Override
    protected void onCreate(Bundle state) {
        setTheme(StateUIEnvironment.night(this)
                ? android.R.style.Theme_DeviceDefault_NoActionBar
                : android.R.style.Theme_DeviceDefault_Light_NoActionBar);
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

    /** The display turned or resized: the host reads it again. */
    @Override
    public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        StateUIHost.configured();
    }

    /** Before the system's own predictive back: the host goes back, or the activity does as it always does. */
    @SuppressWarnings("deprecation")
    @Override
    public void onBackPressed() {
        if (!StateUIHost.back()) super.onBackPressed();
    }

    /**
     * Whether the host has a way back - a page to pop, a sheet to dismiss, a drawer to close. From Android 13
     * the system asks only while one is registered, and shows its predictive back to the launcher otherwise.
     */
    void setHandlesBack(boolean handles) {
        if (handles == handlesBack || Build.VERSION.SDK_INT < 33) {
            handlesBack = handles;
            return;
        }
        handlesBack = handles;

        OnBackInvokedDispatcher dispatcher = getOnBackInvokedDispatcher();
        if (backCallback == null) backCallback = (OnBackInvokedCallback) StateUIHost::back;
        if (handles) {
            dispatcher.registerOnBackInvokedCallback(
                    OnBackInvokedDispatcher.PRIORITY_DEFAULT, (OnBackInvokedCallback) backCallback);
        } else {
            dispatcher.unregisterOnBackInvokedCallback((OnBackInvokedCallback) backCallback);
        }
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
