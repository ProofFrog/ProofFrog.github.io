---
title: HACS 20024 Exercise
layout: default
nav_order: 6
---

# HACS 2024 Exercises

In [Lúcás C. Meier's blog post](https://cronokirby.com/posts/2022/05/state-separable-proofs-for-the-curious-cryptographer/) on state separable proofs, he presents a section on hybrid arguments for state separable proofs. One can encode this proof in EasyCrypt.

First, he states that "an adversary for IND-CPA-1 can obviously break IND-CPA, since the latter allows them to make the one query they need." As a first exercise, demonstrate the contrapositive in ProofFrog. If a symmetric encryption scheme is CPA secure for multiple challenge queries, then it is also CPA secure for one challenge query.

Second, he demonstrates a hybrid argument using a reduction **R**. This is to show that "If we make Q queries in the IND-CPA game, then our advantage is only larger by a factor of Q compared to the IND-CPA-1 game". As a second exercise, demonstrate the contrapositive in ProofFrog. If a symmetric encryption scheme is CPA secure for a single challenge query, then it is also CPA secure for multiple challenge queries.

[Solutions are found here](assets/hacs.zip). I have written a SymEnc primitive, two security definitions that align with the blog post, and two proofs for each of the exercises above. You can consider using the primitives and security definitions I have already provided if you just wish to try writing a proof file.
