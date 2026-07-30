# Evidence

`phase4/APK-SHA256SUMS` records the exact split set that was installed during
the physical Pixel test.

`phase4/REPRODUCIBLE-SOURCE-BUILD-SHA256SUMS` records two consecutive clean
source builds made from this repository after deterministic ZIP timestamps
were added. The two runs were byte-identical to each other.

The source-rebuilt APK hashes differ from the installed artifact because APK
signing bytes differ, but `zipcmp` reports identical ZIP payloads for all
four splits. Both sets use the same local test certificate.

The screenshots show only the math rendering problem and test result. The
authenticated bug-report form screenshot is retained locally in the ignored
`private-evidence/` directory because it exposes the account name and private
conversation titles.
