---
title: Home
layout: home
nav_order: 1
---

<p align="center">
  <img src="prooffrog.png" alt="ProofFrog logo" width="120"/>
</p>

# ProofFrog

**A tool for checking transitions in cryptographic game-hopping proofs.**

ProofFrog verifies the validity of game hops in the reduction-based security paradigm: it checks that the starting and ending games match the security definition, and that each adjacent pair of games is either interchangeable (by code equivalence) or justified by a stated assumption. Proofs are written in FrogLang, a small C/Java-style domain-specific language designed to look like a pen-and-paper proof. ProofFrog is usable from a command line, a browser-based editor, or an MCP server for integration with AI coding assistants.

## Start here

**[Read the Manual]({% link manual/index.md %})** for installation, two tutorials, worked examples, and a complete language reference.

Or browse the [Examples]({% link examples.md %}) page for the catalogue of proofs ProofFrog can currently verify.

Researchers and contributors: see [For Researchers]({% link researchers/index.md %}) for the scientific background, engine internals, soundness story, and publications.

## Acknowledgements

ProofFrog was created by Ross Evans and Douglas Stebila, building on the pygamehop tool by Douglas Stebila and Matthew McKague. ProofFrog is open-source under the MIT License; the source is on [GitHub](https://github.com/ProofFrog/ProofFrog).

<img src="https://github.com/ProofFrog/ProofFrog/blob/main/media/NSERC.jpg?raw=true" alt="NSERC logo" width="750"/>

We acknowledge the support of the Natural Sciences and Engineering Research Council of Canada (NSERC).
