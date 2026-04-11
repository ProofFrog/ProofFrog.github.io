---
title: Scientific Background
layout: default
parent: For Researchers
nav_order: 1
redirect_from:
  - /design/
  - /design.html
---

# Scientific Background
{: .no_toc }

This page explains where ProofFrog fits within the context of game-hopping proofs, reductionist security, and computer-aided cryptography; ProofFrog's design approach; and its relationship to other tools.

ProofFrog operates in the computational model. It is positioned as a deliberate trade-off against tools like [EasyCrypt](https://www.easycrypt.info/) and [CryptoVerif](https://bblanche.gitlabpages.inria.fr/CryptoVerif/): narrower scope in exchange for a shallower learning curve, targeting cryptographers entering computer-aided proofs for the first time and educational contexts where the overhead of a full-scale proof assistant would impede rather than support learning.

- TOC
{:toc}

---

## The three tasks of a game-hopping proof

Verifying a game-hopping proof involves three distinct tasks:

1. State and justify a sequence of games, with each hop justified as either an *interchangeability-based hop* (distinguishing advantage zero, demonstrated by code equivalence) or a *reduction-based hop* (bounded distinguishing advantage, justified by an explicit reduction to an assumed security property).
2. Accumulate the bounded advantages from each reduction-based hop into a single security bound and track the resource usage of each reduction.
3. Assess whether that bound is acceptable given the intended cost model, parameter choices, and any idealized models (random oracle, ideal cipher, etc.).

**ProofFrog addresses Task 1 only.** Tasks 2 and 3 remain the responsibility of the proof author and reader. ProofFrog checks the structural validity of a game sequence, not the tightness or appropriateness of the resulting security bound.

---

## Design choices

ProofFrog's design reflects a set of deliberate choices about where to trade expressivity for simplicity.

### Syntactic rather than logical

Existing tools such as EasyCrypt work at the level of logical formulae over probabilistic relational Hoare logic. ProofFrog instead treats games as abstract syntax trees (ASTs) and verifies game equivalence using techniques drawn from compiler design and static analysis. The engine takes pairs of game ASTs, applies a fixed-point pipeline of transformations, and compares the resulting canonical forms.

This is a deliberate trade-off. Probabilistic relational Hoare logic is strictly more expressive: it can reason about a wider class of programs and a wider class of equivalences. The AST-level approach gives up some of that expressivity in exchange for some automation and a representation that (hopefully) more closely matches how a cryptographer thinks about game code on paper.

### User-supplied reductions, not reduction search

ProofFrog verifies user-written reductions; it does not search for them. The proof author specifies the game sequence, writes the reductions that justify reduction-based hops, and ProofFrog checks that the required interchangeability conditions hold. Reduction search is not attempted (though you can [ask an LLM-based coding agent to try]({% link researchers/gen-ai.md %})).

### Canonicalization, not explicit rewriting

Within each interchangeability-based hop, the user does not direct step-by-step rewriting. The engine instead runs a canonicalization process and compares the resulting canonical forms. If the canonical forms are structurally identical (up to variable renaming), the games are considered interchangeable. For cases where canonical forms differ only in branch conditions, the engine invokes an SMT solver (Z3) to check logical equivalence of those conditions.

This matches the intuition behind a typical pen-and-paper "obviously the same" argument: the proof author does not spell out every algebraic step; they rely on the reader to see that two pieces of code are equivalent after routine simplification. ProofFrog tries to automate that routine simplification. More details are available on the [Canonicalization]({% link manual/canonicalization.md %}) and [Engine Internals]({% link researchers/engine-internals.md %}) pages.

### C/Java-like imperative syntax

The FrogLang domain-specific language is designed to look like pen-and-paper cryptographic pseudocode, using the conventions of Rosulek's [*The Joy of Cryptography*](https://joyofcryptography.com/). Games are written with explicit `Initialize` methods, oracle bodies, and field declarations. A proof from that textbook can typically be transcribed into ProofFrog syntax with minimal structural changes.

The proof file lists the variable and scheme declarations, the security assumptions, the statement to be proved, and the game sequence, including any reductions needed. The proof syntax also supports bounded induction for hybrid arguments: ProofFrog verifies the validity of each hop within the induction and checks both boundary conditions.

---

## Comparison with other tools

**EasyCrypt** uses an imperative language for specifying games together with a formula language for expressing probabilistic relational Hoare logic judgments. Proofs are written using a tactic language that navigates the program and applies logical rules to the formula being proved. EasyCrypt is very expressive and can handle a wide class of general statements; the cost is complexity. Tactic-level reasoning operates at a fine granularity, and proofs can be difficult to read without stepping through them interactively, because the formula each tactic is being applied to is not always apparent from the static proof text.

**CryptoVerif** takes the opposite approach: rather than maximizing expressivity, it prioritizes automation. Games are specified in a process calculus syntax. Proofs can often be discovered automatically, but CryptoVerif also supports an interactive mode where a user can explicitly direct which game transformations to apply when the automatic search fails. Security properties are expressed as internal logical formulae, verified by an internal equational prover rather than by the user directly.

Beyond these two, the computer-aided cryptography space includes a number of other tools. [EasyUC](https://github.com/easyuc/EasyUC) formalizes universal composability within EasyCrypt. [FCF](https://github.com/adampetcher/fcf) (Foundational Cryptography Framework) and [SSProve](https://github.com/SSProve/ssprove) both use the [Rocq](https://rocq-prover.org/) proof assistant: FCF encodes a probabilistic programming language directly, while SSProve formalizes state-separating proofs for more modular game-based arguments. [Squirrel](https://squirrel-prover.github.io/) develops a higher-order logic based on the computationally complete symbolic attacker framework. [CryptHOL](https://www.isa-afp.org/entries/CryptHOL.html) formalizes cryptographic arguments within [Isabelle/HOL](https://isabelle.in.tum.de/). [Owl](https://github.com/secure-foundations/owl) uses refinement types and an information-flow control type system for integrity properties. [F\*](https://www.fstar-lang.org/) has been used to formalize protocols such as TLS, functioning both as a proof assistant and a general-purpose programming language.

ProofFrog's scope is narrower than any of these: it addresses only Task 1 of the game-hopping proof process and relies on AST canonicalization rather than a formally verified program logic. Its intended advantage is a shallower learning curve and a syntax close enough to pen-and-paper conventions that the gap between a textbook proof and a machine-checked one is small. ProofFrog is targeted at educational use and at cryptographers who want to experiment with machine-checked arguments before committing to the overhead of a full-scale proof assistant. For research-grade proofs with complex reductions or non-standard security definitions, EasyCrypt or CryptoVerif will be more appropriate.

ProofFrog's soundness (or lack thereof) is discussed further on the [Soundness]({% link researchers/soundness.md %}) page. The [Limitations]({% link manual/limitations.md %}) page discusses limits on ProofFrog's functionality, completeness, and expressivity.

---

## The bottom line

**ProofFrog is** a tool for verifying the structural validity of a game-hopping sequence in the computational model. It checks that the sequence of games in a proof correctly starts and ends at the appropriate games, and verifies each hop as either an interchangeability-based or reduction-based hop. Interchangeability is checked by AST canonicalization: the engine applies a fixed-point pipeline of compiler-style transformations and compares canonical forms.

**ProofFrog is not** a replacement for EasyCrypt or CryptoVerif. It does not accumulate probability bounds or track resource usage (Tasks 2 and 3 remain manual). It does not reason about computational complexity, concurrency, or side channels. Its engine does not have a formal soundness proof: the correctness of ProofFrog's transformations has not been verified (either manually or mechanically) against a formalized semantics. The set of transformations and heuristics it can apply is limited, as is its expressivity for mathematical and probabilistic reasoning.
