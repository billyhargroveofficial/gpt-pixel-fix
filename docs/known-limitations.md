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

## Scope

Offsets and hashes are valid only for `1.2026.202`. The project intentionally
does not distribute OpenAI APKs, account data, cookies, or signing keys.
