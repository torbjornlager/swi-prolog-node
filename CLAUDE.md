# Native SWI Web Prolog node

This is `swi-prolog-node`; the SWI pack name remains `web_prolog`.
Preserve Web Prolog semantics, selective imports and package compatibility.

No upward layer imports; opaque pids below distribution. Read
`docs/LAYERED_REAL_NODE_PLAN.md` for the layering design and the runtime README
for current qualifications. Keep relocation and behavior changes separate.

Run native checks with an explicit verified SWIPL and `./tools/test.sh`.
Frontend integration needs explicit asset roots. T5's historical peer is a
checksummed source archive under tests/fixtures, not a historical Git tag.
Never change installed engines or live n3/n5 merely to run these tests.
