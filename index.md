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

ProofFrog checks the validity of game hops for cryptographic game-hopping proofs in the reduction-based security paradigm: it checks that the starting and ending games match the security definition, and that each adjacent pair of games is either interchangeable (by code equivalence) or justified by a stated assumption. Proofs are written in FrogLang, a small C/Java-style domain-specific language designed to look like a pen-and-paper proof. ProofFrog is usable from a command line, a browser-based editor, or an MCP server for integration with AI coding assistants.

## Getting started

**[Read the manual]({% link manual/index.md %})** for installation, tutorials, worked examples, and a complete language reference.

**[Browse the examples page]({% link examples.md %})** for a catalogue of proofs ProofFrog can currently verify.

Researchers and contributors: see [the research section of this website]({% link researchers/index.md %}) for the scientific background, engine internals, soundness story, publications, and links to presentations/demos from past events.

## Acknowledgements

ProofFrog was created by Ross Evans and Douglas Stebila, building on the pygamehop tool by Douglas Stebila and Matthew McKague. ProofFrog is open-source under the MIT License; the source code is available on [GitHub](https://github.com/ProofFrog/ProofFrog).

We acknowledge the support of the Natural Sciences and Engineering Research Council of Canada (NSERC).

<img src="https://github.com/ProofFrog/ProofFrog/blob/main/media/NSERC.jpg?raw=true" alt="NSERC logo" style="max-width: 500px;" />

