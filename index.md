---
title: Proof Frog
layout: home
nav_order: 1
---

ProofFrog is a work-in-progress tool for verifying cryptographic game-hopping proofs. All security properties in ProofFrog are written via pairs of indistinguishable games.

# Installation

ProofFrog is implemented in Python and can be installed using `pip`:

`pip install proof_frog`

The `proof_frog` CLI will then be available on your PATH.

A list of examples is given in [Examples]({% link examples.md %}) page.

For example:

```
git clone git@github.com:ProofFrog/examples.git
proof_frog prove 'examples/Proofs/SymEnc/OTUC=>OTS.proof'
```

# Development

See the [GitHub repo](https://github.com/ProofFrog/ProofFrog) for source code and development information.

# Thesis

For a very in-depth description of the inner-workings of ProofFrog, see [the accompanying thesis](https://uwspace.uwaterloo.ca/bitstream/handle/10012/20441/Evans_Ross.pdf).

A paper describing ProofFrog is available at [https://eprint.iacr.org/2025/418](https://eprint.iacr.org/2025/418).
