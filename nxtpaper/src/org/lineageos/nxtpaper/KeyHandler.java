/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.nxtpaper;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.UserHandle;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;
import android.widget.Toast;

import com.android.internal.os.DeviceKeyHandler;

/**
 * The NXTPAPER key (tct_ui_key driver, input device "tswt", KEY 598; mapped to
 * MACRO_1 by tswt.kl). A short press steps through regular, Color Paper and
 * Ink Paper; a long press switches between regular and the long press mode
 * (Settings.Secure nxtpaper_long_press_mode, Color Paper by default), as on
 * stock.
 */
public class KeyHandler implements DeviceKeyHandler {
    private static final String TAG = "NxtPaper";

    private static final int SCANCODE_NXTPAPER = 598;
    private static final long LONG_PRESS_TIMEOUT_MS = 500;

    private final Context mContext;
    private final Handler mHandler;
    private final NxtPaperDisplay mDisplay;

    private boolean mKeyDown;
    private Toast mToast;

    private final Runnable mLongPress = () -> {
        mKeyDown = false;
        onLongPress();
    };

    public KeyHandler(Context context) {
        mContext = context;

        HandlerThread thread = new HandlerThread(TAG);
        thread.start();
        mHandler = new Handler(thread.getLooper());
        mDisplay = new NxtPaperDisplay(context, mHandler);

        // PhoneWindowManager is created before ColorDisplayService publishes
        // DisplayTransformManager; restore the saved mode once booted.
        context.registerReceiver(new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                mDisplay.start();
            }
        }, new IntentFilter(Intent.ACTION_LOCKED_BOOT_COMPLETED), null, mHandler);
    }

    @Override
    public KeyEvent handleKeyEvent(KeyEvent event) {
        if (event.getScanCode() != SCANCODE_NXTPAPER) {
            return event;
        }

        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            if (event.getRepeatCount() == 0) {
                mHandler.post(() -> {
                    mKeyDown = true;
                    mHandler.postDelayed(mLongPress, LONG_PRESS_TIMEOUT_MS);
                });
            }
        } else if (event.getAction() == KeyEvent.ACTION_UP) {
            mHandler.post(() -> {
                if (mKeyDown) {
                    mKeyDown = false;
                    mHandler.removeCallbacks(mLongPress);
                    onShortPress();
                }
            });
        }
        return null;
    }

    private void onShortPress() {
        mDisplay.start();
        switchTo(NxtPaperModes.next(mDisplay.getMode()));
    }

    private void onLongPress() {
        mDisplay.start();
        int longPressMode = Settings.Secure.getIntForUser(mContext.getContentResolver(),
                NxtPaperModes.SETTING_LONG_PRESS_MODE, NxtPaperModes.DEFAULT_LONG_PRESS_MODE,
                UserHandle.USER_CURRENT);
        if (longPressMode == NxtPaperModes.MODE_REGULAR) {
            return;
        }
        int mode = mDisplay.getMode();
        switchTo(mode == longPressMode ? NxtPaperModes.MODE_REGULAR : longPressMode);
    }

    private void switchTo(int mode) {
        Log.i(TAG, "Switching to mode " + mode);
        mDisplay.setMode(mode);

        Context packageContext = NxtPaperModes.packageContext(mContext);
        if (packageContext == null) {
            return;
        }
        if (mToast != null) {
            mToast.cancel();
        }
        // Posted as "android": a toast for another package from the system
        // uid is rejected
        mToast = Toast.makeText(mContext, packageContext.getText(NxtPaperModes.nameRes(mode)),
                Toast.LENGTH_SHORT);
        mToast.show();
    }
}
