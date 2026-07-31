# Known limitations

## Rendering

- A full cold load of the exact long chat is not completely reliable.
  Individual formula images can remain blank even when the renderer returned
  valid SVG.
- Inline formula components do not wrap naturally with surrounding text.
  They may start on a new line or clip when wider than the viewport.
- Three diagnostic corpus failures remained: one dynamic `math.js` load,
  one malformed formula with an extra `}`, and an unsupported `matrix`
  environment.
- The phase-5 build is diagnostic only and is not the build installed on the
  physical Pixel.

## Signing and accounts

- The patched APK set is locally signed and cannot be installed over the
  Google Play-signed package.
- A clean install deletes existing app data.
- Google OAuth rejects an unregistered package/signature pair.
- Play Integrity may report `UNRECOGNIZED_VERSION`.
- Email/password authentication may also be rejected by OpenAI.
- The working physical test preserved an already authenticated session; it
  does not prove that a fresh login works.
- Play Store cannot update the locally signed package.

These signing limitations apply to the patched build. The later stock
Android 16/WebView 133 control used the untouched Google Play-signed ChatGPT
package and completed a fresh sign-in successfully.

## Frozen legacy stack

- The working physical stock control is Android 16 build
  `BP2A.250605.031.A2` with security patch `2025-06-05` and WebView/Chrome
  `133.0.6943.137`. It intentionally lacks later browser and OS security
  fixes.
- Disabling Play Store prevents its normal app/Mainline delivery, and the
  official developer option `ota_disable_automatic_update=1` disables
  automatic OTA application. This is a practical pin, not a cryptographic
  guarantee that the device can never download or offer an update.
- Android 16 protects Google Play Services OTA components from component-level
  ADB disabling. The attempted `pm disable-user` calls fail with
  `SecurityException`; the repository does not claim otherwise.
- A truly immutable pin requires stronger controls such as root/device-owner
  management or network enforcement, each with substantial security and
  usability costs.
- The bootloader remained unlocked for the downgrade experiment, further
  reducing physical-device security.

## Scope

Offsets and hashes are valid only for `1.2026.202`. The project intentionally
does not distribute OpenAI APKs, account data, cookies, or signing keys.
