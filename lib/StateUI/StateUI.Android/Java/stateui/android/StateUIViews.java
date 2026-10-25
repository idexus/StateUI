// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.res.ColorStateList;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.DisplayCutout;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.FrameLayout;
import android.widget.TextView;
import java.util.ArrayList;

/** What the Swift host does to a view in one call where Android asks for several. */
final class StateUIViews {
    private StateUIViews() {}

    /** Measures the view for the two specs; its width in the high half, its height in the low one. */
    static long measure(View view, int widthSpec, int heightSpec) {
        view.measure(widthSpec, heightSpec);
        return ((long) view.getMeasuredWidth() << 32) | (view.getMeasuredHeight() & 0xFFFFFFFFL);
    }

    /**
     * Measures the view at exactly its place, then lays it out there. A view laid out at that size, with nothing
     * in it asking to be laid out again, is only moved: its drawing, and a layer holding it, stay as they are.
     */
    static void place(View view, int left, int top, int right, int bottom) {
        if (view.isLaidOut() && !view.isLayoutRequested()
                && view.getWidth() == right - left && view.getHeight() == bottom - top) {
            view.offsetLeftAndRight(left - view.getLeft());
            view.offsetTopAndBottom(top - view.getTop());
            return;
        }

        view.measure(
                View.MeasureSpec.makeMeasureSpec(right - left, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(bottom - top, View.MeasureSpec.EXACTLY));
        view.layout(left, top, right, bottom);
    }

    /**
     * Slides the view across to `translationX` pixels and fades it to `alpha`, over `duration` milliseconds, and
     * stands it as `visibility` says: shown as the slide starts, hidden once it has ended.
     */
    static void slide(View view, float translationX, float alpha, long duration, int visibility) {
        view.animate().cancel();
        if (duration <= 0 || visibility == View.VISIBLE) view.setVisibility(visibility);
        if (duration <= 0) {
            view.setTranslationX(translationX);
            view.setAlpha(alpha);
            return;
        }
        view.animate().translationX(translationX).alpha(alpha).setDuration(duration)
                .withEndAction(() -> view.setVisibility(visibility)).start();
    }

    /**
     * Slides the view across from `from` to `to` pixels over `duration` milliseconds on the standard easing, shown
     * as it starts and stood as `visibility` says once it ends; at no duration it stands there at once.
     */
    static void slideAcross(View view, float from, float to, long duration, int visibility) {
        view.animate().cancel();
        if (duration <= 0) {
            view.setTranslationX(to);
            view.setVisibility(visibility);
            return;
        }
        view.setVisibility(View.VISIBLE);
        view.setTranslationX(from);
        view.animate().translationX(to).setDuration(duration)
                .setInterpolator(new android.view.animation.PathInterpolator(0.4f, 0f, 0.2f, 1f))
                .withEndAction(() -> view.setVisibility(visibility)).start();
    }

    /** Moves, turns and scales the view about its pivot, in pixels; a pivot of NaN is its center. */
    static void transform(View view, float translationX, float translationY, float rotation,
            float rotationX, float rotationY, float scaleX, float scaleY, float pivotX, float pivotY) {
        view.setTranslationX(translationX);
        view.setTranslationY(translationY);
        view.setRotation(rotation);
        view.setRotationX(rotationX);
        view.setRotationY(rotationY);
        view.setScaleX(scaleX);
        view.setScaleY(scaleY);
        if (Float.isNaN(pivotX)) {
            view.resetPivot();
        } else {
            view.setPivotX(pivotX);
            view.setPivotY(pivotY);
        }
    }

    /**
     * `look` under the platform's pressed ripple, in its theme's color, kept within `mask`'s shape; the look
     * dims while its view is disabled, as the theme's controls dim.
     */
    static Drawable pressable(Context context, StateUIShapeDrawable look, Drawable mask) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.colorControlHighlight});
        ColorStateList highlight = theme.getColorStateList(0);
        theme.recycle();
        look.setDisabledAlpha(disabledAlpha(context));
        return new RippleDrawable(
                highlight != null ? highlight : ColorStateList.valueOf(0x33000000), look, mask);
    }

    /** Words in `color`, dimmed while their view is disabled, as the theme's own colors are. */
    /** The background of the platform's colored button, which a window's main action wears. */
    static Drawable coloredBackground(Context context) {
        TypedArray style = context.obtainStyledAttributes(
                null, new int[] {android.R.attr.background}, 0, android.R.style.Widget_DeviceDefault_Button_Colored);
        Drawable background = style.getDrawable(0);
        style.recycle();
        return background;
    }

    /** The theme's colors for an error, which mark an action that destroys something. */
    static ColorStateList errorWords(Context context) {
        return themeColors(context, android.R.attr.colorError);
    }

    /** The theme's colors for primary words: a label's where the tree colors it not. */
    static ColorStateList primaryWords(Context context) {
        return themeColors(context, android.R.attr.textColorPrimary);
    }

    private static ColorStateList themeColors(Context context, int attribute) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {attribute});
        ColorStateList colors = theme.getColorStateList(0);
        theme.recycle();
        return colors;
    }

    /** The words' colors of the platform's colored button: its style's own, else its text appearance's. */
    static ColorStateList coloredWords(Context context) {
        // Attributes in ascending order, as obtainStyledAttributes reads them.
        TypedArray style = context.obtainStyledAttributes(
                null, new int[] {android.R.attr.textAppearance, android.R.attr.textColor}, 0,
                android.R.style.Widget_DeviceDefault_Button_Colored);
        ColorStateList words = style.getColorStateList(1);
        int appearance = style.getResourceId(0, 0);
        style.recycle();
        if (words != null || appearance == 0) return words;
        TypedArray look = context.obtainStyledAttributes(appearance, new int[] {android.R.attr.textColor});
        words = look.getColorStateList(0);
        look.recycle();
        return words;
    }

    static ColorStateList textColors(Context context, int color) {
        int dimmed = (Math.round(Color.alpha(color) * disabledAlpha(context)) << 24) | (color & 0xFFFFFF);
        return new ColorStateList(
                new int[][] {new int[] {-android.R.attr.state_enabled}, new int[0]}, new int[] {dimmed, color});
    }

    /**
     * What assistive technology meets of `view`, StateUI's view `number`: the name a test finds it by, the words
     * read for it and the hint after them, the class its kind is said by and the value said after them - none
     * leaves the view's own - the actions a reader offers on it and whether a reader steps it, whether it is a
     * heading, and whether it is met at all.
     */
    static void setAccessibility(View view, long number, String identifier, String label, String hint, String kind,
                                 String value, String[] actions, boolean adjustable, boolean heading, int importance) {
        view.setContentDescription(label);
        view.setImportantForAccessibility(importance);
        if (Build.VERSION.SDK_INT >= 28) view.setAccessibilityHeading(heading);
        if (Build.VERSION.SDK_INT >= 30) view.setStateDescription(value);
        boolean words = identifier != null || hint != null || kind != null || actions.length > 0 || adjustable;
        view.setAccessibilityDelegate(words ? new Words(number, identifier, hint, kind, actions, adjustable) : null);
    }

    /** The first id of a reader's actions on a view, one after another in their order: no id of Android's own. */
    // Swift: none
    private static final int ACTIONS = 0x5A7E0000;

    /**
     * The words a view's accessibility node carries beyond the view's own - its name, its hint and its kind - and
     * what a reader does to it: its actions, and its steps where it is adjustable, which TalkBack takes as a
     * slider's scrolls.
     */
    private static final class Words extends View.AccessibilityDelegate {
        private final long number;
        private final String identifier;
        private final String hint;
        private final String kind;
        private final String[] actions;
        private final boolean adjustable;

        Words(long number, String identifier, String hint, String kind, String[] actions, boolean adjustable) {
            this.number = number;
            this.identifier = identifier;
            this.hint = hint;
            this.kind = kind;
            this.actions = actions;
            this.adjustable = adjustable;
        }

        @Override
        public void onInitializeAccessibilityNodeInfo(View host, AccessibilityNodeInfo info) {
            super.onInitializeAccessibilityNodeInfo(host, info);
            if (identifier != null) info.setViewIdResourceName(identifier);
            if (hint != null) info.setHintText(hint);
            if (kind != null) info.setClassName(kind);
            for (int place = 0; place < actions.length; place++) {
                info.addAction(new AccessibilityNodeInfo.AccessibilityAction(ACTIONS + place, actions[place]));
            }
            if (adjustable) {
                info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD);
                info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD);
            }
        }

        @Override
        public boolean performAccessibilityAction(View host, int action, Bundle arguments) {
            int place = action - ACTIONS;
            if (place >= 0 && place < actions.length) return StateUIHost.accessibilityActed(number, actions[place]);
            if (adjustable && action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) {
                return StateUIHost.accessibilityStepped(number, true);
            }
            if (adjustable && action == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) {
                return StateUIHost.accessibilityStepped(number, false);
            }
            return super.performAccessibilityAction(host, action, arguments);
        }
    }

    /**
     * A bar's or a tab's picture at Android's icon size: 24 dp tall, as wide as its shape makes it, whatever
     * size the picture is drawn at elsewhere.
     */
    static BitmapDrawable glyph(Context context, Bitmap picture) {
        BitmapDrawable glyph = drawn(context, picture, android.R.attr.colorControlNormal);
        float tall = 24 * context.getResources().getDisplayMetrics().density;
        glyph.setTargetDensity(Math.round(picture.getDensity() * tall / Math.max(1, picture.getHeight())));
        return glyph;
    }

    /** A picture standing alone: an icon - a mask, `isMask` - in the theme's primary words color, as a label's. */
    static BitmapDrawable picture(Context context, Bitmap picture) {
        return drawn(context, picture, android.R.attr.textColorPrimary);
    }

    /** A picture to draw: an icon in the theme's color `attribute` names, any other as it is. */
    private static BitmapDrawable drawn(Context context, Bitmap picture, int attribute) {
        BitmapDrawable drawable = new BitmapDrawable(context.getResources(), picture);
        if (isMask(picture)) drawable.setTintList(themeColors(context, attribute));
        return drawable;
    }

    /** Whether `picture` is an icon: only how opaque each pixel is, drawn in the color of what shows it. */
    static boolean isMask(Bitmap picture) {
        return picture.getConfig() == Bitmap.Config.ALPHA_8;
    }

    /**
     * The application's drawable `name` - an icon the host puts among its resources - fitted into a square `side`
     * pixels across, kept as a mask; null where it has none such.
     */
    static Bitmap icon(Context context, String name, int side) {
        int id = context.getResources().getIdentifier(name, "drawable", context.getPackageName());
        Drawable drawable = id == 0 || side <= 0 ? null : context.getDrawable(id);
        if (drawable == null) return null;
        // The mask keeps the shape whole: the drawable's own tint, often partly opaque, is not drawn into it.
        drawable = drawable.mutate();
        drawable.setTintList(null);
        float width = Math.max(1, drawable.getIntrinsicWidth());
        float height = Math.max(1, drawable.getIntrinsicHeight());
        float scale = Math.min(side / width, side / height);
        int drawnWidth = Math.round(width * scale);
        int drawnHeight = Math.round(height * scale);
        int left = (side - drawnWidth) / 2;
        int top = (side - drawnHeight) / 2;
        Bitmap drawn = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888);
        drawable.setBounds(left, top, left + drawnWidth, top + drawnHeight);
        drawable.draw(new Canvas(drawn));
        Bitmap mask = drawn.extractAlpha();
        drawn.recycle();
        return mask;
    }

    /** A separator in a stack: a plain view drawn with the theme's list divider, as thick as that line both ways. */
    static View separator(Context context) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.listDivider});
        Drawable line = theme.getDrawable(0);
        theme.recycle();
        View view = new View(context);
        view.setBackground(line);
        int thickness = Math.max(1, line == null ? 1 : line.getIntrinsicHeight());
        view.setMinimumWidth(thickness);
        view.setMinimumHeight(thickness);
        return view;
    }

    /** How opaque the theme draws a disabled control. */
    static float disabledAlpha(Context context) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.disabledAlpha});
        float alpha = theme.getFloat(0, 0.38f);
        theme.recycle();
        return alpha;
    }

    /** The layers of a button's foreground, by their ids: its picture alone, its menu's arrow, a split button's line. */
    // Swift: none
    static final int PICTURE_LAYER = 1, MARK_LAYER = 2, ARROW_LAYER = 3, LINE_LAYER = 4;

    /**
     * Puts `picture` beside the view's words - 0 before them, 1 after, 2 above, 3 below - `gap` pixels
     * away, or the platform's gap for -1, at its own size; with no words, alone in the middle of the view
     * at `width` by `height` pixels, `room` pixels kept on its right. A null picture takes it away. A button
     * holding a menu shows the drawable `arrow` names `side` pixels square, `arrowRight` pixels from its right
     * edge, in its words' colors: a mark after its words (`splits` false), or a split button's arrow, a line
     * `lineHeight` pixels high `lineRight` pixels from that edge setting it apart. A null `arrow` shows none.
     */
    static void setIcon(TextView view, Bitmap picture, int position, int gap, int width, int height, int room,
                        String arrow, boolean splits, int side, int arrowRight, int lineRight, int lineHeight) {
        Drawable icon = picture == null ? null : new BitmapDrawable(view.getResources(), picture);
        if (icon != null && isMask(picture)) icon.setTintList(view.getTextColors());
        boolean alone = view.getText().length() == 0;
        Drawable beside = alone ? null : icon;

        if (gap >= 0) view.setCompoundDrawablePadding(gap);
        view.setCompoundDrawablesRelativeWithIntrinsicBounds(
                position == 0 ? beside : null, position == 2 ? beside : null,
                position == 1 ? beside : null, position == 3 ? beside : null);

        Context context = view.getContext();
        int found = arrow == null ? 0 : context.getResources().getIdentifier(arrow, "drawable", context.getPackageName());
        Drawable down = found == 0 ? null : context.getDrawable(found).mutate();
        ArrayList<Drawable> drawn = new ArrayList<>();
        if (alone && icon != null) drawn.add(icon);
        if (down != null) {
            down.setTintList(view.getTextColors());
            drawn.add(down);
        }
        Drawable line = null;
        if (down != null && splits) {
            line = new ColorDrawable(Color.WHITE);
            line.setTintList(view.getTextColors().withAlpha(89));
            drawn.add(line);
        }
        if (drawn.isEmpty()) {
            view.setForeground(null);
            return;
        }
        LayerDrawable layers = new LayerDrawable(drawn.toArray(new Drawable[0]));
        int index = 0;
        if (alone && icon != null) {
            layers.setId(index, PICTURE_LAYER);
            layers.setLayerGravity(index, Gravity.CENTER);
            layers.setLayerInsetRight(index, room);
            layers.setLayerSize(index++, width, height);
        }
        if (down != null) {
            layers.setId(index, splits ? ARROW_LAYER : MARK_LAYER);
            layers.setLayerGravity(index, Gravity.RIGHT | Gravity.CENTER_VERTICAL);
            layers.setLayerSize(index, side, side);
            layers.setLayerInsetRight(index++, arrowRight);
        }
        if (line != null) {
            layers.setId(index, LINE_LAYER);
            layers.setLayerGravity(index, Gravity.RIGHT | Gravity.CENTER_VERTICAL);
            layers.setLayerSize(index, Math.max(1, Math.round(context.getResources().getDisplayMetrics().density)),
                                lineHeight);
            layers.setLayerInsetRight(index, lineRight);
        }
        view.setForeground(layers);
    }

    /**
     * Puts the focus on `view` - bringing up the keyboard where it takes words - or takes it off; whether the
     * view took it.
     */
    static boolean focus(View view, boolean take) {
        if (!take) {
            if (view.hasFocus()) view.clearFocus();
            return false;
        }
        boolean took = view.requestFocus();
        if (took && view.onCheckIsTextEditor()) {
            android.view.inputmethod.InputMethodManager keyboard =
                    view.getContext().getSystemService(android.view.inputmethod.InputMethodManager.class);
            if (keyboard != null) keyboard.showSoftInput(view, 0);
        }
        return took;
    }

    /**
     * Paints `line` as the theme's line between panes side by side (`dividerVertical`), and answers how wide the
     * theme draws it, in pixels - at least one.
     */
    static int divide(View line) {
        TypedArray theme = line.getContext().obtainStyledAttributes(new int[] { android.R.attr.dividerVertical });
        Drawable divider = theme.getDrawable(0);
        theme.recycle();
        line.setBackground(divider);
        return divider == null ? 1 : Math.max(1, divider.getIntrinsicWidth());
    }

    /**
     * Grounds a split view's sidebar: over the detail on the theme's floating surface - a drawer's, its end corners
     * rounded - with `argb` laid over it where `painted`; beside the detail in `argb` where `painted`, else on
     * nothing, the window showing through.
     */
    static void groundSidebar(View view, boolean over, boolean painted, int argb) {
        if (!over && !painted) {
            view.setBackground(null);
            view.setClipToOutline(false);
            return;
        }
        int color = argb;
        if (over) {
            // Over the detail the drawer stands on the platform's own surface, its material laid over it.
            TypedValue value = new TypedValue();
            view.getContext().getTheme().resolveAttribute(android.R.attr.colorBackgroundFloating, value, true);
            int own = value.resourceId != 0 ? view.getContext().getColor(value.resourceId) : value.data;
            color = painted ? over(argb, own) : own;
        }
        GradientDrawable ground = new GradientDrawable();
        ground.setColor(color);
        if (over) {
            float r = 16 * view.getResources().getDisplayMetrics().density;
            boolean rtl = view.getLayoutDirection() == View.LAYOUT_DIRECTION_RTL;
            ground.setCornerRadii(rtl ? new float[] {r, r, 0, 0, 0, 0, r, r} : new float[] {0, 0, r, r, r, r, 0, 0});
        }
        view.setBackground(ground);
        view.setClipToOutline(over);
    }

    /**
     * Grounds a page on its window's color - the one its activity's window is painted in, else the theme's
     * background - so a page sliding over another hides it.
     */
    static void groundPage(View view) {
        Context context = view.getContext();
        while (context instanceof ContextWrapper && !(context instanceof Activity)) {
            context = ((ContextWrapper) context).getBaseContext();
        }
        Drawable window = context instanceof Activity
                ? ((Activity) context).getWindow().getDecorView().getBackground() : null;
        if (window instanceof ColorDrawable) {
            view.setBackground(new ColorDrawable(((ColorDrawable) window).getColor()));
            return;
        }
        TypedValue value = new TypedValue();
        view.getContext().getTheme().resolveAttribute(android.R.attr.colorBackground, value, true);
        view.setBackground(new ColorDrawable(
                value.resourceId != 0 ? view.getContext().getColor(value.resourceId) : value.data));
    }

    /** The color a split view's sidebar stands on, as ARGB; Long.MIN_VALUE where it stands on nothing. */
    static long sidebarColor(View view) {
        Drawable ground = view.getBackground();
        if (!(ground instanceof GradientDrawable)) return Long.MIN_VALUE;
        ColorStateList color = ((GradientDrawable) ground).getColor();
        return color != null ? color.getDefaultColor() & 0xFFFFFFFFL : Long.MIN_VALUE;
    }

    /**
     * A holder for a page presented over the window's page: on a card in the middle of a wide window, `width` by
     * `height` pixels, over the shade a dialog casts, which takes every touch beside it - as the platform's own dialog
     * stands; filling a narrow one on the theme's window background, where `width` is 0.
     */
    static FrameLayout sheet(Context context, View page, int width, int height) {
        if (page.getParent() instanceof ViewGroup) ((ViewGroup) page.getParent()).removeView(page);
        FrameLayout holder = new FrameLayout(context);
        holder.setClickable(true);
        FrameLayout.LayoutParams whole = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
        if (width <= 0) {
            TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.windowBackground});
            holder.setBackground(theme.getDrawable(0));
            theme.recycle();
            holder.addView(page, whole);
            return holder;
        }
        TypedArray theme = context.obtainStyledAttributes(new int[] {
                android.R.attr.colorBackground, android.R.attr.dialogCornerRadius, android.R.attr.backgroundDimAmount});
        int ground = theme.getColor(0, Color.WHITE);
        float corner = theme.getDimension(1, 0);
        float dim = theme.getFloat(2, 0.6f);
        theme.recycle();
        holder.setBackgroundColor(Color.argb(Math.round(dim * 255), 0, 0, 0));
        holder.setTag(CARD);
        FrameLayout card = new FrameLayout(context);
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(ground);
        shape.setCornerRadius(corner);
        card.setBackground(shape);
        card.setClipToOutline(true);
        card.setElevation(24 * context.getResources().getDisplayMetrics().density);
        card.setClickable(true);
        card.addView(page, whole);
        holder.addView(card, new FrameLayout.LayoutParams(width, height, Gravity.CENTER));
        return holder;
    }

    /**
     * Stands a sheet's holder on `argb` - its window's background - laid over the theme's own sheet: the card in a wide
     * window, the holder filling a narrow one; the theme's own where `argb` is Long.MIN_VALUE.
     */
    static void groundSheet(View holder, long argb) {
        boolean card = CARD.equals(holder.getTag());
        View surface = card ? ((ViewGroup) holder).getChildAt(0) : holder;
        TypedArray theme = holder.getContext().obtainStyledAttributes(
                new int[] {android.R.attr.colorBackground, android.R.attr.windowBackground});
        int own = theme.getColor(0, Color.WHITE);
        Drawable window = theme.getDrawable(1);
        theme.recycle();
        if (argb == Long.MIN_VALUE) {
            if (card) ((GradientDrawable) surface.getBackground()).setColor(own);
            else surface.setBackground(window);
            return;
        }
        int ground = over((int) argb, own);
        if (card) ((GradientDrawable) surface.getBackground()).setColor(ground);
        else surface.setBackground(new ColorDrawable(ground));
    }

    /** `top` laid over `bottom`, as a color with an alpha lies over another. */
    private static int over(int top, int bottom) {
        float a = Color.alpha(top) / 255f;
        return Color.rgb(
                Math.round(Color.red(top) * a + Color.red(bottom) * (1 - a)),
                Math.round(Color.green(top) * a + Color.green(bottom) * (1 - a)),
                Math.round(Color.blue(top) * a + Color.blue(bottom) * (1 - a)));
    }

    /** The color a sheet's holder stands on, as ARGB: its card's in a wide window; Long.MIN_VALUE where none. */
    static long sheetColor(View holder) {
        View surface = CARD.equals(holder.getTag()) ? ((ViewGroup) holder).getChildAt(0) : holder;
        Drawable ground = surface.getBackground();
        if (ground instanceof ColorDrawable) return ((ColorDrawable) ground).getColor() & 0xFFFFFFFFL;
        if (ground instanceof GradientDrawable && ((GradientDrawable) ground).getColor() != null) {
            return ((GradientDrawable) ground).getColor().getDefaultColor() & 0xFFFFFFFFL;
        }
        return Long.MIN_VALUE;
    }

    /** Stands the card of a sheet in a wide window at `width` by `height` pixels; nothing for one filling it. */
    static void sizeSheet(View holder, int width, int height) {
        if (!CARD.equals(holder.getTag()) || width <= 0) return;
        View card = ((ViewGroup) holder).getChildAt(0);
        ViewGroup.LayoutParams params = card.getLayoutParams();
        if (params.width == width && params.height == height) return;
        params.width = width;
        params.height = height;
        card.setLayoutParams(params);
    }

    /** The window's width, or its height where not `across`, in density-independent pixels. */
    static int windowDp(Context context, boolean across) {
        android.content.res.Configuration configuration = context.getResources().getConfiguration();
        return across ? configuration.screenWidthDp : configuration.screenHeightDp;
    }

    /**
     * Draws the activity edge to edge, the system's bars clear over it - their words dark on a light theme - and tells
     * the host what stands over the root on each edge as it changes: the system's bars and a cutout, and the
     * keyboard, which no longer makes the window smaller.
     */
    @SuppressWarnings("deprecation")
    static void edgeToEdge(Activity activity, View root, boolean light) {
        Window window = activity.getWindow();
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);
        WindowManager.LayoutParams attributes = window.getAttributes();
        attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        window.setAttributes(attributes);
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false);
            int dark = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
            WindowInsetsController bars = window.getInsetsController();
            if (bars != null) bars.setSystemBarsAppearance(light ? dark : 0, dark);
        } else {
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
            if (light) flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            window.getDecorView().setSystemUiVisibility(flags);
        }
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets over = insets.getInsets(
                        WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                int keyboard = insets.getInsets(WindowInsets.Type.ime()).bottom;
                StateUIHost.insets(over.left, over.top, over.right, over.bottom, keyboard);
            } else {
                // Under LAYOUT_STABLE the window's insets hold the bars as if shown, the keyboard at the bottom where
                // taller; the stable ones reach a view as none on Android 9.
                DisplayCutout cutout = insets.getDisplayCutout();
                int left = insets.getSystemWindowInsetLeft(), top = insets.getSystemWindowInsetTop();
                int right = insets.getSystemWindowInsetRight(), bottom = insets.getSystemWindowInsetBottom();
                if (cutout != null) {
                    left = Math.max(left, cutout.getSafeInsetLeft());
                    top = Math.max(top, cutout.getSafeInsetTop());
                    right = Math.max(right, cutout.getSafeInsetRight());
                    bottom = Math.max(bottom, cutout.getSafeInsetBottom());
                }
                StateUIHost.insets(left, top, right, bottom, 0);
            }
            return insets;
        });
        root.requestApplyInsets();
    }

    /** What a sheet's holder standing a card in a wide window is tagged. */
    private static final String CARD = "stateui.sheet.card";

    /**
     * Brings a presented page into `parent` over `duration` milliseconds - up from the bottom, or a card fading in -
     * or takes it out the same way; at no duration it stands or goes at once.
     */
    static void rise(ViewGroup parent, View holder, boolean in, long duration) {
        holder.animate().cancel();
        // A card fades in and out, as a dialog does; a page over the whole window rises and goes down.
        boolean card = CARD.equals(holder.getTag());
        float away = parent.getHeight();
        if (in) {
            parent.addView(holder, new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            if (duration <= 0 || away <= 0) return;
            if (card) {
                holder.setAlpha(0);
                holder.animate().alpha(1).setDuration(duration).start();
            } else {
                holder.setTranslationY(away);
                holder.animate().translationY(0).setDuration(duration).start();
            }
            return;
        }
        if (duration <= 0 || away <= 0) {
            parent.removeView(holder);
            return;
        }
        (card ? holder.animate().alpha(0) : holder.animate().translationY(away))
                .setDuration(duration).withEndAction(() -> parent.removeView(holder)).start();
    }
}
