# Four-way SWI ISO/text outcome matrix — 25 October 2026

41 probes per configuration, **164 observations**. Exceptions and syntax
rejections are recorded outcomes, not counted as conformance passes or failures.
Trusted host modules load before the ISO flag is selected for these probes.
See REPORT.md for the independent early-bootstrap controls and limitations.

| Probe | Category | Default | Chars | ISO | ISO + chars |
|---|---|---|---|---|---|
| S01 | syntax | `"abc"` | `[a,b,c]` | `"abc"` | `[a,b,c]` |
| S02 | syntax | `"😀"` | `[😀]` | `"😀"` | `[😀]` |
| S03 | syntax | `[:-(a,b),c]` | `[:-(a,b),c]` | `syntax_error(operator_balance)` | `syntax_error(operator_balance)` |
| S04 | syntax | `[:-(a,b),c]` | `[:-(a,b),c]` | `[:-(a,b),c]` | `[:-(a,b),c]` |
| S05 | syntax | `','(==(A,-),true)` | `','(==(A,-),true)` | `','(==(A,-),true)` | `','(==(A,-),true)` |
| S06 | syntax | `syntax_error(quoted_punctuation)` | `syntax_error(quoted_punctuation)` | `syntax_error(quoted_punctuation)` | `syntax_error(quoted_punctuation)` |
| S07 | syntax | `A{a:1,b:"x"}` | `A{a:1,b:[x]}` | `A{a:1,b:"x"}` | `A{a:1,b:[x]}` |
| S08 | syntax | `receive({}(->(hello,true)))` | `receive({}(->(hello,true)))` | `receive({}(->(hello,true)))` | `receive({}(->(hello,true)))` |
| A01 | arithmetic | `[=('X',2)]` | `[=('X',2)]` | `[=('X',2.0)]` | `[=('X',2.0)]` |
| A02 | arithmetic | `[=('Order',>)]` | `[=('Order',>)]` | `[=('Order',<)]` | `[=('Order',<)]` |
| A03 | arithmetic | `[=('X',-2),=('R',-1)]` | `[=('X',-2),=('R',-1)]` | `[=('X',-2),=('R',-1)]` | `[=('X',-2),=('R',-1)]` |
| E01 | errors | `[=('N',2)]` | `[=('N',2)]` | `type_error(string,42)` | `type_error(string,42)` |
| E02 | errors | `evaluation_error(zero_divisor)` | `evaluation_error(zero_divisor)` | `evaluation_error(zero_divisor)` | `evaluation_error(zero_divisor)` |
| E03 | errors | `instantiation_error` | `instantiation_error` | `instantiation_error` | `instantiation_error` |
| E04 | errors | `[=('X',a),=('B',true)]` | `[=('X',a),=('B',true)]` | `permission_error(access,private_procedure,:(iso_assessment,/(static_probe,1)))` | `permission_error(access,private_procedure,:(iso_assessment,/(static_probe,1)))` |
| E05 | errors | `[]` | `[]` | `permission_error(modify,static_procedure,:(iso_assessment,/(abolish_probe,1)))` | `permission_error(modify,static_procedure,:(iso_assessment,/(abolish_probe,1)))` |
| E06 | errors | `[=('T',x)]` | `[=('T',x)]` | `[=('T',x)]` | `[=('T',x)]` |
| D01 | dcg | `[=('Tokens',[97,98])]` | `[=('Tokens',[a,b])]` | `[=('Tokens',[97,98])]` | `[=('Tokens',[a,b])]` |
| D02 | dcg | `[]` | `[]` | `[]` | `[]` |
| D03 | dcg | `[]` | `[]` | `[]` | `[]` |
| D04 | dcg | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` | `type_error(list,[a\|A])` |
| D05 | dcg | `type_error(callable,1)` | `type_error(callable,1)` | `type_error(callable,1)` | `type_error(callable,1)` |
| C01 | source | `"ab"` | `[a,b]` | `"ab"` | `[a,b]` |
| C02 | source | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `permission_error(access,private_procedure,:(iso_assessment,/(copy_probe,2)))` | `permission_error(access,private_procedure,:(iso_assessment,/(copy_probe,2)))` |
| C03 | source | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `permission_error(access,private_procedure,:(iso_assessment,/(copy_worker,1)))` | `permission_error(access,private_procedure,:(iso_assessment,/(copy_worker,1)))` |
| C04 | source | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` |
| C05 | dcg | `[97,98]` | `[a,b]` | `[97,98]` | `[a,b]` |
| C06 | source | `"ab"` | `[a,b]` | `"ab"` | `[a,b]` |
| C07 | source | `"[-(p(a),true)]"` | `"[-(p(a),true)]"` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,1)))` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,1)))` |
| C08 | source | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` | `copied(A,A,[97,98])` |
| C09 | source | `"[-(p(a),true)]"` | `"[-(p(a),true)]"` | `"[-(p(a),true)]"` | `"[-(p(a),true)]"` |
| B_rule_blacklist | sandbox | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` |
| B_rule_whitelist | sandbox | `admitted_nonbinding` | `admitted_nonbinding` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,1)))` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,1)))` |
| B_safe_blacklist | sandbox | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` |
| B_safe_whitelist | sandbox | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` | `admitted_nonbinding` |
| B_deny_blacklist | sandbox | `permission_error(call,sandboxed,open(assessment_forbidden,write,A))` | `permission_error(call,sandboxed,open(assessment_forbidden,write,A))` | `permission_error(call,sandboxed,open(assessment_forbidden,write,A))` | `permission_error(call,sandboxed,open(assessment_forbidden,write,A))` |
| B_deny_whitelist | sandbox | `permission_error(call,sandboxed,open(A,B,C))` | `permission_error(call,sandboxed,open(A,B,C))` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,0)))` | `permission_error(access,private_procedure,:('<temporary-module>',/(p,0)))` |
| B_guarded_dcg | sandbox | `[97,98]` | `[a,b]` | `[97,98]` | `[a,b]` |
| W01 | inheritance | `flags(false,string,string,"ab")` | `flags(false,string,chars,[a,b])` | `flags(false,string,string,"ab")` | `flags(false,string,chars,[a,b])` |
| W02 | inheritance | `flags(false,string,string,"ab")` | `flags(false,string,chars,[a,b])` | `flags(true,string,string,"ab")` | `flags(true,string,chars,[a,b])` |
| W03 | inheritance | `flags(false,string,"ab",string,"ab","ab")` | `flags(false,string,"ab",chars,[a,b],[a,b])` | `flags(true,string,"ab",string,"ab","ab")` | `flags(true,string,"ab",chars,[a,b],[a,b])` |

Temporary module identities are normalised only for display. Raw outcomes,
contexts, exact commands, engine/source hashes and bootstrap logs are preserved
in assessment-results/. This matrix is not the full Ulrich DCG assessment, a
language-profile certification, a benchmark, or approval to enable ISO mode.
