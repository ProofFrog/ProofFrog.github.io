---
title: KEM-DEM CPA
layout: linear
parent: Worked Examples
grand_parent: Manual
nav_order: 2
---

# KEM-DEM Hybrid Public Key Encryption
{: .no_toc }

The [Chained Symmetric Encryption]({% link manual/worked-examples/chained-encryption.md %}) worked example used a single primitive twice, with two reductions both aimed at the same assumption.

In this worked example we examine **KEM-DEM hybrid public key encryption**, which combines a key encapsulation mechanism (KEM) {% katex %}K{% endkatex %} and a symmetric encryption scheme {% katex %}E{% endkatex %} into a public key encryption scheme {% katex %}\mathsf{KEMDEM}(K, E){% endkatex %}. To encrypt a message {% katex %}m{% endkatex %} under a public key {% katex %}\mathit{pk}{% endkatex %}, the construction encapsulates a fresh shared secret {% katex %}\mathit{ss}{% endkatex %} under {% katex %}\mathit{pk}{% endkatex %} and then uses {% katex %}\mathit{ss}{% endkatex %} as a one-time symmetric key to encrypt {% katex %}m{% endkatex %}. The ciphertext is:

{% katex display %}
(c_{\mathsf{kem}}, c_{\mathsf{sym}}) \quad \text{ where } \quad (\mathit{ss}, c_{\mathsf{kem}}) \gets K.\mathsf{Encaps}(\mathit{pk}), \quad c_{\mathsf{sym}} \gets E.\mathsf{Enc}(\mathit{ss}, m)
{% endkatex %}

We prove that {% katex %}\mathsf{KEMDEM}(K, E){% endkatex %} satisfies CPA security, assuming that {% katex %}K{% endkatex %} is CPA-secure, that {% katex %}E{% endkatex %} satisfies one-time secrecy, and that {% katex %}E{% endkatex %}'s key generation algorithm produces keys uniformly distributed over its key space. The proof uses five reductions: two to KEM CPA security (one forward, one back), two to key uniformity of {% katex %}E{% endkatex %} (one forward, one back), and one to one-time secrecy of {% katex %}E{% endkatex %} in the middle.

This worked example introduces three patterns beyond chained encryption: **multi-primitive composition** (a KEM and a SymEnc combine into a PKE), **reductions in opposite directions** (the same assumption is invoked twice, once forward and once backward), and **bridging between key distributions with a key-uniformity assumption**.

The full proof is available at [`Proofs/PubEnc/KEMDEMCPA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/KEMDEMCPA.proof).

---

- TOC
{:toc}

---

## 1. What this proves

**KEM-DEM hybrid public key encryption** is the standard construction that turns a key encapsulation mechanism (KEM) {% katex %}K{% endkatex %} and a symmetric encryption scheme {% katex %}E{% endkatex %} into a public key encryption (PKE) scheme {% katex %}\mathsf{KEMDEM}(K, E){% endkatex %}. The KEM is used to establish a per-message shared secret under the recipient's public key, and the symmetric scheme is then used to encrypt the actual message under that shared secret. The ciphertext is the pair {% katex %}(c_{\mathsf{kem}}, c_{\mathsf{sym}}){% endkatex %}. Decryption reverses this: decapsulate {% katex %}c_{\mathsf{kem}}{% endkatex %} to recover the shared secret, then symmetrically decrypt {% katex %}c_{\mathsf{sym}}{% endkatex %}. The structural requirement is {% katex %}K.\mathcal{S} \subseteq E.\mathcal{K}{% endkatex %} — the KEM's shared secret space must be a subset of the symmetric encryption scheme's key space — so that the shared secret can be used directly as a symmetric key.

The theorem proved here is: if {% katex %}K{% endkatex %} is CPA-secure, {% katex %}E{% endkatex %} has one-time secrecy, and {% katex %}E{% endkatex %}'s key generation algorithm produces uniformly distributed keys, then {% katex %}\mathsf{KEMDEM}(K,E){% endkatex %} is CPA-secure as a public key encryption scheme.

**Why the key-uniformity assumption is needed.** The `KEMDEM` scheme uses the KEM's shared secret directly as the symmetric key — it never calls `E.KeyGen()`. But the one-time secrecy game for {% katex %}E{% endkatex %} *does* call `E.KeyGen()` to sample its one-time key. So at the point where the proof wants to invoke one-time secrecy, the "symmetric key" in the current game is a uniform sample from the KEM's shared secret space (which equals {% katex %}E.\mathcal{K}{% endkatex %}), while the OTS challenger samples its key via `E.KeyGen()`. These two distributions need to be lined up before the OTS assumption can be applied. The proof does this with a **key-uniformity assumption**: a small left/right game asserting that `E.KeyGen()` is indistinguishable from uniform sampling over `E.Key`. Two extra hops — one forward, one back — bridge the gap around the one-time secrecy hop.

**Joy of Cryptography / Boneh-Shoup parallel.** The KEM-DEM construction and its CPA-security proof appear in Mike Rosulek's [Joy of Cryptography](https://joyofcryptography.com/) and as Exercise 11.9 in Boneh and Shoup's [A Graduate Course in Applied Cryptography](https://toc.cryptobook.us/). The proof here follows the same game-hopping argument described in those references: replace the real KEM shared secret with a random key (using KEM CPA), switch the ciphertext from encrypting the left message to encrypting the right message (using SymEnc one-time secrecy), and then restore the real KEM shared secret (using KEM CPA again, in the reverse direction). ProofFrog mechanically verifies each hop of this argument.

---

## 2. The primitives and the security games

This proof involves three different cryptographic primitives — symmetric encryption {% katex %}E{% endkatex %}, key encapsulation {% katex %}K{% endkatex %}, and public key encryption {% katex %}\mathsf{KEMDEM}(K,E){% endkatex %} — each with its own security game, plus a small key-uniformity game on {% katex %}E{% endkatex %}. We recall all of them before looking at the construction.

### Symmetric encryption primitive

A symmetric encryption scheme is, as in the [chained encryption worked example]({% link manual/worked-examples/chained-encryption.md %}), a triple of algorithms over a key space {% katex %}\mathcal{K}{% endkatex %}, message space {% katex %}\mathcal{M}{% endkatex %}, and ciphertext space {% katex %}\mathcal{C}{% endkatex %}:

{% katex display %}
\begin{array}{l}
\mathsf{KeyGen}: () \to \mathcal{K} \\
\mathsf{Enc}: \mathcal{K} \times \mathcal{M} \to \mathcal{C} \\
\mathsf{Dec}: \mathcal{K} \times \mathcal{C} \to \mathcal{M} \quad \text{(deterministic)}
\end{array}
{% endkatex %}

Notice that `Dec` here is total ({% katex %}\mathcal{M}{% endkatex %}, not {% katex %}\mathcal{M} \cup \{\bot\}{% endkatex %}), reflecting the simplifying assumption that decryption never fails. This is a different primitive from the one used in the chained encryption example, so it has its own file. The FrogLang primitive file is [`Primitives/NonNullableSymEnc.primitive`](https://github.com/ProofFrog/examples/blob/main/Primitives/NonNullableSymEnc.primitive):

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    deterministic Message Dec(Key k, Ciphertext c);
}
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Primitives/NonNullableSymEnc.primitive` to type-check the primitive file, or open it in the web editor and click **Type Check**.

### One-time secrecy game (left/right)

The one-time secrecy game used in this proof is phrased as a **left/right** indistinguishability game, in contrast to the **real/random** formulation used in the chained encryption worked example. The adversary submits two messages {% katex %}m_L{% endkatex %} and {% katex %}m_R{% endkatex %}, and the challenger encrypts either {% katex %}m_L{% endkatex %} (Left game) or {% katex %}m_R{% endkatex %} (Right game) under a freshly sampled key. The adversary must guess which side it is interacting with. As in any "one-time" experiment, the key is sampled fresh on every oracle call via `E.KeyGen()`:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{Left}_E.\mathsf{Eavesdrop}(m_L, m_R)} \\
k \gets E.\mathsf{KeyGen}() \\
c \gets E.\mathsf{Enc}(k, m_L) \\
\text{return } c
\end{array} \qquad
\begin{array}{l}
\underline{\mathsf{Right}_E.\mathsf{Eavesdrop}(m_L, m_R)} \\
k \gets E.\mathsf{KeyGen}() \\
c \gets E.\mathsf{Enc}(k, m_R) \\
\text{return } c
\end{array}
{% endkatex %}

The FrogLang security game file is [`Games/SymEnc/OneTimeSecrecy.game`](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/OneTimeSecrecy.game):

```prooffrog
import '../../Primitives/SymEnc.primitive';

Game Left(SymEnc E) {
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        E.Key k = E.KeyGen();
        E.Ciphertext c = E.Enc(k, mL);
        return c;
    }
}

Game Right(SymEnc E) {
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        E.Key k = E.KeyGen();
        E.Ciphertext c = E.Enc(k, mR);
        return c;
    }
}

export as OneTimeSecrecy;
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Games/SymEnc/OneTimeSecrecy.game`, or open the file in the web editor and click **Type Check**.

### Key uniformity game

The second assumption on {% katex %}E{% endkatex %} is **key uniformity**: the distribution of keys produced by `E.KeyGen()` is indistinguishable from a uniform sample over `E.Key`. This is also phrased as a left/right game, with the two sides using the two sampling methods:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{Real}_E.\mathsf{Challenge}()} \\
k \gets E.\mathsf{KeyGen}() \\
\text{return } k
\end{array} \qquad
\begin{array}{l}
\underline{\mathsf{Random}_E.\mathsf{Challenge}()} \\
k \stackrel{\$}{\leftarrow} E.\mathcal{K} \\
\text{return } k
\end{array}
{% endkatex %}

This assumption is the bridge that lets the proof cross from a "symmetric key sampled uniformly from {% katex %}E.\mathcal{K}{% endkatex %}" world to a "symmetric key generated by `E.KeyGen()`" world (which is what the OTS game uses). It will be invoked twice: once on each side of the OTS hop. The FrogLang security game file is [`Games/SymEnc/KeyUniformity.game`](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/KeyUniformity.game):

```prooffrog
import '../../Primitives/SymEnc.primitive';

Game Real(SymEnc E) {
    E.Key Challenge() {
        E.Key k = E.KeyGen();
        return k;
    }
}

Game Random(SymEnc E) {
    E.Key Challenge() {
        E.Key k <- E.Key;
        return k;
    }
}

export as KeyUniformity;
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Games/SymEnc/KeyUniformity.game`, or open the file in the web editor and click **Type Check**.

### KEM primitive

A **key encapsulation mechanism** is a triple of algorithms over a public key space {% katex %}\mathcal{PK}{% endkatex %}, secret key space {% katex %}\mathcal{SK}{% endkatex %}, ciphertext space {% katex %}\mathcal{C}{% endkatex %}, and shared secret space {% katex %}\mathcal{S}{% endkatex %}:

{% katex display %}
\begin{array}{l}
\mathsf{KeyGen}: () \to \mathcal{PK} \times \mathcal{SK} \\
\mathsf{Encaps}: \mathcal{PK} \to \mathcal{S} \times \mathcal{C} \\
\mathsf{Decaps}: \mathcal{SK} \times \mathcal{C} \to \mathcal{S} \quad \text{(deterministic)}
\end{array}
{% endkatex %}

`Encaps` produces a pair: a shared secret plus a ciphertext that travels to the recipient. `Decaps` recovers the shared secret given the ciphertext and the recipient's secret key. This version assumes that decapsulation never fails. The FrogLang primitive file is [`Primitives/KEM.primitive`](https://github.com/ProofFrog/examples/blob/main/Primitives/KEM.primitive):

```prooffrog
Primitive KEM(Set SharedSecretSpace, Set CiphertextSpace, Set PKeySpace, Set SKeySpace) {
    Set SharedSecret = SharedSecretSpace;
    Set Ciphertext = CiphertextSpace;
    Set PublicKey = PKeySpace;
    Set SecretKey = SKeySpace;

    [PublicKey, SecretKey] KeyGen();
    [SharedSecret, Ciphertext] Encaps(PublicKey pk);
    deterministic SharedSecret Decaps(SecretKey sk, Ciphertext m);
}
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Primitives/KEM.primitive`, or open the file in the web editor and click **Type Check**.

### KEM CPA game

CPA security for a KEM captures the indistinguishability of real and random shared secrets, given the corresponding KEM ciphertext. The adversary's `Initialize` call returns the public key, and it may then call a `Challenge` oracle that returns a {% katex %}(\mathit{ss}, c_{\mathsf{kem}}){% endkatex %} pair. In the `Real` game, {% katex %}\mathit{ss}{% endkatex %} is the genuine shared secret produced by encapsulation. In the `Random` game, the ciphertext is still a genuine encapsulation but the shared secret is replaced by a fresh uniform sample, completely independent of {% katex %}c_{\mathsf{kem}}{% endkatex %}:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{Initialize}()} \\
(\mathit{pk}, \mathit{sk}) \gets K.\mathsf{KeyGen}() \\
\text{return } \mathit{pk}
\end{array}
\qquad
\begin{array}{l}
\underline{\mathsf{Real}_K.\mathsf{Challenge}()} \\
(\mathit{ss}, c) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
\text{return } (\mathit{ss}, c)
\end{array}
\qquad
\begin{array}{l}
\underline{\mathsf{Random}_K.\mathsf{Challenge}()} \\
(\_, c) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
\mathit{ss} \stackrel{\$}{\leftarrow} K.\mathcal{S} \\
\text{return } (\mathit{ss}, c)
\end{array}
{% endkatex %}

(`Initialize` is shared between both sides.) The FrogLang security game file is [`Games/KEM/CPAKEM.game`](https://github.com/ProofFrog/examples/blob/main/Games/KEM/CPAKEM.game):

```prooffrog
import '../../Primitives/KEM.primitive';

Game Real(KEM K) {
    K.PublicKey pk;
    K.SecretKey sk;

    K.PublicKey Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    [K.SharedSecret, K.Ciphertext] Challenge() {
        [K.SharedSecret, K.Ciphertext] rsp = K.Encaps(pk);
        K.SharedSecret ss = rsp[0];
        K.Ciphertext ctxt = rsp[1];
        return [ss, ctxt];
    }
}

Game Random(KEM K) {
    K.PublicKey pk;
    K.SecretKey sk;

    K.PublicKey Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    [K.SharedSecret, K.Ciphertext] Challenge() {
        [K.SharedSecret, K.Ciphertext] rsp = K.Encaps(pk);
        K.SharedSecret ss <- K.SharedSecret;
        K.Ciphertext ctxt = rsp[1];
        return [ss, ctxt];
    }
}

export as CPAKEM;
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Games/KEM/CPAKEM.game`, or open the file in the web editor and click **Type Check**.

### PKE primitive

The **public key encryption** primitive is the goal of the construction: a triple of algorithms over a message space {% katex %}\mathcal{M}{% endkatex %}, ciphertext space {% katex %}\mathcal{C}{% endkatex %}, public key space {% katex %}\mathcal{PK}{% endkatex %}, and secret key space {% katex %}\mathcal{SK}{% endkatex %}:

{% katex display %}
\begin{array}{l}
\mathsf{KeyGen}: () \to \mathcal{PK} \times \mathcal{SK} \\
\mathsf{Enc}: \mathcal{PK} \times \mathcal{M} \to \mathcal{C} \\
\mathsf{Dec}: \mathcal{SK} \times \mathcal{C} \to \mathcal{M} \cup \{\bot\} \quad \text{(deterministic)}
\end{array}
{% endkatex %}

The FrogLang primitive file is [`Primitives/PubKeyEnc.primitive`](https://github.com/ProofFrog/examples/blob/main/Primitives/PubKeyEnc.primitive):

```prooffrog
Primitive PubKeyEnc(Set MessageSpace, Set CiphertextSpace, Set PKeySpace, Set SKeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set PublicKey = PKeySpace;
    Set SecretKey = SKeySpace;

    [PublicKey, SecretKey] KeyGen();
    Ciphertext Enc(PublicKey pk, Message m);
    deterministic Message? Dec(SecretKey sk, Ciphertext m);
}
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Primitives/PubKeyEnc.primitive`, or open the file in the web editor and click **Type Check**.

### PKE CPA game

The PKE CPA game is, like SymEnc one-time secrecy here, a left/right indistinguishability game. The adversary obtains the public key from `Initialize` and may call the `Challenge(mL, mR)` oracle multiple times — multi-message CPA — and each call returns either an encryption of {% katex %}m_L{% endkatex %} or an encryption of {% katex %}m_R{% endkatex %} under the long-term public key:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{Initialize}()} \\
(\mathit{pk}, \mathit{sk}) \gets E.\mathsf{KeyGen}() \\
\text{return } \mathit{pk}
\end{array}
\qquad
\begin{array}{l}
\underline{\mathsf{Left}_E.\mathsf{Challenge}(m_L, m_R)} \\
\text{return } E.\mathsf{Enc}(\mathit{pk}, m_L)
\end{array}
\qquad
\begin{array}{l}
\underline{\mathsf{Right}_E.\mathsf{Challenge}(m_L, m_R)} \\
\text{return } E.\mathsf{Enc}(\mathit{pk}, m_R)
\end{array}
{% endkatex %}

The FrogLang security game file is [`Games/PubKeyEnc/CPA.game`](https://github.com/ProofFrog/examples/blob/main/Games/PubKeyEnc/CPA.game):

```prooffrog
import '../../Primitives/PubKeyEnc.primitive';

Game Left(PubKeyEnc E) {
    E.PublicKey pk;
    E.SecretKey sk;

    E.PublicKey Initialize() {
        [E.PublicKey, E.SecretKey] k = E.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    E.Ciphertext Challenge(E.Message mL, E.Message mR) {
        return E.Enc(pk, mL);
    }
}

Game Right(PubKeyEnc E) {
    E.PublicKey pk;
    E.SecretKey sk;

    E.PublicKey Initialize() {
        [E.PublicKey, E.SecretKey] k = E.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    E.Ciphertext Challenge(E.Message mL, E.Message mR) {
        return E.Enc(pk, mR);
    }
}

export as CPA;
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Games/PubKeyEnc/CPA.game`, or open the file in the web editor and click **Type Check**.

---

## 3. The KEMDEM scheme

{% katex %}\mathsf{KEMDEM}(K, E){% endkatex %} takes a KEM {% katex %}K{% endkatex %} and a symmetric encryption scheme {% katex %}E{% endkatex %} and produces a public key encryption scheme. Its key pair is {% katex %}K{% endkatex %}'s key pair, its messages come from {% katex %}E{% endkatex %}, and its ciphertexts are pairs of a KEM ciphertext and a symmetric ciphertext. It requires {% katex %}K.\mathcal{S} \subseteq E.\mathcal{K}{% endkatex %} so that the KEM's shared secret can serve directly as a symmetric key. In the proof we will further impose equality {% katex %}K.\mathcal{S} = E.\mathcal{K}{% endkatex %} by binding both sets to the same `Set` variable in the proof's `let:` block; see §4 below.

The sets needed for the scheme definition are:

{% katex display %}
\begin{array}{l}
\mathcal{PK} = K.\mathcal{PK}, \quad \mathcal{SK} = K.\mathcal{SK}, \quad \mathcal{M} = E.\mathcal{M}, \quad \mathcal{C} = K.\mathcal{C} \times E.\mathcal{C}
\end{array}
{% endkatex %}

The algorithms comprising the scheme are:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{KeyGen}()} \\
\text{return } K.\mathsf{KeyGen}()
\end{array}
\quad
\begin{array}{l}
\underline{\mathsf{Enc}(\mathit{pk}, m)} \\
(k_{\mathsf{sym}}, c_{\mathsf{kem}}) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
c_{\mathsf{sym}} \gets E.\mathsf{Enc}(k_{\mathsf{sym}}, m) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
\quad
\begin{array}{l}
\underline{\mathsf{Dec}(\mathit{sk}, (c_{\mathsf{kem}}, c_{\mathsf{sym}}))} \\
k_{\mathsf{sym}} \gets K.\mathsf{Decaps}(\mathit{sk}, c_{\mathsf{kem}}) \\
\text{return } E.\mathsf{Dec}(k_{\mathsf{sym}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

`KeyGen` simply delegates to the KEM. `Enc` encapsulates under the public key to produce the shared secret {% katex %}k_{\mathsf{sym}}{% endkatex %} and KEM ciphertext {% katex %}c_{\mathsf{kem}}{% endkatex %}, then uses that shared secret directly as the DEM key to encrypt the message. `Dec` reverses the process. The FrogLang scheme file is [`Schemes/PubEnc/KEMDEM.scheme`](https://github.com/ProofFrog/examples/blob/main/Schemes/PubEnc/KEMDEM.scheme):

```prooffrog
import '../../Primitives/KEM.primitive';
import '../../Primitives/NonNullableSymEnc.primitive';
import '../../Primitives/PubKeyEnc.primitive';

Scheme KEMDEM(KEM K, SymEnc E) extends PubKeyEnc {
    requires K.SharedSecret subsets E.Key;

    Set Message = E.Message;
    Set Ciphertext = [K.Ciphertext, E.Ciphertext];
    Set PublicKey = K.PublicKey;
    Set SecretKey = K.SecretKey;

    [PublicKey, SecretKey] KeyGen() {
        return K.KeyGen();
    }

    Ciphertext Enc(PublicKey pk, Message m) {
        [K.SharedSecret, K.Ciphertext] x = K.Encaps(pk);
        E.Key k_sym = x[0];
        K.Ciphertext c_kem = x[1];
        E.Ciphertext c_sym = E.Enc(k_sym, m);
        return [c_kem, c_sym];
    }

    deterministic Message? Dec(SecretKey sk, Ciphertext c) {
        K.Ciphertext c_kem = c[0];
        E.Ciphertext c_sym = c[1];
        K.SharedSecret k_sym = K.Decaps(sk, c_kem);
        return E.Dec(k_sym, c_sym);
    }
}
```

{: .note }
**Try it.** From the `examples/` directory, run `proof_frog check Schemes/PubEnc/KEMDEM.scheme`, or open the file in the web editor and click **Type Check**.

The `requires K.SharedSecret subsets E.Key;` clause is an essential part of the entire construction. It states that the KEM's shared secret space must be a subset of the SymEnc's key space. Without it, the assignment `E.Key k_sym = x[0];` in `Enc` would be a type error — `x[0]` has type `K.SharedSecret`, not `E.Key`. The `requires` clause makes the subtype relationship explicit, so the type checker can accept the code.

The ciphertext type `[K.Ciphertext, E.Ciphertext]` is a tuple. In FrogLang, `[T1, T2]` is the two-component product type, and components are accessed by constant index: `c[0]` is the KEM ciphertext, `c[1]` is the symmetric ciphertext.

---

## 4. The proof structure

The `games:` block lists twelve game steps, producing eleven hops. Five of those hops are assumption hops (one per reduction); the other six are interchangeability hops verified by the engine. Conceptually the proof moves through six games, which we'll call {% katex %}\mathsf{Game}_0{% endkatex %} through {% katex %}\mathsf{Game}_5{% endkatex %}:

- {% katex %}\mathsf{Game}_0{% endkatex %} — the {% katex %}\mathsf{KEMDEM}{% endkatex %} scheme encrypting the *left* message {% katex %}m_L{% endkatex %} under the *real* KEM shared secret. This is `CPA(KD).Left` with the scheme inlined.
- {% katex %}\mathsf{Game}_1{% endkatex %} — encrypting {% katex %}m_L{% endkatex %} under a DEM key sampled *uniformly* from {% katex %}K.\mathcal{S} = E.\mathcal{K}{% endkatex %}, while the KEM ciphertext is still produced by a real `Encaps` call.
- {% katex %}\mathsf{Game}_2{% endkatex %} — encrypting {% katex %}m_L{% endkatex %} under a DEM key produced by `E.KeyGen()`.
- {% katex %}\mathsf{Game}_3{% endkatex %} — encrypting the *right* message {% katex %}m_R{% endkatex %} under a DEM key produced by `E.KeyGen()`.
- {% katex %}\mathsf{Game}_4{% endkatex %} — encrypting {% katex %}m_R{% endkatex %} under a DEM key sampled uniformly from {% katex %}K.\mathcal{S}{% endkatex %}.
- {% katex %}\mathsf{Game}_5{% endkatex %} — encrypting {% katex %}m_R{% endkatex %} under the *real* KEM shared secret. This is `CPA(KD).Right` with the scheme inlined.

Five reductions bridge these six games:

- {% katex %}R_1{% endkatex %} (KEM CPA, {% katex %}\mathsf{Game}_0 \to \mathsf{Game}_1{% endkatex %}): reduces to KEM CPA security in the **Real → Random** direction. The shared secret starts as the genuine output of `Encaps` and becomes a fresh uniform sample.
- {% katex %}R_2{% endkatex %} (KeyUniformity, {% katex %}\mathsf{Game}_1 \to \mathsf{Game}_2{% endkatex %}): reduces to key uniformity of {% katex %}E{% endkatex %} in the **Random → Real** direction. The symmetric key distribution moves from uniform over {% katex %}E.\mathcal{K}{% endkatex %} to the output of `E.KeyGen()`.
- {% katex %}R_3{% endkatex %} (OneTimeSecrecy, {% katex %}\mathsf{Game}_2 \to \mathsf{Game}_3{% endkatex %}): reduces to one-time secrecy of {% katex %}E{% endkatex %}. The encrypted message switches from {% katex %}m_L{% endkatex %} to {% katex %}m_R{% endkatex %} under a `KeyGen`-sampled key.
- {% katex %}R_4{% endkatex %} (KeyUniformity, {% katex %}\mathsf{Game}_3 \to \mathsf{Game}_4{% endkatex %}): structurally identical to {% katex %}R_2{% endkatex %} but encrypts {% katex %}m_R{% endkatex %}, and invokes key uniformity in the **Real → Random** direction.
- {% katex %}R_5{% endkatex %} (KEM CPA, {% katex %}\mathsf{Game}_4 \to \mathsf{Game}_5{% endkatex %}): structurally identical to {% katex %}R_1{% endkatex %} but encrypts {% katex %}m_R{% endkatex %}, and invokes KEM CPA in the **Random → Real** direction.

Reductions {% katex %}R_1{% endkatex %} and {% katex %}R_5{% endkatex %} both reduce to KEM CPA security, but they invoke it in opposite directions: {% katex %}R_1{% endkatex %} goes Real → Random, {% katex %}R_5{% endkatex %} goes Random → Real. Similarly {% katex %}R_2{% endkatex %} and {% katex %}R_4{% endkatex %} invoke key uniformity in opposite directions. Both directions of each assumption are valid because indistinguishability is symmetric: if no adversary can distinguish the two sides in one direction, no adversary can distinguish them in the other.

This proof file does **not** write out explicit intermediate game definitions. Each conceptual {% katex %}\mathsf{Game}_i{% endkatex %} appears in the `games:` list only as a composed form — either `AssumptionGame compose Reduction` or as an inlined side of `CPA(KD)`. The engine verifies the interchangeability hops by canonicalizing the adjacent composed forms directly. You can add these intermediate game definitions if you find it helpful; ProofFrog will check they match their neighbouring games.

The proof's `let:` block binds {% katex %}K.\mathcal{S}{% endkatex %} and {% katex %}E.\mathcal{K}{% endkatex %} to the *same* `Set` variable (`KEMSharedSecretSpace`), imposing the equality {% katex %}K.\mathcal{S} = E.\mathcal{K}{% endkatex %} that the proof relies on whenever a uniform sample from one side must match a uniform sample from the other.

---

## 5. Reduction {% katex %}R_1{% endkatex %}: Game 0 → Game 1

The first reduction adapts a {% katex %}\mathsf{CPA}(\mathsf{KEMDEM}(K,E)){% endkatex %} adversary so that it can play against a {% katex %}\mathsf{CPAKEM}(K){% endkatex %} challenger. It has no key pair of its own — all key material comes from the challenger. Its `Challenge` oracle delegates to `challenger.Challenge()` to obtain a {% katex %}(k_{\mathsf{sym}}, c_{\mathsf{kem}}){% endkatex %} pair, then uses {% katex %}k_{\mathsf{sym}}{% endkatex %} as the symmetric key to encrypt the **left** message:

{% katex display %}
\begin{array}{l}
\underline{R_1.\mathsf{Challenge}(m_L, m_R)} \\
(k_{\mathsf{sym}}, c_{\mathsf{kem}}) \gets \mathsf{challenger}.\mathsf{Challenge}() \\
c_{\mathsf{sym}} \gets E.\mathsf{Enc}(k_{\mathsf{sym}}, m_L) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

Note that {% katex %}R_1{% endkatex %} has no `Initialize` method of its own: the compose machinery automatically forwards `Initialize` from the outer game to the inner `CPAKEM(K)` challenger, so the challenger's `Initialize` — which generates the KEM key pair and returns `pk` — becomes the `Initialize` of the composed game.

When the external challenger is {% katex %}\mathsf{Real}_K{% endkatex %}, {% katex %}k_{\mathsf{sym}}{% endkatex %} is the genuine shared secret produced by `Encaps`, and {% katex %}R_1 \circ \mathsf{Real}_K{% endkatex %} produces the same distribution as {% katex %}\mathsf{Game}_0{% endkatex %}: the {% katex %}\mathsf{KEMDEM}{% endkatex %} scheme encrypting {% katex %}m_L{% endkatex %} under a real shared secret. When the challenger switches to {% katex %}\mathsf{Random}_K{% endkatex %}, {% katex %}k_{\mathsf{sym}}{% endkatex %} becomes a uniformly random sample from {% katex %}K.\mathcal{S}{% endkatex %}, independent of {% katex %}c_{\mathsf{kem}}{% endkatex %}, and {% katex %}R_1 \circ \mathsf{Random}_K{% endkatex %} produces the same distribution as {% katex %}\mathsf{Game}_1{% endkatex %}.

In FrogLang:

```prooffrog
// Reduction for hop from Game 0 to Game 1
// - Reduction to CPA security of the KEM. The reduction uses the shared secret
//   from the KEM CPA challenger, which is either real (= Game 0) or random (= Game 1).
Reduction R1(SymEnc E, KEM K, KEMDEM KD) compose CPAKEM(K) against CPA(KD).Adversary {
    KD.Ciphertext Challenge(KD.Message mL, KD.Message mR) {
        [K.SharedSecret, K.Ciphertext] y = challenger.Challenge();
        K.SharedSecret k_sym = y[0];
        K.Ciphertext c_kem = y[1];
        E.Ciphertext c_sym = E.Enc(k_sym, mL);
        return [c_kem, c_sym];
    }
}
```

{: .note }
**Try it.** {% katex %}R_1{% endkatex %} lives inside `KEMDEMCPA.proof` along with the rest of the proof. From the `examples/` directory, run `proof_frog prove Proofs/PubEnc/KEMDEMCPA.proof` to verify the whole proof, or open the file in the web editor and click **Run Proof**. See [§11 Verifying](#11-verifying) for the expected output.

Notice that {% katex %}R_1{% endkatex %} has no state fields: all key material lives inside the {% katex %}\mathsf{CPAKEM}(K){% endkatex %} challenger that {% katex %}R_1{% endkatex %} composes against. This contrasts with {% katex %}R_2{% endkatex %} through {% katex %}R_4{% endkatex %} below, which have to manage their own KEM key pair because they compose against a different challenger.

---

## 6. Reduction {% katex %}R_2{% endkatex %}: Game 1 → Game 2

After the assumption hop on KEM CPA, the proof is in a state where the symmetric key is a uniform sample from {% katex %}K.\mathcal{S} = E.\mathcal{K}{% endkatex %}. But the next hop — one-time secrecy of {% katex %}E{% endkatex %} — will want the symmetric key to be the output of `E.KeyGen()` instead (because that's what the OTS game's challenger does internally). So we first bridge the two distributions with a **key-uniformity** hop.

{% katex %}R_2{% endkatex %} composes against a {% katex %}\mathsf{KeyUniformity}(E){% endkatex %} challenger. It has no KEM challenger available — the {% katex %}\mathsf{CPAKEM}(K){% endkatex %} assumption was consumed in the previous hop — and so {% katex %}R_2{% endkatex %} must generate the KEM key pair itself and answer `Initialize` queries from its own state. Its `Challenge` oracle encapsulates under its own public key to produce {% katex %}c_{\mathsf{kem}}{% endkatex %} (discarding the shared secret), asks the `KeyUniformity(E)` challenger for a symmetric key, and uses that key to encrypt {% katex %}m_L{% endkatex %}:

{% katex display %}
\begin{array}{l}
\underline{R_2.\mathsf{Initialize}()} \\
(\mathit{pk}, \mathit{sk}) \gets K.\mathsf{KeyGen}() \\
\text{return } \mathit{pk}
\end{array}
\qquad
\begin{array}{l}
\underline{R_2.\mathsf{Challenge}(m_L, m_R)} \\
(\_, c_{\mathsf{kem}}) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
k_{\mathsf{sym}} \gets \mathsf{challenger}.\mathsf{Challenge}() \\
c_{\mathsf{sym}} \gets E.\mathsf{Enc}(k_{\mathsf{sym}}, m_L) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

When the `KeyUniformity(E)` challenger is in {% katex %}\mathsf{Random}{% endkatex %} mode, {% katex %}k_{\mathsf{sym}}{% endkatex %} is a uniform sample from {% katex %}E.\mathcal{K}{% endkatex %}, which equals {% katex %}K.\mathcal{S}{% endkatex %} (imposed by the proof's `let:` block). So {% katex %}R_2 \circ \mathsf{Random}{% endkatex %} matches {% katex %}\mathsf{Game}_1{% endkatex %}, which in turn matches {% katex %}R_1 \circ \mathsf{Random}_K{% endkatex %} (the closing step of the previous pattern) under canonicalization. When the challenger switches to {% katex %}\mathsf{Real}{% endkatex %} mode, {% katex %}k_{\mathsf{sym}}{% endkatex %} is the output of `E.KeyGen()`, and {% katex %}R_2 \circ \mathsf{Real}{% endkatex %} matches {% katex %}\mathsf{Game}_2{% endkatex %}.

In FrogLang:

```prooffrog
// Reduction for hop from Game 1 to Game 2
// - Reduction to key uniformity of the symmetric encryption scheme. The reduction uses
//   the symmetric key from the key uniformity challenger, which is either real (= Game 2)
//   or random (= Game 1).
Reduction R2(SymEnc E, KEM K, KEMDEM KD) compose KeyUniformity(E) against CPA(KD).Adversary {
    K.PublicKey pk;
    K.SecretKey sk;

    K.PublicKey Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    KD.Ciphertext Challenge(KD.Message mL, KD.Message mR) {
        [K.SharedSecret, K.Ciphertext] x = K.Encaps(pk);
        K.SharedSecret k_sym = challenger.Challenge();
        K.Ciphertext c_kem = x[1];
        E.Ciphertext c_sym = E.Enc(k_sym, mL);
        return [c_kem, c_sym];
    }
}
```

This is a recurring pattern in multi-primitive proofs: a reduction that targets one assumption must internally simulate every other primitive that the surrounding game depends on. {% katex %}R_2{% endkatex %} plays against a `KeyUniformity(E)` challenger but still needs a real KEM key pair — because the scheme under attack uses `K.KeyGen()` and `K.Encaps()` as part of its `Enc` algorithm — so {% katex %}R_2{% endkatex %} generates that KEM key pair in its own `Initialize`.

---

## 7. Reduction {% katex %}R_3{% endkatex %}: Game 2 → Game 3

With the DEM key now distributed as `E.KeyGen()`, the proof is ready to invoke one-time secrecy of {% katex %}E{% endkatex %}. {% katex %}R_3{% endkatex %} composes against an {% katex %}\mathsf{OneTimeSecrecy}(E){% endkatex %} challenger. Like {% katex %}R_2{% endkatex %}, it generates the KEM key pair in its own `Initialize`. Its `Challenge` oracle encapsulates to produce {% katex %}c_{\mathsf{kem}}{% endkatex %} (discarding the shared secret), and asks the `OTS(E)` challenger to produce the DEM ciphertext on either {% katex %}m_L{% endkatex %} or {% katex %}m_R{% endkatex %} under a fresh key:

{% katex display %}
\begin{array}{l}
\underline{R_3.\mathsf{Initialize}()} \\
(\mathit{pk}, \mathit{sk}) \gets K.\mathsf{KeyGen}() \\
\text{return } \mathit{pk}
\end{array}
\qquad
\begin{array}{l}
\underline{R_3.\mathsf{Challenge}(m_L, m_R)} \\
(\_, c_{\mathsf{kem}}) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
c_{\mathsf{sym}} \gets \mathsf{challenger}.\mathsf{Eavesdrop}(m_L, m_R) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

Crucially, {% katex %}R_3{% endkatex %} discards the shared secret produced by `Encaps` and lets the OTS challenger sample its own fresh DEM key via `E.KeyGen()`. When the OTS challenger is in {% katex %}\mathsf{Left}{% endkatex %} mode, the DEM ciphertext is an encryption of {% katex %}m_L{% endkatex %} under a `KeyGen`-sampled key, matching {% katex %}\mathsf{Game}_2{% endkatex %}. When the OTS challenger is in {% katex %}\mathsf{Right}{% endkatex %} mode, the DEM ciphertext is an encryption of {% katex %}m_R{% endkatex %}, matching {% katex %}\mathsf{Game}_3{% endkatex %}. This is the central hop of the whole proof — the point where the "which message is encrypted" bit actually flips.

In FrogLang:

```prooffrog
// Reduction for hop from Game 2 to Game 3
// - Reduction to one-time secrecy of the symmetric encryption scheme. The reduction uses the
//   challenger to encrypt either mL (= Game 2) or mR (= Game 3).
Reduction R3(SymEnc E, KEM K, KEMDEM KD) compose OneTimeSecrecy(E) against CPA(KD).Adversary {
    K.PublicKey pk;
    K.SecretKey sk;

    K.PublicKey Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    KD.Ciphertext Challenge(KD.Message mL, KD.Message mR) {
        [K.SharedSecret, K.Ciphertext] x = K.Encaps(pk);
        K.Ciphertext c_kem = x[1];
        E.Ciphertext c_sym = challenger.Eavesdrop(mL, mR);
        return [c_kem, c_sym];
    }
}
```

---

## 8. Reduction {% katex %}R_4{% endkatex %}: Game 3 → Game 4

The rest of the proof "undoes" the earlier distributional bridges, but on the right-message side. {% katex %}R_4{% endkatex %} is structurally identical to {% katex %}R_2{% endkatex %} but encrypts {% katex %}m_R{% endkatex %} instead of {% katex %}m_L{% endkatex %}, and the direction of the assumption flips: now the proof uses key uniformity to move *back* from "key from `E.KeyGen()`" to "key sampled uniformly from {% katex %}E.\mathcal{K}{% endkatex %}".

{% katex display %}
\begin{array}{l}
\underline{R_4.\mathsf{Initialize}()} \\
(\mathit{pk}, \mathit{sk}) \gets K.\mathsf{KeyGen}() \\
\text{return } \mathit{pk}
\end{array}
\qquad
\begin{array}{l}
\underline{R_4.\mathsf{Challenge}(m_L, m_R)} \\
(\_, c_{\mathsf{kem}}) \gets K.\mathsf{Encaps}(\mathit{pk}) \\
k_{\mathsf{sym}} \gets \mathsf{challenger}.\mathsf{Challenge}() \\
c_{\mathsf{sym}} \gets E.\mathsf{Enc}(k_{\mathsf{sym}}, m_R) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

When the `KeyUniformity(E)` challenger is in {% katex %}\mathsf{Real}{% endkatex %} mode, {% katex %}R_4 \circ \mathsf{Real}{% endkatex %} matches {% katex %}\mathsf{Game}_3{% endkatex %} (closing the OTS pattern). When the challenger switches to {% katex %}\mathsf{Random}{% endkatex %} mode, {% katex %}R_4 \circ \mathsf{Random}{% endkatex %} matches {% katex %}\mathsf{Game}_4{% endkatex %} (opening the closing KEM CPA pattern).

In FrogLang:

```prooffrog
// Reduction for hop from Game 3 to Game 4
// - Reduction to key uniformity of the symmetric encryption scheme. The reduction uses
//   the symmetric key from the key uniformity challenger, which is either real (= Game 3)
//   or random (= Game 4).
Reduction R4(SymEnc E, KEM K, KEMDEM KD) compose KeyUniformity(E) against CPA(KD).Adversary {
    K.PublicKey pk;
    K.SecretKey sk;

    K.PublicKey Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
        return pk;
    }

    KD.Ciphertext Challenge(KD.Message mL, KD.Message mR) {
        [K.SharedSecret, K.Ciphertext] x = K.Encaps(pk);
        K.SharedSecret k_sym = challenger.Challenge();
        K.Ciphertext c_kem = x[1];
        E.Ciphertext c_sym = E.Enc(k_sym, mR);
        return [c_kem, c_sym];
    }
}
```

---

## 9. Reduction {% katex %}R_5{% endkatex %}: Game 4 → Game 5

The fifth and final reduction is structurally identical to {% katex %}R_1{% endkatex %} — it lets its composed {% katex %}\mathsf{CPAKEM}(K){% endkatex %} challenger supply the key pair and the {% katex %}(k_{\mathsf{sym}}, c_{\mathsf{kem}}){% endkatex %} pair — but it encrypts {% katex %}m_R{% endkatex %} instead of {% katex %}m_L{% endkatex %}:

{% katex display %}
\begin{array}{l}
\underline{R_5.\mathsf{Challenge}(m_L, m_R)} \\
(k_{\mathsf{sym}}, c_{\mathsf{kem}}) \gets \mathsf{challenger}.\mathsf{Challenge}() \\
c_{\mathsf{sym}} \gets E.\mathsf{Enc}(k_{\mathsf{sym}}, m_R) \\
\text{return } (c_{\mathsf{kem}}, c_{\mathsf{sym}})
\end{array}
{% endkatex %}

When the KEM challenger is in {% katex %}\mathsf{Random}{% endkatex %} mode, {% katex %}k_{\mathsf{sym}}{% endkatex %} is a random shared secret and {% katex %}R_5 \circ \mathsf{Random}_K{% endkatex %} matches {% katex %}\mathsf{Game}_4{% endkatex %}. When the challenger switches to {% katex %}\mathsf{Real}_K{% endkatex %}, {% katex %}k_{\mathsf{sym}}{% endkatex %} is the genuine shared secret and {% katex %}R_5 \circ \mathsf{Real}_K{% endkatex %} matches {% katex %}\mathsf{Game}_5{% endkatex %}, which is in turn interchangeable with `CPA(KD).Right`.

This is the **Random → Real direction** of the KEM CPA assumption: the proof has finished using the random-key intermediate world and is restoring the real KEM shared secret, but on the right-message side. Both directions of the assumption are valid because indistinguishability is symmetric.

In FrogLang:

```prooffrog
// Reduction for hop from Game 4 to Game 5
// - Reduction to CPA security of the KEM. The reduction uses the shared secret
//   from the KEM CPA challenger, which is either real (= Game 5) or random (= Game 4).
Reduction R5(SymEnc E, KEM K, KEMDEM KD) compose CPAKEM(K) against CPA(KD).Adversary {
    KD.Ciphertext Challenge(KD.Message mL, KD.Message mR) {
        [K.SharedSecret, K.Ciphertext] y = challenger.Challenge();
        K.SharedSecret k_sym = y[0];
        K.Ciphertext c_kem = y[1];
        E.Ciphertext c_sym = E.Enc(k_sym, mR);
        return [c_kem, c_sym];
    }
}
```

---

## 10. The full games block

Putting all twelve game steps together, the `games:` section of `KEMDEMCPA.proof` reads:

```prooffrog
games:
    // Game 0
    CPA(KD).Left against CPA(KD).Adversary;
    CPAKEM(K).Real compose R1(E, K, KD) against CPA(KD).Adversary;
    // Game 1
    CPAKEM(K).Random compose R1(E, K, KD) against CPA(KD).Adversary;
    KeyUniformity(E).Random compose R2(E, K, KD) against CPA(KD).Adversary;
    // Game 2
    KeyUniformity(E).Real compose R2(E, K, KD) against CPA(KD).Adversary;
    OneTimeSecrecy(E).Left compose R3(E, K, KD) against CPA(KD).Adversary;
    // Game 3
    OneTimeSecrecy(E).Right compose R3(E, K, KD) against CPA(KD).Adversary;
    KeyUniformity(E).Real compose R4(E, K, KD) against CPA(KD).Adversary;
    // Game 4
    KeyUniformity(E).Random compose R4(E, K, KD) against CPA(KD).Adversary;
    CPAKEM(K).Random compose R5(E, K, KD) against CPA(KD).Adversary;
    // Game 5
    CPAKEM(K).Real compose R5(E, K, KD) against CPA(KD).Adversary;
    CPA(KD).Right against CPA(KD).Adversary;
```

The twelve entries produce eleven hops. Five are assumption hops — one per reduction — at positions 2 → 3 ({% katex %}R_1{% endkatex %}, CPAKEM Real → Random), 4 → 5 ({% katex %}R_2{% endkatex %}, KeyUniformity Random → Real), 6 → 7 ({% katex %}R_3{% endkatex %}, OneTimeSecrecy Left → Right), 8 → 9 ({% katex %}R_4{% endkatex %}, KeyUniformity Real → Random), and 10 → 11 ({% katex %}R_5{% endkatex %}, CPAKEM Random → Real). The other six transitions (1 → 2, 3 → 4, 5 → 6, 7 → 8, 9 → 10, 11 → 12) are interchangeability hops verified by the engine.

Notice how each reduction occupies two consecutive entries in the games list — one for each side of the composed assumption game — and interchangeability hops connect adjacent reductions at their conceptual boundary {% katex %}\mathsf{Game}_i{% endkatex %}. The interchangeability hop at positions 3 → 4, for example, is the engine verifying that `CPAKEM(K).Random compose R1` and `KeyUniformity(E).Random compose R2` both canonicalize to {% katex %}\mathsf{Game}_1{% endkatex %}, even though they get there via very different-looking source programs.

The full `let:`, `assume:`, and `theorem:` blocks, together with the five reductions above, complete the proof file, which you can find at [`Proofs/PubEnc/KEMDEMCPA.proof`](https://github.com/ProofFrog/examples/blob/main/Proofs/PubEnc/KEMDEMCPA.proof).

---

## 11. Verifying

{: .important }
**Activate your Python virtual environment first** if it is not already active in this terminal: `source .venv/bin/activate` on macOS/Linux (bash/zsh), `source .venv/bin/activate.fish` on fish, or `.venv\Scripts\Activate.ps1` on Windows PowerShell. See [Installation]({% link manual/installation.md %}).

From the `examples/` directory:

```bash
proof_frog prove Proofs/PubEnc/KEMDEMCPA.proof
```

Expected output:

```
Proof Succeeded!
```

The full step-by-step output shows 11 hops over 12 game steps: 6 interchangeability hops (verified by code canonicalization) and 5 assumption hops (one for each of {% katex %}R_1{% endkatex %} through {% katex %}R_5{% endkatex %}).

In the web editor, open `Proofs/PubEnc/KEMDEMCPA.proof` and click **Run Proof**. The output panel turns green with the same step-by-step report.

---

## 12. Lessons learned

- **Multi-primitive composition.** The proof reasons about three distinct primitives simultaneously — a KEM, a SymEnc, and a PKE — each with its own security game and its own type namespace. Reductions must carefully distinguish which primitive's methods and sets they are invoking. The `requires` clause on the scheme is what makes the types align across primitive boundaries.

- **Reductions in opposite directions.** {% katex %}R_1{% endkatex %} and {% katex %}R_5{% endkatex %} both reduce to the same underlying assumption ({% katex %}\mathsf{CPAKEM}(K){% endkatex %}), but {% katex %}R_1{% endkatex %} invokes it in the Real → Random direction and {% katex %}R_5{% endkatex %} invokes it in the Random → Real direction. Similarly, {% katex %}R_2{% endkatex %} and {% katex %}R_4{% endkatex %} invoke key uniformity in opposite directions. Both directions are valid because indistinguishability is symmetric. This "go-and-come-back" pattern often comes up in security proofs: here we use the KEM assumption to move into a world with a random key, do the message-switching argument, then use the same KEM assumption to move back out. Neither direction is privileged; the same security game serves both roles.

- **Bridging distributions with a key-uniformity assumption.** The `KEMDEM` scheme never calls `E.KeyGen()` — it uses the KEM's shared secret directly as the symmetric key — while the one-time secrecy game for {% katex %}E{% endkatex %} *does* call `E.KeyGen()`. These two key distributions aren't always identical, so the proof needs a key-uniformity assumption (that "`E.KeyGen()` *is* indistinguishable from uniform sampling over `E.Key`") to bridge them. The bridge is invoked symmetrically — once on each side of the OTS hop — which is why there are five reductions instead of three.

- **Generic construction parameter handling.** The {% katex %}\mathsf{KEMDEM}{% endkatex %} scheme is parameterized by {% katex %}(K, E){% endkatex %}, and the proof is parameterized by the same values in its `let:` block. Every reduction carries `(E, K, KD)` as parameters. This is how ProofFrog proves theorems about generic constructions rather than concrete instantiations: the proof holds for any choice of {% katex %}K{% endkatex %} and {% katex %}E{% endkatex %} satisfying the stated assumptions and the {% katex %}K.\mathcal{S} = E.\mathcal{K}{% endkatex %} constraint.

- **Proofs without explicit intermediate games.** Unlike proofs that write out each {% katex %}\mathsf{Game}_i{% endkatex %} as a standalone `Game` definition, this proof keeps its intermediate games implicit — every entry in the `games:` list is either a side of `CPA(KD)` or a `compose` expression. The engine verifies the interchangeability hops by canonicalizing adjacent composed forms directly. This keeps the proof file shorter, at the cost of making each conceptual game only visible in the reader's head (or in the line comments that label them). You can add them if you want, or you can use the web editor's game hop detail view to see what the intermediate games are.

---

### Next steps

TODO LEFT OFF HERE

- Elsewhere in the manual
- Explore the examples catalogue
- See via a KEM-DEM example how ProofFrog compares to EasyCrypt
- Learn more about the science

**Learn more.** If you are curious about how ProofFrog compares with other formal verification systems, check out the [Proof Ladders project](https://proof-ladders.github.io/), which includes an example showing CPA security of KEM-DEM in both [ProofFrog](https://github.com/proof-ladders/asymmetric-ladder/tree/main/kemdem/ProofFrog) and [EasyCrypt](https://github.com/proof-ladders/asymmetric-ladder/tree/main/kemdem/EasyCrypt). That version of the ProofFrog proof uses a slightly different formulation of the one-time secrecy game — one phrased with uniform sampling `E.Key k <- E.Key;` instead of `E.KeyGen()` — which lets the proof sidestep the key-uniformity assumption entirely and collapses the five reductions on this page down to three.
