#!/usr/bin/env bash
set -euo pipefail

readonly serial=emulator-5580
readonly package=com.openai.chatgpt
readonly expected_device=chatgpt_emu64xa

if [[ $# -ne 1 || ! "$1" =~ ^(enabled|disabled)$ ]]; then
    printf 'Usage: %s enabled|disabled\n' "$0" >&2
    exit 2
fi

if [[ "$(adb -s "$serial" shell getprop ro.product.device | tr -d '\r')" != \
    "$expected_device" ]]; then
    printf 'Refusing unexpected target on %s\n' "$serial" >&2
    exit 1
fi

# An explicit per-app value requires the NON_DEFAULT bit. The restriction bit
# disables JIT when present and enables JIT when absent.
args=(
    edit-gos-package-state "$package" 0
    add-flag RESTRICT_WEBVIEW_DYN_CODE_LOADING_NON_DEFAULT
)

if [[ "$1" == disabled ]]; then
    args+=(add-flag RESTRICT_WEBVIEW_DYN_CODE_LOADING)
else
    args+=(clear-flag RESTRICT_WEBVIEW_DYN_CODE_LOADING)
fi

args+=(set-kill-uid-after-apply true)
adb -s "$serial" shell pm "${args[@]}"
printf 'ChatGPT WebView JIT explicitly set to %s on %s\n' "$1" "$serial"
