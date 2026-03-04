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

ProofFrog checks the validity of transitions in game-hopping proofs — the standard technique in provable security for showing that a cryptographic scheme satisfies a security property. Proofs are written in FrogLang, a domain-specific language for defining primitives, schemes, security games, and proofs. ProofFrog is [designed]({% link design.md %}) to handle introductory-level proofs, trading expressivity and power for ease of use. The ProofFrog engine checks each hop by manipulating abstract syntax trees into a canonical form, with some help from Z3 and SymPy. ProofFrog's engine does not have any formal guarantees: the soundness of its transformations has not been verified.

ProofFrog can be used via a command-line interface, a browser-based editor, or an MCP server for integration with AI coding assistants.

## Getting Started

ProofFrog is implemented in Python (3.11+) and can be installed using `pip`:

```txt
pip install proof_frog
git clone https://github.com/ProofFrog/examples        # optionally download examples
```

See the [getting started page]({% link getting-started.md %}) for detailed installation options, the web interface, and CLI usage, or the [guide to writing proofs in ProofFrog]({% link guide.md %}).

A list of examples is given on the [Examples]({% link examples.md %}) page.

## Development

See the [GitHub repo](https://github.com/ProofFrog/ProofFrog) for source code and development information. ProofFrog is released under the MIT License.

## Publications

ProofFrog was created by Ross Evans and Douglas Stebila, building on the pygamehop tool created by Douglas Stebila and Matthew McKague. For more information about ProofFrog's design, see [Ross Evans' master's thesis](https://uwspace.uwaterloo.ca/bitstream/handle/10012/20441/Evans_Ross.pdf) and [eprint 2025/418](https://eprint.iacr.org/2025/418).

<img src="https://github.com/ProofFrog/ProofFrog/blob/main/media/NSERC.jpg?raw=true" alt="NSERC logo" width="750"/>

We acknowledge the support of the Natural Sciences and Engineering Research Council of Canada (NSERC).
