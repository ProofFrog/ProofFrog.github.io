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

Before any of the simplifying rewrites run, a global alpha-renaming pass gives every typed
local binder a fresh, globally unique name. FrogLang's block scoping is position-sensitive,
so an inner declaration can shadow an outer one; renaming up front means that a later pass
which splices or reorders code cannot accidentally conflate a shadowed binding with the
binding it shadows. The pass does not affect the final canonical form -- the standardization
pipeline washes the names again at the end -- but it is what makes the passes in between
safe.

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
[`examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRG_PRGSecurity.proof) is a clean illustration -- the
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

Real-proof pointer: [`examples/Proofs/SymEnc/SymEncPRF_INDCPA$_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDCPA%24_MultiChal.proof) -- the final
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

Real-proof pointer: [`examples/Proofs/SymEnc/ModOTP_INDOT.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/ModOTP_INDOT.proof) uses the ModInt
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
- **Exponent bridging:** when a field is defined as `f = g ^ a`, the engine can
  rewrite a later `g ^ (a * b)` to `f ^ b` (and similar rewrites), connecting an
  exponentiation written in terms of the base generator to one written in terms of a
  derived public element. This is what lets Diffie-Hellman-style games whose
  ciphertexts are written `pk ^ r` line up with the reduction's `g ^ (sk * r)` form.
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

Real-proof pointer: [`examples/Proofs/PubKeyEnc/ElGamal_INDCPA_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/ElGamal_INDCPA_MultiChal.proof) uses the
group masking move (the DDH `Right` game replaces `pk ^ r` with a random group element `c`,
and the uniform-absorbs rule fires to simplify `mL * c` to `c`, making the ciphertext
independent of the message).

{: .note }
**If this is not firing for uniform-absorbs:** Exponentiation (`^`) is deliberately
excluded from the group masking move -- `u ^ n` is not necessarily uniform (for example
if the group has even order and `n = 2`, squaring is not a bijection). Use only
`*` and `/` to trigger this rule. Also note the static single-use requirement: `u`
must not appear in both branches of a conditional.

### Decomposing equalities

When two compound values are compared for equality, the engine can break the comparison into its components, which often exposes simplifications that were hidden inside the compound form:

- **Concatenations** (`ConcatEqualityDecompose`): an equality between two concatenations of matching widths decomposes into the conjunction of component-wise equalities.
- **Injective functions** (`InjectiveEqualitySimplify`): for a method declared `injective`, `f(x) == f(y)` is equivalent to `x == y` (an injective function maps distinct inputs to distinct outputs), so the wrapper can be stripped from both sides.
- **Tuples** (`TupleEqualityDecompose`): an inequality between two tuples decomposes into a disjunction of component-wise inequalities (`a != b` iff some `a[i] != b[i]`).

These decompositions let guard conditions written over packaged values match guard conditions written over their parts, which arises frequently in the binding proofs of the [CFRG hybrid KEM case study](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems).

### Control-flow normalization

A range of passes normalize equivalent but differently-written conditional code, so that two games that differ only in how their `if`/`else` and early-return logic is arranged canonicalize to the same form. Examples include unwrapping an `else` whose sibling branch always returns, factoring a guard common to several branches, merging nested guards into a single conjunction, dropping assignments that are dead under a later guard, and folding two branches that return equivalent values. Collectively these passes mean you usually do not have to match the *exact* branch structure of the other side of a hop — only its behavior.

```prooffrog
// Before: redundant else after an early return
if (c == ctStar) {
    return ss;
} else {
    return H(c);
}

// After normalization (the else is unwrapped):
if (c == ctStar) {
    return ss;
}
return H(c);
```

These passes were significantly expanded to support the control-flow-heavy `Decaps` oracles in the KEM binding and IND-CCA proofs.

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

Real-proof pointer: [`examples/Proofs/PRG/TriplingPRG_PRGSecurity.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRG_PRGSecurity.proof) uses sample split
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

A related transform, `FreshInputRFToUniform`, fires when the argument to an RF call
contains a `<-uniq`-sampled variable used solely in that single call. The argument may
be a bare variable `H(v)`, a tuple `H([v, x, ...])`, or a concatenation `H(v || x)` ---
in all cases the `<-uniq` component ensures the full argument is fresh, and the RF call
is replaced by a uniform sample.

```prooffrog
// Before: RF on uniquely-sampled input
BitString<n> r <-uniq[RF.domain] BitString<n>;
BitString<m> z = RF(r);

// After: independent uniform sample
BitString<n> r <-uniq[RF.domain] BitString<n>;
BitString<m> z <- BitString<m>;
```

This also works with composite arguments:

```prooffrog
// Before: RF on tuple with uniquely-sampled component
BitString<n> ss <-uniq[seen] BitString<n>;
BitString<m> z = H([ss, pk]);

// After: independent uniform sample
BitString<m> z <- BitString<m>;
```

Real-proof pointer: [`examples/Proofs/PubKeyEnc/HashedElGamal_INDCPA_ROM_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HashedElGamal_INDCPA_ROM_MultiChal.proof) -- the proof
uses `FreshInputRFToUniform` (after the DDH hop places a uniform group element `c` in
the exclusion set) to collapse `H(c)` into a fresh uniform bitstring, which then masks
the message via XOR.

{: .note }
**If this is not firing:** The exclusion set must be a game field, not a local variable
(a local set is re-initialized on each oracle call, losing the cross-call freshness
guarantee). All calls to the RF must use the same exclusion set. If the argument
variable appears more than once (including inside a tuple or concatenation and elsewhere),
the transform is blocked. The `<-uniq` sampling must be present; plain `<-`
does not trigger this rule. For composite arguments, only top-level tuple elements and
flattened concatenation leaves are checked --- nested sub-expressions like `H([f(v), x])`
are not matched.

### Random oracles as lazy maps

A common way to write a random oracle is as a lazily-populated map: on each query, sample a fresh value if the input has not been seen and otherwise return the stored one. The engine now recognizes this idiom and rewrites such a `Map<K, V>` field into a sampled `Function<K, V>` field (`LazyMapToSampledFunction`), so that a hand-written lazy table and a `Function<D, R> H <- Function<D, R>;` random oracle canonicalize to the same form. This means you can write ROM proofs in the natural lazy-table style instead of massaging them into `Function` form by hand.

```prooffrog
// Before: a lazily-populated map used as a random oracle
Map<GroupElem<G>, BitString<n>> T;

BitString<n> Hash(GroupElem<G> x) {
    if (!(x in T)) {
        T[x] <- BitString<n>;
    }
    return T[x];
}

// After: recognized as a sampled random function
Function<GroupElem<G>, BitString<n>> T <- Function<GroupElem<G>, BitString<n>>;

BitString<n> Hash(GroupElem<G> x) {
    return T(x);
}
```

Two related transforms extend this recognition:

- **Shared-table oracles** (`LazyMapPairToSampledFunction`): two oracle methods that read and write the *same* lazy table under mutually-disjoint guards are recognized together as one sampled function.
- **Table-scan lookups** (`LazyMapScan`): a `for ([K, V] e in M.entries) { ... }` loop that scans the table to find a matching entry is rewritten to a direct lookup, so that scan-style and index-style lazy tables canonicalize the same way.
- **Key re-indexing** (`MapKeyReindex`): a map keyed by one type can be re-indexed to an equivalent map keyed by an injective wrapping of that type, allowing tables that differ only in how their keys are packaged to match.

These transforms underpin the random-oracle proofs in the [CFRG hybrid KEM case study](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems) and the [Hashed ElGamal KEM proof](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/HashedElGamalKEM_INDCCA.proof).

{: .note }
**If this is not firing:** The map field must be used *only* as a lazy lookup table — every reference must be part of the "sample-if-absent, else return" idiom. Explicitly initializing the map in `Initialize`, taking its cardinality (`|M|`), or iterating its `.keys`/`.values`/`.entries` for any purpose other than a recognized scan blocks the rewrite. The map must also default to empty (no initializer), matching the semantics of a freshly-sampled random function.

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
[`examples/Proofs/SymEnc/SymEncPRF_INDCPA$_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDCPA%24_MultiChal.proof).

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

Real-proof pointer: [`examples/Proofs/SymEnc/EncryptThenMAC_INDCCA_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/EncryptThenMAC_INDCCA_MultiChal.proof) uses phased
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
`examples/Games/Helpers/` that state a statistical equivalence as a security assumption.
The user invokes a helper game as an assumption hop in the same way as any other
assumption; the difference is that the helper game is not a hardness assumption but a
statistical argument that the proof author vouches for.

Since version 0.6.0 a helper game may also *declare* the statistical loss it costs, in an
[`advantage <= ...;` clause]({% link manual/language-reference/games.md %}#the-advantage-clause)
placed after its two `Game` blocks. When a proof hops through such a helper, the engine
substitutes that expression into the [advantage bound]({% link manual/advantage-bounds.md %})
it synthesizes for the proof, so the birthday or guessing term appears in the printed bound
rather than as an opaque symbol. The clause is trusted, not proved: the engine checks only
that it is well-formed. Helper games that state a *perfect* equivalence declare
`advantage <= 0;`.

The helper games currently in the distribution are:

### DistinctSampling

**File:** [`examples/Games/Helpers/Probability/DistinctSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/DistinctSampling.game)

**What it states:** Sampling uniformly with replacement from a set `S` is
indistinguishable from sampling so that every returned value is distinct.
The `Replacement` game draws `val <- S`; the `NoReplacement` game keeps its own
set field `seen` and draws `val <-uniq[seen] S`. The two differ only when a uniform draw
collides with an earlier one, so the declared bound is the birthday bound
`count_Samp * (count_Samp - 1) / (2 * |S|)`.

**When to reach for it:** Whenever your proof needs to switch from plain uniform sampling
to `<-uniq` sampling (or back) so that the `UniqueRFSimplification` or
`FreshInputRFToUniform` transform can fire. The switch to `<-uniq` is the forward hop
(Replacement -> NoReplacement); after the random-function simplifications fire, the
switch back is the reverse hop.

```prooffrog
// Four-step pattern using DistinctSampling
G_before against Adversary;                                      // interchangeability
DistinctSampling.Replacement compose R_Sample against Adversary;   // interchangeability
DistinctSampling.NoReplacement compose R_Sample against Adversary; // by DistinctSampling
G_after against Adversary;                                       // interchangeability
```

{: .note }
`DistinctSampling` replaced an earlier `UniqueSampling` helper whose exclusion set was
supplied by the *caller*. That interface was unsound under an adversarial caller: a
reduction could pass an inflated exclusion set (`S \ {x}`) and make the two games
trivially distinguishable. Here the exclusion set is a field of `NoReplacement` and only
ever holds the game's own prior outputs, so it cannot be inflated. Proofs written against
`UniqueSampling` need porting to `DistinctSampling` or `NonzeroSampling`.

Real-proof pointer: used in [`examples/Proofs/SymEnc/SymEncPRF_INDCPA$_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDCPA%24_MultiChal.proof)
and [`examples/Proofs/SymEnc/SymEncPRF_INDOT$.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDOT%24.proof).

### NonzeroSampling

**File:** [`examples/Games/Helpers/Probability/NonzeroSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/NonzeroSampling.game)

**What it states:** A uniform scalar and a uniform *nonzero* scalar are interchangeable.
`MaybeZero` draws `val <- ModInt<order>`; `Nonzero` draws `val <- ModInt<order> \ {0}`.
The two distributions differ only on the single value `0`, giving the declared union bound
`count_Samp / order`. The excluded value is fixed by the game rather than supplied by the
caller, which is what makes the statement safe to universally quantify over reductions.

**When to reach for it:** To bridge "secret key sampled uniformly" and "secret key sampled
uniformly nonzero", which arises whenever a group-based proof needs to invert an exponent.

Real-proof pointer: used in [`examples/Proofs/Group/GapCDH_implies_GapCDH_NZ.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/GapCDH_implies_GapCDH_NZ.proof)
and [`examples/Proofs/KEM/HashedElGamalKEM_INDCCA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/HashedElGamalKEM_INDCCA.proof).

### Regularity

**File:** [`examples/Games/Hash/Regularity.game`](https://github.com/ProofFrog/examples/blob/main/Games/Hash/Regularity.game)

**What it states:** Applying a hash function `H : D -> BitString<n>` to a uniformly
sampled input from `D` is indistinguishable from sampling `BitString<n>` uniformly.
The `Real` game returns `H(x)` for `x <- D`; the `Ideal` game returns `y <- BitString<n>`
directly. This captures the standard-model randomness-extraction property of a
sufficiently regular hash function.

**When to reach for it:** When `H` is a deterministic function (declared in the `let:`
block without sampling, so not a random oracle), and the proof requires treating the
output of `H` on a uniform input as uniformly random. This is the standard-model
counterpart to what `FreshInputRFToUniform` does automatically in the ROM.

Real-proof pointer: used in [`examples/Proofs/Group/DDH_implies_HashedDDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDH_implies_HashedDDH.proof).

### ROMProgramming

**File:** [`examples/Games/Helpers/Probability/ROMProgramming.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/ROMProgramming.game)

**What it states:** Programming a random function at a single target point with a fresh
uniform value is statistically equivalent to evaluating it naturally. The `Natural` game
returns `H(target)` directly; the `Programmed` game stores a fresh random `u` at
initialization time and returns `u` when queried at `target` and `H(x)` otherwise.
This equivalence is exact when `H` is a truly random function, so the game declares
`advantage <= 0;`.

**When to reach for it:** When the proof needs to "program" a random oracle at the
challenge point -- replacing `H(target)` with an independently sampled value so that the
challenge ciphertext becomes statistically independent of the adversary's hash queries.
This is a standard technique in ROM proofs.

{: .warning }
`H` is sampled *inside* each game and is reachable only through the `Query` oracle. A
reduction composed with `ROMProgramming` must therefore route every random-oracle access
through `challenger.Query`. If the reduction holds its own copy of the random oracle and
evaluates it directly, it can compare that value against the one `Initialize` returned and
distinguish the two sides, which would make the assumption false as stated.

Real-proof pointer: used in [`examples/Proofs/Group/CDH_implies_HashedDDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/CDH_implies_HashedDDH.proof)
and [`examples/Proofs/KEM/HashedElGamalKEM_INDCCA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/HashedElGamalKEM_INDCCA.proof).

### RandomTargetGuessing

**File:** [`examples/Games/Helpers/Probability/RandomTargetGuessing.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/RandomTargetGuessing.game)

**What it states:** Comparing an adversary-supplied value against a hidden, uniformly
sampled target is indistinguishable from always returning false. The `Real` game samples
`target <- S` in `Initialize` and returns `c == target` on each `Eq` query; the `Ideal`
game always returns `false`. The declared guessing bound is `count_Eq / |S|`.

**When to reach for it:** When a game checks whether the adversary has guessed a secret
uniform value, and the proof argues that such a guess succeeds only with negligible
probability.

Real-proof pointer: used in [`examples/Proofs/Group/DDH_implies_CDH.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDH_implies_CDH.proof),
whose synthesized bound shows the statistical term resolved into the theorem game's own
query count:

```
Advantage bound: Adv^CDH(G)(A) <= Adv^DDH(G)(B1) + count_Solve/|GroupElem<G>|
```

### The ROFreshSampling family

**Files:** [`examples/Games/Helpers/Probability/ROFreshSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/ROFreshSampling.game)
and the variants `ROFreshSampling2` through `ROFreshSampling5`.

**What they state:** The value of a random oracle at a hidden, freshly sampled input is
indistinguishable from an independent uniform bitstring. The game owns the random function
`H` and exposes it only through a `Hash` oracle; `Real.Challenge()` samples a hidden fresh
input and returns `H` of it, while `Ideal.Challenge()` returns an independent uniform
bitstring. The hidden input is never revealed -- revealing it would let the adversary query
`Hash` at that point and distinguish immediately. The numbered variants cover random
oracles over tuple domains, where freshness comes from a single slot of the tuple.

**When to reach for it:** When a proof needs "the random oracle at a fresh hidden point
looks uniform". Unlike the `<-uniq`-plus-`DistinctSampling` route, these games carry the
entire statistical content themselves, so a proof using them needs no exclusion-set
sampling and no random-function freshness transform. Their interface exposes no
bookkeeping set at all, so a caller cannot misuse them.

Real-proof pointer: used in [`examples/Proofs/PubKeyEnc/HashedElGamal_INDCPA_ROM_MultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HashedElGamal_INDCPA_ROM_MultiChal.proof)
and [`examples/Proofs/Group/DDHMultiChal_implies_HashedDDHMultiChal.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDHMultiChal_implies_HashedDDHMultiChal.proof).

### Case-study helpers

Beyond the general-purpose helpers above, the
[CFRG hybrid KEM case study](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems)
defines six random-oracle helper games of its own, in
[`applications/cfrg-hybrid-kems/games/ROM/`](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems/games/ROM).
Each declares its own `advantage <= ...;` clause -- four of them perfect (`<= 0`), two of
them `1 / (2 ^ lambda)` -- and each ships alongside a hand-written EasyCrypt proof of the
bound it declares (the `.ec` file next to the `.game` file). Those six numbers are
therefore checked by a second tool rather than taken on trust; the hybrid KEM theorems
that use them are not.

{: .important }
Using a helper game adds to the trust base -- see the [Soundness]({% link researchers/soundness.md %}) page in the For Researchers area.

---

## What the engine does not do

The following things are outside the scope of automated canonicalization. Each item
links to [Limitations]({% link manual/limitations.md %}) for details and workarounds.

- **No derivation of probabilities from game code.** Canonicalization itself is
  qualitative: it decides whether two games are interchangeable, never how far apart they
  are. Advantage bookkeeping happens *outside* the pipeline -- after a proof verifies, the
  engine sums the losses of the hops it took (see
  [Advantage Bounds]({% link manual/advantage-bounds.md %})). What no part of the engine
  does is *derive* a collision or guessing probability from a pair of games: where a hop
  crosses a statistical gap, the number comes from a human-written `advantage <= ...;`
  clause on a helper game, which the engine trusts. See
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
  `examples/Games/Helpers/` and use the four-step reduction pattern to cross the gap.

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
