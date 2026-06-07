---
title: Examples
layout: default
nav_order: 3
---

# Examples Catalogue
{: .no_toc }

The [ProofFrog/examples](https://github.com/ProofFrog/examples) repository contains a growing collection of cryptographic proofs verified by ProofFrog. This page organizes them by topic.

- <span class="label label-green">Beginner</span> denotes a proof that is a good starting point for learning ProofFrog
- <span class="label label-purple">Rich example</span> denotes a substantial proof with multiple hops or techniques

---

- TOC
{:toc}

---

## Joy of Cryptography (MIT Press Edition)

The [`examples/joy`](https://github.com/ProofFrog/examples/tree/main/joy) directory contains ProofFrog formulations of constructions from Chapters 1 and 2 of [The Joy of Cryptography](https://joyofcryptography.com/) by Mike Rosulek. These are designed to be read alongside the textbook and are the best place to start learning ProofFrog.

| Proof | Description | |
|:------|:------------|-|
| [OTPCorrectness](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch1/OTPCorrectness.proof) | [One-time pad](https://github.com/ProofFrog/examples/blob/main/joy/Schemes/SymEnc/OTP.scheme) is [correct](https://github.com/ProofFrog/examples/blob/main/joy/Games/SymEnc/Correctness.game) (Claim 1.2.3) | <span class="label label-green">Beginner</span> |
| [OTPSecure](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch2/OTPSecure.proof) | [One-time pad](https://github.com/ProofFrog/examples/blob/main/joy/Schemes/SymEnc/OTP.scheme) has [one-time secrecy](https://github.com/ProofFrog/examples/blob/main/joy/Games/SymEnc/OneTimeSecrecy.game) (Example 2.5.4) | <span class="label label-green">Beginner</span> |
| [OTPSecureLR](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch2/OTPSecureLR.proof) | [One-time pad](https://github.com/ProofFrog/examples/blob/main/joy/Schemes/SymEnc/OTP.scheme) has [left-or-right one-time secrecy](https://github.com/ProofFrog/examples/blob/main/joy/Games/SymEnc/OneTimeSecrecyLR.game) | <span class="label label-green">Beginner</span> |
| [ChainedEncryptionSecure](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch2/ChainedEncryptionSecure.proof) | [Chained encryption](https://github.com/ProofFrog/examples/blob/main/joy/Schemes/SymEnc/ChainedEncryption.scheme) has [one-time secrecy](https://github.com/ProofFrog/examples/blob/main/joy/Games/SymEnc/OneTimeSecrecy.game) (Claim 2.6.2) | <span class="label label-green">Beginner</span> |
{: .table-labels }

**Joy of Cryptography exercises**. The [README file about the Joy of Cryptography examples](https://github.com/ProofFrog/examples/tree/main/joy#exercises) also lists exercises from Chapter 2 that are doable in ProofFrog — try them yourself! Solutions are not publicly available, but instructors can contact Douglas Stebila to obtain a copy.

---

## Symmetric Encryption

### Security notion implications

| Proof | Description | |
|:------|:------------|-|
| [INDOT$_implies_INDOT](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/INDOT%24_implies_INDOT.proof) | [IND-OT$](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT%24.game) implies [IND-OT](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT.game) | <span class="label label-green">Beginner</span> |
| [INDCPA$_MultiChal_implies_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/INDCPA%24_MultiChal_implies_INDCPA_MultiChal.proof) | [IND-CPA$ (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCPA%24_MultiChal.game) security implies [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCPA_MultiChal.game) security |
{: .table-labels }

### Basic constructions

| Proof | Description | |
|:------|:------------|-|
| [ModOTP_INDOT](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/ModOTP_INDOT.proof) | The [modular one-time pad](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/ModOTP.scheme) ({% katex %}\mathrm{Enc}(k, m) = m + k \bmod q{% endkatex %}) has [IND-OT](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT.game) | <span class="label label-green">Beginner</span> |
{: .table-labels }

### PRF-based encryption

The [PRF-based symmetric encryption scheme](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/SymEncPRF.scheme) {% katex %}\Sigma{% endkatex %} encrypts a message {% katex %}m{% endkatex %} under key {% katex %}k{% endkatex %} by sampling a random {% katex %}r{% endkatex %} and outputting {% katex %}(r,\; F(k, r) \oplus m){% endkatex %}, where {% katex %}F{% endkatex %} is a [PRF](https://github.com/ProofFrog/examples/blob/main/Primitives/PRF.primitive).

| Proof | Description | |
|:------|:------------|-|
| [SymEncPRF_INDOT$](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDOT%24.proof) | [PRF-based symmetric encryption](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/SymEncPRF.scheme) has [IND-OT$](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT%24.game) |
| [SymEncPRF_INDCPA$_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/SymEncPRF_INDCPA%24_MultiChal.proof) | [PRF-based symmetric encryption](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/SymEncPRF.scheme) is [IND-CPA$ (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCPA%24_MultiChal.game) secure | <span class="label label-purple">Rich example</span> |
{: .table-labels }

### Composition of encryption schemes

Given two [symmetric encryption](https://github.com/ProofFrog/examples/blob/main/Primitives/SymEnc.primitive) schemes {% katex %}S{% endkatex %} and {% katex %}T{% endkatex %} where {% katex %}S.\mathcal{C} = T.\mathcal{M}{% endkatex %}, the [composed scheme](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/GeneralDoubleSymEnc.scheme) encrypts as {% katex %}\Sigma.\mathrm{Enc}((k_S, k_T), m) = T.\mathrm{Enc}(k_T, S.\mathrm{Enc}(k_S, m)){% endkatex %}.

| Proof | Description |
|:------|:------------|
| [INDOT$_implies_DoubleSymEnc_INDOT$](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/INDOT%24_implies_DoubleSymEnc_INDOT%24.proof) | If a scheme has [IND-OT$](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT%24.game), then [double-encrypting](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/DoubleSymEnc.scheme) with two copies of it also has IND-OT$ |
| [GeneralDoubleSymEnc_INDOT$](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/GeneralDoubleSymEnc_INDOT%24.proof) | If {% katex %}T{% endkatex %} has [IND-OT$](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT%24.game), so does {% katex %}\Sigma{% endkatex %} |
| [GeneralDoubleSymEnc_INDCPA$_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/GeneralDoubleSymEnc_INDCPA%24_MultiChal.proof) | If {% katex %}T{% endkatex %} is [IND-CPA$ (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCPA%24_MultiChal.game) secure, so is {% katex %}\Sigma{% endkatex %} |

### Authenticated encryption

| Proof | Description | |
|:------|:------------|-|
| [EncryptThenMAC_INDCCA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/EncryptThenMAC_INDCCA_MultiChal.proof) | [Encrypt-then-MAC](https://github.com/ProofFrog/examples/blob/main/Schemes/SymEnc/EncryptThenMAC.scheme) is [IND-CCA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCCA_MultiChal.game) secure | <span class="label label-purple">Rich example</span> |
{: .table-labels }

---

## Pseudorandom Generators

| Proof | Description |
|:------|:------------|
| [TriplingPRG_PRGSecurity](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRG_PRGSecurity.proof) | A [length-tripling PRG](https://github.com/ProofFrog/examples/blob/main/Schemes/PRG/TriplingPRG.scheme) built by applying a length-doubling [PRG](https://github.com/ProofFrog/examples/blob/main/Primitives/PRG.primitive) twice is [secure](https://github.com/ProofFrog/examples/blob/main/Games/PRG/PRGSecurity.game) |
| [CounterPRG_PRGSecurity](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/CounterPRG_PRGSecurity.proof) | A [counter-mode PRG](https://github.com/ProofFrog/examples/blob/main/Schemes/PRG/CounterPRG.scheme) built from a [PRF](https://github.com/ProofFrog/examples/blob/main/Primitives/PRF.primitive) is [secure](https://github.com/ProofFrog/examples/blob/main/Games/PRG/PRGSecurity.game) |

---

## Pseudorandom Functions

| Proof | Description |
|:------|:------------|
| [PRFSecurity_implies_PRFSecurity_MultiKey](https://github.com/ProofFrog/examples/blob/main/Proofs/PRF/PRFSecurity_implies_PRFSecurity_MultiKey.proof) | [Multi-key PRF security](https://github.com/ProofFrog/examples/blob/main/Games/PRF/PRFSecurity_MultiKey.game) follows from [single-key PRF security](https://github.com/ProofFrog/examples/blob/main/Games/PRF/PRFSecurity.game) via a hybrid argument |

---

## Group-Based Assumptions

These proofs establish implications between Diffie–Hellman-type assumptions.

| Proof | Description |
|:------|:------------|
| [DDH_implies_CDH](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDH_implies_CDH.proof) | [DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDH.game) implies [CDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/CDH.game) |
| [DDH_implies_HashedDDH](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDH_implies_HashedDDH.proof) | [DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDH.game) implies [Hashed DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/HashedDDH.game) (standard model) |
| [CDH_implies_HashedDDH](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/CDH_implies_HashedDDH.proof) | [CDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/CDH.game) implies [Hashed DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/HashedDDH.game) (random oracle model) |
| [DDHMultiChal_implies_HashedDDHMultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/DDHMultiChal_implies_HashedDDHMultiChal.proof) | [DDH (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDHMultiChal.game) implies [Hashed DDH (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/Group/HashedDDHMultiChal.game) (random oracle model) |
| [GapCDH_implies_GapCDH_NZ](https://github.com/ProofFrog/examples/blob/main/Proofs/Group/GapCDH_implies_GapCDH_NZ.proof) | [gap-CDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/GapCDH.game) implies its [non-zero-exponent variant](https://github.com/ProofFrog/examples/blob/main/Games/Group/GapCDH_NZ.game) (used as a lemma in the Hashed ElGamal KEM proof) |

---

## Public-Key Encryption

### Security notion implications

| Proof | Description |
|:------|:------------|
| [INDCPA_implies_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/INDCPA_implies_INDCPA_MultiChal.proof) | [IND-CPA](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA.game) implies [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_MultiChal.game) for [public-key encryption](https://github.com/ProofFrog/examples/blob/main/Primitives/PubKeyEnc.primitive) |

### ElGamal

| Proof | Description |
|:------|:------------|
| [ElGamal_Correctness](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/ElGamal_Correctness.proof) | [ElGamal](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/ElGamal.scheme) encryption is [correct](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/Correctness.game) |
| [ElGamal_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/ElGamal_INDCPA_MultiChal.proof) | [ElGamal](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/ElGamal.scheme) is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_MultiChal.game) secure under [DDH (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDHMultiChal.game) |
| [HashedElGamal_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HashedElGamal_INDCPA_MultiChal.proof) | [Hashed ElGamal](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/HashedElGamal.scheme) is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_MultiChal.game) secure under [Hashed DDH (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/Group/HashedDDHMultiChal.game) (standard model) |
| [HashedElGamal_INDCPA_ROM_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HashedElGamal_INDCPA_ROM_MultiChal.proof) | [Hashed ElGamal](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/HashedElGamal.scheme) is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_ROM_MultiChal.game) secure under [DDH (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDHMultiChal.game) (random oracle model) |

### Hybrid public-key encryption

| Proof | Description | |
|:------|:------------|-|
| [HybridKEMDEM_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HybridKEMDEM_INDCPA_MultiChal.proof) | [KEM-DEM](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/HybridKEMDEM.scheme) hybrid public-key encryption is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_MultiChal.game) secure | <span class="label label-purple">Rich example</span> |
| [HybridPKEDEM_INDCPA_MultiChal](https://github.com/ProofFrog/examples/blob/main/Proofs/PubKeyEnc/HybridPKEDEM_INDCPA_MultiChal.proof) | [PKE+SymEnc](https://github.com/ProofFrog/examples/blob/main/Schemes/PubKeyEnc/HybridPKEDEM.scheme) hybrid public-key encryption is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/INDCPA_MultiChal.game) secure | <span class="label label-purple">Rich example</span> |
{: .table-labels }

### KEM constructions

The [KEMPRF](https://github.com/ProofFrog/examples/blob/main/Schemes/KEM/KEMPRF.scheme) construction derives the shared secret by applying a [PRF](https://github.com/ProofFrog/examples/blob/main/Primitives/PRF.primitive) to the underlying [KEM](https://github.com/ProofFrog/examples/blob/main/Primitives/KEM.primitive)'s shared secret and ciphertext: {% katex %}\mathit{ss'} = F(k_F, \mathit{ss} \| c){% endkatex %}.

| Proof | Description | |
|:------|:------------|-|
| [KEMPRF_Correctness](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/KEMPRF_Correctness.proof) | [KEMPRF](https://github.com/ProofFrog/examples/blob/main/Schemes/KEM/KEMPRF.scheme) is [correct](https://github.com/ProofFrog/examples/blob/main/Games/KEM/Correctness.game) |
| [KEMPRF_INDCPA](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/KEMPRF_INDCPA.proof) | [KEMPRF](https://github.com/ProofFrog/examples/blob/main/Schemes/KEM/KEMPRF.scheme) is [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/KEM/INDCPA_MultiChal.game) secure |
| [KEMPRF_INDCCA](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/KEMPRF_INDCCA.proof) | [KEMPRF](https://github.com/ProofFrog/examples/blob/main/Schemes/KEM/KEMPRF.scheme) is [IND-CCA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/KEM/INDCCA_MultiChal.game) secure | <span class="label label-purple">Rich example</span> |
| [HashedElGamalKEM_INDCCA](https://github.com/ProofFrog/examples/blob/main/Proofs/KEM/HashedElGamalKEM_INDCCA.proof) | The [Hashed ElGamal KEM](https://github.com/ProofFrog/examples/blob/main/Schemes/KEM/HashedElGamalKEM.scheme) is [IND-CCA (multi-challenge, ROM)](https://github.com/ProofFrog/examples/blob/main/Games/KEM/INDCCA_MultiChal_ROM.game) secure under [gap-CDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/GapCDH.game) in the random oracle model | <span class="label label-purple">Rich example</span> |
{: .table-labels }

---

## Research Applications

### CFRG Hybrid KEM Combiners (draft-irtf-cfrg-hybrid-kems-10)

A ProofFrog formalization of the four hybrid PQ/T KEM combiners specified in the IRTF CFRG draft [*Hybrid PQ/T Key Encapsulation Mechanisms*](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hybrid-kems-10). Each framework combines a post-quantum KEM with a "traditional" component — either another KEM or a nominal group — via a key-derivation function: **UG** and **CG** use a nominal group, **UK** and **CK** use a second KEM; **U**(niversal) and **C**(2PRI) name the two combiner constructions. Each is modelled in two variants (a seed-form matching the draft's primary definition and an expanded-form cache), giving machine-checked proofs of correctness, IND-CCA security (for both the post-quantum and traditional branches), and the LEAK-BIND and HON-BIND binding properties.

This case study motivated much of the new lazy-map random-oracle and group-exponent machinery in the 0.5.0 engine. The [full README](https://github.com/ProofFrog/examples/blob/main/applications/cfrg-hybrid-kems/README.md) documents the modelling choices, the mapping from draft sections to files, and the assumptions each proof relies on (including important caveats about implicit rejection and the absence of a quantum-attacker model).

See the [`applications/cfrg-hybrid-kems/`](https://github.com/ProofFrog/examples/tree/main/applications/cfrg-hybrid-kems) directory for all scheme definitions, games, and proofs.

### KEM Combiner (GHP18)

A ProofFrog formalization of the [KEM combiner](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/KEMCombiner.scheme) from Giacon, Heuer, and Poettering ([PKC 2018](https://eprint.iacr.org/2018/024)). The combiner encapsulates with two KEMs independently, obtaining {% katex %}(\mathit{ss}_1, c_1){% endkatex %} and {% katex %}(\mathit{ss}_2, c_2){% endkatex %}, then derives the combined shared secret as {% katex %}\mathit{ss} = F(\mathit{ss}_1, \mathit{ss}_2, \mathit{pk}_1 \| c_1 \| \mathit{pk}_2 \| c_2){% endkatex %} using a [two-key PRF](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/TwoKeyPRF.primitive) {% katex %}F{% endkatex %}. The combined KEM is secure as long as **at least one** of the component KEMs is secure.

See the [full README](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/README.md) for construction details and a list of all files.

| Proof | Description | |
|:------|:------------|-|
| [GHP18_Correctness](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/GHP18_Correctness.proof) | The [KEM combiner](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/KEMCombiner.scheme) is correct |
| [GHP18_INDCPA1](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/GHP18_INDCPA1.proof) | [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/KEM/INDCPA_MultiChal.game) security from security of the first component KEM | <span class="label label-purple">Rich example</span> |
| [GHP18_INDCPA2](https://github.com/ProofFrog/examples/blob/main/applications/KEMCombiner-GHP18/GHP18_INDCPA2.proof) | [IND-CPA (multi-challenge)](https://github.com/ProofFrog/examples/blob/main/Games/KEM/INDCPA_MultiChal.game) security from security of the second component KEM | <span class="label label-purple">Rich example</span> |
{: .table-labels }

---

## Proof Ladders

The [Proof Ladders project](https://proof-ladders.github.io/) includes an example showing CPA security of KEM-DEM in both [ProofFrog](https://github.com/proof-ladders/asymmetric-ladder/tree/main/kemdem/ProofFrog) and [EasyCrypt](https://github.com/proof-ladders/asymmetric-ladder/tree/main/kemdem/EasyCrypt), which is helpful for seeing how proofs in ProofFrog compare to proofs in more advanced formal verification tools like EasyCrypt.  Note that that version of the ProofFrog KEM-DEM proof uses a slightly different formulation compared to the example linked earlier on this page.

---

## Old Joy of Cryptography Exercises (PDF Preview Edition)

The [`examples/joy_old`](https://github.com/ProofFrog/examples/tree/main/joy_old) directory contains ProofFrog proofs of selected exercises from the older PDF preview edition of [The Joy of Cryptography](https://joyofcryptography.com/). These use an older syntax; for new work, prefer the examples in [`examples/joy`](https://github.com/ProofFrog/examples/tree/main/joy) above.

| Exercise | Description | Proof |
|----------|-------------|-------|
| Claim 2.13 | Double one-time pad has OTUC | [2_13](https://github.com/ProofFrog/examples/blob/main/joy_old/2/2_13.proof) |
| Claim 5.4 | Pseudo one-time pad has OTUC | [5_3](https://github.com/ProofFrog/examples/blob/main/joy_old/5/5_3.proof) |
| Exercise 2.13 | One-time secrecy of the double symmetric encryption scheme | [2_13](https://github.com/ProofFrog/examples/blob/main/joy_old/2_Exercises/2_13.proof) |
| Exercise 2.14 | Alternative characterization of one-time secrecy | [forward](https://github.com/ProofFrog/examples/blob/main/joy_old/2_Exercises/2_14_Forward.proof), [backward](https://github.com/ProofFrog/examples/blob/main/joy_old/2_Exercises/2_14_Backward.proof) |
| Exercise 2.15 | Another alternative characterization of one-time secrecy | [forward](https://github.com/ProofFrog/examples/blob/main/joy_old/2_Exercises/2_15_Forward.proof), [backward](https://github.com/ProofFrog/examples/blob/main/joy_old/2_Exercises/2_15_Backward.proof) |
| Exercise 5.8 | Security of PRG constructions | [a](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_8_a.proof), [b](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_8_b.proof), [e](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_8_e.proof), [f](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_8_f.proof); also [Pseudo-OTP OTUC](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_8_PseudoOTP_OTUC.proof) |
| Exercise 5.10 | Security of a PRG construction | [5_10](https://github.com/ProofFrog/examples/blob/main/joy_old/5_Exercises/5_10.proof) |
| Exercise 7.13 | Alternative characterization of CPA security | [forward](https://github.com/ProofFrog/examples/blob/main/joy_old/7_Exercises/7_13_Forward.proof), [backward](https://github.com/ProofFrog/examples/blob/main/joy_old/7_Exercises/7_13_Backward.proof) |
| Exercise 9.6 | CCA$ security implies CCA security | [9_6](https://github.com/ProofFrog/examples/blob/main/joy_old/9_Exercises/9_6_CCA%24impliesCCA.proof) |

---

## External Uses of ProofFrog

A list of external projects and papers using ProofFrog is maintained on the [external uses page]({% link researchers/external-uses.md %}).
