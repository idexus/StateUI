// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Build;
import android.os.Bundle;
import android.system.ErrnoException;
import android.system.Os;
import android.view.KeyEvent;
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
    /** What {@link StateUIEnvironment#watch} started, stopped as the activity goes. */
    private Object[] environmentWatch;
    /** Whether the activity was made in the night theme: another night makes it again, its controls drawn in it. */
    private boolean madeAtNight;

    /** Before Android 12, the activity is made in the night mode the application holds. */
    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        StateUIEnvironment.holdNightMode(this);
    }

    @Override
    protected void onCreate(Bundle state) {
        madeAtNight = StateUIEnvironment.night(this);
        setTheme(madeAtNight
                ? android.R.style.Theme_DeviceDefault_NoActionBar
                : android.R.style.Theme_DeviceDefault_Light_NoActionBar);
        super.onCreate(state);

        takeSwitches();
        System.loadLibrary(library());

        FrameLayout root = new FrameLayout(this);
        setContentView(root);
        StateUIViews.edgeToEdge(this, root, !StateUIEnvironment.night(this));

        StateUIHost.start(this, root, getResources().getDisplayMetrics().density);
        StateUIEnvironment.settleNightMode(this);
        environmentWatch = StateUIEnvironment.watch(this);
        // A link the activity was started for - not again when it is made anew for a new configuration.
        if (state == null) openLink(getIntent());
    }

    /**
     * A link the system asks the running activity to open - one its head's intent filter takes, the activity
     * single in its task - reaches the host as the start's own does. An activity of the application's own calls
     * {@code super} where it overrides.
     */
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        openLink(intent);
    }

    /** The address {@code intent} asks the application to view, handed to the host; nothing for any other intent. */
    private static void openLink(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction()) || intent.getDataString() == null) return;
        StateUIHost.linkOpened(intent.getDataString());
    }

    @Override
    protected void onResume() {
        super.onResume();
        StateUIHost.phase(StateUIHost.ACTIVE, false);
    }

    @Override
    protected void onPause() {
        super.onPause();
        StateUIHost.phase(StateUIHost.INACTIVE, isChangingConfigurations());
    }

    @Override
    protected void onStop() {
        super.onStop();
        StateUIHost.phase(StateUIHost.BACKGROUND, isChangingConfigurations());
    }

    /**
     * The activity finishing - not one made again for a new configuration - takes its window away, its questions
     * answered as dismissed; one made again leaves its questions for the next to ask.
     */
    @Override
    protected void onDestroy() {
        StateUIEnvironment.unwatch(this, environmentWatch);
        if (isFinishing()) {
            StateUIDialogs.dismissAll();
            StateUIHost.destroying();
        } else {
            StateUIDialogs.leaveAll();
        }
        super.onDestroy();
    }

    /**
     * The display turned or resized: the host reads it again. Another night - a manifest that takes a change of the
     * night mode itself - makes the activity again, as one that does not is: its native controls take a theme only
     * as they are made.
     */
    @Override
    public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        if (StateUIEnvironment.night(this) != madeAtNight) {
            recreate();
            return;
        }
        StateUIHost.configured();
    }

    /** A document picker's result reaches the files it was asked for; any other the activity's own. */
    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        if (!StateUIFiles.result(this, request, result, data)) super.onActivityResult(request, result, data);
    }

    /**
     * A key a view takes reaches it before any view does - its going up with it; a key the views do not take reaches
     * a shortcut the tree states, as Android's own shortcuts come after them.
     */
    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        int action = event.getAction();
        if (action != KeyEvent.ACTION_MULTIPLE && StateUIHost.keyTaken(action == KeyEvent.ACTION_DOWN,
                event.getKeyCode(), event.getUnicodeChar(0), event.getMetaState())) return true;
        if (super.dispatchKeyEvent(event)) return true;
        return event.getAction() == KeyEvent.ACTION_DOWN
                && StateUIHost.keyPressed(event.getKeyCode(), event.getUnicodeChar(0), event.getMetaState());
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

    /**
     * The {@code STATEUI_} switches the run script passed as extras, set in
     * this process's environment before the runtime reads it.
     */
    private void takeSwitches() {
        Bundle extras = getIntent().getExtras();
        if (extras == null) {
            return;
        }
        for (String name : extras.keySet()) {
            String value = extras.getString(name);
            if (!name.startsWith("STATEUI_") || value == null) {
                continue;
            }
            try {
                Os.setenv(name, value, true);
            } catch (ErrnoException ignored) {
                // A switch the process cannot take is a diagnostic left off.
            }
        }
    }
}
