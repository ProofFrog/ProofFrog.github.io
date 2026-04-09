---
title: Engine Internals
layout: default
parent: For Researchers
nav_order: 2
---

# Engine Internals

This page is written for researchers who want to contribute to ProofFrog, understand
its canonicalization pipeline at the module level, use the engine-introspection CLI
commands to diagnose failing proof hops, write a new editor plugin against the LSP
server, or script ProofFrog from an MCP client. It complements the user-facing
[Canonicalization]({% link manual/canonicalization.md %}) page, which describes *what*
the engine does from a proof-author's perspective; this page describes *how* it does
it.

---

## High-level architecture

![ProofFrog pipeline]({{ site.baseurl }}/assets/diagram.png)

ProofFrog is a pipeline: source files are parsed from FrogLang syntax into abstract
syntax trees (ASTs), those ASTs are type-checked by the semantic analyzer, and
verified proofs are checked step by step by the proof engine. The CLI entry point
(`proof_frog prove`) drives this sequence. For each adjacent pair of games in the
`games:` block of a `.proof` file, the engine (a) instantiates both game expressions
against the `let:` bindings in the proof, (b) inlines the scheme methods named in
those expressions, and (c) runs the canonicalization pipeline on each resulting game
AST independently. If the two resulting canonical forms are structurally identical,
the interchangeability hop is accepted; if they differ only in logically equivalent
branch conditions the engine also queries Z3. Reduction-based hops are accepted
by checking the stated assumption appears in the proof's `assume:` block without
running the canonicalization pipeline. The canonicalization step is itself a two-stage
process: a fixed-point loop (`CORE_PIPELINE`) that iterates until the game AST stops
changing, followed by a single-pass normalization (`STANDARDIZATION_PIPELINE`) that
renames variables and fields to canonical identifiers. The full transform catalog is
assembled in `proof_frog/transforms/pipelines.py` and described in detail in the
[Transformation pipeline](#the-transformation-pipeline) section below.

---

## Core modules

The following paragraphs describe each top-level module in the `proof_frog/` package.
The authoritative source for this list is `proof_frog/CLAUDE.md`.

**`proof_frog.py`** is the Click-based CLI entry point. It defines commands for
`version`, `parse`, `check`, `prove`, `describe`, `step-detail`, `inlined-game`,
`canonicalization-trace`, `step-after-transform`, `web`, `lsp`, and `mcp`. The
public commands (`version`, `parse`, `check`, `prove`, `describe`, `web`) are
documented in the [CLI Reference]({% link manual/cli-reference.md %}); the four
introspection commands are documented in the
[Engine introspection commands](#engine-introspection-commands) section of this page.

**`frog_ast.py`** defines every AST node type. All of ProofFrog's analysis and
transformation passes operate on these dataclasses. The main hierarchies are `Root`
(the top-level file node), `Game`, `Scheme`, `Primitive`, `ProofFile`, `Statement`,
and `Expression`. Each node carries a `SourceOrigin` (file and line number) used in
error messages and near-miss location reporting.

**`frog_parser.py`** wraps the ANTLR-generated parsers in `proof_frog/parsing/`. It
exposes a small public API: `parse_file`, `parse_proof_file`, `parse_primitive_file`,
`parse_scheme_file`, `parse_game_file`, and `resolve_import_path`. ParseError is raised
on syntax errors and carries line and column information for the LSP diagnostics layer.

**`semantic_analysis.py`** performs type checking and well-formedness checking on a
parsed AST. It checks that types match across assignments and return statements,
that `deterministic`/`injective` modifiers agree between a primitive declaration and
its scheme implementation, that the Left and Right games in a `.game` file have
compatible signatures, and that imports resolve. The main entry point is
`check_well_formed(root, file_path)`.

**`proof_engine.py`** is the proof verifier. It drives the game-hopping loop:
instantiating games, invoking the inliner, calling `run_pipeline` and
`run_standardization` from `transforms/_base.py`, comparing canonical forms, and
collecting near-misses for the diagnostics layer. It uses Z3 for equivalence checking
of branch conditions and SymPy (via `SymbolicComputation`) for integer arithmetic.
Proof verification runs in parallel by default via `ProcessPoolExecutor`; set the
`PROOFFROG_SEQUENTIAL` environment variable or pass `--sequential` to force a single
process.

**`visitors.py`** provides the AST visitor and transformer base classes:
`Visitor[U]` (read-only traversal returning `U`), `Transformer` (returns a new AST
node), and `BlockTransformer` (works on lists of statements). It also contains the
core utility transformers used directly by the proof engine: `SubstitutionTransformer`
(formal-parameter substitution), the inlining logic, and converters that translate
FrogLang expressions into Z3 and SymPy representations.

**`transforms/`** is the modular canonicalization pipeline. Each file in this
directory defines one or more `TransformPass` subclasses for a particular domain.
`pipelines.py` assembles these into `CORE_PIPELINE` and `STANDARDIZATION_PIPELINE`.
`_base.py` provides the `TransformPass` abstract base class, `PipelineContext`,
`NearMiss`, and the `run_pipeline` / `run_standardization` / `run_pipeline_with_trace`
/ `run_pipeline_until` runners. This subsystem is described at length in
[The transformation pipeline](#the-transformation-pipeline) below.

**`diagnostics.py`** classifies proof-hop failures. When canonicalization produces
two non-identical forms, `diagnose_failure` parses the engine's equivalence diff into
per-method `DiffHunk` objects, matches them against the `NearMiss` records emitted by
transforms, and applies the five `ENGINE_LIMITATION_DETECTORS` to identify known
engine gaps. The result is a `Diagnosis` containing human-readable `Explanation`
objects. See [Diagnostics and near-miss matching](#diagnostics-and-near-miss-matching).

**`describe.py`** generates compact, human-readable interface summaries for any
FrogLang file. It prints the exported name, parameters, fields, and method signatures
without method bodies. Both the `describe` CLI command and the `describe` MCP tool
delegate to this module.

**`dependencies.py`** resolves the import graph for a proof file, computing the
transitive closure of `.primitive`, `.scheme`, and `.game` imports so that the proof
engine and semantic analyzer can load all required definitions.

**`web_server.py`** and **`web/`** implement the Flask-based browser editor exposed
by the `web` command. The server provides REST endpoints for parse, check, prove,
inline, describe, and scaffold operations. The `web/` directory contains a vanilla
ES module client with a toolbar, an Insert dropdown for scaffolding wizards, and
engine introspection actions.

**`lsp/`** implements the Language Server Protocol server. Nine files handle distinct
LSP features; the server communicates with editor clients over stdio using
`TextDocumentSyncKind.Full`. This subsystem is described in
[LSP and MCP](#lsp-and-mcp).

**`mcp_server.py`** implements the MCP (Model Context Protocol) server for Claude
Code integration. It exposes proof-authoring and introspection tools as MCP tool
calls. See [LSP and MCP](#lsp-and-mcp).

**`scaffolding.py`** provides AST-based code-generation helpers for the web editor's
"Insert" wizards. It uses `SubstitutionTransformer` from `visitors.py` to perform
formal-parameter substitution when cloning game and reduction stubs, deliberately
avoiding `proof_engine.instantiate` because that inlines field-level type aliases too
eagerly for scaffolding purposes.

**`antlr/`** and **`parsing/`** contain the ANTLR grammar files
(`Primitive.g4`, `Scheme.g4`, `Game.g4`, `Proof.g4`) and the generated Python parser
code respectively. The `parsing/` directory is excluded from black, mypy, and pylint;
regenerate it with `make parser` after changing a grammar.

---

## The transformation pipeline

For the user-facing model of what these transforms achieve, see the
[Canonicalization]({% link manual/canonicalization.md %}) page.

### Pipeline assembly

The transformation system is declared in `proof_frog/transforms/pipelines.py` and
executed by the runners in `proof_frog/transforms/_base.py`.

`CORE_PIPELINE` is an ordered list of `TransformPass` instances representing the
fixed-point canonicalization loop. `run_pipeline(game, pipeline, ctx)` applies each
pass in sequence, then repeats the entire sequence from the beginning until a full
sweep produces no change (convergence), up to a maximum of 200 iterations. If the
loop does not converge, a warning is emitted but processing continues with the last
state. The output is a semantically equivalent game in a normal form suitable for
structural comparison.

`STANDARDIZATION_PIPELINE` is a shorter list that runs once after `CORE_PIPELINE`
converges, using `run_standardization(game, pipeline, ctx)`. It renames local
variables to canonical identifiers (`v1`, `v2`, ...), normalizes field names, sorts
field assignments into a stable order, and stabilizes independent statements. Because
it runs only once rather than to a fixed point, its passes must be idempotent.

`PipelineContext` is a read-mostly bundle passed to every transform. It carries the
proof's `let:` type map (`proof_let_types`), the `proof_namespace` (the resolved set
of named definitions), any user-supplied `subsets_pairs`, known `equality_pairs`,
an optional `sort_game_fn`, `sampled_let_names` (names that were sampled uniformly in
the `let:` block), and the mutable `near_misses` list to which transforms append
`NearMiss` records (see below). The `max_calls` field bounds how many oracle calls the
engine considers when computing field lifetimes.

For step-by-step debugging, `run_pipeline_with_trace` returns a `PipelineTrace`
containing one `IterationTrace` per fixed-point iteration, each recording the list of
transform names that changed the AST. `run_pipeline_until(game, core, std, ctx, name)`
applies passes from the beginning up to and including the named transform (first
iteration only), enabling inspection of intermediate states.

### Transform categories

Each file under `proof_frog/transforms/` is described below with the key
`TransformPass` subclasses it defines.

**`algebraic.py`** handles arithmetic and bitstring identities.

- `UniformXorSimplification` -- when a uniformly sampled `BitString<n>` value is
  XOR-ed with an expression used only in that one XOR, replaces the pair with a
  fresh uniform sample, implementing the one-time-pad argument.
- `UniformModIntSimplification` -- the analogous simplification for `ModInt<q>`
  addition.
- `UniformGroupElemSimplification` -- the analogous simplification for group element
  scalar multiplication.
- `XorCancellation` -- simplifies `x + x` to the zero bitstring.
- `XorIdentity` -- removes XOR with zero: `x + 0^n` becomes `x`.
- `ModIntSimplification` -- folds constant modular arithmetic expressions via SymPy.
- `NormalizeCommutativeChains` -- sorts operands of XOR, addition, and multiplication
  chains into a canonical order so that the same expression written in different
  orders compares equal.
- `ReflexiveComparison` -- simplifies `x == x` to `true` and `x != x` to `false`.
- `BooleanIdentity` -- simplifies boolean AND/OR with literal `true`/`false`.
- `SimplifyNotPass` -- rewrites `!(a == b)` to `a != b` and `!(a != b)` to `a == b`.
- `GroupElemSimplification`, `GroupElemCancellation`, `GroupElemExponentCombination`
  -- group element exponent arithmetic.

**`sampling.py`** handles uniform random sampling and splice normalization.

- `SimplifySplice` -- propagates slice expressions through concatenation, collapsing
  `(a || b)[0:n]` when the slice boundaries can be determined statically.
- `MergeUniformSamples` -- when two uniform samples of `BitString<n>` and
  `BitString<m>` are used only via concatenation, merges them into a single sample of
  `BitString<n+m>`.
- `MergeProductSamples` -- the corresponding merge for product (tuple) type samples.
- `SplitUniformSamples` -- the inverse: when a `BitString<n>` is only ever accessed
  via non-overlapping slices, splits it into independent samples per slice.
- `SingleCallFieldToLocal` -- if a game field is written in `Initialize` and read in
  exactly one oracle method, converts it to a local variable in that method.
- `CounterGuardedFieldToLocal` -- converts counter-guarded fields (fields that can
  only be written once because of a counter guard) to local variables.
- `SinkUniformSample` -- moves a uniform sample statement as late as possible within
  a block to expose more simplification opportunities.
- `LocalizeInitOnlyFieldSample` -- converts a field that is sampled only in
  `Initialize` and never written again to a local variable in `Initialize`.

**`random_functions.py`** handles `Function<D, R>` random function elimination.

- `ExtractRFCalls` -- lifts random function calls out of expressions into named
  intermediate variables so that subsequent passes can reason about call sites.
- `UniqueRFSimplification` -- when a random function is called on a set of values
  sampled uniformly without replacement (via `<-uniq`), each call returns an
  independent uniform sample.
- `ChallengeExclusionRFToUniform` -- recognizes the pattern where an adversary's
  challenge is excluded from a uniform sample via the challenge-exclusion technique,
  enabling the RF-to-uniform argument even when an injective encoding wrapper is
  present.
- `LocalRFToUniform` -- when a random function variable is local to a single oracle
  method call and its input is fresh, replaces the call with a uniform sample.
- `DistinctConstRFToUniform` -- when a random function is called on a set of
  statically distinct constant inputs, treats each call as an independent uniform
  sample.
- `FreshInputRFToUniform` -- when a random function is called on a fresh `<-uniq`
  sampled input that is used only in that call, replaces the call with a uniform
  sample.

**`inlining.py`** handles variable, field, and expression inlining and
common-subexpression elimination.

- `RedundantCopy` -- removes assignments of the form `x = y` when `y` is not
  subsequently modified.
- `InlineSingleUseVariable` -- substitutes a variable's definition at its single use
  site and removes the binding.
- `DeduplicateDeterministicCalls` -- replaces duplicate calls to the same
  `deterministic` primitive method with a common temporary variable, enabling later
  single-use inlining.
- `ForwardExpressionAlias` -- propagates the right-hand side of a pure assignment
  forward to all uses when the variable is never reassigned.
- `HoistFieldPureAlias` -- if a game field always equals a pure expression throughout
  the game's lifetime, replaces reads of the field with the expression directly.
- `InlineSingleUseField` -- if a game field is written exactly once and read exactly
  once, inlines the write into the read site.
- `InlineMultiUsePureExpression` -- inlines a pure expression used in multiple places
  when doing so does not duplicate non-determinism.
- `CollapseAssignment` -- removes trivial `x = x` assignments.
- `RedundantFieldCopy` -- removes field assignments that duplicate a field that
  already holds the same value.
- `CrossMethodFieldAlias` -- when a `deterministic` method call result is stored in a
  field in one oracle and read in another, propagates the alias across oracle
  boundaries.

**`control_flow.py`** handles conditional and dead-code elimination.

- `BranchElimination` -- eliminates if/else branches whose conditions are literally
  `true` or `false`.
- `SimplifyIf` -- collapses adjacent if/else-if branches with identical bodies into a
  single branch whose condition is the OR of the two original conditions.
- `SimplifyReturn` -- when a method ends with `Type v = expr; return v;`, collapses
  it to `return expr;`.
- `RemoveUnreachable` -- uses Z3 to determine when a return statement is
  unconditionally reached and deletes subsequent dead statements.
- `IfConditionAliasSubstitution` -- substitutes a known alias for a variable that
  appears in an if condition when the alias can be determined from the enclosing
  scope.
- `RedundantConditionalReturn` -- removes a trailing else branch when the then branch
  unconditionally returns.

**`structural.py`** handles field and statement ordering.

- `TopologicalSort` -- reorders statements within a method according to a topological
  sort of their data dependencies, combined with dead-code elimination for statements
  that have no effect on any return value.
- `RemoveDuplicateFields` -- unifies two game fields with the same type when it can
  be statically determined they share the same value throughout the game's lifetime.
- `RemoveUnnecessaryFields` -- deletes game fields that do not contribute to the
  return value of any oracle.
- `UniformBijectionElimination` -- when a uniformly sampled value is only used as
  the argument to an injective function, replaces the composed expression with a
  fresh uniform sample of the output type.

**`symbolic.py`** provides integer arithmetic simplification via SymPy.

- `SymbolicComputation` -- converts integer-typed sub-expressions to SymPy symbolic
  form, simplifies them algebraically, and converts the result back to AST form.

**`types.py`** handles type-related simplifications.

- `DeadNullGuardElimination` -- removes null checks (`if x != None`) when the
  guarded expression is guaranteed to be non-null by the type system.
- `SubsetTypeNormalization` -- normalizes expressions over subset types to the
  underlying base type where semantics allow.

**`tuples.py`** handles tuple expressions.

- `FoldTupleIndex` -- replaces `[a, b, c][1]` with `b` when the tuple index is a
  compile-time constant.
- `ExpandTuple` -- when all read and write sites of a tuple variable use constant
  indices, rewrites the tuple into separate variables per index.
- `SimplifyTuple` -- collapses `[a[0], a[1], ..., a[n-1]]` into `a`.
- `CollapseSingleIndexTuple` -- collapses a tuple that is only ever accessed at a
  single constant index into a scalar.

**`standardization.py`** runs once after the core pipeline converges, normalizing
names and ordering.

- `VariableStandardize` -- renames local variables to `v1`, `v2`, ... in order of
  first appearance in the AST.
- `StandardizeFieldNames` -- renames game fields to `field1`, `field2`, ... in order
  of first appearance.
- `BubbleSortFieldAssignments` -- sorts the field assignment block into a stable
  canonical order.
- `StabilizeIndependentStatements` -- reorders independent statements within a method
  body into a canonical order determined by a stable comparison of their string
  representations, so that two games that differ only in statement order compare
  equal.

**`assumptions.py`** contains `ApplyAssumptions`, which applies user-supplied
equivalence assumptions between pairs of variables. This pass is not included in
`CORE_PIPELINE` by default; it is invoked selectively by the proof engine when an
explicit assumption annotation appears between two games.

### How a transform reports a near-miss

Every `TransformPass` receives the mutable `ctx.near_misses` list via
`PipelineContext`. The convention for transforms is: at any precondition-failure
point where the transform *almost* fires but cannot because some syntactic or
semantic condition does not hold, the transform appends a `NearMiss` to
`ctx.near_misses`. `NearMiss` fields are:

- `transform_name` -- the name of the transform (matches the `name` class attribute)
- `reason` -- a human-readable description of why the precondition failed
- `location` -- a `SourceOrigin` identifying where in the source the near-miss
  occurred, or `None`
- `suggestion` -- an actionable suggestion for the proof author, or `None`
- `variable` -- the variable name involved, for matching against diff hunks, or `None`
- `method` -- the oracle method name where the near-miss occurred, or `None`

After the pipeline completes, the diagnostics engine calls `match_near_misses` to
join near-misses against the diff hunks from the equivalence-check failure. Hunks are
matched by method name (if `method` is set on the `NearMiss`) and by variable
presence (if `variable` is set and appears in the diff text). This is the primary
mechanism by which the engine answers the question "why did my hop fail?" Unit tests
for near-miss reporting live in `tests/unit/transforms/test_near_misses.py`.

---

## Diagnostics and near-miss matching

The diagnostics pipeline in `proof_frog/diagnostics.py` translates a raw
equivalence-check failure into a structured report that the engine can present to the
user and that the MCP server can include in the `hop_results` JSON.

**`classify_diff`** parses the unified diff produced by the engine's
`_build_equivalence_diff` method into a list of `DiffHunk` dataclasses. Each
`DiffHunk` identifies the oracle method name where the difference appears
(`DiffHunk.method`), the lines present in the current game's canonical form
(`current_lines`), and the lines present in the next game's canonical form
(`next_lines`).

**`match_near_misses`** joins the list of `DiffHunk` objects against the collected
`NearMiss` records from both the current and next game's pipeline runs. A near-miss
matches a hunk if the `method` field agrees (or is `None`, indicating any method) and
the `variable` field (if set) appears in the combined diff text for that hunk.

**`diagnose_failure`** takes the diff text and the two lists of near-misses (one per
game in the hop), calls `classify_diff` and `match_near_misses`, and assembles a
`Diagnosis` containing:

- `summary` -- a one-line headline for the failure
- `explanations` -- a list of `Explanation` objects, each with a
  `source_description` (which method differs), a `reason`, an optional `suggestion`,
  and an `engine_limitation` flag
- `unmatched_hunks` -- hunks for which no near-miss was found
- `engine_limitations` -- human-readable strings from the limitation detectors

For unmatched hunks, `diagnose_failure` also runs the five **`ENGINE_LIMITATION_DETECTORS`** -- static detector functions registered in the `_DETECTORS` list:

1. **`detect_commutativity_diff`** -- fires when the two sides differ only in the
   order of `||` or `&&` operands, which `NormalizeCommutativeChains` does not
   normalize (it handles `+` and `*` but not boolean operators).
2. **`detect_field_order_diff`** -- fires when the two sides have the same set of
   statements but in different order, which the structural sort cannot resolve when
   there are circular data dependencies.
3. **`detect_associativity_diff`** -- fires when the two sides differ only in
   parenthesization of `||` or `&&`.
4. **`detect_extra_temporary_diff`** -- fires when one game has `Type v = expr;
   return v;` and the other has `return expr;` directly, indicating that
   `SimplifyReturn` fired on one but not the other.
5. **`detect_if_condition_reorder_diff`** -- fires when the two sides have the same
   set of if/else-if branches but in different order, which the engine does not
   normalize.

When a detector fires, the corresponding `Explanation` is annotated with
`engine_limitation = True` and a workaround suggestion. These five detectors represent
known gaps in the canonicalization pipeline; see
[Limitations]({% link manual/limitations.md %}) for the user-facing view.

---

## Engine introspection commands

The following four CLI commands are intentionally excluded from the
[CLI Reference]({% link manual/cli-reference.md %}) because they target
contributors and MCP/LSP clients rather than end users. All four output JSON and
are the CLI equivalents of the corresponding MCP tools documented in
`ProofFrog/CLAUDE_MCP.md`.

### `step-detail <file> <step_index>`

**Synopsis:**

```bash
proof_frog step-detail <file> <step_index>
```

`step_index` is zero-based: the first game in the `games:` list is index 0.

**Behaviour.** Loads the proof file, instantiates and inlines game step
`step_index`, runs the full canonicalization pipeline, and prints a JSON object
whose key fields are:

- `canonical` -- the fully simplified game AST as a string. This is the field to
  read when writing a matching intermediate `Game` definition.
- `output` -- the raw (pre-simplification) game AST with mangled internal variable
  names; ignore this field.
- `success` -- `false` if the step index is out of range or an error occurred.
- `has_reduction`, `reduction`, `challenger`, `scheme` -- metadata about whether the
  step involves a reduction and what its components are.

Use `step-detail` to inspect what the engine actually compares during an
interchangeability check. Comparing the `canonical` output of step `i` against step
`i+1` directly shows any remaining difference.

**Example:**

```bash
proof_frog step-detail examples/joy/Proofs/Ch2/OTPSecure.proof 0 | python -m json.tool
```

This prints the canonical form of the first game in the OTP security proof.

### `inlined-game <file> <step_text>`

**Synopsis:**

```bash
proof_frog inlined-game <file> "<step_text>"
```

**Behaviour.** Reads the `let:`, `assume:`, and `theorem:` blocks from the proof
file and constructs a minimal scratch proof in which `step_text` is the only game in
the `games:` list. It then evaluates that scratch proof's step 0 and returns the
canonical form. Unlike `step-detail`, the step does not need to appear in the actual
proof file, and stub reductions that prevent parsing do not interfere. This makes it
the primary tool for writing intermediate games: you can explore arbitrary game
expressions against the proof's `let:` context before committing any of them to the
file.

The returned JSON has the same `canonical`, `output`, and `success` fields as
`step-detail`.

**Example:**

```bash
proof_frog inlined-game examples/joy/Proofs/Ch2/OTPSecure.proof \
  "OneTimeSecrecy(E).Left against OneTimeSecrecy(E).Adversary" | python -m json.tool
```

### `canonicalization-trace <file> <step_index>`

**Synopsis:**

```bash
proof_frog canonicalization-trace <file> <step_index>
```

**Behaviour.** Runs the canonicalization pipeline for the given proof step using
`run_pipeline_with_trace` and returns a JSON object containing:

- `success` -- whether the step was found and processed without error.
- `iterations` -- an array of `{iteration: int, transforms_applied: [str]}` objects,
  one per fixed-point iteration in which at least one transform changed the AST.
- `total_iterations` -- how many iterations were required before convergence.
- `converged` -- whether the pipeline converged before the 200-iteration limit.

This command is the first diagnostic to reach for when a hop is failing and near-miss
output is not helpful: it shows the exact sequence of transforms that fire and the
order in which they reduce the game, making it straightforward to identify which
simplification step is not occurring.

**Example:**

```bash
proof_frog canonicalization-trace examples/joy/Proofs/Ch2/OTPSecure.proof 1 \
  | python -m json.tool
```

### `step-after-transform <file> <step_index> <transform_name>`

**Synopsis:**

```bash
proof_frog step-after-transform <file> <step_index> "<transform_name>"
```

**Behaviour.** Applies the canonicalization pipeline up to and including the named
transform (first iteration only, using `run_pipeline_until`) and returns the game AST
at that point. The response JSON contains:

- `success` -- whether the step and transform name were found.
- `output` -- the game AST as a string after the named transform.
- `transform_applied` -- whether the named transform actually changed the AST.
- `available_transforms` -- the full list of valid transform names (useful when the
  supplied name is not recognized).

This command enables single-step debugging of the pipeline: apply transforms one by
one and inspect the intermediate AST to determine exactly where a simplification
should have fired but did not.

**Example:**

```bash
proof_frog step-after-transform examples/joy/Proofs/Ch2/OTPSecure.proof 1 \
  "UniformXorSimplification" | python -m json.tool
```

---

## LSP and MCP

### LSP

The Language Server Protocol implementation lives in `proof_frog/lsp/`. Start it
with `proof_frog lsp`; it listens on stdio and is compatible with any LSP-aware
editor. See [Editor Plugins]({% link manual/editor-plugins.md %}) for the VSCode
plugin configuration; other editors require a thin client configuration pointing at
`proof_frog lsp` as the server command with no additional server code.

**`server.py`** defines `FrogLanguageServer`, a `pygls.lsp.server.LanguageServer`
subclass that uses `TextDocumentSyncKind.Full` (the entire document text is sent on
every change). The server maintains a `document_states` dict mapping document URIs to
`DocumentState` objects and a `proof_results` dict mapping URIs to per-step
verification results. Feature registration, event handler functions, and the
`run_server()` entry point all live here.

**`document_state.py`** defines `DocumentState`, the per-document state record. Each
state object tracks the document URI, file path, `FileType` (derived from extension),
current source text, version number, and a `last_good_ast` cache. The `last_good_ast`
holds the most recently successfully parsed AST; it is used by completion, hover, and
symbol providers so those features continue to work even when the document currently
has syntax errors.

**`diagnostics.py`** (within the `lsp/` package, distinct from the top-level
`diagnostics.py`) implements parse and semantic error reporting. `parse_and_diagnose`
is called on every keystroke: it parses the current source and converts any
`ParseError` into LSP `Diagnostic` objects with line/column ranges. `check_and_diagnose`
is called on save for non-proof files and runs `semantic_analysis.check_well_formed`,
converting `FailedTypeCheck` exceptions into diagnostics.

**`navigation.py`** provides go-to-definition and hover. `goto_definition` resolves
identifier references in import statements to the imported file path. `hover` returns
a `Hover` response with the type or interface description for the symbol under the
cursor, using the `describe` module to format the summary.

**`completion.py`** provides context-sensitive completion items and signature help.
`get_completions` inspects the current cursor position, determines whether the cursor
is inside a method call, a `let:` binding, or a bare expression context, and returns
appropriate completion items. `let:`-binding resolution uses the `last_good_ast` from
`DocumentState` to enumerate available names even when the document is partially
broken. `get_signature_help` is triggered by `(` and `,` and returns parameter
signatures for method calls.

**`symbols.py`** implements the document symbol provider that populates the Outline
panel in editors. `get_document_symbols` traverses the AST and returns
`DocumentSymbol` objects for top-level constructs: primitives, schemes, games, game
methods, and proof blocks.

**`rename.py`** implements F2 rename for local symbols. `prepare_rename` checks
whether the symbol at the cursor position is renameable (local variable or field
within a method). `rename` returns a `WorkspaceEdit` that rewrites all occurrences
of the symbol within its scope.

**`folding.py`** implements folding ranges for block structures and consecutive
comment runs. `get_folding_ranges` scans the source text for `{`/`}` pairs (method
bodies and game blocks) and for runs of `//` comment lines, returning appropriate
`FoldingRange` objects.

**`proof_features.py`** implements the proof-specific LSP features. On save,
`run_proof_verification` runs the full proof engine against the current file and
returns a list of `ProofStepResult` objects (one per hop) and any parse/semantic
diagnostics. `build_code_lenses` converts the step results into inline code lenses
displayed next to each game in the `games:` block, showing a green check or red cross.
`get_proof_steps_response` serializes the step results for the custom
`prooffrog/proofSteps` notification, which the VSCode extension uses to populate the
proof hops tree view. After verification completes, the server sends a
`prooffrog/verificationDone` notification so the client can refresh the tree view
without polling.

### MCP

The MCP server in `proof_frog/mcp_server.py` exposes ProofFrog's capabilities as
MCP tools for LLM-based proof authoring. It is started with `proof_frog mcp
[directory]`, where `directory` sets the working root from which file paths are
resolved. The server uses the `mcp` Python package (installed with
`pip install 'proof_frog[mcp]'`) and communicates over stdio using
`FastMCP` from `mcp.server.fastmcp`. A path-safety check prevents tools from
reading or writing files outside the specified directory or inside hidden directories.

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
FrogLang syntax reference that an LLM can fetch without reading through example files.

The canonical tool-usage guide and setup instructions are in
`ProofFrog/CLAUDE_MCP.md` in the ProofFrog repository. For a practical introduction
to using the MCP server to iteratively write and debug proofs with Claude Code,
see [Vibe-Coding]({% link researchers/vibe-coding.md %}).
