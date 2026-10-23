/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.nxtpaper;

import android.animation.ValueAnimator;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.ContentObserver;
import android.net.Uri;
import android.opengl.Matrix;
import android.os.Handler;
import android.os.UserHandle;
import android.provider.Settings;
import android.util.Log;
import android.view.animation.AnimationUtils;

import java.lang.reflect.Method;
import java.util.Arrays;

/**
 * Applies the NXTPAPER color transforms, like stock TclInkModeTintController
 * (com.tcl.frameworks APEX): a color matrix on its own DisplayTransformManager
 * level, below saturation/grayscale/inversion and above night display, faded
 * over a second. Matrices are stock's (framework-res-ext
 * config_ink_mode_matrix_*), with stock's brightness dependent warm tint.
 *
 * Runs in system_server (created by KeyHandler); DisplayTransformManager is a
 * system_server local service, reached by reflection.
 */
final class NxtPaperDisplay {
    private static final String TAG = "NxtPaper";

    // Stock LEVEL_COLOR_MATRIX_TCT_INK_MODE_COLOR
    private static final int LEVEL_COLOR_MATRIX_NXTPAPER = 140;
    private static final long TRANSITION_DURATION_MS = 1000;
    private static final long BRIGHTNESS_SETTLE_MS = 1000;

    private static final float[] MATRIX_IDENTITY = {
        1f, 0f, 0f, 0f,
        0f, 1f, 0f, 0f,
        0f, 0f, 1f, 0f,
        0f, 0f, 0f, 1f,
    };

    // Column-major, as DisplayTransformManager expects
    private static final float[] MATRIX_COLOR_PAPER = {
        0.537092f, 0.18916732f, 0.182689f, 0f,
        0.37646267f, 0.712042f, 0.35865697f, 0f,
        0.073111996f, 0.0722124f, 0.39865398f, 0f,
        0f, 0f, 0f, 1f,
    };

    private static final float[] MATRIX_INK_PAPER = {
        0.2126f, 0.2126f, 0.2126f, 0f,
        0.7152f, 0.7152f, 0.7152f, 0f,
        0.0722f, 0.0722f, 0.0722f, 0f,
        0f, 0f, 0f, 1f,
    };

    // Warm tint by screen_brightness: <= 60, <= 128, brighter
    private static final int[] BRIGHTNESS_THRESHOLDS = { 60, 128 };
    private static final float[][] WARM_TINT = {
        { 1f, 0.9252f, 0.8214f },
        { 1f, 0.9551f, 0.8928f },
        { 1f, 0.9775f, 0.9464f },
    };

    private final Context mContext;
    private final Handler mHandler;
    private final ContentResolver mResolver;

    private Object mDtm;
    private Method mGetColorMatrix;
    private Method mSetColorMatrix;

    private boolean mStarted;
    private int mMode = -1;
    private int mTintLevel = -1;
    private ValueAnimator mAnimator;

    private final Runnable mBrightnessSettled = () -> update(false);

    NxtPaperDisplay(Context context, Handler handler) {
        mContext = context;
        mHandler = handler;
        mResolver = context.getContentResolver();
    }

    /** Called on the handler thread once system services are up. */
    void start() {
        if (mStarted) {
            return;
        }
        if (!bindDisplayTransformManager()) {
            return;
        }
        mStarted = true;

        ContentObserver observer = new ContentObserver(mHandler) {
            @Override
            public void onChange(boolean selfChange, Uri uri) {
                if (Settings.System.getUriFor(Settings.System.SCREEN_BRIGHTNESS).equals(uri)) {
                    mHandler.removeCallbacks(mBrightnessSettled);
                    mHandler.postDelayed(mBrightnessSettled, BRIGHTNESS_SETTLE_MS);
                } else {
                    update(false);
                }
            }
        };
        mResolver.registerContentObserver(Settings.Secure.getUriFor(NxtPaperModes.SETTING_MODE),
                false, observer, UserHandle.USER_ALL);
        mResolver.registerContentObserver(
                Settings.System.getUriFor(Settings.System.SCREEN_BRIGHTNESS),
                false, observer, UserHandle.USER_ALL);

        mContext.registerReceiver(new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                update(true);
            }
        }, new IntentFilter(Intent.ACTION_USER_SWITCHED), null, mHandler);

        update(true);
    }

    int getMode() {
        return NxtPaperModes.sanitize(Settings.Secure.getIntForUser(mResolver,
                NxtPaperModes.SETTING_MODE, NxtPaperModes.MODE_REGULAR,
                UserHandle.USER_CURRENT));
    }

    void setMode(int mode) {
        Settings.Secure.putIntForUser(mResolver, NxtPaperModes.SETTING_MODE,
                NxtPaperModes.sanitize(mode), UserHandle.USER_CURRENT);
    }

    private void update(boolean immediate) {
        int mode = getMode();
        int tintLevel = getTintLevel();
        if (mode == mMode && (mode == NxtPaperModes.MODE_REGULAR || tintLevel == mTintLevel)) {
            return;
        }
        Log.i(TAG, "Mode " + mMode + " -> " + mode + ", tint level " + tintLevel);
        mMode = mode;
        mTintLevel = tintLevel;
        apply(computeMatrix(mode, tintLevel), immediate);
    }

    private int getTintLevel() {
        int brightness = Settings.System.getIntForUser(mResolver,
                Settings.System.SCREEN_BRIGHTNESS, 255, UserHandle.USER_CURRENT);
        int level = 0;
        while (level < BRIGHTNESS_THRESHOLDS.length && brightness > BRIGHTNESS_THRESHOLDS[level]) {
            level++;
        }
        return level;
    }

    private static float[] computeMatrix(int mode, int tintLevel) {
        float[] base;
        switch (mode) {
            case NxtPaperModes.MODE_COLOR_PAPER:
                base = MATRIX_COLOR_PAPER;
                break;
            case NxtPaperModes.MODE_INK_PAPER:
                base = MATRIX_INK_PAPER;
                break;
            default:
                return MATRIX_IDENTITY;
        }
        float[] tint = MATRIX_IDENTITY.clone();
        for (int i = 0; i < 3; i++) {
            tint[i * 5] = WARM_TINT[tintLevel][i];
        }
        // The tint applies to the output of the mode matrix
        float[] result = new float[16];
        Matrix.multiplyMM(result, 0, tint, 0, base, 0);
        return result;
    }

    private void apply(float[] to, boolean immediate) {
        if (mAnimator != null) {
            mAnimator.cancel();
            mAnimator = null;
        }
        float[] from = getColorMatrix();
        if (from == null) {
            from = MATRIX_IDENTITY;
        }
        if (immediate || Arrays.equals(from, to)) {
            setColorMatrix(to);
            return;
        }

        final float[] start = from;
        final float[] value = new float[16];
        mAnimator = ValueAnimator.ofFloat(0f, 1f);
        mAnimator.setDuration(TRANSITION_DURATION_MS);
        mAnimator.setInterpolator(AnimationUtils.loadInterpolator(mContext,
                android.R.interpolator.fast_out_slow_in));
        mAnimator.addUpdateListener(animator -> {
            float fraction = animator.getAnimatedFraction();
            for (int i = 0; i < 16; i++) {
                value[i] = start[i] + (to[i] - start[i]) * fraction;
            }
            setColorMatrix(value);
        });
        mAnimator.start();
    }

    private boolean bindDisplayTransformManager() {
        try {
            ClassLoader loader = getClass().getClassLoader();
            Class<?> dtmClass = Class.forName(
                    "com.android.server.display.color.DisplayTransformManager", true, loader);
            Class<?> localServices = Class.forName("com.android.server.LocalServices", true,
                    loader);
            mDtm = localServices.getMethod("getService", Class.class).invoke(null, dtmClass);
            if (mDtm == null) {
                Log.w(TAG, "DisplayTransformManager not published yet");
                return false;
            }
            mGetColorMatrix = dtmClass.getMethod("getColorMatrix", int.class);
            mSetColorMatrix = dtmClass.getMethod("setColorMatrix", int.class, float[].class);
            return true;
        } catch (ReflectiveOperationException e) {
            Log.e(TAG, "Cannot reach DisplayTransformManager", e);
            return false;
        }
    }

    private float[] getColorMatrix() {
        try {
            return (float[]) mGetColorMatrix.invoke(mDtm, LEVEL_COLOR_MATRIX_NXTPAPER);
        } catch (ReflectiveOperationException e) {
            Log.e(TAG, "getColorMatrix failed", e);
            return null;
        }
    }

    private void setColorMatrix(float[] matrix) {
        try {
            // Identity is removed rather than stored, as nothing is applied then
            mSetColorMatrix.invoke(mDtm, LEVEL_COLOR_MATRIX_NXTPAPER,
                    Arrays.equals(matrix, MATRIX_IDENTITY) ? null : matrix);
        } catch (ReflectiveOperationException e) {
            Log.e(TAG, "setColorMatrix failed", e);
        }
    }
}
