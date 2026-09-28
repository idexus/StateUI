// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Rect;
import android.view.View;
import android.view.ViewGroup;
import androidx.recyclerview.widget.DefaultItemAnimator;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.LinearSmoothScroller;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;

/**
 * An ItemsView: AndroidX's recycler over the list's identities. It asks the Swift view for each cell it makes, tells
 * it which entry a cell shows, when a cell comes on screen and when one is let go of, and which items are in view.
 * What the Swift view says - the entries and their changes, how they stand, the choice, a scroll - it applies once
 * the recycler is neither laying out nor scrolling, in the order said.
 */
final class StateUIItemsView extends RecyclerView {
    /** An entry's kind: an item, or a header or a footer. */
    static final int ITEM = 0, EDGE = 1;

    /** How the entries stand: down, across, or in columns. */
    static final int LIST = 0, ROW = 1, GRID = 2;

    /** How many items the user may choose, as StateUI numbers it. */
    static final int MULTIPLE = 2;

    /** Where an item scrolled to stands, as StateUI numbers it. */
    private static final int START = 0, END = 2, NEAREST = 3;

    private final long view;
    private final Adapter adapter = new Adapter();
    private final DefaultItemAnimator animator = new DefaultItemAnimator();

    private String[] identities = new String[0];
    private int[] kinds = new int[0];
    private final HashMap<String, Integer> positions = new HashMap<>();

    /** Each entry's columns in a grid, and the room it keeps around it - leading, top, trailing, bottom - in pixels. */
    private int[] spans = new int[0];
    private int[] insets = new int[0];

    private int shape = LIST;
    private final HashSet<String> chosen = new HashSet<>();
    private int mode;
    private boolean tappable;

    /** What waits for the recycler to finish laying out or scrolling, and whether a turn is asked to run it. */
    private final ArrayDeque<Runnable> waiting = new ArrayDeque<>();
    private boolean draining;

    private boolean reporting;

    /** What stands an item where it was asked, once the recycler has laid it out. */
    private Runnable settling;

    StateUIItemsView(Context context, long view) {
        super(context);
        this.view = view;
        animator.setSupportsChangeAnimations(false);
        setItemAnimator(null);
        // The pool keeps every cell it is given: a cell dropped would leave its Swift view behind.
        getRecycledViewPool().setMaxRecycledViews(ITEM, Integer.MAX_VALUE);
        getRecycledViewPool().setMaxRecycledViews(EDGE, Integer.MAX_VALUE);
        setLayoutManager(new LinearLayoutManager(context));
        addItemDecoration(new Spacing());
        setAdapter(adapter);
        addOnScrollListener(new OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recycler, int dx, int dy) {
                reportLater();
            }
        });
    }

    /** As wide as it is offered and as tall as it is given: its room is what its layout gives, never its items. */
    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        int width = MeasureSpec.getMode(widthSpec) == MeasureSpec.UNSPECIFIED ? 0 : MeasureSpec.getSize(widthSpec);
        int height = MeasureSpec.getMode(heightSpec) == MeasureSpec.EXACTLY ? MeasureSpec.getSize(heightSpec) : 0;
        super.onMeasure(
                MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY));
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        Runnable settle = settling;
        settling = null;
        if (settle != null) settle.run();
    }

    // What the Swift view says.

    /**
     * The entries, their kinds, columns and room, and the changes from the ones before - runs of removed positions,
     * last first, then runs of inserted ones, first first, each a start and a count - animated or not.
     */
    void setEntries(String[] identities, int[] kinds, int[] spans, int[] insets, int[] removed, int[] inserted,
            boolean animated) {
        change(() -> {
            this.identities = identities;
            this.kinds = kinds;
            this.spans = spans;
            this.insets = insets;
            positions.clear();
            for (int position = 0; position < identities.length; position++) positions.put(identities[position], position);

            setItemAnimator(animated ? animator : null);
            for (int run = 0; run + 1 < removed.length; run += 2) adapter.notifyItemRangeRemoved(removed[run], removed[run + 1]);
            for (int run = 0; run + 1 < inserted.length; run += 2) adapter.notifyItemRangeInserted(inserted[run], inserted[run + 1]);
            reportLater();
        });
    }

    /** How the entries stand - `shape`, in `columns` for a grid - with each one's columns and room. */
    void setPlacement(int shape, int columns, int[] spans, int[] insets) {
        change(() -> {
            this.spans = spans;
            this.insets = insets;
            if (shape != this.shape) {
                this.shape = shape;
                setLayoutManager(manager(shape, columns));
                return;
            }
            LayoutManager manager = getLayoutManager();
            if (manager instanceof GridLayoutManager && ((GridLayoutManager) manager).getSpanCount() != columns) {
                ((GridLayoutManager) manager).setSpanCount(columns);
            } else {
                invalidateItemDecorations();
            }
        });
    }

    /** The items chosen, how many the user may choose, and whether a tap on an item does anything. */
    void setChoice(String[] chosen, int mode, boolean tappable) {
        change(() -> {
            this.chosen.clear();
            this.chosen.addAll(Arrays.asList(chosen));
            this.mode = mode;
            this.tappable = tappable;
            for (int index = 0; index < getChildCount(); index++) {
                Cell cell = (Cell) getChildViewHolder(getChildAt(index));
                show(cell);
            }
        });
    }

    /** Scrolls until the item of `identity` stands where `anchor` says, gliding there or not. */
    void scrollToItem(String identity, int anchor, boolean animated) {
        change(() -> {
            Integer position = positions.get(identity);
            LinearLayoutManager manager = (LinearLayoutManager) getLayoutManager();
            if (position == null || manager == null) return;
            if (animated) {
                LinearSmoothScroller scroller = new LinearSmoothScroller(getContext()) {
                    @Override
                    public int calculateDtToFit(int viewStart, int viewEnd, int boxStart, int boxEnd, int snap) {
                        return distance(viewStart, viewEnd, boxStart, boxEnd, anchor);
                    }
                };
                scroller.setTargetPosition(position);
                manager.startSmoothScroll(scroller);
                return;
            }
            if (manager.findViewByPosition(position) != null) {
                settle(position, anchor);
                return;
            }
            // Far off, the item is brought to the start first, and stood where it was asked once it is laid out.
            int first = manager.findFirstVisibleItemPosition();
            int standing = anchor == NEAREST ? (position < first ? START : END) : anchor;
            manager.scrollToPositionWithOffset(position, 0);
            settling = () -> settle(position, standing);
        });
    }

    /** The list left: nothing waits, and the recycler lets every cell go. */
    void release() {
        waiting.clear();
        settling = null;
        setAdapter(null);
    }

    /** Scrolls by `pixels` along the list, as far as it goes: a test's scroll. */
    void scrollAlong(int pixels) {
        if (shape == ROW) scrollBy(pixels, 0); else scrollBy(0, pixels);
    }

    /** How far along the list stands now, in pixels. */
    int scrolled() {
        return shape == ROW ? computeHorizontalScrollOffset() : computeVerticalScrollOffset();
    }

    /** The items the cells on screen show chosen, in the order they show. */
    String[] chosen() {
        HashSet<String> shown = new HashSet<>();
        for (int index = 0; index < getChildCount(); index++) {
            View child = getChildAt(index);
            Cell cell = (Cell) getChildViewHolder(child);
            if (child.isActivated() && cell.identity != null) shown.add(cell.identity);
        }
        return Arrays.stream(identities).filter(shown::contains).toArray(String[]::new);
    }

    /** How many items the user may choose, as the cells tell assistive technology. */
    int mode() {
        return mode;
    }

    /** The cell showing the entry of `identity`, where one does. */
    View cellShowing(String identity) {
        Integer position = positions.get(identity);
        return position == null ? null : getLayoutManager().findViewByPosition(position);
    }

    // What the recycler does.

    /** Runs `change` now, or once the recycler stops laying out and scrolling, after every change waiting before it. */
    private void change(Runnable change) {
        if (waiting.isEmpty() && !isComputingLayout()) {
            change.run();
            return;
        }
        waiting.add(change);
        if (draining) return;
        draining = true;
        post(this::drain);
    }

    private void drain() {
        if (isComputingLayout()) {
            post(this::drain);
            return;
        }
        draining = false;
        while (!waiting.isEmpty()) waiting.poll().run();
    }

    private LayoutManager manager(int shape, int columns) {
        if (shape != GRID) {
            return new LinearLayoutManager(getContext(), shape == ROW ? HORIZONTAL : VERTICAL, false);
        }
        GridLayoutManager grid = new GridLayoutManager(getContext(), Math.max(columns, 1));
        grid.setSpanSizeLookup(new GridLayoutManager.SpanSizeLookup() {
            @Override
            public int getSpanSize(int position) {
                int columns = grid.getSpanCount();
                return position < spans.length ? Math.max(1, Math.min(spans[position], columns)) : 1;
            }
        });
        return grid;
    }

    /** Stands the item at `position`, laid out, where `anchor` says. */
    private void settle(int position, int anchor) {
        View shown = getLayoutManager().findViewByPosition(position);
        if (shown == null) return;
        boolean across = shape == ROW;
        int dt = across
                ? distance(shown.getLeft(), shown.getRight(), getPaddingLeft(), getWidth() - getPaddingRight(), anchor)
                : distance(shown.getTop(), shown.getBottom(), getPaddingTop(), getHeight() - getPaddingBottom(), anchor);
        if (dt != 0) scrollAlong(-dt);
    }

    /** How far the item from `start` to `end` moves to stand where `anchor` says in the room from `boxStart` to `boxEnd`. */
    private int distance(int start, int end, int boxStart, int boxEnd, int anchor) {
        if (shape == ROW && getLayoutDirection() == LAYOUT_DIRECTION_RTL) {
            int width = getWidth();
            return -StateUIHost.itemsDistance(view, anchor, width - end, width - start, width - boxEnd, width - boxStart);
        }
        return StateUIHost.itemsDistance(view, anchor, start, end, boxStart, boxEnd);
    }

    /** Tells the Swift view the items in view, once the scroll or the layout under way is over. */
    private void reportLater() {
        if (reporting) return;
        reporting = true;
        post(this::report);
    }

    private void report() {
        reporting = false;
        LinearLayoutManager manager = (LinearLayoutManager) getLayoutManager();
        if (manager == null) return;
        int first = manager.findFirstVisibleItemPosition();
        int last = manager.findLastVisibleItemPosition();
        if (first == NO_POSITION || last < first || last >= identities.length) return;
        StateUIHost.itemsShowing(view, Arrays.copyOfRange(identities, first, last + 1));
    }

    /** Shows a cell's entry chosen or not, and whether a tap on it does anything. */
    private void show(Cell cell) {
        if (!(cell.itemView instanceof StateUIItemCell) || cell.getItemViewType() != ITEM) return;
        ((StateUIItemCell) cell.itemView).setChosen(
                cell.identity != null && chosen.contains(cell.identity), mode == MULTIPLE);
        cell.itemView.setClickable(tappable);
    }

    /** A cell as wide as the list, or as tall as the row, and as long as its entry asks. */
    private void fit(View cell) {
        int width = shape == ROW ? ViewGroup.LayoutParams.WRAP_CONTENT : ViewGroup.LayoutParams.MATCH_PARENT;
        int height = shape == ROW ? ViewGroup.LayoutParams.MATCH_PARENT : ViewGroup.LayoutParams.WRAP_CONTENT;
        ViewGroup.LayoutParams params = cell.getLayoutParams();
        if (params == null) {
            cell.setLayoutParams(new LayoutParams(width, height));
        } else if (params.width != width || params.height != height) {
            params.width = width;
            params.height = height;
            cell.setLayoutParams(params);
        }
    }

    private static final class Cell extends ViewHolder {
        final long number;
        String identity;

        Cell(View view) {
            super(view);
            number = ((StateUIViewGroup) view).number();
        }
    }

    private final class Adapter extends RecyclerView.Adapter<Cell> {
        @Override
        public int getItemCount() {
            return identities.length;
        }

        @Override
        public int getItemViewType(int position) {
            return kinds[position];
        }

        @Override
        public Cell onCreateViewHolder(ViewGroup parent, int kind) {
            return new Cell(StateUIHost.itemCell(view, kind));
        }

        @Override
        public void onBindViewHolder(Cell cell, int position) {
            cell.identity = identities[position];
            fit(cell.itemView);
            show(cell);
            StateUIHost.itemHeld(view, cell.number, cell.identity);
        }

        @Override
        public void onViewAttachedToWindow(Cell cell) {
            if (cell.identity != null) StateUIHost.itemShown(view, cell.number, cell.identity);
        }

        @Override
        public void onViewRecycled(Cell cell) {
            cell.identity = null;
            StateUIHost.itemLetGo(view, cell.number);
        }

        /** A cell with a view still moving is let go of all the same: it stays the Swift view's to reuse. */
        @Override
        public boolean onFailedToRecycleView(Cell cell) {
            return true;
        }
    }

    /** The room each entry keeps around it, its leading side at the start of the reading direction. */
    private final class Spacing extends ItemDecoration {
        @Override
        public void getItemOffsets(Rect room, View child, RecyclerView parent, State state) {
            int position = parent.getChildAdapterPosition(child);
            if (position == NO_POSITION || 4 * position + 3 >= insets.length) {
                room.setEmpty();
                return;
            }
            int leading = insets[4 * position];
            int trailing = insets[4 * position + 2];
            boolean rtl = getLayoutDirection() == LAYOUT_DIRECTION_RTL;
            room.set(rtl ? trailing : leading, insets[4 * position + 1], rtl ? leading : trailing, insets[4 * position + 3]);
        }
    }
}
