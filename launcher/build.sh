#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user_home_dir="$(getent passwd "$(id -u)" | cut -d: -f6)"
sdk_dir="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$user_home_dir/Android/Sdk}}"
build_tools="$(
    find "$sdk_dir/build-tools" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
        sort -V |
        tail -n 1
)"
android_jar="$(
    find "$sdk_dir/platforms" -mindepth 2 -maxdepth 2 -name android.jar -print 2>/dev/null |
        sort -V |
        tail -n 1
)"
java_bin_candidates=()
[[ -z "${JAVA_HOME:-}" ]] || java_bin_candidates+=("$JAVA_HOME/bin")
if command -v java >/dev/null 2>&1; then
    java_bin_candidates+=("$(dirname -- "$(command -v java)")")
fi
[[ -z "${GRAPHENE_BUILD_ROOT:-}" ]] ||
    java_bin_candidates+=("$GRAPHENE_BUILD_ROOT/prebuilts/jdk/jdk21/linux-x86/bin")
while IFS= read -r graphene_tree; do
    java_bin_candidates+=(
        "$graphene_tree/prebuilts/jdk/jdk21/linux-x86/bin"
    )
done < <(
    find "$user_home_dir" -mindepth 1 -maxdepth 1 -type d \
        -name 'grapheneos-*' -print 2>/dev/null |
        sort -Vr
)
java_bin_dir=""
for candidate in "${java_bin_candidates[@]}"; do
    if [[ -x "$candidate/java" && -x "$candidate/jar" && \
          -x "$candidate/javac" ]]; then
        java_bin_dir="$candidate"
        break
    fi
done
if [[ -z "$java_bin_dir" ]]; then
    printf 'error: java, jar, and javac were not found; set JAVA_HOME to a full JDK\n' >&2
    exit 1
fi
out_dir="$project_dir/build"
classes_dir="$out_dir/classes"
dex_dir="$out_dir/dex"
unsigned_apk="$out_dir/chatgpt-chrome-unsigned.apk"
aligned_apk="$out_dir/chatgpt-chrome-aligned.apk"
signed_apk="$out_dir/chatgpt-chrome.apk"
keystore="${CHATGPT_LAUNCHER_KEYSTORE:-$user_home_dir/.android/debug.keystore}"
keystore_alias="${CHATGPT_LAUNCHER_KEY_ALIAS:-androiddebugkey}"
keystore_password="${CHATGPT_LAUNCHER_KS_PASS:-android}"
key_password="${CHATGPT_LAUNCHER_KEY_PASS:-$keystore_password}"

export JAVA_HOME="$(cd -- "$java_bin_dir/.." && pwd)"
export PATH="$java_bin_dir:$PATH"

mkdir -p "$classes_dir" "$dex_dir"
rm -f "$unsigned_apk" "$aligned_apk" "$signed_apk"

javac \
    -source 8 \
    -target 8 \
    -bootclasspath "$android_jar" \
    -d "$classes_dir" \
    "$project_dir/src/dev/billy/chatgptchrome/MainActivity.java"

"$build_tools/d8" \
    --min-api 23 \
    --lib "$android_jar" \
    --output "$dex_dir" \
    "$classes_dir/dev/billy/chatgptchrome/MainActivity.class"

"$build_tools/aapt" package \
    -f \
    -M "$project_dir/AndroidManifest.xml" \
    -S "$project_dir/res" \
    -I "$android_jar" \
    -F "$unsigned_apk"

(
    cd "$dex_dir"
    "$build_tools/aapt" add "$unsigned_apk" classes.dex
)

"$build_tools/zipalign" -f 4 "$unsigned_apk" "$aligned_apk"
"$build_tools/apksigner" sign \
    --ks "$keystore" \
    --ks-key-alias "$keystore_alias" \
    --ks-pass "pass:$keystore_password" \
    --key-pass "pass:$key_password" \
    --out "$signed_apk" \
    "$aligned_apk"

"$build_tools/apksigner" verify --verbose "$signed_apk"
sha256sum "$signed_apk"
