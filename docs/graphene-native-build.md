# GrapheneOS full-build ChatGPT LaTeX test

Date: 2026-07-31  
Status: completed on a dedicated emulator; no physical phone was flashed.

## Environment

- GrapheneOS source tag: `2026071500` (stable source, Android 17).
- Local custom product: `chatgpt_sdk_phone64_x86_64` /
  `chatgpt_emu64xa`, `userdebug`.
- Runtime fingerprint:
  `GrapheneOS/chatgpt_sdk_phone64_x86_64/chatgpt_emu64xa:17/CP2A.260605.016/2026073000:userdebug/test-keys`.
- Android release / SDK / security patch: `17` / `37` / `2026-07-05`.
- WebView provider: `app.vanadium.webview`
  `150.0.7871.124.0` (`787112439`), selected as both current and preferred.
- ChatGPT: untouched Google Play-signed ARM64 split set,
  `1.2026.202` (`2620225`), `primaryCpuAbi=arm64-v8a`.
- ARM64 APK execution on the x86_64 emulator used Android's test-only
  `libndk_translation.so` native bridge. The emulator was launched with
  `-qemu -cpu host`; without host AVX exposure the translator exited with
  `SIGILL`.
- Network: validated emulator Wi-Fi (`AndroidWifi`) via
  `-feature VirtioWifi`.

This is a UI/runtime experiment based on GrapheneOS source. It is not an
official GrapheneOS production image and says nothing about the security
properties of an official physical-device build.

## Workload and controls

The official application generated a long response after this prompt:

> Output exactly 120 separate display LaTeX equations, one equation per
> display block, each equation x squared plus y squared equals z squared. No
> prose and do not combine blocks.

The local database audit found 118 formula nodes in the native-gate response
and 114 in the WebView-gate response. The server did not obey the requested
count exactly, but both responses used the same simple supported expression
and nearly the same number of separate display blocks.

The only intentional application-state change was the existing Statsig local
override for gate `3320767387`:

- `true`: native `ValdiLatexFormulaContent`;
- `false`: `WebViewLatexFormulaContent`.

Each recorded run reset `dumpsys gfxinfo`, issued the same 24 up/down swipe
pairs (48 swipes total), and then collected frame, memory and view counts.
The virtual display was 1344 × 1440 at 60 Hz.

## Results

| Condition | Formula nodes | WebViews | Jank, three runs | p50 |
|---|---:|---:|---:|---:|
| Gate=true, native renderer | 118 | 0 | 2.12%, 2.91%, 0.00% | 17–18 ms |
| Gate=false, WebView renderer | 114 | 114 | 91.79%, 96.41%, 100.00% | 73 ms |

Raw rows are stored in
[`experiments/graphene-native-build.tsv`](../experiments/graphene-native-build.tsv).

The server returned the long answer quickly; the catastrophic delay and
scrolling failure appeared while the official client created and composed
the formula WebViews. This directly reproduces the original symptom on the
GrapheneOS build. Current GrapheneOS therefore does not fix the affected
account cohort.

## Artifact hashes

Images:

```text
3bfa990be8f52e19236f7a3accc59fa5c551154456671b7a375e4c8c4cc68aa9  system.img
f8feedb7ff2b3c6f115d03c4b75181f0521206c6ee1000e5d9bac47cdbc7255b  vendor.img
f7bddfaa858d053ca9fc8075065d113a47f6e85283bd234d3570d59080381137  ramdisk.img
60329d1cb93e7be9dd1fc43b731bdc8662a0deae6d1b73416b9eaec7db2b323b  userdata.img
90b18781606e42c03d5f87855c39350a098c17f519267bb845612d1d6f41000d  ramdisk-qemu.img
```

Official ChatGPT split APKs:

```text
f1198e4434d610a80bc1dd40ec2a5c268303d79939e7bcb9fc1d78d1548fc7e5  base.apk
6defac6da995c02846ed259fc048447599d21e29a18d71d61e0c0d7f4d50ae72  split_config.arm64_v8a.apk
7fbf3d0849e747855aa0ed0f35680f1976657a4718abd55022f4c0d9fdf67e04  split_config.en.apk
72e32fc131bb839eb152987a4a2a29c85baed157822e508216f85721a98a8ef3  split_config.xxhdpi.apk
```

The exact Vanadium WebView APK from the source tree had SHA-256
`67d24befad529cdcbcc1184e0c26cffff46231aa7d2fba2eda4ddc904841257f`.

## Practical conclusion

Do not flash the primary Pixel for this issue. GrapheneOS retains the same
OpenAI account assignment and ships a modern Vanadium WebView that still
magnifies the one-WebView-per-formula path. Current CalyxOS and LineageOS
also ship WebView generations in the same modern range. The only old
GrapheneOS/WebView combination that looks theoretically interesting is an
unsupported downgrade, which is security-inappropriate and protected against
rollback.

The safe mitigations remain:

1. use the official app with formulas grouped into a small number of
   `aligned` display blocks;
2. test another OpenAI account/profile, which may receive the native cohort;
3. wait for OpenAI to expand/fix the native renderer rollout.

Root can force the Statsig override while keeping the official APK untouched,
but it requires an unlocked/rooted phone and is appropriate only for a spare
test device.
