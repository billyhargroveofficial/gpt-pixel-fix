#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
original_dir="${CHATGPT_PATCH_ORIGINAL_DIR:-$project_dir/original}"
output_dir="${CHATGPT_PATCH_OUTPUT_DIR:-$project_dir/output/chatgpt-1.2026.202-native-latex}"

user_home_dir="$(getent passwd "$(id -u)" | cut -d: -f6)"
android_sdk_dir="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$user_home_dir/Android/Sdk}}"

if [[ -n "${CHATGPT_PATCH_BUILD_TOOLS_DIR:-}" ]]; then
    build_tools_dir="$CHATGPT_PATCH_BUILD_TOOLS_DIR"
else
    build_tools_dir="$(
        find "$android_sdk_dir/build-tools" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
            sort -V |
            tail -n 1
    )"
fi

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
    if [[ -x "$candidate/java" && -x "$candidate/jar" ]]; then
        java_bin_dir="$candidate"
        break
    fi
done
if [[ -z "$java_bin_dir" ]]; then
    printf 'error: java and jar were not found; set PATH to a full JDK\n' >&2
    exit 1
fi

export JAVA_HOME="$(cd -- "$java_bin_dir/.." && pwd)"
export PATH="$java_bin_dir:$PATH"

zipalign_bin="$build_tools_dir/zipalign"
apksigner_bin="$build_tools_dir/apksigner"
aapt2_bin="$build_tools_dir/aapt2"
keystore_path="${CHATGPT_PATCH_KEYSTORE:-$user_home_dir/.android/debug.keystore}"
keystore_alias="${CHATGPT_PATCH_KEY_ALIAS:-androiddebugkey}"
keystore_password="${CHATGPT_PATCH_KS_PASS:-android}"
key_password="${CHATGPT_PATCH_KEY_PASS:-$keystore_password}"

required_commands=(unzip sha256sum cmp perl jar java touch)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'error: required command is missing: %s\n' "$command_name" >&2
        exit 1
    }
done

for required_file in \
    "$original_dir/base.apk" \
    "$original_dir/split_config.arm64_v8a.apk" \
    "$original_dir/split_config.en.apk" \
    "$original_dir/split_config.xxhdpi.apk" \
    "$project_dir/patch_dex.pl" \
    "$zipalign_bin" \
    "$apksigner_bin" \
    "$aapt2_bin" \
    "$keystore_path"; do
    [[ -f "$required_file" ]] || {
        printf 'error: required file is missing: %s\n' "$required_file" >&2
        exit 1
    }
done

check_sha256() {
    local expected="$1"
    local file_path="$2"
    local actual
    actual="$(sha256sum "$file_path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        printf 'error: unexpected SHA-256 for %s\nexpected: %s\nactual:   %s\n' \
            "$file_path" "$expected" "$actual" >&2
        exit 1
    fi
}

# These guards deliberately bind the patch to ChatGPT 1.2026.202. Applying
# offsets to any other release would be unsafe.
check_sha256 f1198e4434d610a80bc1dd40ec2a5c268303d79939e7bcb9fc1d78d1548fc7e5 "$original_dir/base.apk"
check_sha256 6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72 "$original_dir/split_config.arm64_v8a.apk"
check_sha256 7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04 "$original_dir/split_config.en.apk"
check_sha256 72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3 "$original_dir/split_config.xxhdpi.apk"

work_dir="$(mktemp -d "$project_dir/.build.XXXXXX")"
cleanup() {
    case "$work_dir" in
        "$project_dir"/.build.*) rm -rf -- "$work_dir" ;;
        *) printf 'warning: refusing to remove unexpected work directory: %s\n' "$work_dir" >&2 ;;
    esac
}
trap cleanup EXIT

mkdir -p "$work_dir/extracted" "$work_dir/inject" "$work_dir/unsigned" "$work_dir/aligned" "$work_dir/signed"
unzip -qq "$original_dir/base.apk" classes4.dex classes5.dex -d "$work_dir/extracted"

check_sha256 b122238373ca3c14333bd9f78f1283ae9d7ce14733ce1857cff73d99bb83737b "$work_dir/extracted/classes4.dex"
check_sha256 63bccef7e54fc5ce54e66ba80052e877f7947bbfd86ef6c9ded150cfde5ea6e1 "$work_dir/extracted/classes5.dex"

"$project_dir/patch_dex.pl" \
    "$work_dir/extracted/classes4.dex" \
    "$work_dir/inject/classes4.dex" \
    0x5124b2:0a03:1213

"$project_dir/patch_dex.pl" \
    "$work_dir/extracted/classes5.dex" \
    "$work_dir/inject/classes5.dex" \
    0x6ebe90:6e20a2950100:000000000000

check_sha256 90c1471789203877ba5a652d85652a32104a7660b57009c03a0f18061f638760 "$work_dir/inject/classes4.dex"
check_sha256 35c92b73f2aa7f3c7a87b7483bdbe65d314d80fd80769ddc56057ae1d604432d "$work_dir/inject/classes5.dex"

cp "$original_dir/base.apk" "$work_dir/unsigned/base.apk"
TZ=UTC touch -a -m -d '1981-01-01 01:01:02 UTC' \
    "$work_dir/inject/classes4.dex" \
    "$work_dir/inject/classes5.dex"
TZ=UTC jar --update --file "$work_dir/unsigned/base.apk" --no-compress \
    -C "$work_dir/inject" classes4.dex \
    -C "$work_dir/inject" classes5.dex

apk_names=(
    base.apk
    split_config.arm64_v8a.apk
    split_config.en.apk
    split_config.xxhdpi.apk
)

for apk_name in "${apk_names[@]:1}"; do
    cp "$original_dir/$apk_name" "$work_dir/unsigned/$apk_name"
done

for apk_name in "${apk_names[@]}"; do
    "$zipalign_bin" -f -P 16 4 \
        "$work_dir/unsigned/$apk_name" \
        "$work_dir/aligned/$apk_name"

    "$apksigner_bin" sign \
        --ks "$keystore_path" \
        --ks-key-alias "$keystore_alias" \
        --ks-pass "pass:$keystore_password" \
        --key-pass "pass:$key_password" \
        --v1-signing-enabled false \
        --v2-signing-enabled true \
        --v3-signing-enabled true \
        --v4-signing-enabled false \
        --out "$work_dir/signed/$apk_name" \
        "$work_dir/aligned/$apk_name"

    "$apksigner_bin" verify --verbose --print-certs "$work_dir/signed/$apk_name" >/dev/null
    "$zipalign_bin" -c -P 16 4 "$work_dir/signed/$apk_name"
done

base_badging="$("$aapt2_bin" dump badging "$work_dir/signed/base.apk" | sed -n '1p')"
[[ "$base_badging" == *"name='com.openai.chatgpt'"* ]] || {
    printf 'error: rebuilt base has the wrong package name\n' >&2
    exit 1
}
[[ "$base_badging" == *"versionCode='2620225'"* ]] || {
    printf 'error: rebuilt base has the wrong version code\n' >&2
    exit 1
}

expected_signer=""
for apk_name in "${apk_names[@]}"; do
    signer="$(
        "$apksigner_bin" verify --print-certs "$work_dir/signed/$apk_name" |
            sed -n 's/^V3\.0 Signer: certificate SHA-256 digest: //p'
    )"
    [[ -n "$signer" ]] || {
        printf 'error: could not read signer from %s\n' "$apk_name" >&2
        exit 1
    }
    if [[ -z "$expected_signer" ]]; then
        expected_signer="$signer"
    elif [[ "$signer" != "$expected_signer" ]]; then
        printf 'error: split signer mismatch in %s\n' "$apk_name" >&2
        exit 1
    fi
done

mkdir -p "$output_dir"
for apk_name in "${apk_names[@]}"; do
    install -m 0644 "$work_dir/signed/$apk_name" "$output_dir/$apk_name"
done

if [[ -n "${CHATGPT_PHASE4_INPUT_DIR:-}" ]]; then
    mkdir -p "$CHATGPT_PHASE4_INPUT_DIR/splits-official"
    phase4_input_dir="$(
        cd -- "$CHATGPT_PHASE4_INPUT_DIR"
        pwd
    )"
    install -m 0644 \
        "$work_dir/unsigned/base.apk" \
        "$phase4_input_dir/base-phase1-unsigned.apk"
    unzip -p "$original_dir/base.apk" assets/math_jax.valdimodule \
        >"$phase4_input_dir/math_jax.original.valdimodule"
    for apk_name in "${apk_names[@]:1}"; do
        install -m 0644 \
            "$original_dir/$apk_name" \
            "$phase4_input_dir/splits-official/$apk_name"
    done

    check_sha256 \
        d2af202efd729f25168597833ecadf635d8a34e363f7298aca400ce7ca29d703 \
        "$phase4_input_dir/base-phase1-unsigned.apk"
    check_sha256 \
        73f3b322f29d882ccfe0784a193d077afb515f00a7ead3fff925af265227ad79 \
        "$phase4_input_dir/math_jax.original.valdimodule"
    printf 'Prepared phase-4 inputs:\n  %s\n' "$phase4_input_dir"
fi

printf 'Built ChatGPT 1.2026.202 native-LaTeX split set:\n'
printf '  %s\n' "$output_dir"
printf 'Signer SHA-256: %s\n' "$expected_signer"
sha256sum "$output_dir"/*.apk
