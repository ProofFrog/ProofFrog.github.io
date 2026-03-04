---
title: Design
layout: default
nav_order: 5
---

# Design of ProofFrog

## Philosophy

Cryptographic proofs provide theoretical guarantees on the security of constructions, but human fallibility means that even expert-reviewed proofs may hide flaws or errors.
Proof assistants are software tools built for formally verifying each step in a proof, and have the potential to prevent erroneous proofs from being published and insecure constructions from being implemented.
Unfortunately, existing tooling for verifying cryptographic proofs has found limited adoption in the cryptographic community, in part due to concerns with ease of use.

ProofFrog is a tool for verifying transitions in cryptographic game-hopping proofs.
It focuses on stating and justifying the validity of a sequence of games: verifying that the starting and ending games correctly match the security definition, and checking each hop as either an *interchangeability-based hop* (where the two adjacent games have zero distinguishing advantage, demonstrated by code equivalence) or a *reduction-based hop* (where the two adjacent games have bounded distinguishing advantage, justified by exhibiting a reduction to an assumed security property).
The accumulation of bounded advantages and the assessment of the final security bound remain tasks for the proof's author.

To check interchangeability of two games, ProofFrog manipulates abstract syntax trees (ASTs) of games to arrive at a canonical form, instead of working at the level of logical formulae.
Treating games as ASTs allows us to leverage techniques from compiler design and static analysis to prove output equivalence of games, thereby demonstrating the validity of hops in a game sequence.
The main technique used in our engine is to take pairs of game ASTs and perform a variety of transformations in an attempt to coerce the two ASTs into canonical forms, which can then be compared.
These transformations are performed on the AST with little user guidance, which makes writing a proof in many cases as simple as just specifying which reductions are being leveraged.

ProofFrog also targets ease of use: although it implements a domain-specific language that a user must learn, the language has an imperative C or Java-like syntax that should be comfortable for the average cryptographer.
The proof syntax is intentionally designed for improved readability by closely mimicking that of a typical pen-and-paper proof.
ProofFrog is aimed at an introductory audience: while its expressivity and scope are smaller than existing tools such as EasyCrypt and CryptoVerif, it prioritizes ease of use and has been able to verify game hop sequences from a wide swath of textbook-level proofs.

It is important to note that ProofFrog's engine does not have any formal guarantees: the soundness of its transformations has not been verified.

## Engine Functionality

Information about ProofFrog's engine can be found in [Ross Evans' master's thesis](https://uwspace.uwaterloo.ca/bitstream/handle/10012/20441/Evans_Ross.pdf) and [eprint 2025/418](https://eprint.iacr.org/2025/418).

A diagram summarizing ProofFrog's engine functionality is presented below.

![ProofFrog Functionality Diagram](/assets/diagram.png)

- The `InstantiationTransformer` takes parameterized ASTs and rewrites parameters in terms of variables defined inside the `let` section of the proof file.
- The `InlineTransformer` is used to inline function calls. This can happen during composition of games with reductions, or when calling a scheme method from within a game's oracle.
- "Tuple Expansion" takes tuples where the indices for all reads and writes can be statically determined, and rewrites them as multiple variable declarations.
- ["Copy Propagation](https://en.wikipedia.org/wiki/Copy_propagation)" removes variables that are copies of others
- "Statement Sorting" attempts to create a canonical ordering of statements within a block via a combination of depth first search and topological sorting. It also performs dead code elimination for statements that have no effect on the return value of an oracle.
- "Slice Simplification" is an advanced form of copy propagation used when one variable is a copy of another, but there is an intermediate concatenated bitstring that the variable is sliced out of
- "Symbolic Computation" takes integer variables and simplifies expressions they are used in into a simplest form via [SymPy](https://www.sympy.org/en/index.html)
- The "Remove Duplicated Fields" transformation searches each pair of fields in a game with the same type and unifies the values if it can be statically determined they share the same value throughout the game's entire lifetime
- The "Apply User Assumptions" transformation utilizes assumptions about variables that a user can specify between pair of games to simplify conditions
- "Apply Branch Elimination" takes branches where the conditions are `true` or `false` and simplifies them
- "Remove Unnecessary Fields" deletes any fields that do not affect the return value of any oracle
- "Canonicalize Returns" takes return statements that return variables and (when the value of the variable can be statically determined) rewrite them to return that variable
- "Collapse Branches" takes adjacent if/else-if branches with identical blocks of code and rewrites them into one branch where the condition is the OR of the previous two conditions
- "Simplify Not Operations" just takes `!(a == b)` and rewrites it to `a != b`
- "Simplify Tuple Copies" takes tuples of the form `[a[0], a[1], ..., a[n-1]]` and rewrites them into just `a`
- "Remove Unreachable Code" attempts to use [Z3](https://github.com/Z3Prover/z3) to determine when a return statement is guaranteed to have executed, and deletes all code remaining in an oracle past that point
- Normalization of field and variable names just assigns each field a numeric name based on the first appearance in the AST.
