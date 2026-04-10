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

This page is the "what and why" of ProofFrog for readers who already understand game-hopping proofs, reductionist security, and the landscape of computer-aided cryptography. It explains where ProofFrog sits in that landscape, what it does and does not attempt, and why it is designed the way it is.

---

## Motivation

Cryptographic security proofs provide theoretical guarantees against entire classes of adversaries. A proof of security can, in principle, completely eliminate a class of attacks. Human fallibility, however, means that even a proof reviewed by experts may still hide flaws or outright errors. Computer-aided cryptography is the response: software tooling designed to formally verify each step in a proof, preventing erroneous results from being published and insecure constructions from being deployed.

The field can be broadly divided into three approaches: verifying implementation-level security, verifying functional correctness and efficiency, and verifying design-level security. Design-level security tooling divides further into two camps. The symbolic model (exemplified by ProVerif and Tamarin) assumes atomic data and treats cryptographic primitives as black boxes; this idealization makes verification more tractable but provides weaker security guarantees. The computational model is less idealized: the underlying representation of data is taken seriously and primitives are modelled as explicit probabilistic algorithms. ProofFrog operates in the computational model.

Within the computational model, several proof assistants exist and have demonstrated significant expressivity. Despite this, adoption in the broader cryptographic community has remained limited, in part due to ease-of-use concerns. ProofFrog is positioned as a deliberate trade-off: narrower scope in exchange for a shallower learning curve, targeting cryptographers who are entering computer-aided proofs for the first time and educational contexts where the overhead of a full-scale proof assistant would impede rather than support learning.

---

## The Three Tasks of a Game-Hopping Proof

Game-hopping (Shoup 2004, Bellare--Rogaway 2006) is the standard technique for organizing reductionist security proofs in the computational model. A proof author presents a sequence of games that gradually transform the starting game into the ending game, where each hop changes the output distribution by a small (possibly zero) amount.

Writing and verifying such a proof involves three distinct tasks.

**Task 1: State and justify a sequence of games.** The starting game is the target scheme inlined into the left game of the target security definition; the ending game is the target scheme inlined into the right game. Each hop must be justified as either an *interchangeability-based hop* (the two adjacent games have distinguishing advantage zero, demonstrated by code equivalence) or a *reduction-based hop* (bounded distinguishing advantage, justified by exhibiting a reduction to an assumed security property and verifying the required interchangeability conditions hold for that reduction).

**Task 2: Accumulate bounded distinguishing advantages.** The advantages from each reduction-based hop must be accumulated into a single security bound, and the resource usage (time, query counts, and so on, depending on the resource model) of each reduction must be tracked.

**Task 3: Assess the accumulated bound.** Someone relying on the theorem must assess whether the accumulated bound is sufficiently small in an appropriate cost model, whether the security definition is suitable for the intended application, whether the parameter choices are appropriate given the bound and resource usage, and whether any idealized models (random oracle model, ideal cipher model, etc.) are acceptable for the use case.

**ProofFrog addresses Task 1 only.** Tasks 2 and 3 remain the responsibility of the proof author and the reader, to be carried out and verified manually. This is the most important framing point for understanding ProofFrog's scope: it checks the structural validity of a game sequence, not the tightness or appropriateness of the resulting security bound.

---

## Design Choices

ProofFrog's design reflects a set of deliberate choices about where to trade expressivity for simplicity.

### AST-level rather than logical

Existing tools such as EasyCrypt work at the level of logical formulae over probabilistic relational Hoare logic. ProofFrog instead treats games as abstract syntax trees (ASTs) and verifies game equivalence using techniques drawn from compiler design and static analysis. The engine takes pairs of game ASTs, applies a fixed-point pipeline of transformations, and compares the resulting canonical forms.

This is a deliberate trade-off. Probabilistic relational Hoare logic is strictly more expressive: it can reason about a wider class of programs and a wider class of equivalences. The AST-level approach gives up some of that expressivity in exchange for a degree of automation that is difficult to achieve at the logical level, and in exchange for a representation that closely matches how a cryptographer thinks about game code on paper.

### Canonicalization, not explicit rewriting

The user does not direct proof-search. The engine runs a fixed-point canonicalization pipeline and compares the resulting canonical forms. If the canonical forms are structurally identical (up to variable renaming), the games are interchangeable. For cases where canonical forms differ only in branch conditions, the engine invokes an SMT solver (Z3) to check logical equivalence of those conditions.

This matches the intuition behind a typical pen-and-paper "obviously the same" argument: the proof author does not spell out every algebraic step; they rely on the reader to see that two pieces of code are equivalent after routine simplification. ProofFrog automates that routine simplification. The full list of transformations in the canonicalization pipeline is described in the Engine Internals page.

### User-supplies-reductions, not reduction search

ProofFrog verifies user-written reductions; it does not search for them. The proof author specifies the game sequence, writes the reductions that justify reduction-based hops, and ProofFrog checks that the required interchangeability conditions hold. Reduction search is not attempted. This keeps the engine tractable and keeps proofs readable: every reduction in a ProofFrog proof is an explicit, human-authored artifact, not a certificate emitted by an automated procedure that the user must then inspect.

### C/Java-like imperative syntax

The FrogLang DSL is designed to look like pen-and-paper cryptographic pseudocode, using the conventions of Rosulek's *The Joy of Cryptography*. Games are written with explicit `Initialize` methods, oracle bodies, and field declarations. A proof from that textbook can typically be transcribed into ProofFrog syntax with minimal structural changes. The proof file lists a `let:` block for variable and scheme declarations, an `assume:` block for security assumptions, a `theorem:` block for the statement to be proved, and a `games:` block for the game sequence. Each entry in the `games:` block is either a single game or a reduction composed with a game.

The syntax also supports bounded induction for hybrid arguments: ProofFrog verifies the validity of each hop within the induction and checks both boundary conditions.

---

## Positioning Relative to Other Tools

**EasyCrypt** uses an imperative language for specifying games together with a formula language for expressing probabilistic relational Hoare logic judgments. Proofs are written using a tactic language that navigates the program and applies logical rules to the formula being proved. EasyCrypt is very expressive and can handle a wide class of general statements; the cost is complexity. Tactic-level reasoning operates at a fine granularity, and proofs can be difficult to read without stepping through them interactively, because the formula each tactic is being applied to is not always apparent from the static proof text.

**CryptoVerif** takes the opposite approach: rather than maximizing expressivity, it prioritizes automation. Games are specified in a process calculus syntax. Proofs can often be discovered automatically, but CryptoVerif also supports an interactive mode where a user can explicitly direct which game transformations to apply when the automatic search fails. Security properties are expressed as internal logical formulae, verified by an internal equational prover rather than by the user directly.

Beyond these two, the computer-aided cryptography space includes a number of other tools. EasyUC formalizes universal composability within EasyCrypt. FCF (Foundational Cryptography Framework) and SSProve both use the Rocq proof assistant: FCF encodes a probabilistic programming language directly, while SSProve formalizes state-separating proofs for more modular game-based arguments. Squirrel develops a higher-order logic based on the computationally complete symbolic attacker framework. CryptHol formalizes cryptographic arguments within Isabelle/HOL. Owl uses refinement types and an information-flow control type system for integrity properties. F* has been used to formalize protocols such as TLS, functioning both as a proof assistant and a general-purpose programming language.

ProofFrog's scope is narrower than any of these: it addresses only Task 1 of the game-hopping proof process and relies on AST canonicalization rather than a formally verified program logic. Its intended advantage is a shallower learning curve and a syntax close enough to pen-and-paper conventions that the gap between a textbook proof and a machine-checked one is small. ProofFrog is targeted at educational use and at cryptographers who want to experiment with machine-checked arguments before committing to the overhead of a full-scale proof assistant. For research-grade proofs with complex reductions or non-standard security definitions, EasyCrypt or CryptoVerif will be more appropriate.

For a detailed discussion of what ProofFrog cannot currently handle, see the [Limitations page]({% link manual/limitations.md %}).

---

## What ProofFrog Is and Isn't

**ProofFrog is** a tool for verifying the structural validity of a game-hopping sequence in the computational model. It checks that the sequence of games in a proof correctly starts and ends at the appropriate games, and verifies each hop as either an interchangeability-based or reduction-based hop. Interchangeability is checked by AST canonicalization: the engine applies a fixed-point pipeline of compiler-style transformations and compares canonical forms. It is written in Python, consists of approximately 5,000 lines of code, and is released under the MIT license.

**ProofFrog is not** a replacement for EasyCrypt or CryptoVerif. It does not accumulate probability bounds or track resource usage (Tasks 2 and 3 remain manual). It does not reason about computational complexity, concurrency, or side channels. Its engine does not have a formal soundness proof: the correctness of ProofFrog's transformations has not been verified against a mechanized semantics, though the eprint paper describes the intended semantics and the transformations in detail. A discussion of the soundness question is on the [Soundness page]({% link researchers/soundness.md %}).

**Lineage.** ProofFrog was built by Ross Evans, Matthew McKague, and Douglas Stebila at the University of Waterloo, building on the pygamehop framework developed by Stebila and McKague at the Queensland University of Technology. Development was supported by the Natural Sciences and Engineering Research Council of Canada under grant RGPIN-2022-03187. The full bibliography and related publications are collected on the [Publications page]({% link researchers/publications/index.md %}).
