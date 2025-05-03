---
title: Design Philosophy
layout: default
nav_order: 2
---

# Design Philosophy

ProofFrog takes a novel approach in that it focuses purely on high-level manipulations of games as abstract syntax trees (ASTs) instead of working at the level of logical formulae.
Treating games as ASTs allows us to leverage techniques from compiler design
and static analysis to prove output equivalence of games; thereby allowing us to demonstrate the validity of hops in a game sequence.
The main technique used in our engine is to take pairs of game ASTs and perform a variety of transformations in an attempt to coerce each AST into a canonical form.
If each pair of ASTs in a game hop can be made equivalent, then our proof engine can assert the validity of the hop.
ProofFrog also targets ease of use: although it implements a domain-specific language that a user must learn, the language has an imperative C-like syntax that should be comfortable for the average cryptographer.
Furthermore, it performs transformations to the ASTs with little user guidance which makes writing a proof in many cases as simple as just specifying the hops.
Finally, the proof syntax attempts to mimic closely to that of a typical pen-and-paper proof.
