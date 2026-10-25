# Separate DCG/text diagnostics

These 32 observations are **not** part of Ulrich's comparison or a portable-text
profile adoption. Each quote mode is set explicitly on the test module before
reading the query and any supplied source. The native default remains `string`.
The `chars` configuration exists only inside disposable test processes.

Eight diagnostics cover ordinary/empty/Unicode literals, supplied grammars with
those terminals, literal/list equality and runtime `phrase` on a literal. Both
paths match all diagnostic expectations. The supplied-source guarded path uses
`isolation:load_source_text/3` with the public profile active. This does not test
all production option/input readers, serialization or cross-node text migration.

| Case | Quote mode | Query | Source | Direct | Guarded |
|---|---|---|---|---|---|
| TD-001-string | string | `X="ab".` | `` | `['X'="ab"]` | `['X'="ab"]` |
| TD-001-chars | chars | `X="ab".` | `` | `['X'=[a,b]]` | `['X'=[a,b]]` |
| TD-002-string | string | `X="".` | `` | `['X'=""]` | `['X'=""]` |
| TD-002-chars | chars | `X="".` | `` | `['X'=[]]` | `['X'=[]]` |
| TD-003-string | string | `X="é😀".` | `` | `['X'="é😀"]` | `['X'="é😀"]` |
| TD-003-chars | chars | `X="é😀".` | `` | `['X'=[é,😀]]` | `['X'=[é,😀]]` |
| TD-004-string | string | `phrase(tokens,L).` | `tokens --> "ab".` | `['L'=[97,98]]` | `['L'=[97,98]]` |
| TD-004-chars | chars | `phrase(tokens,L).` | `tokens --> "ab".` | `['L'=[a,b]]` | `['L'=[a,b]]` |
| TD-005-string | string | `phrase(tokens,L).` | `tokens --> "".` | `['L'=[]]` | `['L'=[]]` |
| TD-005-chars | chars | `phrase(tokens,L).` | `tokens --> "".` | `['L'=[]]` | `['L'=[]]` |
| TD-006-string | string | `phrase(tokens,L).` | `tokens --> "é😀".` | `['L'=[233,128512]]` | `['L'=[233,128512]]` |
| TD-006-chars | chars | `phrase(tokens,L).` | `tokens --> "é😀".` | `['L'=[é,😀]]` | `['L'=[é,😀]]` |
| TD-007-string | string | `X="ab",X=[a,b].` | `` | `false` | `false` |
| TD-007-chars | chars | `X="ab",X=[a,b].` | `` | `['X'=[a,b]]` | `['X'=[a,b]]` |
| TD-008-string | string | `phrase("ab",L).` | `` | `['L'=[97,98]]` | `['L'=[97,98]]` |
| TD-008-chars | chars | `phrase("ab",L).` | `` | `['L'=[a,b]]` | `['L'=[a,b]]` |

The compiled native `"ab"` grammar consumes `[97,98]`; the character-list
configuration consumes `[a,b]`. The supplementary character U+1F600 is represented
as code 128512 in the native DCG and as one atom in the character-list DCG.
Empty text is a native empty string or an empty character list respectively;
both empty grammars consume no terminals. These representation differences are
not, by themselves, evidence of a DCG standards violation.
