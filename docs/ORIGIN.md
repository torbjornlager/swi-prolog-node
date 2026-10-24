# Native package provenance

The native snapshot was extracted from trinity-demonstrator commit
`a75782d8d8e29ab8ad8330634f597e4b7f852980`, with the explicitly verified
external-example-root preparation introduced in the extraction rehearsal.
The complete original demonstrator remains at
https://github.com/torbjornlager/trinity-demonstrator.

The old native rehearsal head was
`fd5d32449a0f06ca982766ec548227e95a0bc867`. Its full refs and working tree were
backed up and the Git bundle verified before replacing this repository's
ancestry. No native runtime implementation or original test assertion was
removed in the clean snapshot. Investigation records and unrelated manuscript
material are retained in that backup and the source repository instead of here.

T5 uses the server files from the former `demonstrator-peer` commit
`2b5eae7ad4118e88f4aec77c513b6204dbf3b69e`. Their bytes and original MIT
license are preserved in a source-only archive. The fixture manifest records
all 53 file digests; T5 pins the compressed archive's SHA-256 before extraction.
No old Git object, tag or ancestry is required by that test.

The shared SXML validator stays at its existing native package path for import
compatibility and browser assembly. Package name/version, operators, exports
and runtime URLs are preserved. Only the package home URL now names this repo.

Runtime and frontend ownership are still being separated. This snapshot does
not migrate existing deployments or alter installed SWI/Trealla engines.
