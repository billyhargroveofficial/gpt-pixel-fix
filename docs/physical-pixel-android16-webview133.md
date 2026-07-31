# Physical Pixel proof: stock Android 16 and WebView 133

Date: 2026-07-31 (Europe/Moscow)

## Result

The catastrophic LaTeX scrolling regression disappeared on the physical
Pixel 9 Pro XL after a full downgrade to an official Google factory image
containing WebView 133. ChatGPT itself was not patched.

| Item | Exact value |
|---|---|
| Device | Pixel 9 Pro XL (`komodo`) |
| Build | `BP2A.250605.031.A2` / build ID `13578606` |
| Android | 16 |
| Security patch | `2025-06-05` |
| WebView | `com.google.android.webview` `133.0.6943.137` |
| Chrome | `133.0.6943.137` |
| ChatGPT | official `1.2026.202`, versionCode `2620225` |

The official package completed a fresh account sign-in. With the real heavy
mathematical conversation open, the test ran 12 upward and 12 downward
260-ms ADB swipes after resetting `gfxinfo`.

| Metric | Value |
|---|---:|
| Frames | 655 |
| Deadline-janky frames | 6 (`0.92%`) |
| p50 / p90 / p95 / p99 | 6 / 11 / 13 / 21 ms |
| Missed-vsync frames | 0 |

For context, the earlier official-app capture of the real heavy conversation
on a modern WebView path recorded `87.06%` jank and p50 `150 ms`. The physical
result therefore agrees with the matched emulator cross-install: the severe
amplifier follows the WebView generation, not Pixel/Tensor hardware or the
Android major version alone.

## Update pin applied during the experiment

The following state was verified after the test:

```text
automatic_system_updates=0
ota_disable_automatic_update=1
com.android.vending: disabled-user
com.google.android.factoryota: disabled-user
staged package/Mainline sessions: none
```

`ota_disable_automatic_update=1` is the backing global setting for Android's
developer option **Automatic system updates = off**. Play Store was also
disabled because its global auto-update switch had already allowed immediate
background updates on the freshly signed-in phone.

Verification commands:

```sh
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.version.security_patch
adb shell dumpsys webviewupdate
adb shell dumpsys package com.android.chrome | grep versionName
adb shell settings get global automatic_system_updates
adb shell settings get global ota_disable_automatic_update
adb shell pm list packages -d
```

To re-enable Play Store deliberately:

```sh
adb shell pm enable com.android.vending
adb shell appops set com.android.vending RUN_ANY_IN_BACKGROUND allow
adb shell appops set com.android.vending RUN_IN_BACKGROUND allow
```

Re-enabling it can immediately queue app and Mainline updates. Verify the
provider again before testing.

## What this pin does not guarantee

This is the strongest practical no-root pin applied in the experiment, not an
immutable security boundary. Stock Android 16 rejects component-level ADB
disabling of the protected Google Play Services OTA services with
`SecurityException`. The developer option prevents automatic OTA application,
but the system can still check for, download, or offer updates.

Absolute blocking would require materially more invasive controls such as
root, device-owner management, or enforced network filtering. Those controls
can break account sync, push notifications, Play Integrity, banking apps, and
recovery paths.

## Security warning

WebView is part of the browser attack surface. Version 133 and the June 2025
OS patch level intentionally omit later security fixes, while the unlocked
bootloader weakens physical security. This configuration is useful as a causal
proof and an emergency personal workaround, not a generally safe long-term
recommendation.

## Primary references

- AOSP `Settings.Global.OTA_DISABLE_AUTOMATIC_UPDATE`:
  https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/provider/Settings.java
- AOSP developer-option controller (value `1` means disabled):
  https://android.googlesource.com/platform/packages/apps/Settings/+/master/src/com/android/settings/development/DisableAutomaticUpdatesPreferenceController.java
