package fr.home.adbkeeper;

import android.accessibilityservice.AccessibilityService;
import android.content.ContentResolver;
import android.database.ContentObserver;
import android.os.Handler;
import android.provider.Settings;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;

public class KeeperService extends AccessibilityService {
    private static final String TAG = "AdbKeeper";

    private final ContentObserver adbObserver = new ContentObserver(new Handler()) {
        @Override
        public void onChange(boolean selfChange) {
            enableAdb();
        }
    };

    @Override
    protected void onServiceConnected() {
        // com.xiaomi.mitv.settings sets adb_enabled=0 on BOOT_COMPLETED, possibly after this point
        getContentResolver().registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ADB_ENABLED), false, adbObserver);
        enableAdb();
    }

    @Override
    public void onDestroy() {
        getContentResolver().unregisterContentObserver(adbObserver);
        super.onDestroy();
    }

    private void enableAdb() {
        ContentResolver resolver = getContentResolver();
        if (Settings.Global.getInt(resolver, Settings.Global.ADB_ENABLED, 0) == 1) {
            return;
        }
        try {
            Settings.Global.putInt(resolver, Settings.Global.ADB_ENABLED, 1);
            Log.i(TAG, "adb_enabled set to 1");
        } catch (SecurityException e) {
            Log.e(TAG, "WRITE_SECURE_SETTINGS not granted", e);
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }
}
