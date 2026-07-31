# Experiments

These scripts are preserved as the exact safety-pinned harness used during
the A/B investigation. They default to the isolated
`emulator-5580`/`chatgpt_emu64xa` target and refuse an unexpected device.

## Required local inputs

- official ChatGPT `1.2026.202` split APKs under
  `patches/phase1/original/`, or `CHATGPT_OFFICIAL_APK_DIR`;
- a GrapheneOS source/output tree in `GRAPHENE_BUILD_ROOT` for the native
  bridge experiment;
- synthetic conversation databases in `CHATGPT_FORMULA_DB_DIR`.

The databases are deliberately not committed. They were derived from a local
ChatGPT database schema even though their retained message content is
synthetic. `make-minimal-conversation-db.sh` and
`make_grouped_formula_db.py` document the transformations.

`set-statsig-latex-gate-5580.sh` changes only a rooted disposable emulator's
local Statsig override. It must not be pointed at a physical phone.

The original Google/Vanadium provider A/B is in
`webview-ab-results.tsv`. The 12 primary Android 16/17 renderer rows plus six
bidirectional WebView 133/145 cross-install rows are in
`android16-17-primary.tsv`; full-factorial conditions are documented in
`docs/android16-17-matched-control.md`.

`graphene-native-build.tsv` contains the six full GrapheneOS source-build
runs: three with the native renderer and three with the one-WebView-per-
formula renderer.

The practical response-format mitigation is in `formula-grouping.tsv`.
It compares 12 display blocks of 10 aligned rows and one display block of 120
aligned rows against the 120-separate-block baseline. Its methodology,
content audits and prompt template are documented in
`docs/formula-grouping-workaround.md`.
