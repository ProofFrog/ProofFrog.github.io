---
title: Canonicalization
layout: default
parent: Manual
nav_order: 40
---

# Canonicalization
{: .no_toc }

This page explains what the ProofFrog engine does between receiving a `.proof` file and
producing a green (valid) or red (failed) result for each hop. It is written for a
cryptographer who wants to understand why two games are being called interchangeable, or
who is diagnosing a hop that refuses to validate.

- TOC
{:toc}

---

## Overview

`proof_frog prove` walks the `games:` list in a proof file and, for each adjacent pair of
games, does one of two things. If the pair corresponds to an assumption hop -- the two
games differ only in which side of an assumed security property is composed with a
reduction -- it checks that the assumption appears in the `assume:` section and accepts
the hop on that basis. Otherwise it treats the pair as an interchangeability hop: it
canonicalizes both games independently and compares their canonical forms. The
canonicalization step is a fixed-point loop of semantics-preserving abstract syntax tree (AST) rewrites (the
core pipeline) followed by a single-pass normalization (the standardization pipeline).
If the canonical forms are structurally identical, the hop is accepted; if not, the
engine additionally asks Z3 whether the two forms differ only in logically equivalent
branch conditions.

The phrase "semantics-preserving" means preserving the probability distribution that the
game induces over adversary outputs, as defined by the FrogLang execution model in
[Execution Model]({% link manual/language-reference/execution-model.md %}). The engine is
deliberately limited to a fixed catalog of transformations it believes to be sound; it does
not discover or invent new algebraic moves. For a list of what the engine cannot do, see
[Limitations]({% link manual/limitations.md %}).

---

## What the engine simplifies automatically

The subsections below describe the main categories of canonicalization transforms the engine applies.
For each category a minimal before/after snippet illustrates the transform firing, a
real-proof pointer gives an example from the distribution, and a callout lists common
reasons the transform might not fire.

### Inlining of method calls

When a game calls a scheme method -- for example `E.Enc(k, m)` in a CPA game
instantiated with a concrete scheme -- the engine substitutes the method's body at the
call site. Local variables in the inlined body are renamed to avoid collisions, and
`this.Method(args)` references inside the method are rewritten to use the scheme
instance name before inlining, so they resolve correctly in the outer context.
Inlining runs in a fixed-point loop until no further method calls can be expanded;
this is guaranteed to terminate because FrogLang does not permit recursive methods.
After inlining, every game is expressed purely in terms of sampling statements,
arithmetic, map operations, and control flow -- no abstract method calls remain.

```prooffrog
// Before: CPA game with scheme method call
E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
    return E.Enc(k, mL);
}

// After inlining OTP.Enc (which returns k + m):
E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
    return k + mL;
}
```

Real-proof pointer: every proof in the distribution relies on inlining.
[`examples/Proofs/PRG/TriplingPRGSecure.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRGSecure.proof) is a clean illustration -- the
`TriplingPRG` scheme composes calls to an underlying `PRG`, and those calls are inlined
before the PRG reduction hops.

{: .note }
**If this is not firing:** Check that the scheme is fully instantiated in the `let:`
block. If a method signature is abstract (no body), or if the `this.Method` reference
inside a scheme body is not resolved, inlining will stop at that call site. Running
`proof_frog prove -v` shows the inlined-but-not-yet-canonicalized form and will reveal
dangling call nodes.

### Algebraic simplification on bitstrings

The engine applies several identities for `BitString<n>` arithmetic (XOR and
concatenation).

**XOR cancellation:** `x + x` simplifies to `0^n`. The transform flattens the XOR chain
and removes pairs of identical terms. It guards against cancelling calls to
non-deterministic methods -- `F.Enc(k, x) + F.Enc(k, x)` is left alone unless `F.Enc`
is annotated `deterministic`.

**XOR identity:** `x + 0^n` and `0^n + x` simplify to `x`.

**Uniform-absorbs (one-time-pad move):** When `u` is sampled uniformly from
`BitString<n>` and is used exactly once, the expression `u + m` (or `m + u`) simplifies
to just `u`. This formalizes the one-time-pad argument: XOR of a uniform value with any
independent value is uniform.

```prooffrog
// Uniform-absorbs on bitstrings
BitString<n> u <- BitString<n>;
return u + m;
// simplifies to:
BitString<n> u <- BitString<n>;
return u;
```

**Concat/slice inverses:** `SimplifySplice` replaces `(x || y)[0 : n]` with `x` when the
slice boundaries align with the component widths, saving a round-trip through
concatenation and slicing.

Real-proof pointer: [`examples/Proofs/SymEnc/SymEncPRFCPA$.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRFCPA%24.proof) -- the final
merge of two independent uniform samples into the CPA$ random game relies on XOR
absorption after the PRF is replaced by a random function.

{: .note }
**If this is not firing:** The most common cause is that `u` is used more than once
(static use-count, including both branches of an `if/else`). The engine counts
statically and will not fire even if only one branch executes at runtime. Restructure so
that `u` appears in only one branch. A second cause is that the ADD is in a `ModInt`
context rather than a `BitString` context; the engine checks the type to distinguish
the two.

### Algebraic simplification on `ModInt<q>`

The engine applies addition and multiplication identities for `ModInt<q>`: additive
identity (`x + 0` -> `x`), multiplicative identity (`x * 1` -> `x`), multiplicative
zero (`x * 0` -> `0`), additive inverse (`x - x` -> `0`), and double negation.

**Uniform-absorbs for ModInt:** When `u` is sampled uniformly from `ModInt<q>` and is
used exactly once, the expression `u + m` or `u - m` (mod q) simplifies to `u`. This
is the modular-arithmetic analogue of the one-time-pad argument: adding a uniform
element modulo `q` with any fixed value is uniform.

```prooffrog
// Uniform-absorbs on ModInt
ModInt<q> u <- ModInt<q>;
return u + m;
// simplifies to:
ModInt<q> u <- ModInt<q>;
return u;
```

Real-proof pointer: [`examples/Proofs/SymEnc/ModOTPSecure.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/ModOTPSecure.proof) uses the ModInt
one-time-pad argument directly.

{: .note }
**If this is not firing:** Same static use-count caveat as for bitstrings. Also check
that the expression is in a `ModInt<q>` context and not an `Int` context; symbolic
computation (SymPy) handles `Int` arithmetic separately.

### Algebraic simplification on `GroupElem<G>`

The engine applies the following identities for group elements in `GroupElem<G>`:

- **Cancellation:** `x * m / x` simplifies to `m` in an abelian group. (Guards against
  non-deterministic bases -- the bases must be structurally equal and deterministic.)
- **Exponent identities:** `g ^ 0` simplifies to `G.identity`; `g ^ 1` simplifies to
  `g`.
- **Multiplicative identity:** `G.identity * g` and `g * G.identity` simplify to `g`;
  `g / G.identity` simplifies to `g`.
- **Power-of-power:** `(h ^ a) ^ b` simplifies to `h ^ (a * b)`, when the exponent
  types are compatible for multiplication.
- **Exponent combination:** `g ^ a * g ^ b` simplifies to `g ^ (a + b)`, and
  `g ^ a / g ^ b` to `g ^ (a - b)`, when the bases are structurally identical and
  deterministic.
- **Uniform-absorbs (group masking):** When `u` is sampled uniformly from `GroupElem<G>`
  and is used exactly once, the expressions `u * m`, `m * u`, `u / m`, and `m / u`
  all simplify to `u`. Left and right multiplication (and their inverses under division)
  are bijections on any finite group, so any of these forms preserves the uniform
  distribution.

```prooffrog
// Power-of-power and exponent combination
GroupElem<G> h = G.generator ^ a;
return (h ^ b) * (h ^ c);
// simplifies to:
return G.generator ^ (a * b + a * c);
```

Real-proof pointer: [`examples/Proofs/PubEnc/ElGamalCPA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/ElGamalCPA.proof) uses the
group masking move (the DDH `Right` game replaces `pk ^ r` with a random group element `c`,
and the uniform-absorbs rule fires to simplify `mL * c` to `c`, making the ciphertext
independent of the message).

{: .note }
**If this is not firing for uniform-absorbs:** Exponentiation (`^`) is deliberately
excluded from the group masking move -- `u ^ n` is not necessarily uniform (for example
if the group has even order and `n = 2`, squaring is not a bijection). Use only
`*` and `/` to trigger this rule. Also note the static single-use requirement: `u`
must not appear in both branches of a conditional.

### Sample merge and sample split

**Merge** (`MergeUniformSamples`): If two independent uniform samples `x <- BitString<n>`
and `y <- BitString<m>` are used only via their concatenation `x || y` and nowhere else,
they collapse to a single sample `z <- BitString<n + m>`. Soundness: the concatenation
of independent uniforms is uniform of the combined length.

**Split** (`SplitUniformSamples`): The reverse move. If a single sample `z <-
BitString<n + m>` is accessed only via non-overlapping slices (for example
`z[0 : n]` and `z[n : n + m]`), it splits into independent samples for each slice.
Soundness: non-overlapping slices of a uniform bitstring are independent uniforms.

These two moves are inverses and together allow the engine to match games that represent
the same randomness in different granularities.

```prooffrog
// Sample merge
BitString<n> x <- BitString<n>;
BitString<m> y <- BitString<m>;
return x || y;
// simplifies to:
BitString<n + m> x <- BitString<n + m>;
return x;
```

```prooffrog
// Sample split
BitString<n + m> z <- BitString<n + m>;
return [z[0 : n], z[n : n + m]];
// simplifies to:
BitString<n> z_0 <- BitString<n>;
BitString<m> z_1 <- BitString<m>;
return [z_0, z_1];
```

Real-proof pointer: [`examples/Proofs/PRG/TriplingPRGSecure.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRGSecure.proof) uses sample split
to decompose a single PRG output into its two halves (each half is then used
independently as a new seed or output value, and the split enables the per-component
uniform reasoning).

{: .note }
**If merge is not firing:** Every leaf variable in the concatenation must be used
exclusively in that concatenation -- any other reference (including assigning the
variable to a map, using it in a condition, or passing it to a method) blocks the merge.
Also, the operator is overloaded: `||` on `Bool` is logical OR, not concatenation;
the engine checks types and will not merge boolean expressions. If split is not firing,
check that all uses of the large sample are via slices with no bare references.

### Random function on distinct inputs

When a `Function<D, R>` field is used as a random oracle (sampled via `<- Function<D,
R>`), and every call to it uses an argument that was sampled using `<-uniq[S]` from the
same persistent set field `S`, the engine replaces each `z = H(r)` with `z <- R` (an
independent uniform sample). Soundness: a truly random function evaluated on pairwise
distinct inputs produces independent uniform outputs -- this is a direct consequence of
the definition of a random function.

In practice, the bookkeeping set `S` is almost always the random function's own implicit
`.domain` set -- for example `r <-uniq[RF.domain] BitString<n>` guarantees that `r` has
not been queried before on `RF`, which is exactly the precondition this transform
requires. See [Function<D, R>]({% link manual/language-reference/basics.md %}#functiond-r)
for details on `.domain`.

A related transform, `FreshInputRFToUniform`, fires when the argument `v` to `H(v)` is
a `<-uniq`-sampled variable used solely in that single call: in that case the input is
structurally guaranteed to be fresh, and the RF call is replaced by a uniform sample.

```prooffrog
// Before: RF on uniquely-sampled input
BitString<n> r <-uniq[RF.domain] BitString<n>;
BitString<m> z = RF(r);

// After: independent uniform sample
BitString<n> r <-uniq[RF.domain] BitString<n>;
BitString<m> z <- BitString<m>;
```

Real-proof pointer: [`examples/Proofs/PubEnc/HashedElGamalCPAROM.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/HashedElGamalCPAROM.proof) -- the proof
uses `FreshInputRFToUniform` (after the DDH hop places a uniform group element `c` in
the exclusion set) to collapse `H(c)` into a fresh uniform bitstring, which then masks
the message via XOR.

{: .note }
**If this is not firing:** The exclusion set must be a game field, not a local variable
(a local set is re-initialized on each oracle call, losing the cross-call freshness
guarantee). All calls to the RF must use the same exclusion set. If the argument
variable appears more than once (including a second call to the same RF with the same
variable), the transform is blocked. The `<-uniq` sampling must be present; plain `<-`
does not trigger this rule.

### `deterministic` and `injective` annotations

**Same-method call deduplication** (`DeduplicateDeterministicCalls`): If a method
annotated `deterministic` on a primitive is called more than once with structurally
equal arguments, all occurrences are replaced with a single shared variable. This
implements common subexpression elimination for deterministic calls and eliminates the
need for explicit "IsDeterministic" assumption games that earlier versions of ProofFrog
required.

**Cross-method field aliasing** (`CrossMethodFieldAlias`): If `Initialize` stores the
result of a `deterministic` call in a field (e.g., `pk = G.generator ^ sk`), and an
oracle method also calls the same function with the same arguments, the oracle's call is
replaced with the field reference. This connects the Initialize-time computation to the
oracle-time use.

**Encoding-wrapper transparency** (`UniformBijectionElimination`): If a uniformly sampled
`BitString<n>` variable is used exclusively wrapped in a single `deterministic injective`
method call with matching input and output type (`BitString<n>` to `BitString<n>`), the
wrapper is removed and the variable stands alone. Soundness: a deterministic injective
function on a finite set of the same cardinality is a bijection and hence preserves
uniformity.

```prooffrog
// Before: duplicate deterministic call
BitString<n> c1 = E.Enc(k, mL);
BitString<n> c2 = E.Enc(k, mL);
return [c1, c2];

// After: shared variable
BitString<n> v = E.Enc(k, mL);
return [v, v];
```

Real-proof pointer: any proof where a deterministic scheme method is invoked twice
with identical arguments after inlining will exercise `DeduplicateDeterministicCalls`
-- typically visible in proofs where the same encryption or hash call appears on both
branches of a conditional or in two separate oracle bodies that reference the same
message.

{: .note }
**If deduplication is not firing:** The method must be declared `deterministic` in the
primitive file. The engine checks this annotation; without it, the two calls are treated
as independent non-deterministic events that cannot be merged. If the annotation is
present but the arguments are not syntactically identical (for example, one side has
`k` and the other has a copy `k2 = k` that has not yet been inlined), run more inlining
passes or check for redundant copy variables.

### Code simplification

The engine applies a collection of standard program simplifications as part of the core
pipeline:

- **Dead code elimination** (`RemoveUnnecessaryFields`, `RemoveUnreachable`): Unused
  variables and fields are removed. Statements after all execution paths have returned
  are dropped (Z3 assists with reachability under complex conditions).
- **Constant folding** (`SymbolicComputation`): Arithmetic sub-expressions involving
  only known constant values are evaluated symbolically via SymPy.
- **Single-use variable inlining** (`InlineSingleUseVariable`, `SimplifyReturn`):
  A variable declared and used exactly once is inlined at its use site.
  `Type v = expr; return v;` collapses to `return expr;`.
- **Redundant copy elimination** (`RedundantCopy`): `Type v = w;` where `v` is just
  a copy of `w` is eliminated and `w` used directly.
- **Branch elimination** (`BranchElimination`): `if (true) { ... }` and
  `if (false) { ... }` are collapsed to their taken or dropped bodies.
- **Tuple index folding** (`FoldTupleIndex`): `[a, b][0]` folds to `a`,
  `[a, b][1]` to `b`, and so on.

These simplifications are individually simple but collectively they do a large amount of
work: after inlining a scheme into a game, the result is often cluttered with
intermediate variables, unreachable code, and trivially foldable branches. The
simplification passes clean all of that up before the final structural comparison.

```prooffrog
// Before: redundant temporary and unreachable return
BitString<n> v = k + m;
return v;
if (true) { return 0^n; }     // unreachable after above return

// After:
return k + m;
```

Real-proof pointer: dead code elimination is exercised in almost every proof. The
elimination of the random-function field after `UniqueRFSimplification` replaces all
its calls with uniform samples is a good representative case; see
[`examples/Proofs/SymEnc/SymEncPRFCPA$.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRFCPA%24.proof).

{: .note }
**If a branch is not being eliminated:** The engine folds `if (true)` and `if (false)`
conditions, but it does not evaluate conditions that involve symbolic variables at the
structural level. If you expect a condition to simplify to a constant, check that all
relevant variables have been inlined first. If the condition involves Z3-provable facts
(rather than syntactic constants), see the next subsection.

### SMT-assisted comparison of branch conditions

After the core pipeline converges, if the two canonical game forms are structurally
identical except for the conditions in one or more `if` statements, the engine calls Z3
to check whether the differing conditions are logically equivalent. If Z3 confirms
equivalence under the current proof context (including any `assume expr;` predicates
stated in the `games:` section), the hop is accepted.

This allows the engine to validate hops where two games write the same guard condition
in syntactically different but logically equivalent forms -- for example `a != b` versus
`!(a == b)`, or a condition that simplifies under an inequality asserted in the proof
context.

The `RemoveUnreachable` pass also uses Z3 to determine whether a statement after a
guarded return is reachable, allowing dead branches under non-trivially-false conditions
to be removed.

Real-proof pointer: [`examples/Proofs/SymEnc/EncryptThenMACCCA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/EncryptThenMACCCA.proof) uses phased
games with guard conditions that require Z3 to confirm equivalence after inlining.

{: .note }
**If SMT comparison is not catching an expected equivalence:** Z3 reasons over the
quantifier-free fragment of linear arithmetic and equality; it does not handle
non-linear arithmetic or cryptographic assumptions by default. If the conditions involve
nonlinear constraints, you may need to introduce an intermediate game whose guard is
already in the simplified form.

---

## Helper games -- doing things manually

Some probabilistic facts cannot be derived purely from program structure: they require
an external statistical argument (typically a birthday bound or a random oracle
property). ProofFrog handles these via *helper games* -- ordinary `.game` files in
`examples/Games/Misc/` that state a statistical equivalence as a security assumption.
The user invokes a helper game as an assumption hop in the same way as any other
assumption; the difference is that the helper game is not a hardness assumption but a
statistical argument that the proof author vouches for.

Four helper games currently in the distribution are:

### UniqueSampling

**File:** [`examples/Games/Misc/UniqueSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Misc/UniqueSampling.game)

**What it states:** Sampling uniformly with replacement from a set `S` is
indistinguishable from sampling without replacement (exclusion sampling, `<-uniq`).
The `Replacement` game draws `val <- S`; the `NoReplacement` game draws
`val <-uniq[bookkeeping] S`. The statistical distinguishing advantage is bounded by
the guessing probability `|bookkeeping| / |S|`.

**When to reach for it:** Whenever your proof needs to switch from plain uniform sampling
to `<-uniq` sampling (or back) so that the `UniqueRFSimplification` or
`FreshInputRFToUniform` transform can fire. The switch to `<-uniq` is the forward hop
(Replacement -> NoReplacement); after the random-function simplifications fire, the
switch back is the reverse hop. In reductions that compose with `UniqueSampling`, the
bookkeeping set is typically the random function's implicit `.domain` set -- for example,
the reduction calls `challenger.Samp(RF.domain)` to delegate sampling to the
`UniqueSampling` challenger while using `RF`'s query history as the exclusion set.

```prooffrog
// Four-step pattern using UniqueSampling
G_before against Adversary;                              // interchangeability
UniqueSampling.Replacement compose R_Uniq against Adversary;  // interchangeability
UniqueSampling.NoReplacement compose R_Uniq against Adversary; // by UniqueSampling
G_after against Adversary;                               // interchangeability
```

Real-proof pointer: used in [`examples/Proofs/SymEnc/SymEncPRFCPA$.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRFCPA%24.proof),
[`examples/Proofs/PubEnc/HashedElGamalCPAROM.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/HashedElGamalCPAROM.proof), [`examples/Proofs/Group/DDHMultiChalImpliesHashedDDHMultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDHMultiChalImpliesHashedDDHMultiChal.proof).

### HashOnUniform

**File:** [`examples/Games/Misc/HashOnUniform.game`](https://github.com/ProofFrog/examples/blob/main/Games/Misc/HashOnUniform.game)

**What it states:** Applying a hash function `H : D -> BitString<n>` to a uniformly
sampled input from `D` is indistinguishable from sampling `BitString<n>` uniformly.
The `Real` game returns `H(x)` for `x <- D`; the `Ideal` game returns `y <- BitString<n>`
directly. This captures the standard-model randomness-extraction property of a
sufficiently regular hash function.

**When to reach for it:** When `H` is a deterministic function (declared in the `let:`
block without sampling, so not a random oracle), and the proof requires treating the
output of `H` on a uniform input as uniformly random. This is the standard-model
counterpart to what `FreshInputRFToUniform` does automatically in the ROM.

Real-proof pointer: used in [`examples/Proofs/Group/DDHImpliesHashedDDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDHImpliesHashedDDH.proof).

### ROMProgramming

**File:** [`examples/Games/Misc/ROMProgramming.game`](https://github.com/ProofFrog/examples/blob/main/Games/Misc/ROMProgramming.game)

**What it states:** Programming a random function at a single target point with a fresh
uniform value is statistically equivalent to evaluating it naturally. The `Natural` game
returns `H(target)` directly; the `Programmed` game stores a fresh random `u` at
initialization time and returns `u` when queried at `target` and `H(x)` otherwise.
This equivalence is exact (perfect) when `H` is a truly random function.

**When to reach for it:** When the proof needs to "program" a random oracle at the
challenge point -- replacing `H(target)` with an independently sampled value so that the
challenge ciphertext becomes statistically independent of the adversary's hash queries.
This is a standard technique in ROM proofs.

Real-proof pointer: used in [`examples/Proofs/Group/CDHImpliesHashedDDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/CDHImpliesHashedDDH.proof).

### RandomTargetGuessing

**File:** [`examples/Games/Misc/RandomTargetGuessing.game`](https://github.com/ProofFrog/examples/blob/main/Games/Misc/RandomTargetGuessing.game)

**What it states:** Comparing an adversary-supplied value against a hidden, uniformly
sampled target is indistinguishable from always returning false. The `Real` game samples
`target <- S` in `Initialize` and returns `c == target` on each `Eq` query; the `Ideal`
game always returns `false`. Any adversary distinguishes the two with advantage at most
`q / |S|`, where `q` is the number of queries.

**When to reach for it:** When a game checks whether the adversary has guessed a secret
uniform value, and the proof argues that such a guess succeeds only with negligible
probability.

Real-proof pointer: used in [`examples/Proofs/Group/DDHImpliesCDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDHImpliesCDH.proof).

{: .important }
Using a helper game adds to the trust base -- see the [Soundness]({% link researchers/soundness.md %}) page in the For Researchers area.

---

## What the engine does not do

The following things are outside the scope of automated canonicalization. Each item
links to [Limitations]({% link manual/limitations.md %}) for details and workarounds.

- **No quantitative probability reasoning.** The engine does not compute or bound
  advantage, security loss, or collision probabilities. Those quantities are the proof
  author's responsibility and are stated as external arguments. See
  [Limitations]({% link manual/limitations.md %}) for details.

- **No nested induction.** The engine supports single-level hybrid arguments via the
  [`induction` construct]({% link manual/language-reference/proofs.md %}#induction-hybrid-arguments),
  but nested induction or induction with complex base cases must be decomposed into
  multiple proof files via `lemma:`. See [Limitations]({% link manual/limitations.md %})
  for details.

- **No reduction search.** When a proof hop requires a reduction to an underlying
  hardness assumption, the user supplies the reduction code. The engine verifies that
  the supplied reduction composed with each side of the assumption is interchangeable
  with the adjacent games; it does not propose or construct reductions. See
  [Limitations]({% link manual/limitations.md %}) for details.

- **No always-recognition of stylistically different equivalent code.** Two games that
  are semantically equivalent but written in stylistically different forms -- different
  operand order in a `||` concatenation, different field declaration order, different
  branch order in an `if/else if` -- may not be recognized as equivalent. The engine
  normalizes commutative `+` and `*` chains but not `||` or `&&`. See
  [Limitations]({% link manual/limitations.md %}) for details.

---

## Diagnosing a failing hop

When a proof step fails, the following recipe finds the problem in most cases.

**Step 1: Get the canonical forms.**
Run `proof_frog prove -v` (see [CLI Reference]({% link manual/cli-reference.md %}#prove)) or,
in the browser, click the Inlined Game button for each of the two games in the failing
hop (see [Web Editor]({% link manual/web-editor.md %})).
The verbose output shows the fully canonicalized form of each game after the entire
pipeline has run.

**Step 2: Find the first structural difference.**
Compare the two canonical forms side by side. The engine produces structurally sorted
output, so the first difference corresponds to the first point where the two games
diverge after all simplifications. Common differences include a leftover method call
that was not inlined (because a scheme field was not resolved), a variable that
was not simplified away (because the uniform-absorbs precondition was not met), or
a field that appears in one game but not the other (because dead-code elimination
fired asymmetrically).

**Step 3: Apply one of three fixes.**

- *Add an intermediate game.* If the two games are genuinely equivalent but the engine
  cannot bridge the gap in one step, split the hop into two: write a new intermediate
  game that is partway between them, so that each half-hop is within the engine's
  capability.

- *Add a helper assumption.* If the gap corresponds to a statistical fact (birthday
  bound, hash-on-uniform, ROM programming), introduce the appropriate helper game from
  `examples/Games/Misc/` and use the four-step reduction pattern to cross the gap.

- *Restructure existing code.* If the canonical forms differ only in ordering --
  operand order in a concatenation, field declaration order, branch order in an
  if/else if -- adjust the intermediate game or the reduction body to match the
  other side's ordering. The relevant known limitations are listed in
  [Limitations]({% link manual/limitations.md %}).

**Step 4: If you believe the engine should validate and it isn't, file an issue.**
Include the smallest proof file that reproduces the problem and the full output of
`proof_frog prove -v <your-file.proof>`. The canonical forms in the verbose output
are exactly what is compared, so they are the key evidence. Issues can be filed at
[https://github.com/ProofFrog/ProofFrog/issues](https://github.com/ProofFrog/ProofFrog/issues).

For specific error messages and their meanings, see
[Troubleshooting]({% link manual/troubleshooting.md %}).
