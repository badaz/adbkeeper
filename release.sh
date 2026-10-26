#!/bin/bash
# Tags HEAD with the versionName of AndroidManifest.xml and publishes the APK as a GitHub release.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' AndroidManifest.xml)
TAG=v$VERSION

[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "versionName $VERSION is not semver" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean" >&2; exit 1; }
git fetch -q origin
git merge-base --is-ancestor HEAD origin/main || { echo "HEAD is not pushed to origin/main" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    [ "$(git rev-parse "$TAG^{commit}")" = "$(git rev-parse HEAD)" ] || { echo "$TAG already exists on another commit" >&2; exit 1; }
else
    git tag -a "$TAG" -m "adbkeeper $VERSION"
fi

./build.sh
cp adbkeeper.apk "build/adbkeeper-$VERSION.apk"
git push origin "$TAG"
gh release create "$TAG" "build/adbkeeper-$VERSION.apk" --verify-tag --title "adbkeeper $VERSION" --generate-notes
