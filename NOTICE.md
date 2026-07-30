# Notice

This is an independent interoperability and performance investigation. It is
not an OpenAI product and contains no official ChatGPT APK, user database,
authentication session, cookie, password, or private signing key.

Patch scripts are pinned to the exact hashes of ChatGPT Android
`1.2026.202`. They are not safe to apply to another release without a new
binary analysis.

The files under `patches/phase4/vendor/` are the minimal MathJax 4.1.1 and
New Computer Modern font inputs needed to reproduce the experiment. Their
upstream license metadata is retained in the vendored tree.

The small APK under `launcher/dist/` is built from the source in `launcher/`.
It contains no ChatGPT code and only opens `https://chatgpt.com/` in a Chrome
Custom Tab.
