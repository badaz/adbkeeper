# AGENTS.md

`CLAUDE.md` is a symlink to this file: edit `AGENTS.md` only.

adbkeeper is a tiny Android app that keeps adb debugging on across reboots of Xiaomi/Fengmi projectors, whose settings app turns it off at boot. This is a public repository. `README.md` is for users: what the app does, how to install, build and release it. `doc/findings.md` holds what was learned about the device, with evidence; add a line there for each new fact found on a device, including dead ends and why.

## Build

`KEYSTORE_PASS=<password> ./build.sh` builds and signs `adbkeeper.apk` without Gradle, with `javac`, `d8` and `aapt2` from `$ANDROID_HOME`; it needs a `keystore.jks` at the root (see Build in `README.md`). There are no tests: a change is checked on a device.

## Rules

- Keep the app minimal: one accessibility service, no UI, no Gradle.
- `keystore.jks` is gitignored and signs the published releases; never delete or regenerate it, since an APK signed with another key cannot update an installed release.
- Bump `versionCode` (+1) and `versionName` (semver, matching the tag `v<versionName>`) in `AndroidManifest.xml` for each release; `./release.sh` tags and publishes it on GitHub.
- On a device, append to `enabled_accessibility_services` instead of overwriting it: other apps' services are enabled there.
- Keep personal details out of the repository: no local IP, no list of the apps installed on a given device.
- `README.md` and `doc/findings.md` only claim what was observed on a device, a reboot included.
- Code and comments in English.
