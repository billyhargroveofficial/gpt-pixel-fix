#!/usr/bin/env bash
set -euo pipefail

readonly serial=emulator-5580
readonly expected_device=chatgpt_emu64xa
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly apk_dir="${CHATGPT_OFFICIAL_APK_DIR:-$script_dir/../../patches/phase1/original}"

check_hash() {
    local path=$1
    local expected=$2
    local actual
    actual=$(sha256sum "$path" | awk '{ print $1 }')
    if [[ "$actual" != "$expected" ]]; then
        printf 'SHA-256 mismatch for %s\nexpected %s\nactual   %s\n' \
            "$path" "$expected" "$actual" >&2
        exit 1
    fi
}

if ! adb devices | awk 'NR > 1 && $2 == "device" { print $1 }' |
    grep -Fxq "$serial"; then
    printf '%s is not an online emulator; refusing to continue\n' "$serial" >&2
    exit 1
fi

actual_device=$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')
if [[ "$actual_device" != "$expected_device" ]]; then
    printf 'Unexpected target on %s: %s (expected %s)\n' \
        "$serial" "$actual_device" "$expected_device" >&2
    exit 1
fi

printf '%-34s %s\n' \
    ro.product.device "$actual_device" \
    ro.build.fingerprint "$(adb -s "$serial" shell getprop ro.build.fingerprint)" \
    ro.product.cpu.abilist "$(adb -s "$serial" shell getprop ro.product.cpu.abilist)" \
    ro.product.cpu.abilist64 "$(adb -s "$serial" shell getprop ro.product.cpu.abilist64)" \
    ro.dalvik.vm.native.bridge "$(adb -s "$serial" shell getprop ro.dalvik.vm.native.bridge)" \
    ro.dalvik.vm.isa.arm64 "$(adb -s "$serial" shell getprop ro.dalvik.vm.isa.arm64)" \
    ro.enable.native.bridge.exec "$(adb -s "$serial" shell getprop ro.enable.native.bridge.exec)" \
    ro.berberis.flags "$(adb -s "$serial" shell getprop ro.berberis.flags)" \
    ro.berberis.version "$(adb -s "$serial" shell getprop ro.berberis.version)" \
    dalvik.vm.usejit "$(adb -s "$serial" shell getprop dalvik.vm.usejit)"

adb -s "$serial" root >/dev/null
adb -s "$serial" wait-for-device

printf '\nNative bridge registration:\n'
adb -s "$serial" shell cat /proc/sys/fs/binfmt_misc/status
adb -s "$serial" shell cat /proc/sys/fs/binfmt_misc/arm64_dyn
adb -s "$serial" shell cat /proc/sys/fs/binfmt_misc/arm64_exe

printf '\nNative bridge files:\n'
adb -s "$serial" shell ls -l \
    /system/bin/arm64/app_process64 \
    /system/bin/arm64/linker64 \
    /system/bin/ndk_translation_program_runner_binfmt_misc_arm64 \
    /system/lib64/libndk_translation.so

check_hash "$apk_dir/base.apk" \
    f1198e4434d610a80bc1dd40ec2a5c268303d79939e7bcb9fc1d78d1548fc7e5
check_hash "$apk_dir/split_config.arm64_v8a.apk" \
    6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72
check_hash "$apk_dir/split_config.en.apk" \
    7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04
check_hash "$apk_dir/split_config.xxhdpi.apk" \
    72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3

printf '\nInstalling untouched, Google Play-signed ChatGPT APK splits on %s\n' "$serial"
adb -s "$serial" install-multiple \
    "$apk_dir/base.apk" \
    "$apk_dir/split_config.arm64_v8a.apk" \
    "$apk_dir/split_config.en.apk" \
    "$apk_dir/split_config.xxhdpi.apk"

printf '\nInstalled package ABI and version:\n'
adb -s "$serial" shell dumpsys package com.openai.chatgpt |
    grep -E 'versionCode=|versionName=|primaryCpuAbi=|secondaryCpuAbi='
