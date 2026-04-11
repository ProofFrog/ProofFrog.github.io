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

If you are unfamiliar with cryptographic game hopping proofs or the the basics of ProofFrog, you should start with the [installation instructions]({% link manual/installation.md %}) and then the [tutorial]({% link manual/tutorial/index.md %}). Once you've completed the tutorial, continue on with the examples below.

## General strategies

Before diving into specific examples, here are some practical strategies that apply to most ProofFrog proofs.

**Build proofs incrementally.** Start with the `let:`, `assume:`, and `theorem:` sections. Then add the first and last game steps (the two sides of the theorem's security property). Fill in intermediate hops and reductions one at a time, running `proof_frog prove` after each change to see which hops pass. This makes it much easier to isolate problems.

**Exploit symmetric proof structure.** Many proofs are symmetric around a midpoint. The first half transitions from the theorem's Left (or Real) game toward a "neutral" middle where all cryptographic operations have been replaced by randomness. The second half mirrors the same steps in reverse, transitioning from the middle to the Right (or Random) game. When planning a proof, sketch the midpoint game first and then work outward in both directions.

**Use helper assumptions and cryptographic assumptions.** Cryptographic game hopping proofs naturally use hardness assumptions about specific primitives (such as PRG security or the decisional Diffie-Hellman assumption). You may also find it helpful to use helper assumptions (available in the [`Games/Helpers/`](https://github.com/ProofFrog/examples/tree/main/Games/Helpers/) directory) that capture basic probabilistic facts (for example, about sampling with replacement versus without) or enable other proof strategies (such as ROM programming).

## Examples

1. **[Chained symmetric encryption]({% link manual/worked-examples/chained-encryption.md %})**: A first proof involving reductions, showing the one-time secrecy of chained symmetric encryption: {% katex %}c_1 \leftarrow \mathsf{Enc}(k, k'); c_2 \leftarrow \mathsf{Enc}(k', m){% endkatex %}. This proof introduces the "four-step reduction pattern" for game-hopping proofs.
2. **[Chosen-plaintext attack security of hybrid public key encryption (the KEM-DEM construction)]({% link manual/worked-examples/kemdem-cpa.md %})**: This construction involves multiple primitives (symmetric encryption and public key encryption), and multiple reductions three reductions, two of them to the same assumption in opposite directions.
