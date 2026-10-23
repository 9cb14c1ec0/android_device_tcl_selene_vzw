/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.nxtpaper;

import android.content.Context;
import android.content.pm.PackageManager;
import android.util.Log;

/** Display modes and the settings shared by the key handler and the tile. */
final class NxtPaperModes {
    private static final String TAG = "NxtPaper";

    static final String PACKAGE_NAME = "org.lineageos.nxtpaper";

    // Same Settings.Secure names as stock, so the values mean the same thing.
    static final String SETTING_MODE = "nxtpaper_ink_style_state";
    // Mode a long press switches to (and back to regular from)
    static final String SETTING_LONG_PRESS_MODE = "nxtpaper_long_press_mode";

    static final int MODE_REGULAR = 0;
    static final int MODE_COLOR_PAPER = 1;
    static final int MODE_INK_PAPER = 2;
    static final int MODE_COUNT = 3;

    static final int DEFAULT_LONG_PRESS_MODE = MODE_COLOR_PAPER;

    private NxtPaperModes() {}

    static int sanitize(int mode) {
        return mode >= 0 && mode < MODE_COUNT ? mode : MODE_REGULAR;
    }

    static int next(int mode) {
        return (sanitize(mode) + 1) % MODE_COUNT;
    }

    static int nameRes(int mode) {
        switch (mode) {
            case MODE_COLOR_PAPER:
                return R.string.mode_color_paper;
            case MODE_INK_PAPER:
                return R.string.mode_ink_paper;
            default:
                return R.string.mode_regular;
        }
    }

    /** Resources of this package, also when running inside system_server. */
    static Context packageContext(Context context) {
        if (PACKAGE_NAME.equals(context.getPackageName())) {
            return context;
        }
        try {
            return context.createPackageContext(PACKAGE_NAME, 0);
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "Package context unavailable", e);
            return null;
        }
    }
}
