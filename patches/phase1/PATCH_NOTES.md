# ChatGPT Android 1.2026.202 — native LaTeX experiment

## Result

This patch forces the native Valdi/DIL LaTeX renderer that is already shipped
inside the official ChatGPT APK. It also prevents one unsupported expression
from poisoning the process-global renderer state and sending every later
formula through a separate WebView.

This is a diagnostic build, not an official OpenAI build. It is bound by hash
to package `com.openai.chatgpt`, version code `2620225`, version name
`1.2026.202`.

## Exact changes

Only two code sequences are changed. The DEX files keep their original sizes
and `dex\n037\0` format; SHA-1 and Adler-32 headers are recalculated.

1. `classes4.dex`, offset `0x5124b2`
   - Original: `0a03` (`move-result v3`)
   - Patched: `1213` (`const/4 v3, 0x1`)
   - Effect: the native-renderer feature-gate result is forced to `true`.
2. `classes5.dex`, offset `0x6ebe90`
   - Original: `6e20a2950100`
   - Patched: `000000000000` (three `nop` instructions)
   - Effect: a per-formula Valdi failure is no longer stored in the
     process-global `Ltv70;->c` latch. Unsupported syntax still falls back to a
     WebView, but later supported formulas remain native.

`patch_dex.pl` refuses unexpected old bytes. `build.sh` additionally refuses
any input APK or DEX whose SHA-256 differs from the analyzed release.

## Emulator test

Target: `emulator-5554`, API 37 Google Play AVD, ABI list
`x86_64,arm64-v8a`. No physical Pixel was touched.

The patched four-APK split set installed and launched successfully. There were
no `VerifyError`, crash, ANR, or OOM events.

Guest-mode synthetic response:

- 120 supported display formulas;
- one deliberately unsupported `\xrightarrow` formula;
- `libvaldi_dil_export.so` loaded successfully;
- logcat contained one expected Valdi error for `\xrightarrow`;
- `dumpsys meminfo` after rendering reported `WebViews: 1`, `Views: 180`,
  total PSS 280,913 KiB;
- there was one Chromium sandbox process;
- after 32 scripted scroll gestures: 527 frames, frame-time percentiles
  16/16/16/21 ms (50/90/95/99), legacy jank 5/527 (0.95%);
- Android's newer frame-deadline counter reported 74/527 (14.04%), mostly
  16 ms frames; it is included here rather than hidden.

The single WebView is consistent with the one unsupported expression taking
the fallback path while supported formulas use Valdi.

## Signing and login limitations

Android will not install this build over the Play-signed app. Every split must
be signed with the same replacement certificate, so the official app must be
uninstalled first. That deletes the live app data. The emulator installer
therefore creates a complete AVD snapshot before uninstalling.

Original Google signer SHA-256:

`b24f4bfbb3cf293f938703b9d87027c1102cc36dc4fa206910e08927db40473c`

Current local test signer SHA-256:

`cfbcc4201c9c66b8fdcc912bdbbf6706aa061b464eea8fca03a718b16b41ec80`

Observed behavior:

- guest mode works;
- the email/phone login page opens;
- full email/phone authentication was not attempted;
- Google sign-in fails before the account chooser because the replacement
  package/signature pair is not registered for Google's OAuth client;
- logcat says the Android application is not registered for OAuth2 and asks
  for a matching package name and SHA-1 certificate;
- Play Store reports a certificate mismatch;
- Play Integrity can report `UNRECOGNIZED_VERSION`, and OpenAI may reject
  authentication or later requests;
- the Play Store cannot update this locally signed package;
- the official source stamp is lost.

The standard Android debug keystore was used only for this AVD test. Keep one
stable private signing key for any future patched upgrades; changing it again
requires another uninstall.

## GrapheneOS conclusion

Changing Pixel firmware is very unlikely to fix this specific bug. The smooth
path is already present in the same APK and was selected by an application
feature gate; the slow path creates WebViews per formula. GrapheneOS does not
change OpenAI's rollout assignment and cannot make a re-signed APK pass
Google OAuth or Play Integrity.

The clean long-term fix is for OpenAI to enable/fix the native renderer in the
officially signed app. This patch proves that the renderer itself materially
improves the problematic workload, but its replacement signature makes it
unsuitable as a transparent daily-driver replacement for an authenticated
Play Store installation.

## Commands

Build:

```bash
cd patches/phase1
./build.sh
```

Install only on an emulator (the script rejects physical serials):

```bash
./install-emulator.sh emulator-5554
```

Restore the complete pre-install AVD state:

```bash
./restore-emulator.sh emulator-5554 chatgpt_prepatch_20260730
```

Known snapshots created during this investigation:

- `chatgpt_prepatch_20260730` — official app and its pre-patch AVD state;
- `chatgpt_patched_guest_20260730` — working patched guest-mode test.
