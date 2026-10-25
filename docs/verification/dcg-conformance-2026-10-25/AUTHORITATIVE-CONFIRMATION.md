# Final DCG specification: confirmation pending

25 October 2026. This is a standards-clarification inquiry, not a SWI bug report
or a proposal to change its default behaviour. The inquiry was sent to Ulrich
Neumerkel on 25 October 2026 after explicit user approval. Confirmation is pending.

## Evidence found

The public comparison links a draft error subclause. The final published
specification is identified by ISO as ISO/IEC TS 13211-3:2025, but the public
previews inspected do not include the required error/negation clauses.
The final requirements therefore remain unconfirmed in this investigation.

There is relevant maintainer evidence: Jan Wielemaker's SWI 9.3.23 announcement
(18 April 2025) explains that partial terminal-list grammar bodies were removed
to improve ISO alignment and describes an instantiation error. The corresponding
commit removes the branch that had accepted partial terminals. This is evidence
of an intentional compatibility decision, not proof of the final error wording.
Current upstream `boot/dcg.pl` still uses `is_list/1` and the list-type-error
branch observed in our separate engine. We must not infer from the announcement
that our measurements are wrong, or from our measurements that the announcement
settles the final specification.

Sources checked:

- [Jan's SWI 9.3.23 announcement](https://swi-prolog.discourse.group/t/ann-swi-prolog-9-3-23/8948)
- [Partial-terminal change, commit 0fb90b28696650c6475f07c719251883ca39a97a](https://github.com/SWI-Prolog/swipl-devel/commit/0fb90b28696650c6475f07c719251883ca39a97a)
- [Current host DCG translator](https://github.com/SWI-Prolog/swipl-devel/blob/master/boot/dcg.pl) — moving branch; checked 25 October 2026, supplementary evidence only
- [Published specification identity](https://www.iso.org/standard/83635.html)
- [Ulrich's comparison](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase)
- [Draft error subclause](https://www.complang.tuwien.ac.at/ulrich/iso-prolog/draft-8.18.1.3)

## Sent inquiry

Recipient: Ulrich Neumerkel, `ulrich@complang.tuwien.ac.at`, the public
contact given on his ISO Prolog working-documents page.

Subject: Clarifying final ISO/IEC TS 13211-3:2025: partial terminals and negation

Dear Ulrich,

We are checking the portable DCG contract for Web Prolog. Your phrase comparison
and linked draft describe outcomes for the following cases:

```prolog
phrase([a|Tail], Input).
phrase(([a], \+1), []).
phrase(([a], \+1; []), []).
```

Our separate SWI 10.1.18 build reports a list type error in the first case and a
callable type error in the other two, identically with and without our execution
guards. The relevant DCG translation branches are also present in current SWI
upstream source.

Could you confirm the requirements of the **final published 2025 specification**,
with clause references, particularly:

1. Must the first case raise `instantiation_error` for the unbound terminal-list
   tail, rather than a list type error?
2. When grammar negation is supported, must the second and third cases fail and
   succeed respectively because the negation is never reached, or may translation
   reject its invalid argument before execution?
3. Are any of these choices permitted variations or affected by a strictly
   conforming mode? Does the final text differ from the linked draft here?

We are seeking clarification before preparing any implementation report. This
is not a request to change SWI's established defaults; compatibility may favour
an opt-in portable layer even if a difference is confirmed.

Many thanks,
Torbjörn

## Submission verification

Sent using Apple Mail from the user's iCloud account. The recipient address was
checked in the compose window. After Mail's send delay ended, the message appeared
in the Sent mailbox with the exact subject above and time 11:33 (local time,
25 October 2026); its sent-message window was opened and the body checked.
The email was plain text, without attachments. This verifies submission via Mail,
not delivery to the recipient or agreement with the proposed interpretations.
No upstream bug report or request to change SWI defaults was sent.

## Decision after confirmation

Record the answer with its source/date and final clause references. Separate
confirmed requirements from implementation policy. Only then decide whether an
upstream clarification, a narrow candidate repair, or a separately selected
portable DCG implementation is appropriate. No runtime, installed-engine or
n3/n5 change is part of this inquiry.
