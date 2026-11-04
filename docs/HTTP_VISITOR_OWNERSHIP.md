# HTTP visitor ownership

Public deployments can opt into independent anonymous HTTP visitors with:

```prolog
set_setting(node_http_identity:anonymous_visitors, true).
```

This is an explicit deployment option; legacy installations retain their existing
anonymous identity policy until configured. It does not authenticate users or
make arbitrary native code safe to execute.

Browsers receive a stateless, HMAC-signed, host-only, HttpOnly, SameSite=Lax cookie.
HTTPS nodes use a Secure `__Host-wp_visitor` cookie. The signature is bound to the
node port, expires after one day, and uses a process-local OS-random secret.
Restarting the node invalidates its cookies and all in-memory sessions/queries.

CLI/RPC clients may instead send `X-Web-Prolog-Query-Owner` containing 64 lowercase
hex digits generated from 32 cryptographically random bytes. This is a bearer
capability for an anonymous conversation, not a user credential. Keep it private,
use HTTPS, and retain it across pages. It grants no authenticated capabilities.
The native `rpc/2-3` client creates one per invocation and reuses it on subsequent
pages. The browser runtime supplies an origin-specific capability for cross-site
RPC where cookies may be unavailable. Reverse proxies must permit that header in
CORS preflights and must not publish it in logs.

The server hashes the nonce before using it as an anonymous principal identifier,
so metadata and ordinary principal logs do not disclose a reusable capability.
Malformed or duplicate owner headers are rejected. Invalid/expired cookies receive
a new identity. A client retaining neither cookie nor capability gets an independent
query context on each request: offset replay remains possible, but it cannot check
out another visitor's live continuation.

HTTP cache keys now include the principal and resolved client IP as well as the
query. Anonymous ISOTOPE sessions inherit visitor ownership. Anonymous WebSocket
connections get independently generated principals when this option is enabled.
Anonymous promise/actor lifetime accounts remain request/carrier scoped.

Admission charges both the visitor and the resolved client address. Rotating
capabilities does not multiply the per-address request/concurrency allowance.
Cached HTTP work is limited to 16 entries per owner/address and 32 per address,
within the node's existing global cache size. Cache insertion evicts only the
submitting owner's entries; it does not displace someone else's continuation.
If the global/address quota is full, the submitting entry can be discarded and a
later offset request is recomputed, as for any cache miss. NAT users share the
address allowance; IP addresses are resource buckets, not user identities.

Public programs cannot set proxy identity, client-address, or budget headers via
RPC options, including runtime-bound options. Standalone trusted clients retain
custom-header support, and real Authorization credentials remain supported.
The `node:` alias exposes public builtins and ordinary system/list/apply calls,
not private controller/cache entry points. Explicit `node_*:` qualification cannot
re-enter controller internals through the validator's execution module. These
checks also apply to meta-calls such as `node:call(cache(...))`.

The proxy must overwrite client forwarding headers and protect direct backend
access. The runtime's legacy private/loopback proxy trust is not an OS isolation
boundary. Native exploits, container escape, and comprehensive hostile-worker
containment need separate qualification.

Run `SWIPL=/verified/swipl ./tools/test.sh T4_NATIVE` for the full node suite and
real-HTTP visitor tests. The latter covers two-client paging, signed-cookie and
header tampering, session ownership, cache pressure, identity churn, concurrent
admission, private-controller access, nested proxy-header forgery and native RPC.
