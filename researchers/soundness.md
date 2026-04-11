---
title: Soundness
layout: default
parent: For Researchers
nav_order: 3
---

# Soundness
{: .no_toc }

ProofFrog has no formal soundness proof. Each transformation in the canonicalization
pipeline is written by hand (and possibly with the assistance of coding agents) and 
intended to be semantics-preserving, but correctness and soundness have not been 
formally verified. 

When ProofFrog validates a game hop, that is evidence the hop is correct -- not a
machine-checked certificate. Serious use requires additional external checking: manual
review of the proof structure, cross-comparison with pen-and-paper arguments, and a
preference for small hops that can be individually inspected. A user treating ProofFrog
as a rubber stamp is misusing the tool. The validation means the engine did not find a
counterexample using its current pipeline; it does not mean no counterexample exists.

It is a future goal to link ProofFrog with existing formal verification tools, such as
EasyCrypt, to improve assurance.

- TOC
{:toc}

---

## ProofFrog's checking methodology

ProofFrog's engine attempts to verify three kinds of proof steps.

**Interchangeability hops.** Two games are interchangeable if and only if for all
adversaries, the probability distribution over adversary outputs is identical. Formally:

```
Pr[A interacting with Game1 outputs 1] = Pr[A interacting with Game2 outputs 1]
```

Adversary interaction with games is described in more detail on the [Execution Model]({% link
manual/language-reference/execution-model.md %}) page. ProofFrog attempts to verify
interchangeability by canonicalizing both games and comparing their canonical forms. The
canonicalization pipeline is a deterministic rewrite sequence: inlining,
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

## The trust base

Every component listed below can harbor a bug that causes the engine to validate an
invalid hop.

**The parser** (`proof_frog/frog_parser.py` and the ANTLR grammars under
`proof_frog/parsing/`). A parser bug could miscategorize a construct and feed the wrong
AST into the engine. The grammars are not formally specified beyond the ANTLR grammar 
files; their correctness relative to the intended language semantics is not proved.

**The type checker and semantic analysis** (`proof_frog/semantic_analysis.py`). A
semantic-analysis bug could allow a malformed program through, or could annotate a 
well-formed program with incorrect type information that downstream transforms rely on.

**The transformation pipeline** (all of `proof_frog/transforms/`). Each transform is a
Python function, written by hand or with the help of coding agents, that is intended to 
be semantics-preserving. This is the largest
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

---

## What is NOT claimed

The following are things that a user seeking machine-checked proofs of cryptographic 
arguments might hope for, but ProofFrog does not claim to provide.

**Soundness of individual transforms.** No individual transform in
`proof_frog/transforms/` is proved correct in isolation or in composition. The transforms
are tested, not verified.

**Completeness of the engine.** Some interchangeable games will fail to canonicalize to
the same form. The engine is incomplete: it cannot find all valid interchangeability
relationships. Such failures are capability limitations, not soundness issues -- the engine
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

## Writing and interpreting ProofFrog proofs in light of lack of formal soundness guarantees

Because ProofFrog lacks a soundness proof and has a large trust base, validation using 
ProofFrog is evidence but not a guarantee, and responsibility for
believing a proof sits with the people writing and reading it. The practices below don't
eliminate that responsibility, but they give a proof author and a proof reviewer concrete
ways to form a judgement.

**When writing a proof, keep hops small.** The smaller a hop, the fewer transforms fire
and the easier it is to manually inspect what changed. When a hop applies a large number
of transforms, it may be helpful to split it into a few smaller hops -- both for your 
own assurance while constructing the proof and to give later readers a sequence of claims
they can each individually check.

**When writing a proof, explicit intermediate games help understanding.** Writing
out each intermediate game explicitly, rather than relying on ProofFrog to accept a large
implicit hop, forces you to state precisely what you think the intermediate game is.
That statement then becomes a piece of the proof a reader -- or future you -- can check
independently, without having to trust that the engine's implicit reasoning matched your
own.

**When reviewing a proof, inspect canonical forms directly.** When you are unsure
whether the engine is validating a hop for the reason you think it is, the `step-detail`
and `canonicalization-trace` CLI commands (or the hop inspector in the web editor) 
expose the canonical form of a specific game
step and the sequence of intermediate rewrites the pipeline applied. `step-after-transform`
shows the game AST after all transforms up to a named pass. Reviewing the canonical form
before and after a hop gives you direct evidence of what the engine is claiming, which
you can then reconcile with what the proof author intended. (`proof_frog prove -v` adds
game-level output to a proof run; `-vv` adds per-transform tracing.)

**Cross-check against pen-and-paper arguments.** If a textbook or a previously
published pen-and-paper proof agrees with what ProofFrog accepts, the two checks
reinforce each other: an automated check and a manual one, each covering errors the
other might miss. If they disagree, one of them is wrong and the divergence itself is
valuable information. When reviewing someone else's ProofFrog proof, try to reconstruct
the argument on paper for at least the hops you find most load-bearing.

**Consider validating tricky ProofFrog hops in another tool.** If a ProofFrog proof
introduces a bespoke assumption to bridge a tricky hop, or leaves the hop unverified,
it may be possible to formalize that specific hop in another tool, such as EasyCrypt.

---

## Soundness issues

**Report suspicious validations.** If while writing or reviewing a proof you suspect
the engine has accepted an incorrect hop -- for example, if ProofFrog validates a hop
that you believe is mathematically invalid -- file an issue on the
[ProofFrog issue tracker](https://github.com/ProofFrog/ProofFrog/issues) and apply the
`soundness` label.
Include the proof file, the specific hop, and your analysis of why you think the hop is
wrong. A validated hop that is actually invalid is a soundness bug and should be treated
as high priority.

Issues suspected of being soundness concerns are tagged with the
[`soundness`](https://github.com/ProofFrog/ProofFrog/issues?q=label%3Asoundness) label
on the issue tracker. These are distinct from 
[capability limitations]({% link manual/limitations.md %}), where the engine
correctly rejects a valid hop because its current pipeline cannot show the hop is in
fact valid.

---

## Comparison with other tools

Other more established formal verification tools for cryptography like EasyCrypt and 
CryptoVerif have stronger trust bases: their program logics and tactic
languages have pen-and-paper formalizations with meta-theoretic soundness arguments for
those logics. ProofFrog lacks such soundness arguments. For high-assurance cryptographic work -- standards,
deployed protocols, production code -- the more established tools remain the appropriate
choice. ProofFrog's may be suitable for more preliminary work: exploration, education, and
iterative proof development where the ease of writing and checking a game-hopping proof
is worth the weaker soundness guarantee.

One concrete direction that could narrow this gap is an export functionality that encodes
ProofFrog's automated transformations into the syntax of a more established engine such
as EasyCrypt, so that individual hops could be discharged by a tool with a stronger
logical foundation. While this is not yet implemented, we hope to explore this direction
in the future.
