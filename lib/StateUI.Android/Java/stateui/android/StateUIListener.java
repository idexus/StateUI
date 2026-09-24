// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.text.Editable;
import android.text.TextWatcher;
import android.view.ContextMenu;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.widget.CompoundButton;
import android.widget.SeekBar;
import android.widget.TextView;

/** What the user does to one view, forwarded to the Swift view by its number. */
final class StateUIListener implements View.OnClickListener, CompoundButton.OnCheckedChangeListener,
        SeekBar.OnSeekBarChangeListener, TextWatcher, TextView.OnEditorActionListener,
        View.OnScrollChangeListener, View.OnTouchListener, View.OnHoverListener, View.OnCreateContextMenuListener,
        ViewTreeObserver.OnGlobalLayoutListener, ViewTreeObserver.OnScrollChangedListener {
    private final long view;

    /** Whether a finger holds the view, as its touches last said. */
    private boolean holding;

    /** The gestures the view's element listens for; none before it first listens for one. */
    private StateUIGestures gestures;

    StateUIListener(long view) {
        this.view = view;
    }

    @Override
    public void onClick(View clicked) {
        StateUIHost.clicked(view);
    }

    @Override
    public void onCheckedChanged(CompoundButton button, boolean on) {
        StateUIHost.toggled(view, on);
    }

    @Override
    public void onProgressChanged(SeekBar bar, int progress, boolean fromUser) {
        StateUIHost.moved(view, progress);
    }

    @Override
    public void onStartTrackingTouch(SeekBar bar) {
        StateUIHost.dragStarted(view);
    }

    @Override
    public void onStopTrackingTouch(SeekBar bar) {
        StateUIHost.dragCompleted(view);
    }

    @Override
    public void beforeTextChanged(CharSequence text, int start, int count, int after) {}

    @Override
    public void onTextChanged(CharSequence text, int start, int before, int count) {}

    @Override
    public void afterTextChanged(Editable text) {
        StateUIHost.textChanged(view, text.toString());
    }

    /** Once per Return: the keyboard's action, or a hardware key as it goes down. */
    @Override
    public boolean onEditorAction(TextView field, int action, KeyEvent event) {
        if (event == null) {
            StateUIHost.submitted(view);
            return false;
        }
        if (event.getAction() == KeyEvent.ACTION_DOWN) StateUIHost.submitted(view);
        return true;
    }

    @Override
    public void onScrollChange(View scroller, int x, int y, int oldX, int oldY) {
        StateUIHost.scrolled(view);
    }

    /** Which gestures `touched`'s element listens for; see `StateUIGestures.configure`. */
    void setGestures(View touched, float density, int taps, int panFingers, int swipeDirections,
                     float swipeThreshold, boolean pinch, boolean pointer) {
        if (gestures == null) gestures = new StateUIGestures(touched, view, density);
        gestures.configure(taps, panFingers, swipeDirections, swipeThreshold, pinch, pointer);
    }

    /**
     * Says when a finger takes hold of the view and when it lets go, and follows the gestures its element
     * listens for; the view handles the touch itself unless a gesture takes it.
     */
    @Override
    public boolean onTouch(View touched, MotionEvent event) {
        int action = event.getActionMasked();
        boolean ends = action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL;
        if (holding == ends) {
            holding = !ends;
            StateUIHost.held(view, holding);
        }
        return gestures != null && gestures.onTouch(event);
    }

    @Override
    public boolean onHover(View hovered, MotionEvent event) {
        return gestures != null && gestures.onHover(event);
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View asked, ContextMenu.ContextMenuInfo information) {
        StateUIHost.menuOpening(view, menu);
    }

    @Override
    public void onGlobalLayout() {
        StateUIHost.laidOut();
    }

    @Override
    public void onScrollChanged() {
        StateUIHost.laidOut();
    }
}
