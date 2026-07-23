---
title: Engine Internals
layout: default
parent: For Researchers
nav_order: 2
---

# Engine Internals
{: .no_toc }

This page orients researchers and contributors to ProofFrog's internals: the overall
pipeline, the canonicalization mechanism, the introspection commands for diagnosing
failing hops, and the <abbr title="Language Server Protocol">LSP</abbr>/<abbr title="Model Context Protocol">MCP</abbr> interfaces. It complements the user-facing
[Canonicalization]({% link manual/canonicalization.md %}) page, which describes *what*
the engine does from a proof-author's perspective; this page describes *how* it does
it. For the broader design of ProofFrog and its canonicalization approach, see the
ProofFrog [paper](https://eprint.iacr.org/2025/418) and
[thesis](https://hdl.handle.net/10012/20441), both listed on the
[Publications]({% link researchers/publications/index.md %}) page.

- TOC
{:toc}

---

## High-level architecture

ProofFrog is a pipeline: source files are parsed from FrogLang syntax into abstract
syntax trees (ASTs), those ASTs are type-checked by the semantic analyzer, and
verified proofs are checked step by step by the proof engine. For each adjacent pair
of games in the `games:` block of a `.proof` file, the engine (a) instantiates both
game expressions against the proof's `let:` bindings, (b) inlines the scheme methods
named in those expressions, and (c) runs the canonicalization pipeline on each
resulting game AST independently. If the two canonical forms are structurally
identical the interchangeability hop is accepted; if they differ only in logically
equivalent branch conditions the engine also queries Z3. Reduction-based hops are
accepted by checking that the stated assumption appears in the proof's `assume:`
block. The canonicalization step is itself a two-stage process: a fixed-point loop
(`CORE_PIPELINE`) that iterates until the game AST stops changing, followed by a
single-pass normalization (`STANDARDIZATION_PIPELINE`) that renames variables and
fields to canonical identifiers.

![ProofFrog pipeline]({{ site.baseurl }}/assets/diagram.svg)

---

## The transformation pipeline

For the user-facing model of what these transforms achieve, see the
[Canonicalization]({% link manual/canonicalization.md %}) page.

### Pipeline assembly

Canonicalization runs in two stages. The first stage is a fixed-point loop: an
ordered list of transformations is applied in sequence, then the entire sequence is
repeated from the beginning, until a full sweep produces no change. If the loop does
not converge within a generous iteration bound, a warning is emitted and processing
continues with the last state reached.

The second stage is a single-pass normalization that runs once after the first
stage converges. It renames local variables and fields to canonical identifiers,
sorts field assignments, and stabilizes independent statements. Because it runs
only once, its passes must be idempotent.

### Transform categories

The transforms that make up the fixed-point core stage are grouped by the class of
simplification they perform. Each source file under
[`proof_frog/transforms/`](https://github.com/ProofFrog/ProofFrog/tree/main/proof_frog/transforms)
in the ProofFrog repository defines one or more transforms in a given category. The
appendix at the bottom of this page gives a one-line summary of every individual
transform.

- **[Alpha-renaming](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/alpha_rename.py)** — a global pre-pipeline pass that gives every typed local binder a fresh, globally unique name. It runs first in `CORE_PIPELINE` and exists to make the passes after it safe; see [below](#why-alpha-renaming-runs-first).
- **[Algebraic identities](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/algebraic.py)** — arithmetic and bitstring identities: XOR cancellation and identity, boolean simplification, commutative-chain and concatenation-chain normalization, modular arithmetic folding, group-element exponent arithmetic, and decomposition of equalities between concatenations, injective-function calls, and tuples into their component parts.
- **[Uniform sampling](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/sampling.py)** — uniform random sampling and splice normalization: merging and splitting samples, propagating slices through concatenation, sinking samples later in a block, and converting init-only or single-use fields into local variables.
- **[Random functions](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/random_functions.py)** — `Function<D, R>` random-function elimination: lifting random-function calls into named temporaries, recognizing fresh/distinct/unique inputs, replacing calls with uniform samples when the inputs are provably distinct (including through injective encoding wrappers), and recognizing a `Map<K, V>` used as a lazily-populated random oracle and rewriting it into a sampled `Function<K, V>`.
- **[Map iteration](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/map_iteration.py)** — rewriting a `for ... in M.entries` scan that looks up a matching key into a direct map lookup, so scan-style and index-style lazy tables canonicalize the same way.
- **[Map re-indexing](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/map_reindex.py)** — re-keying a lazy map whose key is a consistent injective wrapping `w(x)` to use the inner value `x` directly (via the shared injective-wrapper recognizer protocol).
- **[Inlining and common-subexpression elimination](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/inlining.py)** — variable, field, and expression inlining; common-subexpression elimination; cross-method field aliasing; and hoisting of group-exponent and deterministic-call computations into `Initialize`.
- **[Control flow](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/control_flow.py)** — branch and dead-code elimination; conditional merging and guard factoring; normalization of equivalent `if`/`else` and early-return arrangements; return-statement simplification; Z3-backed unreachability and return-branch folding.
- **[Structural ordering](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/structural.py)** — field and statement ordering: topological sort with dead-code elimination, field unification and pruning, uniform-bijection elimination.
- **[Symbolic integer arithmetic](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/symbolic.py)** — integer sub-expression simplification via SymPy.
- **[Type-driven simplifications](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/types.py)** — null-guard elimination and subset-type normalization.
- **[Tuples](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/tuples.py)** — tuple index folding, expansion, collapsing, and `[a[0], a[1], ..., a[n-1]]` reconstruction.

Two further groups of transforms run outside the fixed-point core stage. The
[standardization passes](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/standardization.py)
form the single-pass second stage described above, renaming locals and fields to
canonical identifiers, sorting field assignments, and stabilizing independent
statements. The [assumption-application pass](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/assumptions.py)
is invoked by the proof engine only when an explicit assumption annotation appears
between two games in a proof, and substitutes the user-supplied equivalence pairs
between variables.

### Why alpha-renaming runs first

FrogLang's block scoping is **position-sensitive**: a name used before its local
declaration binds to the enclosing scope — a game field, an outer local, or a
parameter — and only from the declaration point onward does it bind to the local.
So in

```prooffrog
Int out = x;      // reads the FIELD x (the local x is not declared yet)
Int x = 0;        // declares the local x
return out + x;   // reads the LOCAL x
```

the two occurrences of `x` denote different things. This mirrors the typechecker's
scope stack, which adds a typed binder to the current scope only *after* visiting its
right-hand side.

That rule interacts badly with passes that rewrite code by splicing or reordering
block-local declarations — `BranchElimination` splicing the body of an `if (true)`
into its parent block, or `SimplifyIf` normalizing branches. If a body-local shadows
an outer local or a field, a name-blind rewrite conflates the two bindings, and the
engine can certify a hop that a distinguisher refutes. Two such soundness failures
were found in the 2026 audit.

`AlphaRename` removes the collision at the root rather than teaching each pass to
avoid it. It gives every typed local binder a fresh globally-unique name, rewriting
exactly the references that resolve to it under position-sensitive scope, so no later
pass has a same-name collision to mishandle. Only *local* binders are touched: fields,
method parameters, game parameters, and proof-`let:`/scheme/primitive names are left
alone. Loop binders are not renamed but are masked in the loop body, so a same-named
outer local cannot leak in. The pass skips names already carrying its reserved prefix,
which makes it idempotent on its own output and safe to sit inside the fixed-point loop.

Because every renamed binder is typed, the post-pipeline `VariableStandardize` pass
re-washes them all to the canonical `v1`, `v2`, ... names. Canonical forms are therefore
unchanged by the pass's presence — it buys soundness for the passes in between at no
cost to what two games are compared as.

### Reporting failures to the user

The engine has two complementary mechanisms for explaining why an
interchangeability hop failed.

The first is **near-miss reporting**. At any point where a transform *almost*
fires but cannot because some syntactic or semantic precondition does not hold,
it records a near-miss: a note carrying the transform's name, a human-readable
reason, an optional source location, an optional suggestion for the proof author,
and optional variable and oracle-method identifiers. After the pipeline completes,
the engine joins collected near-misses against the diff between the two canonical
forms by method name and variable presence, so that it can tell the user "this
simplification would have fired here except for X."

The second mechanism handles failures in regions where no transform ever attempted
to simplify. There the engine falls back to a small set of detectors for known
gaps in the canonicalization pipeline — cosmetic patterns the algorithm does not
currently normalize, such as commutativity and associativity of boolean operators
or reordering of independent if/else-if branches. When one of these detectors
matches the diff, the failure is reported as an engine limitation with a
suggested workaround rather than being left unexplained. The full list of known
limitations, together with their user-facing workarounds, is on the
[Limitations]({% link manual/limitations.md %}) page.

---

## Advantage-bound synthesis

[`proof_frog/advantage.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/advantage.py)
implements the machinery behind the `Advantage bound:` line and the `bound:` clause. For
the user-facing account, see [Advantage Bounds]({% link manual/advantage-bounds.md %}).
Structurally it is three tiers.

**Tier 1 — synthesis.** A pure fold over a verified proof's `hop_results` (or over the
proof AST directly, via `synthesize_from_steps`), composing the triangle-inequality sum of
per-hop losses into a SymPy expression over opaque `Adv_i` symbols. Equivalence hops
contribute `0`; assumption and lemma hops contribute one term each, with repeats collapsing
to `k * Adv^X(B)` and distinct reductions numbered `B1`, `B2`, and so on. The engine
supplies the per-hop bookkeeping — `justification`, `reduction`, `direction` — on each
`HopResult`. Tier 1 runs no transforms and calls neither Z3 nor SymPy's solver; it is
arithmetic over data the proof run already produced. Inductive proofs are reported as
unsupported rather than approximated.

**Tier 2 — statistical helper bounds.** When a `by_assumption` hop's notion resolves to a
helper `.game` file carrying a declared `advantage <= ...;` clause,
`resolve_statistical` substitutes the clause's game parameters from the assumption
instantiation and replaces the opaque term with the concrete expression. Set cardinalities
stay opaque positive symbols. The clause's per-oracle query counts are *derived* rather than
assumed: `_derive_oracle_count` statically counts how often the composed reduction invokes
each oracle, with a call in `Initialize` counting once, a call in any other reduction method
counting `count_<method>` times (that method being an oracle of the theorem game), loops
multiplying, and `if` branches summing as an upper bound. The result is a bound stated in
the theorem game's own query counts. An integer `calls <= N` cap in `assume:` pins the
surviving counts to `N`, which is sound because these bounds are monotone in the counts.

**Tier 3 — checking a claim.** `check_claimed_bound` matches each `advantage(...)`
reference in the proof's `bound:` clause to a synthesized term by exact `(notion, reduction)`
identity; an unmatched reference becomes a fresh nonnegative symbol, which can only add
slack and so cannot produce a false pass. It then decides whether
`claimed - synthesized >= 0` over the nonnegativity region, using SymPy for the easy cases
and falling back to Z3 over the reals (`_sympy_to_z3`, `_decide_nonnegative`). The real
region is a superset of the integer domain the quantities actually inhabit, so a
non-negativity proof there is sound for the intended domain. Symbolic exponents, a Z3
`unknown`, or a timeout yield `undecided` — never `verified`. The three-valued result is
`verified` / `not_verified` (which fails `prove` unless `--skip-bound`, and prints a witness)
/ `undecided` (which warns only).

On the AST side, the parser wraps a claim in `frog_ast.ClaimedBound`, kept opaque to the
generic name-resolution and type-check walk via `Visitor.should_descend` — the same
treatment `AdvantageClause` gets. `NameResolutionVisitor._check_claimed_bound` validates
well-formedness separately: that each named reduction is declared by the proof and composes
the notion it is paired with, and that each `count_` names a real theorem oracle.

---

## Engine introspection commands

Four CLI commands are intentionally excluded from the
[CLI Reference]({% link manual/cli-reference.md %}) because they target contributors
and MCP/LSP clients rather than end users. All four output JSON and are the CLI
equivalents of the corresponding MCP tools documented in
[`CLAUDE_MCP.md`](https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md)
in the ProofFrog repository.

### `step-detail <file> <step_index>`

Loads the proof file, instantiates and inlines game step `step_index` (zero-based),
runs the full canonicalization pipeline, and prints a JSON object whose key fields
are:

- `canonical` — the fully simplified game AST as a string. This is the field to
  read when writing a matching intermediate `Game` definition.
- `output` — the raw (pre-simplification) game AST with mangled internal variable
  names; ignore this field.
- `success` — `false` if the step index is out of range or an error occurred.
- `has_reduction`, `reduction`, `challenger`, `scheme` — metadata about whether the
  step involves a reduction and what its components are.

Comparing the `canonical` output of step `i` against step `i+1` directly shows any
remaining difference.

```bash
proof_frog step-detail examples/joy/Proofs/Ch2/OTPSecure.proof 0 | python -m json.tool
```

### `inlined-game <file> <step_text>`

Reads the `let:`, `assume:`, and `theorem:` blocks from the proof file and
constructs a minimal scratch proof in which `step_text` is the only game in the
`games:` list, then evaluates that scratch proof's step 0. Unlike `step-detail`, the
step does not need to appear in the actual proof file, and stub reductions that
prevent parsing do not interfere. This makes it the primary tool for writing
intermediate games: you can explore arbitrary game expressions against the proof's
`let:` context before committing any of them to the file. The returned JSON has the
same `canonical`, `output`, and `success` fields as `step-detail`.

```bash
proof_frog inlined-game examples/joy/Proofs/Ch2/OTPSecure.proof \
  "OneTimeSecrecy(E).Left against OneTimeSecrecy(E).Adversary" | python -m json.tool
```

### `canonicalization-trace <file> <step_index>`

Runs the canonicalization pipeline for the given proof step using
`run_pipeline_with_trace` and returns a JSON object containing `success`,
`iterations` (an array of `{iteration, transforms_applied}` objects, one per
iteration in which at least one transform changed the AST), `total_iterations`,
and `converged` (whether the pipeline converged before the 200-iteration limit).

This is the first diagnostic to reach for when a hop is failing and near-miss
output is not enough: it shows the exact sequence of transforms that fire and the
order in which they reduce the game, making it straightforward to identify which
simplification is missing.

```bash
proof_frog canonicalization-trace examples/joy/Proofs/Ch2/OTPSecure.proof 1 \
  | python -m json.tool
```

### `step-after-transform <file> <step_index> <transform_name>`

Applies the canonicalization pipeline up to and including the named transform
(first iteration only, using `run_pipeline_until`) and returns the game AST at that
point. The response JSON contains `success`, `output` (the AST as a string after the
named transform), `transform_applied` (whether the named transform actually changed
the AST), and `available_transforms` (the full list of valid names, useful when the
supplied name is not recognized).

This enables single-step debugging: apply transforms one by one and inspect the
intermediate AST to determine exactly where a simplification should have fired but
did not.

```bash
proof_frog step-after-transform examples/joy/Proofs/Ch2/OTPSecure.proof 1 \
  "UniformXorSimplification" | python -m json.tool
```

---

## LSP and MCP servers

### LSP server

ProofFrog ships with a Language Server Protocol implementation, started by
`proof_frog lsp`. It listens on stdio and is compatible with any LSP-aware editor;
see [Editor Plugins]({% link manual/editor-plugins.md %}) for the VSCode plugin
configuration. Other editors need only a thin client pointing at `proof_frog lsp`
as the server command.

The server implements the standard LSP features over FrogLang source: parse and
semantic diagnostics, go-to-definition, hover, context-sensitive completion and
signature help, document symbols for the Outline panel, local-symbol rename, and
folding ranges. The server caches the most recently successfully parsed AST for
each open document, so that completion, hover, and symbols continue to work even
while the document currently has syntax errors.

On save, the server runs the full proof engine against the file and surfaces the
results back to the editor as inline code lenses — a green check or red cross next
to each game in the `games:` block. The VSCode extension additionally uses a
custom notification to populate its proof-hops tree view with per-step results;
other clients can ignore that notification and rely on the code lenses alone.

### MCP server

ProofFrog also exposes its capabilities as
[Model Context Protocol](https://modelcontextprotocol.io/) tools for LLM-based
proof authoring. Start the MCP server with `proof_frog mcp [directory]`, where the
optional directory argument sets the working root from which all file paths are
resolved; a path-safety check prevents tools from reading or writing files outside
that directory or inside hidden subdirectories. The server communicates over stdio
and requires the optional MCP extra (`pip install 'proof_frog[mcp]'`).

The server exposes the following tools:

| Tool | Description |
|------|-------------|
| `version` | Report the installed ProofFrog version |
| `list_files` | Browse `.primitive`, `.game`, `.scheme`, `.proof` files as a nested tree |
| `read_file` | Read a ProofFrog file by path |
| `write_file` | Create or overwrite a file; parent directories are created automatically |
| `describe` | Compact interface summary (parameters, fields, signatures, no bodies) |
| `parse` | Syntax check; returns `{output, success}` |
| `check` | Semantic type-check; returns `{output, success}` |
| `prove` | Full proof verification; returns `{output, success, hop_results}` |
| `get_step_detail` | Canonical form of a proof step (use `canonical` field, not `output`) |
| `get_inlined_game` | Canonical form of an arbitrary step expression against the proof's `let:` context |
| `get_canonicalization_trace` | Which transforms fired at each fixed-point iteration |
| `get_step_after_transform` | Game AST after transforms up to a named pass |

It also exposes a `prooffrog://language-reference` MCP resource containing a concise
FrogLang syntax reference that an LLM can fetch without reading through example
files.

The MCP-oriented tool-usage guide and setup instructions are in
[`CLAUDE_MCP.md`](https://github.com/ProofFrog/ProofFrog/blob/main/CLAUDE_MCP.md)
in the ProofFrog repository. For a practical introduction to using the MCP server
to iteratively write and debug proofs with Claude Code, see the
[Gen AI & Proving page]({% link researchers/gen-ai.md %}).

---

## Appendix: transform catalog

This appendix contains a one-line summary of every transform in
[`proof_frog/transforms/`](https://github.com/ProofFrog/ProofFrog/tree/main/proof_frog/transforms),
grouped by source file. The authoritative ordering is in
[`pipelines.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/pipelines.py).

**[`alpha_rename.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/alpha_rename.py)**

- `AlphaRename` — gives every typed local binder a fresh globally-unique name, under position-sensitive scope. Runs first in `CORE_PIPELINE`; see [Why alpha-renaming runs first](#why-alpha-renaming-runs-first).

**[`algebraic.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/algebraic.py)**

- `UniformXorSimplification` — uniform `BitString<n>` XOR'd with an expression used only in that one XOR becomes a fresh uniform sample (one-time pad).
- `UniformModIntSimplification` — the `ModInt<q>` addition analogue.
- `UniformGroupElemSimplification` — the group-element scalar-multiplication analogue.
- `XorCancellation` — `x + x` becomes the zero bitstring.
- `XorIdentity` — `x + 0^n` becomes `x`.
- `ModIntSimplification` — folds constant modular arithmetic (identity, zero, inverse) via SymPy.
- `NormalizeCommutativeChains` — sorts XOR, `+`, and `*` operand chains into a canonical order; also normalizes `==`/`!=` operand order.
- `FlattenConcatChain` — left-associates `||` chains (sound under both Boolean OR and BitString concatenation).
- `ReflexiveComparison` — `x == x` → `true`, `x != x` → `false`.
- `BooleanIdentity` — boolean AND/OR with literal `true`/`false`.
- `BooleanAbsorption` — drops a conjunct `B` from an `A && B` chain when `A`'s flat OR-disjuncts are a subset of `B`'s.
- `SimplifyNot` — `!(a == b)` → `a != b`, `!(a != b)` → `a == b`.
- `GroupElemSimplification`, `GroupElemCancellation`, `GroupElemExponentCombination` — group-element exponent arithmetic (power-of-power, identity rules, term cancellation, and same-base exponent combination).
- `InjectiveEqualitySimplify` — `f(a..) == f(b..)` → component-wise `&&` (and `!=` to the disjunction) when `f` is `deterministic injective`.
- `ConcatEqualityDecompose` — decomposes an equality involving a concatenation into pairwise slice equalities when component lengths are derivable.
- `TupleEqualityDecompose` — rewrites `a != b` on tuples to the per-component disjunction of `!=` (the `==` direction is intentionally left atomic).

**[`sampling.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/sampling.py)**

- `SimplifySplice` — propagates slices through concatenation, collapsing `(a || b)[0:n]` when boundaries are static.
- `MergeUniformSamples` — merges `BitString<n>` and `BitString<m>` samples used only via concatenation into one `BitString<n+m>`.
- `MergeProductSamples` — the product (tuple) type analogue.
- `SplitUniformSamples` — the inverse: splits a `BitString<n>` into independent samples per non-overlapping slice.
- `SingleCallFieldToLocal` — converts an init-written, single-oracle-read field into a local variable.
- `CounterGuardedFieldToLocal` — converts counter-guarded (write-once) fields into local variables.
- `SinkUniformSample` — moves uniform samples as late as possible within a block to expose further simplifications.
- `LocalizeInitOnlyFieldSample` — converts a field sampled only in `Initialize` and never written again into a local there.
- `SliceOfInlineConcat` — rewrites a slice of a concatenated variable to the underlying component when the slice bounds line up with the concat boundaries.

**[`random_functions.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/random_functions.py)**

- `ExtractRFCalls` — lifts random-function calls out of expressions into named intermediate variables.
- `UniqueRFSimplification` — calls on `<-uniq`-sampled inputs each return an independent uniform sample.
- `ChallengeExclusionRFToUniform` — recognizes challenge-exclusion even through an injective encoding wrapper.
- `LocalRFToUniform` — a single-oracle-local random function called on a fresh input becomes a uniform sample.
- `DistinctConstRFToUniform` — statically distinct constant inputs yield independent uniform samples.
- `FreshInputRFToUniform` — a `<-uniq` input used only in one RF call (bare, in a tuple, or in a concatenation) becomes a uniform sample.
- `LocalFunctionFieldToLet` — unifies a game-local sampled `Function<K, V>` field with an identically-typed let-bound random function when the latter is otherwise unused in the game.
- `LazyMapToSampledFunction` — rewrites a `Map<K, V>` field used exclusively as a lazy random oracle into a sampled `Function<K, V>` field.
- `LazyMapPairToSampledFunction` — generalizes the above to a pair of maps used jointly through the guarded-pair lazy-lookup idiom.

**[`map_iteration.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/map_iteration.py)**

- `LazyMapScan` — rewrites a `for e in M.entries { if e[0] == k { return e[1]; } }` scan over a lazy map into a direct `M[k]` lookup, given uniqueness of map keys.

**[`map_reindex.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/map_reindex.py)**

- `MapKeyReindex` — re-indexes a lazy map whose key is a consistent injective wrapper `w(x)` to use the inner value `x` directly; uses the shared `_wrappers.py` recognizer protocol.

**[`inlining.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/inlining.py)**

- `RedundantCopy` — removes `x = y` when `y` is not later modified.
- `IfSplitBranchAssignment` — moves trailing statements into if/else branches when every branch assigns the same variable.
- `InlineSingleUseVariable` — substitutes at the single use site and drops the binding.
- `DeduplicateDeterministicCalls` — introduces a common temporary for duplicate calls to a `deterministic` method.
- `HoistDuplicateBranchCall` — hoists a deterministic call duplicated across exclusive branch returns into one local before the branches.
- `ForwardExpressionAlias` — forward-propagates a never-reassigned pure RHS to all uses.
- `HoistFieldPureAlias` — replaces reads of a field always equal to a pure expression with the expression.
- `CrossMethodFieldAlias` — propagates a `deterministic` call result stored in a field across oracle boundaries.
- `HoistDeterministicCallToInitialize` — hoists a deterministic call out of oracles into `Initialize` and caches it in a new field.
- `SplitOpaqueTupleField` — splits a tuple-typed field whose RHS is an opaque call and whose reads are constant-indexed projections into one field per used component.
- `HoistGroupExpToInitialize` — hoists `base ^ k` group exponentiations into `Initialize` and caches them in a pinned field (requires a prime-order / nonzero-exponent `requires:` context).
- `RefactorGroupElemFieldExp` — rewrites `base ^ (a * b)` as `Field2 ^ b` when a pinned field `Field2 = base ^ a` exists, exploiting `(g^a)^b = g^(a*b)`.
- `InlineSingleUseField` — inlines the write into the read site when a field is written and read exactly once (skipping pinned fields); a cross-method variant extends this when the expression is pure with stable field free vars.
- `ExtractRepeatedTupleAccess` — extracts repeated `var[constant]` accesses into named locals (CSE for tuple destructuring).
- `InlineLocalTupleLiteral` — substitutes a `[..] v = [..]` tuple-literal local through its constant-index accesses.
- `InlineMultiUsePureExpression` — inlines a pure expression at multiple uses when it does not duplicate non-determinism.
- `CollapseAssignment` — collapses a declaration followed by a reassignment into one statement.
- `RedundantFieldCopy` — removes intermediate locals used only to assign to a field.

**[`control_flow.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/control_flow.py)**

- `IfConditionAliasSubstitution` — substitutes field references with local aliases inside equality-guarded if-branches (including tuple-alias guards).
- `GuardConditionSimplification` — replaces a deterministic guard `C` with `true` in its then-branch and `false` in its else-branch.
- `IfToBooleanAssignment` — collapses `if (C) { x = true; } else { x = false; }` to `x = C;` (and the negated form).
- `RedundantConditionalReturn` — removes `if (c) { B } B` when `B` unconditionally returns and is immediately followed by an identical copy.
- `AbsorbRedundantEarlyReturn` — absorbs a duplicated early `return X;` into a following guard as a conjunction.
- `FactorCommonGuard` — transposes a P-first nested guard into V-first form, factoring a shared inner guard (P deterministic, V write-free).
- `MergeNestedGuard` — merges `if (P) { if (Q) {..} TAIL } TAIL` into `if (P && Q) {..} TAIL`.
- `DeadGuardedAssignmentElimination` — replaces `v = E` with `v = false` when the store is reached only under conditions entailing a later guard `G`.
- `IfFalseReturnToConjunction` — absorbs `if (P) { return false; } ... return Q;` into `... return Q && !P;`.
- `BranchElimination` — eliminates branches whose conditions are literal `true`/`false`.
- `UniqExclusionBranchElimination` — statically eliminates `x in S` branches when `x` was sampled via `<-uniq[S]` and `S` is unchanged since.
- `ElseUnwrap` — unwraps an else block when the if-branch unconditionally returns.
- `SimplifyReturn` — collapses `Type v = expr; return v;` to `return expr;`.
- `SimplifyIf` — merges adjacent if/else-if branches with identical (alpha-equivalent) bodies.
- `RemoveUnreachable` — Z3-backed dead-statement elimination after unconditional returns.
- `FoldEquivalentReturnBranch` — folds `if (P) { return X; } return Y;` to `return Y;` when Z3 proves `P ⇒ (X ↔ Y)` (refuses on non-deterministic calls).

**[`structural.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/structural.py)**

- `TopologicalSort` — reorders statements by data dependency, with dead-code elimination for no-effect statements.
- `RemoveDuplicateFields` — unifies two same-type fields that provably share the same value.
- `RemoveUnnecessaryFields` — deletes fields not contributing to any oracle's return value.
- `UniformBijectionElimination` — a uniform sample composed with an injective function becomes a fresh sample of the output type.

**[`symbolic.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/symbolic.py)**

- `SymbolicComputation` — integer sub-expressions round-tripped through SymPy for algebraic simplification.

**[`types.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/types.py)**

- `DeadNullGuardElimination` — removes `if x != None` guards when the type system already guarantees non-null.
- `SubsetTypeNormalization` — normalizes subset-type expressions to the underlying base type where semantics allow.

**[`tuples.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/tuples.py)**

- `FoldTupleIndex` — `[a, b, c][1]` → `b` when the index is a compile-time constant.
- `ExpandTuple` — rewrites a tuple into per-index variables when all accesses use constant indices.
- `SimplifyTuple` — collapses `[a[0], a[1], ..., a[n-1]]` into `a`.
- `CollapseSingleIndexTuple` — scalarizes a tuple accessed only at one constant index.
- `NormalizeProductLiteral` — normalizes `ProductType` tuple literals appearing in expression (value) positions, fixing their Z3 encoding. Declared types — `the_type` slots, sample spaces, loop variable types — are deliberately left untouched.

**[`standardization.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/standardization.py)**

- `StandardizeParameters` — canonicalizes oracle parameter names, so that two games differing only in what an oracle calls its argument canonicalize together.
- `VariableStandardize` — renames locals to `v1`, `v2`, ... in order of first appearance.
- `StandardizeFieldNames` — renames game fields to canonical names by oracle first-read order, then regroups by type so α-equivalent games agree on field numbering.
- `BubbleSortFieldAssignments` — sorts the field assignment block into a stable canonical order.
- `StabilizeIndependentStatements` — reorders independent statements canonically (Kahn topological sort).
- `FieldLexMinByRHS` — within each same-type field group, picks the lex-smallest slot for the field with the smallest Initialize-RHS key; runs at the end of the pipeline (after the final `VariableStandardize`) so RHS keys see final local names.

**[`assumptions.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/assumptions.py)**

- `ApplyAssumptions` — applies user-supplied equivalence pairs between variables. Not in the core pipeline; invoked by the engine when an assumption annotation appears between two games.
