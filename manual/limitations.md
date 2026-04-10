---
title: Limitations
layout: default
parent: Manual
nav_order: 50
---

# Limitations
{: .no_toc }

ProofFrog is a mechanized proof assistant for a specific class of cryptographic arguments.
This page describes where the tool stops: what it cannot express, what it deliberately
chooses not to do, and where its current implementation is weak.
If a proof step fails unexpectedly, this page is the right place to start diagnosing why.

- TOC
{:toc}

---

## Soundness vs. capability -- read this first

This page is about **capability limits**: things the engine cannot do or has not yet been
built to do. When you hit a capability limit you see a failed proof step, and the goal is
to understand why and find a workaround. The sections below catalogue those situations.

A separate concern is **trust limits**: even when the engine validates a proof, how
confident should you be in the validation? That question is about soundness -- does the
engine's acceptance of a proof actually guarantee what the proof claims? The answer
involves the formal semantics of FrogLang, the correctness of the canonicalization
pipeline, and the scope of the reduction paradigm itself. That story lives in the For Researchers area at [Soundness]({% link researchers/soundness.md %}). Both kinds of
limits are real and important. They are documented separately because they require
different mental models: a capability limit is a practical obstacle to finishing a proof;
a trust limit is a question about what a finished proof means.

---

## Things ProofFrog does not model

FrogLang is a domain-specific language for game-hopping proofs in the reduction security
paradigm. Several aspects of real cryptographic systems are deliberately outside its scope.
These are not bugs or oversights; they are the boundary the language was designed around.

**Computational complexity.** FrogLang does not model the running time of adversaries or
scheme algorithms. The notion of "efficient adversary" is present as a conceptual
assumption but is not tracked in the language. ProofFrog proofs establish qualitative
reductions -- if the underlying assumption holds for all efficient adversaries, so does the
theorem -- but do not bound how the advantage or running time scales with security
parameters.

**Quantitative bounds.** Security loss and advantage bounds are not tracked. A successful
proof says that a reduction exists; it does not say how tight the reduction is. If your
proof requires a concrete tightness argument (for example, hybrid counting over
polynomially many independent samples), that argument lives outside what ProofFrog
verifies.

**Recursive computation.** FrogLang methods cannot call themselves recursively, and
there is no loop construct. The language is not Turing-complete. Proofs that require
reasoning about an inductively defined sequence of games (for example, a hybrid argument
over n independent challenges) must be structured using the `lemma:` mechanism to reason
about a single step, with the inductive argument stated externally.

**Side channels.** Timing, power, cache, and other physical side-channel attacks are not
modeled. All games are defined solely by the sequence of return values their oracles
produce. An adversary who learns something from the time it takes an oracle to respond
is outside the model.

**Concurrency.** All oracle calls are sequential. There is no model of concurrent
adversaries, parallel oracle queries, or adaptive ordering of queries that depends on
partial results arriving simultaneously.

**Abort semantics.** FrogLang has no `abort` statement. Failure conditions are
represented through control flow: returning `None` via optional types, conditional
early returns, or implicitly through collision probabilities in unique sampling
(`<-uniq`). A proof that relies on a game aborting with a certain probability requires
modeling that probability as a distinguishing event within the reduction, not as a
built-in abort primitive.

---

## Capabilities the engine deliberately lacks

Some things the engine does not do are intentional design choices, not missing features.

**Lemma synthesis.** The engine does not search for or invent lemmas. When a proof step
requires a non-trivial algebraic identity or a helper reduction, the user states the
lemma explicitly using the `lemma:` block and provides the corresponding proof file.
The engine verifies the lemma proof and adds its conclusion to the available assumptions,
but the creative step of identifying what lemma is needed belongs to the user.

**Reduction search.** The engine does not search for reductions. When a proof hop
invokes an underlying hardness assumption, the user supplies the reduction -- the code
that translates a challenge from the underlying game into the context of the proof.
The engine verifies that the supplied reduction composed with each side of the assumption
is interchangeable with the adjacent games in the proof sequence, but it does not propose
or construct reductions automatically.

**Probability bookkeeping.** The engine does not compute or track numerical advantage
bounds. It verifies that a chain of interchangeable-or-reduction-justified hops connects
the two sides of the security property, which establishes that the theorem follows from
the stated assumptions. Quantifying the concrete advantage (for example, the probability
of a collision in a birthday argument) is the user's responsibility and is stated as an
external comment or separate argument outside the proof file.

---

## Capabilities the engine aspires to but is currently weak at

The following limitations are registered in the engine's diagnostic system and will
be flagged explicitly in the `prove -v` output when a failing step looks like one of
these cases.

### `||` and `&&` commutativity
{: .no_toc }

The engine normalizes `+` and `*` via commutative chain normalization, but it does not
normalize the operand order of `||` (logical OR on Bool, or concatenation on BitString)
or `&&`. As a result, `a || b` and `b || a` will not be recognized as identical during
canonicalization.

**Workaround.** Reorder the operands manually in your intermediate game so that both
sides of the hop list them in the same order.

### Field declaration ordering
{: .no_toc }

The engine does not reorder field declarations (state variables or local variable
declarations) within a game. If two games have the same set of declarations but in a
different order, they will not be recognized as equivalent.

**Workaround.** Match the declaration order between adjacent games manually. When writing
an intermediate game, inspect the canonical form produced by `prove -v` on the preceding
step and copy the field order from there.

### `||` and `&&` associativity
{: .no_toc }

Just as the engine does not normalize commutativity for `||` and `&&`, it does not
normalize associativity. The expressions `(a || b) || c` and `a || (b || c)` are
treated as structurally different and will not be recognized as identical.

**Workaround.** Reparenthesize the expression in your intermediate game so that the
parenthesization matches the previous step. Running `prove -v` shows the canonical form
on both sides of a failing hop, which makes it straightforward to identify where the
grouping differs.

### Extra temporary variable form
{: .no_toc }

The engine's `SimplifyReturn` transform inlines single-use temporary variables that are
immediately returned. If this transform fires on one game but not on a structurally
similar game written differently, the two canonical forms will not match. Concretely:

```
// Form A -- SimplifyReturn inlines this
Type v = f();
return v;

// Form B -- already in direct form
return f();
```

When one game uses Form A and the other uses Form B, the engine may or may not unify
them depending on how the surrounding code looks.

**Workaround.** Pick one form consistently across all intermediate games in a proof.
The direct-return form (`return f();`) is the canonical target, so preferring it avoids
the discrepancy.

### `if`/`else if` branch reordering
{: .no_toc }

The engine does not normalize the order of `if`/`else if` branches. Two games that
test the same conditions in a different order will not be recognized as equivalent, even
if the branch bodies are identical.

**Workaround.** Match the branch order from the previous game. When writing an
intermediate game, check the canonical form from `prove -v` and copy the branch order
from there.

### Higher-level soft spots
{: .no_toc }

Beyond the registered limitations above, the following areas are known to be
challenging for the current engine, even though the diagnostic system may not always
produce a specific error message for them.

**Group-theoretic reasoning beyond the engine's listed identities.** The engine knows
a fixed set of algebraic identities (XOR cancellation, modular arithmetic rules, and
similar). If a proof step requires an identity outside that set -- for example, a
non-trivial group law or an algebraic manipulation involving exponents -- the engine
will not find it automatically. The user must introduce an intermediate game that
already has the result of the identity applied.

**Nested induction.** FrogLang supports single-level hybrid arguments via the `induction` construct (see [Proofs: Induction]({% link manual/language-reference/proofs.md %}#induction-hybrid-arguments)), but nested induction or induction with complex base cases must be handled by breaking the argument into multiple proof files composed via the `lemma:` mechanism.

**Probabilistic reasoning beyond the algebraic identities listed in [Canonicalization]({% link manual/canonicalization.md %}).**
The engine knows that XOR with a uniform value produces a uniform value, that unique
sampling gives independent uniform outputs, and that random functions on fresh inputs
give uniform outputs. Beyond these specific patterns, general probabilistic arguments --
such as the probability of a collision under a specific distribution, or the independence
of two events that happen to be statistically independent -- are not mechanized. Such
arguments must be made externally and reflected in the intermediate game structure.

---

## What kinds of proofs do work well

ProofFrog is well matched to a recognizable class of proofs:

- **Textbook game-hopping proofs** at the level of Joy of Cryptography and similar
  introductory graduate texts. The worked examples in the ProofFrog distribution cover
  one-time pad security, pseudorandom generator security, and similar foundational
  results.

- **Proofs that are primarily inlining plus a small number of reductions.** The engine's
  core strength is automated interchangeability checking via canonicalization. Proofs
  that consist of a sequence of definitional expansions (inlining a scheme into a game),
  followed by one or two reduction hops, map directly onto what the engine does best.

- **Proofs whose structure mirrors a standard pen-and-paper argument.** If you can
  describe the proof as "game G1 is identical to game G2 by inspection, then we hop via
  the PRG assumption to game G3, then G3 is identical to the right side by inspection,"
  the engine is likely to validate each of those steps.

See the [Worked Examples]({% link manual/worked-examples/index.md %}) section of the manual for annotated proof walkthroughs, and the [Examples Gallery]({% link examples.md %}) for a browsable index of all proof files in the distribution.

---

## Reporting a limitation

If you encounter a case where the engine rejects a proof step that you believe is
mathematically valid, please open an issue at
[https://github.com/ProofFrog/ProofFrog/issues](https://github.com/ProofFrog/ProofFrog/issues).
Include the smallest proof file that reproduces the problem, the full output of
`python -m proof_frog prove -v <your-file.proof>` (which shows the canonical form of
each game and the point of failure), and a brief description of what you expected the
engine to accept and why.
