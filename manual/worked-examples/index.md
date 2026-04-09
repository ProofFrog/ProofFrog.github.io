---
title: Worked Examples
layout: linear
parent: Manual
nav_order: 20
has_children: true
permalink: /manual/worked-examples/
---

# Worked Examples

This page contains walkthroughs of complete ProofFrog proofs from the `examples/` directory, organized by complexity. Each example introduces ideas that the next one builds on.

If you are unfamiliar with cryptographic game hopping proofs or the the basics of ProofFrog, you should start with the [installation instructions]({% link manual/installation.md %}) and then the [tutorial]({% link manual/tutorial/index.md %}). Once you've completed the tutorial, continue on with these examples:

1. **[Chained symmetric encryption]({% link manual/worked-examples/chained-encryption.md %})**: A first proof involving reductions, showing the one-time secrecy of chained symmetric encryption: {% katex %}c_1 \leftarrow \mathsf{Enc}(k, k'); c_2 \leftarrow \mathsf{Enc}(k', m){% endkatex %}. This proof introduces the "four-step reduction pattern" for game-hopping proofs.
2. **[Chosen-plaintext attack security of hybrid public key encryption (the KEM-DEM construction)]({% link manual/worked-examples/kemdem-cpa.md %})**: This construction involves multiple primitives (symmetric encryption and public key encryption), and multiple reductions three reductions, two of them to the same assumption in opposite directions.
