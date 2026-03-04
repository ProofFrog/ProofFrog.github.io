---
title: Examples
layout: default
nav_order: 4
---

# Examples

Below are a list of examples that ProofFrog can currently verify.
Many are adapted from [The Joy of Cryptography](https://joyofcryptography.com/).
In such cases, we will indicate which claim in the textbook is being proved. References and examples are from the old PDF preview version, and need to be updated to the final print edition.

## One-Time Uniform Ciphertexts implies One-Time Secrecy

This proves [Theorem 2.15](https://joyofcryptography.com/pdf/book.pdf#page=49).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/OTUCimpliesOTS.proof).

## CPA$ Security implies CPA Security

This proves [Claim 7.3](https://joyofcryptography.com/pdf/book.pdf#page=145).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/CPA%24impliesCPA.proof).

## Composing Two Symmetric Encryption Schemes for One-Time Uniform Ciphertexts

This proof analyzes a symmetric encryption scheme {% katex %}\Sigma{% endkatex %} that composes two symmetric encryption schemes {% katex %}S{% endkatex %} and {% katex %}T{% endkatex %} where {% katex %}S.C = T.M{% endkatex %}, and
{% katex display %}
\Sigma.\mathrm{KeyGen}() = (S.\mathrm{KeyGen()}, T.\mathrm{KeyGen()})
{% endkatex %}
{% katex display %}
\Sigma.\mathrm{Enc}((k_S, k_T), m) = T.\mathrm{Enc}(k_T, S.\mathrm{Enc}(k_S, m))
{% endkatex %}
{% katex display %}
\Sigma.\mathrm{Dec}((k_S, k_T), c) = S.\mathrm{Dec}(k_S, T.\mathrm{Dec}(k_T, c))
{% endkatex %}

If {% katex %}T{% endkatex %} has one-time uniform ciphertexts, then so does {% katex %}\Sigma{% endkatex %}. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/GeneralDoubleOTUC.proof).

## OTUC implies Double OTUC

If a symmetric encryption scheme has one-time uniform ciphertexts, then the double encryption scheme (composing two copies of it) also has one-time uniform ciphertexts. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/OTUCimpliesDoubleOTUC.proof).

## Composing Two Symmetric Encryption Schemes for CPA$ security

This proof analyzes the same encryption scheme {% katex %}\Sigma{% endkatex %} as in the prior heading. If {% katex %}T{% endkatex %} is CPA$ secure, then so is {% katex %}\Sigma{% endkatex %}. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/DoubleCPA%24.proof).

## Double One-Time Pad has One-Time Uniform Ciphertexts

This proves [Claim 2.13](https://joyofcryptography.com/pdf/book.pdf#page=45).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Book/2/2_13.proof).

## Pseudo One-Time Pad has One-Time Uniform Ciphertexts

This proves [Claim 5.4](https://joyofcryptography.com/pdf/book.pdf#page=102).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Book/5/5_3.proof).

## Pseudorandomness of a length-tripling PRG

This proves [Claim 5.5](https://joyofcryptography.com/pdf/book.pdf#page=105).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/PRG/TriplingPRGSecure.proof).

## One-Time Secrecy implies CPA Security for Public Key Encryption Schemes

This proves [Claim 15.5](https://joyofcryptography.com/pdf/book.pdf#page=273).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/OTSimpliesCPA.proof).

## KEM-DEM Hybrid Encryption is CPA secure

This proves CPA security of the hybrid public key encryption scheme constructed via the KEM-DEM paradigm, assuming CPA security of the KEM and one-time secrecy of the symmetric encryption scheme.

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/KEMDEMCPA.proof).

## Hybrid Encryption is CPA secure

This proves [Claim 15.9](https://joyofcryptography.com/pdf/book.pdf#page=279).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/Hybrid.proof).

## Encrypt-then-MAC is CCA secure

This proves [Claim 10.10](https://joyofcryptography.com/pdf/book.pdf#page=205).

The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Proofs/SymEnc/EncryptThenMACCCA.proof).

## Textbook Exercises

The following are ProofFrog proofs of exercises from [The Joy of Cryptography](https://joyofcryptography.com/).

### Exercise 2.13

One-time secrecy of the double symmetric encryption scheme. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Book/2_Exercises/2_13.proof).

### Exercise 2.14

An alternative characterization of one-time secrecy. Proved in both directions:
[forward](https://github.com/ProofFrog/examples/blob/main/Book/2_Exercises/2_14_Forward.proof) and
[backward](https://github.com/ProofFrog/examples/blob/main/Book/2_Exercises/2_14_Backward.proof).

### Exercise 2.15

Another alternative characterization of one-time secrecy. Proved in both directions:
[forward](https://github.com/ProofFrog/examples/blob/main/Book/2_Exercises/2_15_Forward.proof) and
[backward](https://github.com/ProofFrog/examples/blob/main/Book/2_Exercises/2_15_Backward.proof).

### Exercise 5.8

Security of various PRG constructions. Parts:
[a](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_8_a.proof),
[b](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_8_b.proof),
[e](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_8_e.proof),
[f](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_8_f.proof).
Also, [Pseudo-OTP has OTUC](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_8_PseudoOTP_OTUC.proof) (used in part e).

### Exercise 5.10

Security of a PRG construction. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Book/5_Exercises/5_10.proof).

### Exercise 7.13

An alternative characterization of CPA security. Proved in both directions:
[forward](https://github.com/ProofFrog/examples/blob/main/Book/7_Exercises/7_13_Forward.proof) and
[backward](https://github.com/ProofFrog/examples/blob/main/Book/7_Exercises/7_13_Backward.proof).

### Exercise 9.6

CCA$ security implies CCA security. The proof file can be found [here](https://github.com/ProofFrog/examples/blob/main/Book/9_Exercises/9_6_CCA%24impliesCCA.proof).
