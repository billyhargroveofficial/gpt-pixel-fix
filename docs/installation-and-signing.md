# Installation and signing

## Do not start on a valuable daily-driver session

Android treats the Play Store build and this local build as different
signers. Replacing one with the other normally requires uninstalling
`com.openai.chatgpt`, which deletes its app data. A fresh login into the
re-signed build is not guaranteed to work.

The physical proof-of-concept succeeded only because an already authenticated
local-signer session was preserved during the iterative upgrades.

## Build inputs

Place the exact official `1.2026.202` split set in
`patches/phase1/original/`:

```text
base.apk
split_config.arm64_v8a.apk
split_config.en.apk
split_config.xxhdpi.apk
```

The phase-1 build refuses different SHA-256 values. Use one stable private
keystore for every locally signed upgrade:

```sh
export CHATGPT_PATCH_KEYSTORE=/absolute/path/to/your.keystore
export CHATGPT_PATCH_KEY_ALIAS=your_alias
export CHATGPT_PATCH_KS_PASS='...'
export CHATGPT_PATCH_KEY_PASS='...'
```

Do not commit those values or the keystore.

## Build chain

```sh
cd patches/phase1
CHATGPT_PHASE4_INPUT_DIR=../phase4/input ./build.sh

cd ../phase4
./build.sh
```

Phase 1 exports its unsigned patched base, original MathJax module, and
signed split inputs when `CHATGPT_PHASE4_INPUT_DIR` is set. Phase 4 verifies
their hashes before continuing.

Install only after backing up and verifying recovery. A split set is installed
with:

```sh
adb install-multiple -r \
  output/chatgpt-1.2026.202-native-latex-phase4/base.apk \
  output/chatgpt-1.2026.202-native-latex-phase4/split_config.arm64_v8a.apk \
  output/chatgpt-1.2026.202-native-latex-phase4/split_config.en.apk \
  output/chatgpt-1.2026.202-native-latex-phase4/split_config.xxhdpi.apk
```

This document is not a promise that login or backend access will work.
