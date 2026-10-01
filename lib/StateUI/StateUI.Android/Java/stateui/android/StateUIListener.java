// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.text.Editable;
import android.text.InputType;
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
        View.OnFocusChangeListener,
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
        // Only the user's move: a progress the program sets - which some devices animate, telling it later - is not.
        if (fromUser) StateUIHost.moved(view, progress);
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

    /**
     * Once per Return: the keyboard's action, or a hardware key as it is let go - its release then reaches no field
     * the submission put the focus on. An editor's hardware Return starts a new line.
     */
    @Override
    public boolean onEditorAction(TextView field, int action, KeyEvent event) {
        if (event == null) {
            StateUIHost.submitted(view);
            return false;
        }
        if ((field.getInputType() & InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0) return false;
        if (event.getAction() == KeyEvent.ACTION_UP) StateUIHost.submitted(view);
        return true;
    }

    @Override
    public void onScrollChange(View scroller, int x, int y, int oldX, int oldY) {
        StateUIHost.scrolled(view);
    }

    /** What `touched`'s element listens for; see `StateUIGestures.configure`. */
    void setGestures(View touched, float density, boolean countsTaps, boolean drags, boolean pinch, boolean pointer) {
        if (gestures == null) gestures = new StateUIGestures(touched, view, density);
        gestures.configure(countsTaps, drags, pinch, pointer);
    }

    /** Whether a gesture under way takes the rest of the touch from the view's own handling. */
    boolean takesTouch() {
        return gestures != null && gestures.taking();
    }

    /** Whether the view's element listens for a gesture, so a touch nothing else takes stays the view's. */
    boolean wantsTouch() {
        return gestures != null && gestures.wanted();
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
    public void onFocusChange(View focused, boolean hasFocus) {
        StateUIHost.focusChanged(view, hasFocus);
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
