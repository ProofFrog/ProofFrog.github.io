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

ProofFrog checks the validity of game hops for cryptographic game-hopping proofs in the reduction-based security paradigm: it checks that the starting and ending games match the security definition, and that each adjacent pair of games is either interchangeable (by code equivalence) or justified by a stated assumption. Proofs are written in FrogLang, a small C/Java-style domain-specific language designed to look like a pen-and-paper proof. ProofFrog is usable from a command line, a browser-based editor, or an MCP server for integration with AI coding assistants. ProofFrog is suitable for introductory level proofs, but is not as expressive for advanced concepts as other verification tools like EasyCrypt.

## Getting started

**[Read the manual]({% link manual/index.md %})** for [installation]({% link manual/installation.md %}), [tutorials]({% link manual/tutorial/index.md %}), [worked examples]({% link manual/worked-examples/index.md %}), and a complete [language reference]({% link manual/language-reference/index.md %}).

**[Browse the examples page]({% link examples.md %})** for a catalogue of proofs ProofFrog can currently analyze.

**Researchers**: see [the research section of this website]({% link researchers/index.md %}) for the scientific background, engine internals, soundness story, publications, and links to presentations/demos from past events.

Checking your first proof is as easy as:

```bash
pip install proof_frog
git clone https://github.com/ProofFrog/examples
proof_frog prove examples/Proofs/PubEnc/KEMDEMCPA.proof
```

See the [installation instructions]({% link manual/installation.md %}) for details.

## Participate on GitHub

[ProofFrog's GitHub site](https://github.com/ProofFrog) is the place to go to download the ProofFrog source code and examples, [ask questions](https://github.com/orgs/ProofFrog/discussions), and contribute issues or pull requests.

## Recent updates

- Mar. 6, 2026: [ProofFrog discussions and demos at HACS 2026](http://prooffrog.github.io/researchers/presentations/hacs-2026/)
- **Mar. 5, 2026: Release of [ProofFrog version 0.3.1](https://github.com/ProofFrog/ProofFrog/releases/tag/v0.3.1)** featuring a web interface and engine updates

## Acknowledgements

ProofFrog was created by Ross Evans and Douglas Stebila, building on the pygamehop tool by Douglas Stebila and Matthew McKague. ProofFrog is open-source under the MIT License; the source code is available on [GitHub](https://github.com/ProofFrog/ProofFrog).

We acknowledge the support of the Natural Sciences and Engineering Research Council of Canada (NSERC).

<img src="https://github.com/ProofFrog/ProofFrog/blob/main/media/NSERC.jpg?raw=true" alt="NSERC logo" style="max-width: 500px;" />
