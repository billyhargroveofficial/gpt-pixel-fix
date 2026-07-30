#!/usr/bin/env bash
set -euo pipefail

readonly serial=emulator-5580
readonly package=com.openai.chatgpt
readonly expected_device=chatgpt_emu64xa
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly db_dir="${CHATGPT_FORMULA_DB_DIR:-$script_dir/../generated/minimal-formulas}"
readonly remote_db=/data/user/0/com.openai.chatgpt/databases/conversations.db

if [[ $# -ne 1 || ! "$1" =~ ^(120|12|1)$ ]]; then
    printf 'Usage: %s 120|12|1\n' "$0" >&2
    exit 2
fi

case "$1" in
    120)
        local_db="$db_dir/conversations-120-nodes.db"
        expected_hash=26b02658c14c5686929fe7bf476c46ce160b62e6f00c53dda3585f80176cd791
        ;;
    12)
        local_db="$db_dir/conversations-12-nodes.db"
        expected_hash=866d33aa9f011fec95c4d5c359bc54291013e222e43dade74fe07f0b46b90a89
        ;;
    1)
        local_db="$db_dir/conversations-1-node.db"
        expected_hash=8c2c673d65bfffe78f4e8c719247017ac6a367ace98ca636a86d84d9f85e92ee
        ;;
esac

if [[ "$(sha256sum "$local_db" | awk '{ print $1 }')" != "$expected_hash" ]]; then
    printf 'Refusing unexpected database content: %s\n' "$local_db" >&2
    exit 1
fi
if [[ "$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')" != \
    "$expected_device" ]]; then
    printf 'Refusing unexpected target on %s\n' "$serial" >&2
    exit 1
fi

adb -s "$serial" root >/dev/null
adb -s "$serial" wait-for-device
adb -s "$serial" shell am force-stop "$package"

if ! adb -s "$serial" shell test -f "$remote_db"; then
    printf 'ChatGPT has not created its database yet: %s\n' "$remote_db" >&2
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

readonly staging=/data/local/tmp/chatgpt-formula-db
adb -s "$serial" push "$local_db" "$staging" >/dev/null
adb -s "$serial" shell cp "$staging" "$remote_db"
adb -s "$serial" shell rm -f "$remote_db-wal" "$remote_db-shm"
adb -s "$serial" shell chown "$app_uid:$app_uid" "$remote_db"
adb -s "$serial" shell chmod 600 "$remote_db"
adb -s "$serial" shell restorecon "$remote_db"
adb -s "$serial" shell rm -f "$staging"

actual_hash=$(
    adb -s "$serial" shell sha256sum "$remote_db" |
        awk '{ print $1 }' |
        tr -d '\r'
)
if [[ "$actual_hash" != "$expected_hash" ]]; then
    printf 'Remote database verification failed: %s\n' "$actual_hash" >&2
    exit 1
fi

printf 'Installed %s-node formula conversation on %s (uid %s)\n' \
    "$1" "$serial" "$app_uid"
