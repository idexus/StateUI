// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.content.Context;
import android.graphics.SurfaceTexture;
import android.view.Choreographer;
import android.view.Surface;
import android.view.TextureView;

// listing: Cube3DSample.Android.java
/**
 * The surface a cube is drawn into by the Swift half, with OpenGL ES: a TextureView, drawn as a view is, so the
 * opacity, transform and clip StateUI puts on every view hold for it. It hands its surface over as it comes and goes,
 * and asks for the display's frames while it spins and stands in a window.
 */
final class Cube3DView extends TextureView implements TextureView.SurfaceTextureListener, Choreographer.FrameCallback {
    private static final float SIDE = 240;

    private final long control;
    private final float density;
    private Surface surface;
    private boolean spinning = true;
    private boolean following;

    Cube3DView(Context context, long control) {
        super(context);
        this.control = control;
        density = context.getResources().getDisplayMetrics().density;
        setSurfaceTextureListener(this);
    }

    /** Whether the cube turns: frames come only while it does. */
    void setSpinning(boolean value) {
        spinning = value;
        follow();
    }

    @Override
    protected void onMeasure(int width, int height) {
        int side = Math.round(SIDE * density);
        setMeasuredDimension(resolveSize(side, width), resolveSize(side, height));
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        follow();
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        follow();
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture texture, int width, int height) {
        surface = new Surface(texture);
        GalleryNatives.surfaceReady(control, surface, width, height);
        follow();
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture texture, int width, int height) {
        if (surface != null) GalleryNatives.surfaceReady(control, surface, width, height);
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture texture) {
        GalleryNatives.surfaceGone(control);
        surface.release();
        surface = null;
        follow();
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture texture) {}

    @Override
    public void doFrame(long nanoseconds) {
        if (!following) return;
        GalleryNatives.cubeFrame(control, nanoseconds);
        Choreographer.getInstance().postFrameCallback(this);
    }

    /** Asks for frames while the cube spins on a surface in a window, and for none otherwise. */
    private void follow() {
        boolean wanted = spinning && surface != null && isAttachedToWindow();
        if (wanted == following) return;
        following = wanted;
        if (wanted) {
            Choreographer.getInstance().postFrameCallback(this);
        } else {
            Choreographer.getInstance().removeFrameCallback(this);
        }
    }
}
// listing: end
