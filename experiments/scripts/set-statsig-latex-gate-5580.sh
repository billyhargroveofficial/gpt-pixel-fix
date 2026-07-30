#!/usr/bin/env bash
set -euo pipefail

readonly serial=emulator-5580
readonly package=com.openai.chatgpt
readonly expected_device=chatgpt_emu64xa
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly patcher="$script_dir/../tools/patch_statsig_override.py"
readonly remote_pb=/data/user/0/com.openai.chatgpt/files/datastore/com.statsig.androidsdk.prefs/ondiskvaluecache_unc.preferences_pb

if [[ $# -ne 1 || ! "$1" =~ ^(true|false)$ ]]; then
    printf 'Usage: %s true|false\n' "$0" >&2
    exit 2
fi
if [[ "$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')" != \
    "$expected_device" ]]; then
    printf 'Refusing unexpected target on %s\n' "$serial" >&2
    exit 1
fi

tmp_dir=$(mktemp -d /tmp/chatgpt-statsig-5580.XXXXXX)
cleanup() {
    [[ ! -e "$tmp_dir/input.pb" ]] || unlink "$tmp_dir/input.pb"
    [[ ! -e "$tmp_dir/output.pb" ]] || unlink "$tmp_dir/output.pb"
    rmdir "$tmp_dir"
}
trap cleanup EXIT

adb -s "$serial" root >/dev/null
adb -s "$serial" wait-for-device
adb -s "$serial" shell am force-stop "$package"

if ! adb -s "$serial" shell test -f "$remote_pb"; then
    printf 'Statsig DataStore has not been created yet: %s\n' "$remote_pb" >&2
    exit 1
fi

app_uid=$(
    adb -s "$serial" shell stat -c '%u' /data/user/0/com.openai.chatgpt |
        tr -d '\r'
)
if [[ ! "$app_uid" =~ ^[0-9]+$ ]]; then
    printf 'Could not determine ChatGPT uid: %s\n' "$app_uid" >&2
    exit 1
fi

adb -s "$serial" pull "$remote_pb" "$tmp_dir/input.pb" >/dev/null
python3 "$patcher" "$tmp_dir/input.pb" "$tmp_dir/output.pb" \
    --gate 3320767387 --value "$1"

readonly staging=/data/local/tmp/chatgpt-statsig-override.pb
adb -s "$serial" push "$tmp_dir/output.pb" "$staging" >/dev/null
adb -s "$serial" shell cp "$staging" "$remote_pb"
adb -s "$serial" shell chown "$app_uid:$app_uid" "$remote_pb"
adb -s "$serial" shell chmod 600 "$remote_pb"
adb -s "$serial" shell restorecon "$remote_pb"
adb -s "$serial" shell rm -f "$staging"

printf 'Set official ChatGPT gate 3320767387=%s on %s\n' "$1" "$serial"
