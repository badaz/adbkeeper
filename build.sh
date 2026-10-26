#!/bin/bash
# Builds and signs adbkeeper.apk without Gradle.
set -euo pipefail
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:?ANDROID_HOME must point to the Android SDK}
BT=$SDK/build-tools/${BUILD_TOOLS_VERSION:-35.0.0}
JAR=$SDK/platforms/${PLATFORM:-android-33}/android.jar
: "${KEYSTORE_PASS:?KEYSTORE_PASS must hold the keystore password}"
[ -f keystore.jks ] || { echo "keystore.jks is missing, see Build in README.md" >&2; exit 1; }
export PATH=/opt/homebrew/opt/openjdk/bin:$PATH

rm -rf build && mkdir -p build/classes build/dex build/res
javac --release 8 -classpath "$JAR" -d build/classes $(find src -name '*.java')
"$BT/d8" --min-api 28 --lib "$JAR" --output build/dex $(find build/classes -name '*.class')
"$BT/aapt2" compile --dir res -o build/res
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml -o build/unsigned.apk build/res/*.flat
(cd build/dex && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk
"$BT/apksigner" sign --ks keystore.jks --ks-pass env:KEYSTORE_PASS --out adbkeeper.apk build/aligned.apk
echo "built $(pwd)/adbkeeper.apk"
