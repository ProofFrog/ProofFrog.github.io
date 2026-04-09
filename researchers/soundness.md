---
title: Soundness
layout: default
parent: For Researchers
nav_order: 3
---

# Soundness

## Summary

ProofFrog has no formal soundness proof. Each transformation in the canonicalization
pipeline is written by hand and intended to be semantics-preserving, but correctness has
not been mechanically verified. Treat ProofFrog as a *proof-finding aid*, not a
*proof certifier*.

When ProofFrog validates a game hop, that is evidence the hop is correct -- not a
machine-checked certificate. Serious use requires additional external checking: manual
review of the proof structure, cross-comparison with pen-and-paper arguments, and a
preference for small hops that can be individually inspected. A user treating ProofFrog
as a rubber stamp is misusing the tool. The validation means the engine did not find a
counterexample using its current pipeline; it does not mean no counterexample exists.

---

## The claim

ProofFrog's engine attempts to verify three kinds of proof steps.

**Interchangeability hops.** Two games are interchangeable if and only if for all
adversaries, the probability distribution over adversary outputs is identical. Formally:

```
Pr[A interacting with Game1 outputs 1] = Pr[A interacting with Game2 outputs 1]
```

This definition is stated precisely on the [Execution Model]({% link
manual/language-reference/execution-model.md %}) page. ProofFrog attempts to verify
interchangeability by canonicalizing both games and comparing their canonical forms. The
canonicalization pipeline is a deterministic, hand-written rewrite sequence: inlining,
algebraic simplification, dead code elimination, sampling normalization, and others. If
the canonical forms are structurally identical (up to variable renaming), the engine
reports the hop valid. When the canonical forms differ only in the conditions of `if`
statements, the engine calls Z3 to check logical equivalence of those conditions.

**Assumption hops.** An assumption hop substitutes one side of a declared `assume:`
security property for the other. ProofFrog verifies that the game step pattern matches
the assumed property (`Security.Side1 compose R` to `Security.Side2 compose R`) and
trusts the assumption itself. The assumption is not verified -- it is what the proof
depends on.

**Lemma hops.** ProofFrog recursively verifies the lemma's proof file (unless
`--skip-lemmas` is used), checks that the lemma's assumptions are a subset of the
current proof's `assume:` block, and adds the lemma's theorem to the available
assumptions. The soundness of a lemma hop reduces to the soundness of the lemma's own
proof.

---

## What is in the trust base

Every component listed below can harbor a bug that causes the engine to validate an
invalid hop.

**The parser** (`proof_frog/frog_parser.py` and the ANTLR grammars under
`proof_frog/parsing/`). A parser bug could miscategorize a construct and feed the wrong
AST into the engine. The grammars are not formally specified; their correctness relative
to the intended language semantics is not proved.

**The type checker and semantic analysis** (`proof_frog/semantic_analysis.py`). A
semantic-analysis bug could allow a malformed program through, or could annotate a well-
formed program with incorrect type information that downstream transforms rely on.

**The transformation pipeline** (all of `proof_frog/transforms/`). Each transform is a
hand-written Python function intended to be semantics-preserving. This is the largest
component of the trust base and the most likely source of soundness failures. A transform
that is almost correct -- one that is semantics-preserving in 999 out of 1000 inputs and
wrong on the 1000th -- could validate an incorrect hop without any diagnostic signal. The
current practice is to introduce both positive and negative unit tests when adding or
modifying transforms, and to add near-miss instrumentation at precondition-failure points.
This reduces the risk of wrong transforms going undetected, but does not eliminate it.

**SMT integration** (Z3 calls, primarily in the symbolic transforms). Z3 is used to
check logical equivalence of conditions when canonical forms are structurally close but
not identical. Z3's own correctness is outside ProofFrog's control. A Z3 soundness bug
could cause ProofFrog to accept logically non-equivalent conditions as equivalent.

**SymPy** (for symbolic arithmetic simplification). SymPy is used to simplify symbolic
expressions involving modular arithmetic and group operations. Like Z3, its correctness
is an external dependency.

**The Python runtime.** Interpreter bugs, floating-point behavior, dictionary ordering
semantics, and similar runtime properties are all implicitly trusted.

Be honest about the size of this trust base. EasyCrypt and CryptoVerif also have trust
bases, but those tools have pen-and-paper formalizations of their program logics, with
meta-theoretic soundness arguments for those logics. ProofFrog has neither a
formalization nor a meta-theoretic soundness argument. The published ProofFrog eprint
explicitly notes that it "does not provide any formal proofs of correctness for the
transformations ProofFrog uses or for the correctness of the engine's implementation."

---

## What is NOT claimed

The following are things a reader might reasonably assume that ProofFrog does not claim.

**Soundness of individual transforms.** No individual transform in
`proof_frog/transforms/` is proved correct in isolation or in composition. The transforms
are tested, not verified.

**Completeness of the engine.** Some interchangeable games will fail to canonicalize to
the same form. The engine is incomplete: it cannot find all valid interchangeability
relationships. Failures are capability limitations, not soundness issues -- the engine
does not accept invalid hops just because it cannot verify valid ones. See the
[Limitations]({% link manual/limitations.md %}) page for a catalogue of known gaps.

**Tight security bounds.** ProofFrog reports whether a hop is valid, not how much
advantage an adversary could gain. Concrete security bounds -- loss factors, collision
probabilities, hybrid counts -- are the proof author's responsibility and are stated
outside what ProofFrog verifies.

**Side-channel resistance, timing attacks, fault attacks.** None of these are modeled.
All games are defined solely by the sequence of return values their oracles produce.

**Abort semantics.** FrogLang has no abort primitive. Proofs that rely on game aborts
with explicit probability accounting must model those probabilities as indistinguishable
events within the reduction, not as built-in abort steps.

**Concurrency.** All oracle calls are sequential. Concurrent adversaries, parallel oracle
queries, and reactive systems are outside the model.

**Correctness of the language semantics.** FrogLang does not have a formal semantics
document. The intended semantics is described in the manual and in the published paper,
but the correspondence between that prose description and the engine's actual behavior is
not formally established.

---

## Mitigations a careful user can apply

These practices reduce the trust load without eliminating it.

**Keep hops small.** The smaller a hop, the fewer transforms fire and the easier it is
to manually inspect what changed. A hop that inlines one function and cancels one XOR is
straightforwardly checkable by hand. A hop that fires fifteen transforms across a complex
game body is not. When in doubt, split a large hop into two or three smaller ones.

**Inspect canonical forms directly.** The `step-detail` and `canonicalization-trace`
CLI commands expose the canonical form of a specific game step and the sequence of
intermediate rewrites the pipeline applied. `step-after-transform` shows the game AST
after all transforms up to a named pass. Reviewing the canonical form before and after
a hop gives you direct evidence of what the engine is claiming. (`proof_frog prove -v`
adds game-level output to a proof run; `-vv` adds per-transform tracing.)

**Cross-check against pen-and-paper proofs.** If a textbook says the proof works and
ProofFrog says the proof works, the two checks reinforce each other. If they disagree,
one of them is wrong and you need to determine which. The agreement of two independent
checks -- one automated, one manual -- is stronger evidence than either alone.

**Prefer named intermediate games over implicit games.** Writing out each intermediate
game explicitly, rather than relying on ProofFrog to accept a large implicit hop, forces
you to state precisely what you think the intermediate game is. That statement is then
independently checkable.

**Report suspicious validations.** If you suspect the engine has accepted an incorrect
hop -- for example, if ProofFrog validates a hop that you believe is mathematically
invalid -- file an issue at
[https://github.com/ProofFrog/ProofFrog/issues](https://github.com/ProofFrog/ProofFrog/issues).
Include the proof file, the specific hop, and your analysis of why you think the hop is
wrong. A validated hop that is actually invalid is a soundness bug and should be treated
as high priority.

---

## Comparison framing

EasyCrypt and CryptoVerif have deeper trust bases: their program logics and tactic
languages have pen-and-paper formalizations with meta-theoretic soundness arguments for
those logics. ProofFrog makes no such claims. This is a genuine gap,
not a rhetorical understatement. For high-assurance cryptographic work -- standards,
deployed protocols, production code -- the more established tools remain the appropriate
choice. ProofFrog's niche is earlier in the pipeline: exploration, education, and
iterative proof development where the ease of writing and checking a game-hopping proof
is worth the weaker soundness guarantee.

One concrete direction that could narrow this gap is an export functionality that encodes
ProofFrog's automated transformations into the syntax of a more established engine such
as EasyCrypt, so that individual hops could be discharged by a tool with a stronger
logical foundation. This is identified as future work in the published paper but is not
yet implemented.

---

## Known soundness issues

There is currently no dedicated `soundness` label on the issue tracker. If you file an
issue that you believe is a soundness concern -- as opposed to a capability limitation
where the engine correctly rejects a valid hop -- please mention it explicitly in the
issue body and we will tag it accordingly. The distinction matters: a capability failure
is expected and documented; a soundness failure means the engine has accepted something
it should not have, which is a qualitatively different problem.
