# Findings

What was learned about the projector while building adbkeeper, with how each fact was established. It is the background for the design described in the [README](../README.md).

## Device

- Xiaomi/Fengmi `FengMiProjA2` (product `franky`), Android 9 (SDK 28), build `9.12.5.118`, `ro.build.type=user`, not rooted.
- Home automation (Home Assistant here) can drive it over adb on Wi-Fi (port 5555), for example polling its state with `dumpsys … | grep -q state=ON`.
- Debugging is turned off by a reboot, not by the "lamp off" standby.
- The "ADB Debugging" screen of the Xiaomi settings reads `Settings.Global adb_enabled` (`SettingsUtil.isEnableADB()`); there is no other setting behind it.
- The system sets `service.adb.tcp.port=5555` again on every boot, so adb listens on Wi-Fi as soon as `adb_enabled` goes back to 1.

## Who turns adb off

- `com.xiaomi.mitv.settings` writes `adb_enabled=0` about 34 s after boot: `12-14 19:54:47.863 D SettingsUtil: setSettingsValue android.provider.Settings$Global.putInt(adb_enabled,0)`, and again at `20:01:07.195` on the next boot.
- Decompiling `/system/priv-app/MiTVSettings2/MiTVSettings2.apk` with jadx shows why: `SettingsBroadcastReceiver.onReceive` calls `SettingsUtil.setADBEnable(0)` on `BOOT_COMPLETED` whenever `Build.TYPE` is `user` and `mitv.os.Build.isTvProduct()` is true, with no other condition.

## Third-party apps are stopped at boot

- During the package scan at boot, Xiaomi's modified PackageManager puts every third-party app in the `stopped` state; the log lists those that were not already stopped: `12-14 20:00:46.707 D PackageManager: stop: fr.home.adbkeeper for user 0`, and the same line for every other third-party app, Play Store and Google Play services included.
- After that boot, every app of `pm list packages -3` was `stopped=true`.
- A stopped app receives neither implicit broadcasts nor alarms, so a `BOOT_COMPLETED` receiver never runs, whatever its priority.
- The only related string in `/system/framework/oat/arm/services.vdex` is the property `persist.sys.stop.vendorapp`, empty on the device; its role is unknown because the code is compact dex, which jadx cannot read.
- No whitelist was found in `/system/etc`, `/vendor/etc` or `/data/system`.
- Enabled accessibility services escape this: the system binds them regardless of the `stopped` state, which starts their process. `dev.vodik7.tvquickactions` was stopped at boot, then ran (PID 4102, `stopped=false`) thanks to its `KeyAccessibilityService` listed in `enabled_accessibility_services`.
- `enabled_accessibility_services` can hold other apps' services, so adbkeeper's entry must be appended to it, not written over it.

## What works without root

- `pm grant <package> android.permission.WRITE_SECURE_SETTINGS` from the adb shell lets an app write `Settings.Global adb_enabled`.
- `setprop persist.*` is refused: it needs root.
- `pm disable` on a component of another app is refused to the shell user.
- Disabling all of `com.xiaomi.mitv.settings` would also stop the rest of its boot init (`SystemInitService`, `SyncService`), so it was not tried.

## Attempts

- v1, a `BOOT_COMPLETED` receiver with priority -1000: `cmd package query-receivers --brief -a android.intent.action.BOOT_COMPLETED` ranked it after Xiaomi's receiver (139 vs 103), and it worked when launched by hand, but on reboot it was stopped at the package scan and never ran (no `AdbKeeper` line in the log).
- v2, an accessibility service with a `ContentObserver` on `adb_enabled`: without a reboot, `settings put global adb_enabled 0` was undone 3 ms later (`12-14 20:05:44.832 AdbKeeper: adb_enabled set to 1`) and adb stayed reachable over Wi-Fi. On 2026-10-26, debugging was still on after a reboot; the boot log sequence (stop, Xiaomi's `putInt(adb_enabled,0)`, then `AdbKeeper`) was not captured.
- A stopped app newly installed on Android 9 does not receive `BOOT_COMPLETED` until it has been launched once; v1 had a no-UI activity for that, which v2 no longer needs.

## Debugging tips

- The logcat buffer rotates fast (about 40,000 lines at boot): save it with `adb logcat -b all -d > boot.log` as soon as adb connects.
- While v2 runs, turning debugging off in the Settings does not stick; remove the service from `enabled_accessibility_services` first.
