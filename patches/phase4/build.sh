#!/usr/bin/env bash
set -euo pipefail

phase3_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
python_tool="$phase3_root/tools/valdimodule.py"
generator="$phase3_root/tools/generate_mathjax_modules.mjs"
dex_patcher="$phase3_root/../phase1/patch_dex.pl"
input_base="$phase3_root/input/base-phase1-unsigned.apk"
input_module="$phase3_root/input/math_jax.original.valdimodule"
entries_dir="$phase3_root/work/math_jax.entries"
verify_dir="$phase3_root/work/math_jax.verified"
patched_module="$phase3_root/build/math_jax.phase4.valdimodule"
working_base="$phase3_root/build/base-phase4-unsigned.apk"
output_dir="$phase3_root/output/chatgpt-1.2026.202-native-latex-phase4"
output_base="$output_dir/base.apk"
install_version_code=2620230

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

for command in python node npm zstd unzip 7z zipcmp sha256sum touch jar java; do
  command -v "$command" >/dev/null
done
for tool in \
  "$zipalign_bin" \
  "$apksigner_bin" \
  "$aapt2_bin"; do
  test -x "$tool"
done
test -f "$keystore"
test -x "$dex_patcher"
test -f "$input_base"
test -f "$input_module"

verify_sha256() {
  local expected="$1"
  local file="$2"
  test "$(sha256sum "$file" | cut -d ' ' -f1)" = "$expected"
}

# Pin every phase-1 input so this isolated build cannot silently target a
# different APK set or MathJax asset.
verify_sha256 \
  d2af202efd729f25168597833ecadf635d8a34e363f7298aca400ce7ca29d703 \
  "$input_base"
verify_sha256 \
  73f3b322f29d882ccfe0784a193d077afb515f00a7ead3fff925af265227ad79 \
  "$input_module"
verify_sha256 \
  6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72 \
  "$phase3_root/input/splits-official/split_config.arm64_v8a.apk"
verify_sha256 \
  7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04 \
  "$phase3_root/input/splits-official/split_config.en.apk"
verify_sha256 \
  72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3 \
  "$phase3_root/input/splits-official/split_config.xxhdpi.apk"

mkdir -p "$phase3_root/work" "$phase3_root/build" "$output_dir"
rm -rf -- "$entries_dir" "$verify_dir"
rm -f -- \
  "$patched_module" \
  "$working_base" \
  "$output_dir/"*.apk \
  "$output_dir/"*.idsig

python "$python_tool" roundtrip "$input_module"
python "$python_tool" unpack "$input_module" "$entries_dir"

node "$generator" \
  "$phase3_root/vendor/mathjax-src-4.1.1/BaseMappings.js" \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/calligraphic.js" \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/double-struck.js" \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/cyrillic.js" \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/svg.js" \
  "$entries_dir" \
  >"$phase3_root/build/generated-modules.json"

node --check \
  "$entries_dir/src/mathjax_src/input/tex/base/BaseMappings.js"

python "$python_tool" pack "$entries_dir" "$patched_module" \
  >"$phase3_root/build/patched-module-inspect.json"
python "$python_tool" compare "$input_module" "$patched_module" \
  --expected-changed src/mathjax_src/input/tex/base/BaseMappings.js \
  --expected-changed hash \
  >"$phase3_root/build/module-compare.json"

python "$python_tool" unpack "$patched_module" "$verify_dir"
cmp \
  "$entries_dir/src/mathjax_src/input/tex/base/BaseMappings.js" \
  "$verify_dir/src/mathjax_src/input/tex/base/BaseMappings.js"
cmp "$entries_dir/hash" "$verify_dir/hash"

# Exercise the exact generated CommonJS sources against MathJax 4.1.1 on the
# host before they are packed into the Valdi archive.
node_fixture="$phase3_root/work/node-test"
rm -rf -- "$node_fixture"
mkdir -p "$node_fixture"
cp -- "$phase3_root/package.json" "$phase3_root/package-lock.json" \
  "$node_fixture/"
npm ci --ignore-scripts --no-audit --no-fund --prefix "$node_fixture"
test -d "$node_fixture/node_modules/@mathjax/src/cjs"
test -d "$node_fixture/node_modules/@mathjax/mathjax-newcm-font/cjs"
mkdir -p "$node_fixture/node_modules/@mathjax/src/mathjax_font"
cp -- "$phase3_root/vendor/node-fixture/mathjax_font/svg.js" \
  "$node_fixture/node_modules/@mathjax/src/mathjax_font/svg.js"
cp -- "$phase3_root/vendor/node-fixture/mathjax_font/package.json" \
  "$node_fixture/node_modules/@mathjax/src/mathjax_font/package.json"
cp -- "$entries_dir/src/mathjax_src/input/tex/base/BaseMappings.js" \
  "$node_fixture/node_modules/@mathjax/src/cjs/input/tex/base/BaseMappings.js"
cp -- "$phase3_root/vendor/mathjax-newcm-font-4.1.1/svg.js" \
  "$node_fixture/node_modules/@mathjax/mathjax-newcm-font/cjs/svg.js"
cp -- \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/tex-calligraphic.static.js" \
  "$node_fixture/node_modules/@mathjax/mathjax-newcm-font/cjs/svg/tex-calligraphic.js"
cp -- \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/tex-calligraphic-bold.static.js" \
  "$node_fixture/node_modules/@mathjax/mathjax-newcm-font/cjs/svg/tex-calligraphic-bold.js"
cp -- \
  "$phase3_root/vendor/mathjax-newcm-font-4.1.1/double-struck.static.js" \
  "$node_fixture/node_modules/@mathjax/mathjax-newcm-font/cjs/svg/double-struck.js"
node "$phase3_root/tools/host_mathjax_smoke.cjs" "$node_fixture" \
  >"$phase3_root/build/host-mathjax-smoke.json"

# Force Valdi's own "bundled fallback" branch. ChatGPT's dynamic-delivery
# cache otherwise overrides the APK's patched math_jax.valdimodule with the
# signed, unmodified remote bundle.
unzip -p "$input_base" classes.dex >"$phase3_root/build/classes.from-phase1.dex"
"$dex_patcher" \
  "$phase3_root/build/classes.from-phase1.dex" \
  "$phase3_root/build/classes.phase4.dex" \
  0x2ae220:5560678a:12100000

# The Markdown preprocessor normally recognizes display delimiters only when
# spaces precede them.  A block quote prefixes each line with ">", so \[ and
# \] become independent U+E001 inline sentinels and never reach LatexView.
# These equal-length regex replacements admit Markdown quote prefixes while
# preserving the existing display-block path.
unzip -p "$input_base" classes5.dex \
  >"$phase3_root/build/classes5.from-phase1.dex"
"$dex_patcher" \
  "$phase3_root/build/classes5.from-phase1.dex" \
  "$phase3_root/build/classes5.phase4.dex" \
  0x7e0b64:283f3a5c6e7c2429202a5c5c5d202a283f3a5c6e7c2429:283f3a5c6e7c24295b203e5d2a3f5c5c5d285c6e7c2429 \
  0x7e0b7d:283f3a5c6e7c5e29202a5c5c285c5b29202a283f3a5c6e7c2429:283f3a5c6e7c5e295b203e5d2a3f5c5c285c5b29285c6e7c2429

cp -- "$input_base" "$working_base"
mkdir -p "$phase3_root/build/inject/assets"
cp -- "$patched_module" \
  "$phase3_root/build/inject/assets/math_jax.valdimodule"
cp -- "$phase3_root/build/classes.phase4.dex" \
  "$phase3_root/build/inject/classes.dex"
cp -- "$phase3_root/build/classes5.phase4.dex" \
  "$phase3_root/build/inject/classes5.dex"
TZ=UTC touch -a -m -d '1981-01-01 01:01:02 UTC' \
  "$phase3_root/build/inject/assets/math_jax.valdimodule" \
  "$phase3_root/build/inject/classes.dex" \
  "$phase3_root/build/inject/classes5.dex"
(
  cd "$phase3_root/build/inject"
  TZ=UTC 7z u -tzip -mx=9 -mtc=off -mta=off -bd -y \
    "$working_base" assets/math_jax.valdimodule >/dev/null
)
TZ=UTC jar --update --file "$working_base" --no-compress \
  -C "$phase3_root/build/inject" classes.dex \
  -C "$phase3_root/build/inject" classes5.dex

apk_compare_report="$phase3_root/build/apk-payload-compare.txt"
if zipcmp "$input_base" "$working_base" >"$apk_compare_report"; then
  printf 'zipcmp unexpectedly found no phase-4 APK payload change\n' >&2
  exit 1
else
  zipcmp_status=$?
  test "$zipcmp_status" -eq 1
fi
awk '
  NR == 1 { if (substr($0, 1, 4) != "--- ") exit 1; next }
  NR == 2 { if (substr($0, 1, 4) != "+++ ") exit 1; next }
  NR > 2 {
    if ($0 ~ /^[-+] file '\''assets\/math_jax[.]valdimodule'\'', /) {
      mathjax++
      next
    }
    if ($0 ~ /^[-+] file '\''classes[.]dex'\'', /) {
      classes++
      next
    }
    if ($0 ~ /^[-+] file '\''classes5[.]dex'\'', /) {
      classes5++
      next
    }
    exit 1
  }
  END {
    if (NR != 8 || mathjax != 2 || classes != 2 || classes5 != 2) exit 1
  }
' "$apk_compare_report"

unsigned_set="$phase3_root/build/unsigned-vc$install_version_code"
aligned_set="$phase3_root/build/aligned-vc$install_version_code"
rm -rf -- "$unsigned_set" "$aligned_set"
mkdir -p "$unsigned_set" "$aligned_set"
cp -- "$working_base" "$unsigned_set/base.apk"
cp -- "$phase3_root/input/splits-official/"*.apk "$unsigned_set/"

apk_names=(
  base.apk
  split_config.arm64_v8a.apk
  split_config.en.apk
  split_config.xxhdpi.apk
)

# Every split in one installed package must carry the same monotonically
# increasing versionCode. Patch the single little-endian binary AXML field,
# then sign the complete set with the existing local debug key.
for apk_name in "${apk_names[@]}"; do
  manifest_dir="$phase3_root/build/manifests/$apk_name"
  rm -rf -- "$manifest_dir"
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
    my $old = pack("V", 2620225);
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
  TZ=UTC touch -a -m -d '1981-01-01 01:01:02 UTC' \
    "$manifest_dir/AndroidManifest.xml"
  TZ=UTC jar --update --file "$unsigned_set/$apk_name" --no-compress \
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
done

: >"$phase3_root/build/apksigner-verify.txt"
expected_signer=
for apk_name in "${apk_names[@]}"; do
  "$apksigner_bin" verify --verbose --print-certs \
      "$output_dir/$apk_name" \
      >>"$phase3_root/build/apksigner-verify.txt"
  "$zipalign_bin" -c -P 16 4 "$output_dir/$apk_name"
  badging="$("$aapt2_bin" dump badging "$output_dir/$apk_name" | sed -n '1p')"
  case "$badging" in
    *"versionCode='$install_version_code'"*) ;;
    *) printf 'unexpected versionCode in %s\n' "$apk_name" >&2; exit 1 ;;
  esac
  signer="$(
    "$apksigner_bin" verify --print-certs "$output_dir/$apk_name" |
      sed -n 's/^V3[.]0 Signer: certificate SHA-256 digest: //p'
  )"
  test -n "$signer"
  if test -z "$expected_signer"; then
    expected_signer="$signer"
  else
    test "$signer" = "$expected_signer"
  fi
done

unzip -p "$output_base" assets/math_jax.valdimodule \
  >"$phase3_root/build/math_jax.from-candidate.valdimodule"
cmp "$patched_module" \
  "$phase3_root/build/math_jax.from-candidate.valdimodule"

unzip -p "$output_base" classes.dex \
  >"$phase3_root/build/classes.from-candidate.dex"
cmp "$phase3_root/build/classes.phase4.dex" \
  "$phase3_root/build/classes.from-candidate.dex"
test "$(od -An -tx1 -j $((0x2ae220)) -N4 \
  "$phase3_root/build/classes.from-candidate.dex" | tr -d ' \n')" = \
  "12100000"

unzip -p "$output_base" classes4.dex \
  >"$phase3_root/build/classes4.from-candidate.dex"
unzip -p "$output_base" classes5.dex \
  >"$phase3_root/build/classes5.from-candidate.dex"
cmp "$phase3_root/build/classes5.phase4.dex" \
  "$phase3_root/build/classes5.from-candidate.dex"

# Retain both phase-1 byte patches in the phase-4 candidate.
test "$(od -An -tx1 -j $((0x5124b2)) -N2 \
  "$phase3_root/build/classes4.from-candidate.dex" | tr -d ' \n')" = "1213"
test "$(od -An -tx1 -j $((0x6ebe90)) -N6 \
  "$phase3_root/build/classes5.from-candidate.dex" | tr -d ' \n')" = \
  "000000000000"
test "$(od -An -tx1 -j $((0x7e0b64)) -N23 \
  "$phase3_root/build/classes5.from-candidate.dex" | tr -d ' \n')" = \
  "283f3a5c6e7c24295b203e5d2a3f5c5c5d285c6e7c2429"
test "$(od -An -tx1 -j $((0x7e0b7d)) -N26 \
  "$phase3_root/build/classes5.from-candidate.dex" | tr -d ' \n')" = \
  "283f3a5c6e7c5e295b203e5d2a3f5c5c285c5b29285c6e7c2429"

(
  cd "$output_dir"
  sha256sum ./*.apk >SHA256SUMS
)
sha256sum "$patched_module" \
  >"$phase3_root/build/math_jax.phase4.sha256"

printf 'Phase 4 candidate built at %s\n' "$output_dir"
