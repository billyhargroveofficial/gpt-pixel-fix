#!/usr/bin/env bash
set -euo pipefail

phase5_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
phase4_root="$(CDPATH= cd -- "$phase5_root/../../patches/phase4" && pwd)"
python_tool="$phase4_root/tools/valdimodule.py"
input_dir="${CHATGPT_PHASE4_OUTPUT_DIR:-$phase4_root/output/chatgpt-1.2026.202-native-latex-phase4}"
build_dir="$phase5_root/build"
entries_dir="$phase5_root/work/dil_math.entries"
verify_dir="$phase5_root/work/dil_math.verified"
output_dir="$phase5_root/output/chatgpt-1.2026.202-phase5-instrumented"
input_module="$build_dir/dil_math.original.valdimodule"
patched_module="$build_dir/dil_math.instrumented.valdimodule"
working_base="$build_dir/base.instrumented.unsigned.apk"
install_version_code=2620231

user_home_dir="$(getent passwd "$(id -u)" | cut -d: -f6)"
android_sdk_dir="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$user_home_dir/Android/Sdk}}"
if [[ -n "${CHATGPT_PATCH_BUILD_TOOLS_DIR:-}" ]]; then
  build_tools="$CHATGPT_PATCH_BUILD_TOOLS_DIR"
else
  build_tools="$(
    find "$android_sdk_dir/build-tools" -mindepth 1 -maxdepth 1 -type d \
      -print 2>/dev/null | sort -V | tail -n 1
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
  java_bin_candidates+=("$graphene_tree/prebuilts/jdk/jdk21/linux-x86/bin")
done < <(
  find "$user_home_dir" -mindepth 1 -maxdepth 1 -type d \
    -name 'grapheneos-*' -print 2>/dev/null | sort -Vr
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
zipalign_bin="$build_tools/zipalign"
apksigner_bin="$build_tools/apksigner"
aapt2_bin="$build_tools/aapt2"
keystore="${CHATGPT_PATCH_KEYSTORE:-$user_home_dir/.android/debug.keystore}"
keystore_alias="${CHATGPT_PATCH_KEY_ALIAS:-androiddebugkey}"
keystore_password="${CHATGPT_PATCH_KS_PASS:-android}"
key_password="${CHATGPT_PATCH_KEY_PASS:-$keystore_password}"

for command in python unzip 7z sha256sum touch java jar; do
  command -v "$command" >/dev/null
done
for tool in \
  "$zipalign_bin" \
  "$apksigner_bin" \
  "$aapt2_bin"; do
  test -x "$tool"
done
test -f "$keystore"

rm -rf -- "$build_dir" "$phase5_root/work" "$output_dir"
mkdir -p \
  "$build_dir/inject/assets" \
  "$entries_dir" \
  "$output_dir"

unzip -p "$input_dir/base.apk" assets/dil_math.valdimodule \
  >"$input_module"
python "$python_tool" roundtrip "$input_module"
python "$python_tool" unpack "$input_module" "$entries_dir"

cp -- \
  "$entries_dir/src/renderMathSvg.js" \
  "$entries_dir/src/renderMathSvgOriginal.js"
cp -- \
  "$phase5_root/instrument/renderMathSvg.js" \
  "$entries_dir/src/renderMathSvg.js"
sha256sum "$phase5_root/instrument/renderMathSvg.js" |
  cut -d ' ' -f1 >"$entries_dir/hash"

python "$python_tool" pack "$entries_dir" "$patched_module" \
  >"$build_dir/patched-module-inspect.json"
python "$python_tool" unpack "$patched_module" "$verify_dir"
cmp \
  "$phase5_root/instrument/renderMathSvg.js" \
  "$verify_dir/src/renderMathSvg.js"
cmp \
  "$entries_dir/src/renderMathSvgOriginal.js" \
  "$verify_dir/src/renderMathSvgOriginal.js"

cp -- "$input_dir/base.apk" "$working_base"
cp -- "$patched_module" \
  "$build_dir/inject/assets/dil_math.valdimodule"
TZ=UTC touch -a -m -d '1981-01-01 01:01:02 UTC' \
  "$build_dir/inject/assets/dil_math.valdimodule"
(
  cd "$build_dir/inject"
  TZ=UTC 7z u -tzip -mx=9 -mtc=off -mta=off -bd -y \
    "$working_base" assets/dil_math.valdimodule >/dev/null
)

unsigned_set="$build_dir/unsigned"
aligned_set="$build_dir/aligned"
mkdir -p "$unsigned_set" "$aligned_set"
cp -- "$working_base" "$unsigned_set/base.apk"
cp -- "$input_dir"/split_config.*.apk "$unsigned_set/"

apk_names=(
  base.apk
  split_config.arm64_v8a.apk
  split_config.en.apk
  split_config.xxhdpi.apk
)

for apk_name in "${apk_names[@]}"; do
  manifest_dir="$build_dir/manifests/$apk_name"
  mkdir -p "$manifest_dir"
  unzip -p "$unsigned_set/$apk_name" AndroidManifest.xml \
    >"$manifest_dir/AndroidManifest.xml.original"
  perl -0777 -e '
    use strict;
    use warnings;
    my ($input, $output, $new_version_code) = @ARGV;
    open my $in, "<:raw", $input or die "open $input: $!";
    local $/;
    my $data = <$in>;
    close $in;
    my $old = pack("V", 2620230);
    my $new = pack("V", $new_version_code);
    my $count = ($data =~ s/\Q$old\E/$new/g);
    die "expected one versionCode field in $input, found $count\n"
      unless $count == 1;
    open my $out, ">:raw", $output or die "open $output: $!";
    print {$out} $data;
    close $out;
  ' \
    "$manifest_dir/AndroidManifest.xml.original" \
    "$manifest_dir/AndroidManifest.xml" \
    "$install_version_code"
  jar --update \
      --file "$unsigned_set/$apk_name" \
      --no-compress \
      -C "$manifest_dir" AndroidManifest.xml
  "$zipalign_bin" -f -P 16 4 \
    "$unsigned_set/$apk_name" \
    "$aligned_set/$apk_name"
  "$apksigner_bin" sign \
      --ks "$keystore" \
      --ks-key-alias "$keystore_alias" \
      --ks-pass "pass:$keystore_password" \
      --key-pass "pass:$key_password" \
      --v1-signing-enabled false \
      --v2-signing-enabled true \
      --v3-signing-enabled true \
      --v4-signing-enabled false \
      --out "$output_dir/$apk_name" \
      "$aligned_set/$apk_name"
  "$apksigner_bin" verify --verbose \
      "$output_dir/$apk_name" >/dev/null
  "$zipalign_bin" -c -P 16 4 "$output_dir/$apk_name"
  "$aapt2_bin" dump badging "$output_dir/$apk_name" |
    sed -n '1p' |
    grep -F "versionCode='$install_version_code'" >/dev/null
done

unzip -p "$output_dir/base.apk" assets/dil_math.valdimodule \
  >"$build_dir/dil_math.from-candidate.valdimodule"
cmp "$patched_module" "$build_dir/dil_math.from-candidate.valdimodule"

(
  cd "$output_dir"
  sha256sum ./*.apk >SHA256SUMS
)

printf 'Phase 5 instrumented candidate built at %s\n' "$output_dir"
