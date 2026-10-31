// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapView;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * A map of Google's, drawn by the Maps SDK for Android - a view that knows nothing of StateUI. What it shows comes as
 * calls - a region, a map type, traffic, the user's position, the gestures allowed, and the markers, a line each:
 * "number, latitude, longitude, kind, label, subtitle", a tab apart. It tells a tap on the map, a marker chosen and a
 * marker's details asked for, through GalleryNatives. Platforms/Android/Swift/Host/GoogleMapView.swift is its Swift
 * half.
 *
 * The SDK's key is the application's: google-maps-key.properties beside build.gradle.kts, which git keeps out, says
 * it, and the manifest hands it to the SDK. Without one, "No key - only for development" stands under the map.
 */
final class GoogleMapView extends LinearLayout {
    /** Meters in a degree of latitude. */
    private static final double METERS = 111320;
    private static final int LOCATION_ASKED = 4071;

    private final long control;
    private final MapView map;
    private final boolean keyed;
    private GoogleMap google;

    private double[] region;
    private boolean regionAnimates;
    private int mapType = GoogleMap.MAP_TYPE_NORMAL;
    private boolean traffic, userLocation, zooms = true, scrolls = true;
    private String markers = "";
    private final Map<String, Marker> shown = new HashMap<>();
    private final Map<Marker, String> numbers = new HashMap<>();
    private boolean resumed;

    GoogleMapView(Context context, long control) {
        super(context);
        this.control = control;
        setOrientation(VERTICAL);
        map = new MapView(context);
        map.onCreate(null);
        addView(map, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));
        keyed = hasKey(context);
        if (!keyed) {
            TextView missing = new TextView(context);
            missing.setText("No key - only for development");
            missing.setGravity(Gravity.CENTER);
            int padding = Math.round(6 * context.getResources().getDisplayMetrics().density);
            missing.setPadding(0, padding, 0, 0);
            addView(missing, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        }
        map.getMapAsync(ready -> {
            google = ready;
            google.getUiSettings().setMapToolbarEnabled(false);
            google.setOnMapClickListener(at -> GalleryNatives.mapClicked(this.control, at.latitude, at.longitude));
            google.setOnMarkerClickListener(marker -> {
                String number = numbers.get(marker);
                if (number != null) GalleryNatives.markerSelected(this.control, Long.parseLong(number));
                return false;
            });
            google.setOnInfoWindowClickListener(marker -> {
                String number = numbers.get(marker);
                if (number != null) GalleryNatives.markerDetails(this.control, Long.parseLong(number));
            });
            showAll();
        });
    }

    /** The region the map shows: latitude, longitude and radius in meters; slid there when {@code animated}. */
    void show(double latitude, double longitude, double radius, boolean animated) {
        region = new double[] {latitude, longitude, radius};
        regionAnimates = animated;
        showRegion();
    }

    /** How the world is drawn: 0 standard, 1 satellite, 2 hybrid. */
    void showType(int type) {
        mapType = type == 1 ? GoogleMap.MAP_TYPE_SATELLITE : type == 2 ? GoogleMap.MAP_TYPE_HYBRID
                : GoogleMap.MAP_TYPE_NORMAL;
        if (google != null) google.setMapType(mapType);
    }

    void showTraffic(boolean on) {
        traffic = on;
        if (google != null) google.setTrafficEnabled(on);
    }

    /** Shows the user's own position, asking for it first where the user has not allowed it yet. */
    void showUserLocation(boolean on) {
        userLocation = on;
        showPosition(true);
    }

    /** Whether a hand may zoom the map, and whether it may pan it. */
    void allow(boolean zooms, boolean scrolls) {
        this.zooms = zooms;
        this.scrolls = scrolls;
        if (google == null) return;
        google.getUiSettings().setZoomGesturesEnabled(zooms);
        google.getUiSettings().setScrollGesturesEnabled(scrolls);
    }

    /** Shows the markers of {@code lines}, keeping each marker shown before by its number. */
    void showMarkers(String lines) {
        markers = lines;
        if (google == null) return;
        Set<String> kept = new HashSet<>();
        for (String line : lines.split("\n")) {
            String[] parts = line.split("\t", -1);
            if (parts.length < 6) continue;
            kept.add(parts[0]);
            LatLng at = new LatLng(Double.parseDouble(parts[1]), Double.parseDouble(parts[2]));
            Marker marker = shown.get(parts[0]);
            if (marker == null) {
                marker = google.addMarker(new MarkerOptions().position(at));
                if (marker == null) continue;
                shown.put(parts[0], marker);
                numbers.put(marker, parts[0]);
            }
            marker.setPosition(at);
            marker.setTitle(parts[4]);
            marker.setSnippet(parts[5].isEmpty() ? null : parts[5]);
            marker.setIcon(BitmapDescriptorFactory.defaultMarker(hue(parts[3])));
        }
        shown.entrySet().removeIf(entry -> {
            if (kept.contains(entry.getKey())) return false;
            numbers.remove(entry.getValue());
            entry.getValue().remove();
            return true;
        });
    }

    /** Ends the map, its element gone. */
    void release() {
        if (resumed) map.onPause();
        map.onStop();
        map.onDestroy();
        resumed = false;
    }

    private void showAll() {
        showType(mapType == GoogleMap.MAP_TYPE_SATELLITE ? 1 : mapType == GoogleMap.MAP_TYPE_HYBRID ? 2 : 0);
        showTraffic(traffic);
        allow(zooms, scrolls);
        showPosition(false);
        showMarkers(markers);
        showRegion();
    }

    /** Slides or moves the map to the region once it is ready and has a size to fit the region in. */
    private void showRegion() {
        if (google == null || region == null || map.getWidth() == 0 || map.getHeight() == 0) return;
        double latitude = region[0], longitude = region[1], radius = region[2];
        double across = radius / (METERS * Math.max(Math.cos(Math.toRadians(latitude)), 0.01));
        LatLngBounds bounds = new LatLngBounds(
                new LatLng(latitude - radius / METERS, longitude - across),
                new LatLng(latitude + radius / METERS, longitude + across));
        CameraUpdate update = CameraUpdateFactory.newLatLngBounds(bounds, map.getWidth(), map.getHeight(), 0);
        // A map with no key runs no animation: it moves at once.
        if (regionAnimates && keyed) google.animateCamera(update); else google.moveCamera(update);
        region = null;
    }

    /** Shows the user's position where it is allowed; asks for it, when {@code asks}, where it is not. */
    private void showPosition(boolean asks) {
        if (google == null) return;
        boolean allowed = getContext().checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || getContext().checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        if (allowed) {
            try {
                google.setMyLocationEnabled(userLocation);
            } catch (SecurityException refused) {
                // Taken back between the check and the call: nothing shows.
            }
        } else if (userLocation && asks && getContext() instanceof Activity) {
            ((Activity) getContext()).requestPermissions(new String[] {
                    Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                    LOCATION_ASKED);
        }
    }

    /** Whether the manifest hands the SDK a key: an empty one draws no tiles. */
    private static boolean hasKey(Context context) {
        try {
            ApplicationInfo info = context.getPackageManager()
                    .getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);
            String key = info.metaData != null ? info.metaData.getString("com.google.android.geo.API_KEY") : null;
            return key != null && !key.isEmpty();
        } catch (PackageManager.NameNotFoundException unknown) {
            return false;
        }
    }

    /** The hue of a marker's color by its kind, the same colors as the Web's. */
    private static float hue(String kind) {
        int color;
        switch (kind) {
            case "place": color = 0xFF1A73E8; break;
            case "saved": color = 0xFFF9AB00; break;
            case "searchResult": color = 0xFF9334E6; break;
            default: color = 0xFFEA4335;
        }
        float[] hsv = new float[3];
        Color.colorToHSV(color, hsv);
        return hsv[0];
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        map.onStart();
    }

    @Override
    protected void onDetachedFromWindow() {
        if (resumed) map.onPause();
        resumed = false;
        map.onStop();
        super.onDetachedFromWindow();
    }

    @Override
    protected void onWindowVisibilityChanged(int visibility) {
        super.onWindowVisibilityChanged(visibility);
        if (visibility == View.VISIBLE && !resumed) {
            map.onResume();
            resumed = true;
        } else if (visibility != View.VISIBLE && resumed) {
            map.onPause();
            resumed = false;
        }
    }

    /** The window back in front - the question of the user's position answered, perhaps: it shows if allowed. */
    @Override
    public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (focused) showPosition(false);
    }

    @Override
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        post(this::showRegion);
    }

    /** A hand on a map it may move keeps it from the page scrolling around the map. */
    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_DOWN && (zooms || scrolls) && getParent() != null) {
            getParent().requestDisallowInterceptTouchEvent(true);
        }
        return super.dispatchTouchEvent(event);
    }
}
