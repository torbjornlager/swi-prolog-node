# Native computed-answer cycle rejection

25 October 2026. Working-source candidate over
`b61270d11c55b4a98166365c793e97e4a721acbb`; not a deployed-node update.

Each successful goal evaluation checks the answer template before collection.
A cyclic template becomes `error(representation_error(cyclic_term),_)`. Escaping
cyclic exceptions receive the same finite representation error before pending
error storage; a finite prefix retains the existing pending-error behavior.
Ordinary errors retain their variable sharing. Internal cycles and locally caught
cyclic exceptions can still produce finite answers. No occurs-check flag changes
or general unification changes were made.

## Checks

The separate verified SWI 10.1.18 build (with the previously verified core/HTTP
patches) ran:

```sh
SWIPL=/Users/torbjorn.lager/.local/share/trinity-runtime-tests/swi-default-startup-2026-10-24/runtime/bin/swipl tools/test.sh T2
SWIPL=/Users/torbjorn.lager/.local/share/trinity-runtime-tests/swi-default-startup-2026-10-24/runtime/bin/swipl tools/test.sh T4_NATIVE
```

- [T2](T2.log): 145 parameter selections pass (101 test definitions). New cases
  exercise cycle rejection with finite/all collection, cyclic exception shapes,
  prefix preservation, local catches, sharing, next-page rejection and recovery.
- [T4_NATIVE](T4_NATIVE.log): 1529 parameter selections pass, including existing
  paging, promise, transport and cleanup assertions.
- Live disposable native SWI/Trealla checks: 31/31 required repair selections
  pass, including HTTP, WebSocket, RPC, promise sharing and callback/retry paths.
  One Trealla cyclic-exception engine diagnostic remains separate.

The consolidated report and exact working-source hashes are in
`trinity-conformance/reports/2026-10-25-cyclic-answer-rejection/`; it includes
commands, process records, source/binary hashes, health and preservation checks.
The peer engine was unmodified Trealla v3.14.10 with matching separate libraries.

Trealla's standalone exception diagnostic loses the cycle before its handler;
this native repair does not imply that engine issue is resolved. Actor messages,
the separate non-ground remote actor diagnostics, browser runtimes, GNU and the
book examples were not changed. The dependency pin, installed runtime launchers
and binaries, and n3/n5 remain unchanged. Existing ISO assessment files and their
README entry are preserved.
