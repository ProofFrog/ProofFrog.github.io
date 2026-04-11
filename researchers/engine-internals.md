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

- **[Algebraic identities](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/algebraic.py)** — arithmetic and bitstring identities: XOR cancellation and identity, boolean simplification, commutative-chain normalization, modular arithmetic folding, group-element exponent arithmetic.
- **[Uniform sampling](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/sampling.py)** — uniform random sampling and splice normalization: merging and splitting samples, propagating slices through concatenation, sinking samples later in a block, and converting init-only or single-use fields into local variables.
- **[Random functions](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/random_functions.py)** — `Function<D, R>` random-function elimination: lifting random-function calls into named temporaries, recognizing fresh/distinct/unique inputs, and replacing calls with uniform samples when the inputs are provably distinct (including through injective encoding wrappers).
- **[Inlining and common-subexpression elimination](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/inlining.py)** — variable, field, and expression inlining; common-subexpression elimination; cross-method field aliasing.
- **[Control flow](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/control_flow.py)** — branch and dead-code elimination; conditional merging; return-statement simplification; Z3-backed unreachability analysis.
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

**[`algebraic.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/algebraic.py)**

- `UniformXorSimplification` — uniform `BitString<n>` XOR'd with an expression used only in that one XOR becomes a fresh uniform sample (one-time pad).
- `UniformModIntSimplification` — the `ModInt<q>` addition analogue.
- `UniformGroupElemSimplification` — the group-element scalar-multiplication analogue.
- `XorCancellation` — `x + x` becomes the zero bitstring.
- `XorIdentity` — `x + 0^n` becomes `x`.
- `ModIntSimplification` — folds constant modular arithmetic via SymPy.
- `NormalizeCommutativeChains` — sorts XOR, `+`, and `*` operand chains into a canonical order.
- `ReflexiveComparison` — `x == x` → `true`, `x != x` → `false`.
- `BooleanIdentity` — boolean AND/OR with literal `true`/`false`.
- `SimplifyNotPass` — `!(a == b)` → `a != b`, `!(a != b)` → `a == b`.
- `GroupElemSimplification`, `GroupElemCancellation`, `GroupElemExponentCombination` — group-element exponent arithmetic.

**[`sampling.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/sampling.py)**

- `SimplifySplice` — propagates slices through concatenation, collapsing `(a || b)[0:n]` when boundaries are static.
- `MergeUniformSamples` — merges `BitString<n>` and `BitString<m>` samples used only via concatenation into one `BitString<n+m>`.
- `MergeProductSamples` — the product (tuple) type analogue.
- `SplitUniformSamples` — the inverse: splits a `BitString<n>` into independent samples per non-overlapping slice.
- `SingleCallFieldToLocal` — converts an init-written, single-oracle-read field into a local variable.
- `CounterGuardedFieldToLocal` — converts counter-guarded (write-once) fields into local variables.
- `SinkUniformSample` — moves uniform samples as late as possible within a block to expose further simplifications.
- `LocalizeInitOnlyFieldSample` — converts a field sampled only in `Initialize` and never written again into a local there.

**[`random_functions.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/random_functions.py)**

- `ExtractRFCalls` — lifts random-function calls out of expressions into named intermediate variables.
- `UniqueRFSimplification` — calls on `<-uniq`-sampled inputs each return an independent uniform sample.
- `ChallengeExclusionRFToUniform` — recognizes challenge-exclusion even through an injective encoding wrapper.
- `LocalRFToUniform` — a single-oracle-local random function called on a fresh input becomes a uniform sample.
- `DistinctConstRFToUniform` — statically distinct constant inputs yield independent uniform samples.
- `FreshInputRFToUniform` — a `<-uniq` input used only in one RF call becomes a uniform sample.

**[`inlining.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/inlining.py)**

- `RedundantCopy` — removes `x = y` when `y` is not later modified.
- `InlineSingleUseVariable` — substitutes at the single use site and drops the binding.
- `DeduplicateDeterministicCalls` — introduces a common temporary for duplicate calls to a `deterministic` method.
- `ForwardExpressionAlias` — forward-propagates a never-reassigned pure RHS to all uses.
- `HoistFieldPureAlias` — replaces reads of a field always equal to a pure expression with the expression.
- `InlineSingleUseField` — inlines the write into the read site when a field is written and read exactly once.
- `InlineMultiUsePureExpression` — inlines a pure expression at multiple uses when it does not duplicate non-determinism.
- `CollapseAssignment` — removes trivial `x = x`.
- `RedundantFieldCopy` — removes field assignments that duplicate a field already holding the same value.
- `CrossMethodFieldAlias` — propagates a `deterministic` call result stored in a field across oracle boundaries.

**[`control_flow.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/control_flow.py)**

- `BranchElimination` — eliminates branches whose conditions are literal `true`/`false`.
- `SimplifyIf` — merges adjacent if/else-if branches with identical bodies under an OR condition.
- `SimplifyReturn` — collapses `Type v = expr; return v;` to `return expr;`.
- `RemoveUnreachable` — Z3-backed dead-statement elimination after unconditional returns.
- `IfConditionAliasSubstitution` — substitutes a known alias inside an if condition.
- `RedundantConditionalReturn` — drops the else branch when the then branch unconditionally returns.

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

**[`standardization.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/standardization.py)**

- `VariableStandardize` — renames locals to `v1`, `v2`, ... in order of first appearance.
- `StandardizeFieldNames` — renames game fields to `field1`, `field2`, ... in order of first appearance.
- `BubbleSortFieldAssignments` — sorts the field assignment block into a stable canonical order.
- `StabilizeIndependentStatements` — reorders independent statements canonically by stable string comparison.

**[`assumptions.py`](https://github.com/ProofFrog/ProofFrog/blob/main/proof_frog/transforms/assumptions.py)**

- `ApplyAssumptions` — applies user-supplied equivalence pairs between variables. Not in the core pipeline; invoked by the engine when an assumption annotation appears between two games.
