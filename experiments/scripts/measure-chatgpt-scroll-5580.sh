#!/usr/bin/env bash
set -euo pipefail

readonly serial=emulator-5580
readonly package=com.openai.chatgpt
readonly expected_device=chatgpt_emu64xa

if [[ "$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')" != \
    "$expected_device" ]]; then
    printf 'Refusing unexpected target on %s\n' "$serial" >&2
    exit 1
fi

if [[ -z "$(adb -s "$serial" shell pidof "$package" | tr -d '\r')" ]]; then
    printf '%s is not running on %s\n' "$package" "$serial" >&2
    exit 1
fi

printf 'Resetting frame statistics; the desired conversation must already be open.\n'
adb -s "$serial" shell dumpsys gfxinfo "$package" reset >/dev/null

physical_size=$(adb -s "$serial" shell wm size |
    sed -n 's/.*Physical size: \([0-9][0-9]*x[0-9][0-9]*\).*/\1/p' |
    tr -d '\r')
if [[ ! "$physical_size" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    printf 'Could not determine emulator display size: %s\n' "$physical_size" >&2
    exit 1
fi
width=${BASH_REMATCH[1]}
height=${BASH_REMATCH[2]}
x=$((width / 2))
y_start=$((height * 78 / 100))
y_end=$((height * 22 / 100))

# 24 up/down pairs: the same 48-swipe workload used for the provider A/B.
for _ in $(seq 1 24); do
    adb -s "$serial" shell input swipe "$x" "$y_start" "$x" "$y_end" 180
    adb -s "$serial" shell input swipe "$x" "$y_end" "$x" "$y_start" 180
done

printf '\nFrame statistics:\n'
adb -s "$serial" shell dumpsys gfxinfo "$package" |
    grep -E \
        'Total frames rendered:|Janky frames:|50th percentile:|90th percentile:|95th percentile:|99th percentile:'

printf '\nMemory / view statistics:\n'
adb -s "$serial" shell dumpsys meminfo "$package" |
    grep -E \
        'TOTAL PSS:|TOTAL RSS:|Views:|ViewRootImpl:|AppContexts:|Activities:|WebViews:'
