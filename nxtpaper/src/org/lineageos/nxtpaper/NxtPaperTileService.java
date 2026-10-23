/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.nxtpaper;

import android.database.ContentObserver;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

/** Steps through the modes like a short press of the NXTPAPER key. */
public class NxtPaperTileService extends TileService {
    private final ContentObserver mObserver = new ContentObserver(
            new Handler(Looper.getMainLooper())) {
        @Override
        public void onChange(boolean selfChange) {
            updateTile();
        }
    };

    @Override
    public void onStartListening() {
        getContentResolver().registerContentObserver(
                Settings.Secure.getUriFor(NxtPaperModes.SETTING_MODE), false, mObserver);
        updateTile();
    }

    @Override
    public void onStopListening() {
        getContentResolver().unregisterContentObserver(mObserver);
    }

    @Override
    public void onClick() {
        // The key handler in system_server applies the change
        Settings.Secure.putInt(getContentResolver(), NxtPaperModes.SETTING_MODE,
                NxtPaperModes.next(getMode()));
    }

    private int getMode() {
        return NxtPaperModes.sanitize(Settings.Secure.getInt(getContentResolver(),
                NxtPaperModes.SETTING_MODE, NxtPaperModes.MODE_REGULAR));
    }

    private void updateTile() {
        Tile tile = getQsTile();
        if (tile == null) {
            return;
        }
        int mode = getMode();
        tile.setState(mode == NxtPaperModes.MODE_REGULAR ? Tile.STATE_INACTIVE : Tile.STATE_ACTIVE);
        tile.setSubtitle(getString(NxtPaperModes.nameRes(mode)));
        tile.updateTile();
    }
}
