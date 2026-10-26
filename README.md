# adbkeeper

A tiny Android app, with no UI, that keeps adb debugging on across reboots of Xiaomi/Fengmi projectors, so tools that drive the projector over Wi-Fi adb (Home Assistant, scripts) keep working after a reboot. No root needed.

Tested on a Fengmi `FengMiProjA2` (product `franky`), Android 9, firmware `9.12.5.118`. Other Xiaomi TV devices whose settings app turns adb off at boot may behave the same way.

## Why

On these firmwares, the Xiaomi settings app (`com.xiaomi.mitv.settings`) sets `adb_enabled` to 0 on every boot, so debugging has to be turned back on by hand after each reboot. A plain boot receiver cannot undo it: the firmware also stops every third-party app at boot, and a stopped app never receives `BOOT_COMPLETED`. [doc/findings.md](doc/findings.md) has the details and the evidence.

## How it works

`KeeperService` is an accessibility service that listens to no events. The system starts enabled accessibility services at boot even when their app is stopped. Once started, the service sets `adb_enabled` to 1 and watches the setting with a `ContentObserver`, setting it back to 1 whenever something writes 0. It writes the setting with `WRITE_SECURE_SETTINGS`, which `pm grant` gives it from the adb shell, without root.

While the service runs, turning debugging off in the projector settings does not stick: it goes back on immediately. To turn it off for good, [uninstall](#uninstall) adbkeeper first.

## Install

You need adb access to the projector once (debugging turned on in its developer settings) and the APK, from the [releases](https://github.com/badaz/adbkeeper/releases) or [built yourself](#build).

```
adb connect <projector-ip>:5555
adb install -r adbkeeper.apk
adb shell pm grant fr.home.adbkeeper android.permission.WRITE_SECURE_SETTINGS
# Appends the service to the enabled accessibility services, keeping the existing ones
adb shell 'cur=$(settings get secure enabled_accessibility_services); [ "$cur" = null ] && cur=; case "$cur" in *fr.home.adbkeeper*) ;; *) settings put secure enabled_accessibility_services "${cur:+$cur:}fr.home.adbkeeper/fr.home.adbkeeper.KeeperService";; esac'
adb shell settings put secure accessibility_enabled 1
```

Check that it works:

```
adb shell pidof fr.home.adbkeeper
# expected: a PID
adb shell settings put global adb_enabled 0
adb shell logcat -d -s AdbKeeper
# expected: "adb_enabled set to 1", and adb stays connected
```

Then reboot the projector: debugging should be on once it has booted.

## Uninstall

Remove the service from the enabled accessibility services, keeping the other entries, then uninstall the app:

```
adb shell 'settings put secure enabled_accessibility_services "$(settings get secure enabled_accessibility_services | sed "s#:*fr.home.adbkeeper/fr.home.adbkeeper.KeeperService##")"'
adb uninstall fr.home.adbkeeper
```

## Troubleshooting

If debugging is off after a reboot, turn it back on by hand, connect, and save the log right away, since the buffer rotates fast at boot:

```
adb logcat -b all -d > boot.log
grep -E "AdbKeeper|adb_enabled|stop: fr.home" boot.log
adb shell 'pidof fr.home.adbkeeper; settings get secure enabled_accessibility_services'
```

A working boot shows `stop: fr.home.adbkeeper` during the package scan, then `putInt(adb_enabled,0)` from the Xiaomi settings app, then `AdbKeeper: adb_enabled set to 1`. Otherwise, check whether the service started (`dumpsys accessibility`), whether its entry is still in `enabled_accessibility_services`, and whether its process was killed (`am_kill`).

## Build

Requirements: the Android SDK in `$ANDROID_HOME` (build-tools 35.0.0 and platform android-33 by default, overridable with `BUILD_TOOLS_VERSION` and `PLATFORM`) and a JDK. No Gradle.

The APK must be signed. Generate a keystore once, at the root of the repo (it is gitignored):

```
keytool -genkeypair -keystore keystore.jks -alias adbkeeper -keyalg RSA -keysize 2048 -validity 10000 -dname CN=adbkeeper
```

Then build, passing the keystore password:

```
KEYSTORE_PASS=<password> ./build.sh
```

Android only installs an update signed with the same key as the installed app. Keep using the same keystore for your builds; switching between your builds and the release APKs requires `adb uninstall` and the install steps again.

## Release

The version follows semver: `versionName` in `AndroidManifest.xml`, tagged `v<versionName>`; `versionCode` goes up by 1 with each release. To publish one, bump both, commit, push `main`, then run `KEYSTORE_PASS=<password> ./release.sh`. It checks that the tree is clean and pushed, tags `HEAD` if the tag does not exist yet, builds the APK, pushes the tag and creates a GitHub release with `adbkeeper-<versionName>.apk` attached.
