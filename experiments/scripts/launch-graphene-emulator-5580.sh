#!/usr/bin/env bash
set -euo pipefail

# This launcher is deliberately pinned to a fresh emulator serial and a
# dedicated data directory. It must never select the connected Pixel or the
# existing emulator-5554/emulator-5556 test environments.
readonly build_root="${GRAPHENE_BUILD_ROOT:?set GRAPHENE_BUILD_ROOT to the GrapheneOS source tree}"
readonly emulator_bin="$build_root/prebuilts/android-emulator/linux-x86_64/emulator"
readonly data_dir="${GRAPHENE_TEST_DATA_DIR:?set GRAPHENE_TEST_DATA_DIR to a new empty path}"
readonly expected_serial=emulator-5580

if [[ -e "$data_dir" ]]; then
    printf 'Refusing to reuse existing data directory: %s\n' "$data_dir" >&2
    exit 1
fi

if adb devices | awk 'NR > 1 { print $1 }' | grep -Fxq "$expected_serial"; then
    printf 'Refusing to reuse active serial: %s\n' "$expected_serial" >&2
    exit 1
fi

cd "$build_root"
if [[ -n "${GRAPHENE_BUILD_TOOLS:-}" ]]; then
    export PATH="$GRAPHENE_BUILD_TOOLS:$PATH"
fi
source build/envsetup.sh >/dev/null
lunch chatgpt_sdk_phone64_x86_64-aosp_current-userdebug >/dev/null

for image in system.img vendor.img ramdisk.img userdata.img; do
    if [[ ! -f "$ANDROID_PRODUCT_OUT/$image" ]]; then
        printf 'Missing build image: %s/%s\n' "$ANDROID_PRODUCT_OUT" "$image" >&2
        exit 1
    fi
done

mkdir -m 700 "$data_dir"
printf 'Launching isolated GrapheneOS test as %s\n' "$expected_serial"
printf 'Writable data directory: %s\n' "$data_dir"

exec env QT_QPA_PLATFORM=xcb "$emulator_bin" \
    -port 5580 \
    -datadir "$data_dir" \
    -initdata "$ANDROID_PRODUCT_OUT/userdata.img" \
    -wipe-data \
    -no-snapshot \
    -no-snapstorage \
    -no-boot-anim \
    -no-window \
    -no-audio \
    -no-metrics \
    -gpu host \
    -memory 8192 \
    -cores 8
