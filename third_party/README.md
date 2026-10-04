# OpenP2P source snapshot

`openp2p/` contains the Go sources from the requested local reference project,
including its OpenHarmony exports. `SOURCE.json` records the reference commit
and each source file's SHA256; `LICENSE` retains the original MIT license.
No account configuration, credentials, build cache, or development signing
materials are included.

Desktop CI builds this source with Go 1.20.x. The bundled QUIC version depends
on Go 1.20 internals; upgrading Go requires upgrading and testing QUIC together.

The OHOS `.so`/`.h` pair in `ohos/entry/libs/arm64-v8a/` is copied together from
the reference project's OpenHarmony-SIG Go build. Rebuild OHOS libraries on
Linux using OpenHarmony-SIG Go (`GOOS=openharmony`, arm64, CGO, c-shared), never
with stock Go or `GOOS=linux`.
