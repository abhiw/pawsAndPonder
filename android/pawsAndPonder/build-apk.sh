#!/usr/bin/env bash
# Builds the Paws and Ponder APK into dist/.
#
#   ./build-apk.sh            debug APK, signed with the debug key, ready to install
#   ./build-apk.sh release    release APK, shrunk by R8
#
# The release APK is signed when these environment variables are set; otherwise it is left unsigned:
#   KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, and optionally KEY_PASSWORD (defaults to KEYSTORE_PASSWORD).
# Passwords are passed to apksigner through the environment, so they don't show up in the process list.
set -euo pipefail

cd "$(dirname "$0")"

build_type="${1:-debug}"
case "$build_type" in
  debug) task="assembleDebug" ;;
  release) task="assembleRelease" ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 1 ;;
esac

# Without a system JDK, use the one bundled with Android Studio.
if [[ -z "${JAVA_HOME:-}" ]] && ! /usr/bin/env java -version >/dev/null 2>&1; then
  for jbr in "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
             "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
             "/opt/android-studio/jbr" "$HOME/android-studio/jbr"; do
    if [[ -x "$jbr/bin/java" ]]; then export JAVA_HOME="$jbr"; break; fi
  done
fi

version=$(sed -nE 's/.*versionName *= *"([^"]+)".*/\1/p' app/build.gradle.kts | head -n 1)
out_dir="app/build/outputs/apk/$build_type"
mkdir -p dist

./gradlew ":app:$task"

if [[ "$build_type" == "debug" ]]; then
  target="dist/PawsAndPonder-$version-debug.apk"
  cp "$out_dir/app-debug.apk" "$target"
  echo "Built $target"
  exit 0
fi

unsigned="$out_dir/app-release-unsigned.apk"
if [[ ! -f "$unsigned" ]]; then
  # A signing config in Gradle produces app-release.apk instead.
  target="dist/PawsAndPonder-$version-release.apk"
  cp "$out_dir/app-release.apk" "$target"
  echo "Built $target"
  exit 0
fi

if [[ -z "${KEYSTORE_PATH:-}" ]]; then
  target="dist/PawsAndPonder-$version-release-unsigned.apk"
  cp "$unsigned" "$target"
  echo "Built $target"
  echo "It is unsigned and can't be installed. Set KEYSTORE_PATH, KEYSTORE_PASSWORD and KEY_ALIAS to sign it." >&2
  exit 0
fi

: "${KEYSTORE_PASSWORD:?KEYSTORE_PASSWORD is required when KEYSTORE_PATH is set}"
: "${KEY_ALIAS:?KEY_ALIAS is required when KEYSTORE_PATH is set}"
export KEYSTORE_PASSWORD
export KEY_PASSWORD="${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"

sdk_dir="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_dir" && -f local.properties ]]; then
  sdk_dir=$(sed -n 's/^sdk\.dir=//p' local.properties)
fi
build_tools=$(ls -1 "$sdk_dir/build-tools" 2>/dev/null | sort -V | tail -n 1)
apksigner="$sdk_dir/build-tools/$build_tools/apksigner"
if [[ ! -x "$apksigner" ]]; then
  echo "apksigner not found. Set ANDROID_HOME to your Android SDK." >&2
  exit 1
fi

target="dist/PawsAndPonder-$version-release.apk"
"$apksigner" sign \
  --ks "$KEYSTORE_PATH" \
  --ks-pass env:KEYSTORE_PASSWORD \
  --ks-key-alias "$KEY_ALIAS" \
  --key-pass env:KEY_PASSWORD \
  --out "$target" \
  "$unsigned"
"$apksigner" verify "$target"
echo "Built and signed $target"
