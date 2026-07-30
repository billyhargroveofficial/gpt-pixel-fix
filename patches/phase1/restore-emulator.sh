#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'usage: %s emulator-SERIAL SNAPSHOT-TAG\n' "$(basename -- "$0")" >&2
    exit 2
}

serial="${1:-}"
snapshot_tag="${2:-}"
[[ -n "$serial" && -n "$snapshot_tag" ]] || usage
[[ "$serial" == emulator-* ]] || {
    printf 'error: refusing to touch a physical device: %s\n' "$serial" >&2
    exit 1
}
[[ "$snapshot_tag" =~ ^[A-Za-z0-9_.-]+$ ]] || {
    printf 'error: invalid snapshot tag: %s\n' "$snapshot_tag" >&2
    exit 1
}

adb_bin="${ADB:-adb}"
[[ "$("$adb_bin" -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || {
    printf 'error: target does not identify itself as an emulator\n' >&2
    exit 1
}

printf 'Restoring the complete AVD state from snapshot: %s\n' "$snapshot_tag"
"$adb_bin" -s "$serial" emu avd snapshot load "$snapshot_tag"
"$adb_bin" -s "$serial" wait-for-device
printf 'Restore completed for %s\n' "$serial"
