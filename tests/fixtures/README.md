# Historical T5 peer fixture

`demonstrator-peer.tar.gz` contains only the 52 historical `src/` files and
original MIT LICENSE from trinity-demonstrator commit
`2b5eae7ad4118e88f4aec77c513b6204dbf3b69e` (the former `demonstrator-peer` tag).
No historical book material, web assets or Git objects are included.
All file contents are byte-identical to that source tree. The JSON manifest
records every file digest and the compressed archive digest.

T5 verifies the archive's SHA-256 before extracting into a temporary directory,
then starts the peer on a fresh port with the explicitly selected SWIPL.
No historical Git refs or network download are required. The peer is a test
fixture only; it is never imported into the native node or started on n3/n5.
Update the fixture and its pinned digest deliberately, without changing the
existing interoperability assertions.
