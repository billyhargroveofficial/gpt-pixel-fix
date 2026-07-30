#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'usage: %s emulator-SERIAL [APK-DIRECTORY]\n' "$(basename -- "$0")" >&2
    exit 2
}

serial="${1:-}"
[[ -n "$serial" ]] || usage
[[ "$serial" == emulator-* ]] || {
    printf 'error: refusing to touch a physical device: %s\n' "$serial" >&2
    exit 1
}

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
apk_dir="${2:-$project_dir/output/chatgpt-1.2026.202-native-latex}"
adb_bin="${ADB:-adb}"

device_state="$("$adb_bin" -s "$serial" get-state 2>/dev/null || true)"
[[ "$device_state" == device ]] || {
    printf 'error: emulator is not ready: %s (%s)\n' "$serial" "$device_state" >&2
    exit 1
}

[[ "$("$adb_bin" -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || {
    printf 'error: target does not identify itself as an emulator\n' >&2
    exit 1
}

"$adb_bin" -s "$serial" emu avd name >/dev/null

apk_names=(
    base.apk
    split_config.arm64_v8a.apk
    split_config.en.apk
    split_config.xxhdpi.apk
)
for apk_name in "${apk_names[@]}"; do
    [[ -f "$apk_dir/$apk_name" ]] || {
        printf 'error: missing APK: %s\n' "$apk_dir/$apk_name" >&2
        exit 1
    }
done

timestamp="$(date +%Y%m%d_%H%M%S)"
snapshot_tag="chatgpt_before_patch_$timestamp"
backup_dir="$project_dir/backup/$snapshot_tag/official-apks"
mkdir -p "$backup_dir"

printf 'Saving full AVD snapshot: %s\n' "$snapshot_tag"
"$adb_bin" -s "$serial" emu avd snapshot save "$snapshot_tag"

mapfile -t installed_paths < <(
    "$adb_bin" -s "$serial" shell pm path com.openai.chatgpt 2>/dev/null |
        tr -d '\r' |
        sed -n 's/^package://p'
)

if ((${#installed_paths[@]})); then
    printf 'Backing up currently installed APKs to %s\n' "$backup_dir"
    for installed_path in "${installed_paths[@]}"; do
        "$adb_bin" -s "$serial" pull "$installed_path" "$backup_dir/$(basename -- "$installed_path")"
    done

    printf 'Uninstalling the currently signed package from the emulator.\n'
    "$adb_bin" -s "$serial" uninstall com.openai.chatgpt
fi

printf 'Installing patched split set on %s\n' "$serial"
"$adb_bin" -s "$serial" install-multiple \
    "$apk_dir/base.apk" \
    "$apk_dir/split_config.arm64_v8a.apk" \
    "$apk_dir/split_config.en.apk" \
    "$apk_dir/split_config.xxhdpi.apk"

"$adb_bin" -s "$serial" shell am force-stop com.openai.chatgpt
"$adb_bin" -s "$serial" shell monkey \
    -p com.openai.chatgpt \
    -c android.intent.category.LAUNCHER \
    1 >/dev/null

printf 'Installed and launched. Restore point: %s\n' "$snapshot_tag"
printf 'To restore: %s %s %s\n' \
    "$project_dir/restore-emulator.sh" "$serial" "$snapshot_tag"
