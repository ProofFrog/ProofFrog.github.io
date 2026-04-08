---
title: Chained Encryption
layout: default
parent: Worked Examples
grand_parent: Manual
nav_order: 1
---

# Chained Encryption

In Tutorial Part 2 you proved that OTP has one-time secrecy — a one-hop interchangeability proof with an empty `assume:` block. Real cryptographic proofs usually look more like this: they build a scheme out of another scheme and reduce the security of the construction to the security of its building block. In this worked example we walk through `examples/joy/Proofs/Ch2/ChainedEncryptionSecure.proof` step by step. It is the first proof in the manual that uses a reduction, and the first place you will see the standard four-step reduction pattern — the organizing principle behind almost every game-hopping proof you will write.

---

## 1. What this proves

**ChainedEncryption** is Construction 2.6.1 from Joy of Cryptography. It composes two independent symmetric encryption schemes, `E1` and `E2`, into a single scheme. To encrypt a message `m`, the scheme generates a fresh key `kprime` for `E2`, encrypts `kprime` under `E1` (producing `c1`), and then encrypts `m` under `kprime` via `E2` (producing `c2`). The ciphertext is the pair `[c1, c2]`. The key type for the composed scheme is `E1.Key`; the message type is `E2.Message`; and the critical structural requirement is that `E2.Key` must be a subset of `E1.Message` — so that a freshly generated `E2` key can itself be treated as a message for `E1`.

The theorem proved here is: if both `E1` and `E2` satisfy one-time secrecy, then `ChainedEncryption(E1, E2)` also satisfies one-time secrecy. The `assume:` block asserts `OneTimeSecrecy(E1)` and `OneTimeSecrecy(E2)`. There are no computational hardness assumptions; the result follows from these two security properties alone.

---

## 2. Joy of Cryptography parallel

This mirrors Claim 2.6.2 in [Joy of Cryptography](https://joyofcryptography.com/) by Mike Rosulek, which proves the same result. Rosulek's proof is the mental model: replace the `E1` encryption of `kprime` with a random ciphertext (using `E1`'s one-time secrecy), then replace the `E2` encryption of `m` with a random ciphertext (using `E2`'s one-time secrecy). At that point both components of the ciphertext are uniformly random and independent of `m`, so the combined ciphertext is uniformly random — which is exactly the `OneTimeSecrecy.Random` game for the composed scheme. The FrogLang proof encodes this argument precisely and has the engine verify each step.

---

## 3. The scheme

The full scheme file, exactly as it appears on disk:

```prooffrog
// Construction 2.6.1: Chained encryption
// Combines two encryption schemes E1, E2 by encrypting a fresh
// key for E2 under E1, then encrypting the message under E2.
// Requires E2's keys to be encryptable by E1.

import '../../Primitives/SymEnc.primitive';

Scheme ChainedEncryption(SymEnc E1, SymEnc E2) extends SymEnc {
    requires E2.Key subsets E1.Message;

    Set Key = E1.Key;
    Set Message = E2.Message;
    Set Ciphertext = [E1.Ciphertext, E2.Ciphertext];

    Key KeyGen() {
        E1.Key k = E1.KeyGen();
        return k;
    }

    Ciphertext Enc(Key k, Message m) {
        E2.Key kprime = E2.KeyGen();
        E1.Ciphertext c1 = E1.Enc(k, kprime);
        E2.Ciphertext c2 = E2.Enc(kprime, m);
        return [c1, c2];
    }

    deterministic Message? Dec(Key k, Ciphertext c) {
        E2.Key? kprime = E1.Dec(k, c[0]);
        if (kprime == None) {
            return None;
        }
        return E2.Dec(kprime, c[1]);
    }
}
```

The `requires` clause on line 9 is a structural constraint: `E2.Key subsets E1.Message`. Without this, the scheme cannot instantiate `E1.Enc(k, kprime)` because `kprime` has type `E2.Key` but `E1.Enc` expects an `E1.Message`. The `requires` clause makes this subtype relationship explicit and lets the type checker accept the call.

The `Ciphertext` type is a **tuple**: `[E1.Ciphertext, E2.Ciphertext]`. In FrogLang, `[T1, T2]` is the two-component product type; the components are accessed by constant index: `c[0]` and `c[1]`. The `Dec` method extracts `c[0]` (the `E1` ciphertext), tries to decrypt it with `E1.Dec`, and uses the recovered `kprime` to decrypt `c[1]` with `E2.Dec`. Either decryption step can fail, hence the `E2.Key?` intermediate type and the `None` check.

For the full syntax of `Scheme`, the `requires` clause, tuple types, and method modifiers, see the [Schemes language reference]({% link manual/language-reference/schemes.md %}).

---

## 4. The proof structure

The `games:` block lists six game steps, producing five hops. The overall shape:

- **Step 1** — `OneTimeSecrecy(CE).Real against OneTimeSecrecy(CE).Adversary`
  The starting point: the theorem's Real side, with `CE` playing the role of challenger and a generic adversary.

- **Step 2** — `OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Interchangeability hop. The direct game from step 1 is rewritten in terms of reduction `R1` composed with the Real side of `E1`'s one-time secrecy game. The engine verifies that these two representations are code-equivalent.

- **Step 3** — `OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Assumption hop (Real to Random for `E1`). Justified by `OneTimeSecrecy(E1)` in `assume:`. The engine accepts this without code-equivalence checking.

- **Step 4** — `OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Interchangeability hop. After `E1`'s encryption has been replaced with random, the code is reorganized through reduction `R2`, which hands `E2`'s encryption off to the `E2` challenger. Again engine-verified by code equivalence.

- **Step 5** — `OneTimeSecrecy(E2).Random compose R2(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Assumption hop (Real to Random for `E2`). Justified by `OneTimeSecrecy(E2)` in `assume:`.

- **Step 6** — `OneTimeSecrecy(CE).Random against OneTimeSecrecy(CE).Adversary`
  The ending point: the theorem's Random side. Once both components `c1` and `c2` are uniformly random (component-wise), the joint pair is also uniformly random, which equals a direct sample from `CE.Ciphertext`. The engine verifies this final equivalence.

The proof is symmetric: the first half (hops 1-2-3) handles `E1`'s encryption, replacing `c1` with a random ciphertext; the second half (hops 3-4-5) handles `E2`'s encryption, replacing `c2` with a random ciphertext. Steps 2 through 5 are two interleaved applications of the four-step reduction pattern, with step 4 serving as both the exit step of the first application and the entry step of the second.

---

## 5. The four-step reduction pattern, walked through

The standard way to invoke an assumption in a game-hopping proof is the four-step reduction pattern. Each invocation occupies four consecutive game steps:

```
G_A;                           // interchangeable with Security.Real compose R
Security.Real compose R;       // interchangeability confirmed
Security.Random compose R;     // assumption hop  (Real -> Random for Security)
G_B;                           // interchangeable with Security.Random compose R
```

Hops 1 to 3 in this proof are the first complete instance of the pattern, applied to `E1`. Here are the four lines exactly as they appear in `ChainedEncryptionSecure.proof`:

```prooffrog
    OneTimeSecrecy(CE).Real against OneTimeSecrecy(CE).Adversary;

    // Factor out E1's encryption into reduction R1
    OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary;

    // By assumption: E1 has one-time secrecy
    OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary;

    // Factor out E2's encryption into reduction R2
    OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) against OneTimeSecrecy(CE).Adversary;
```

Reading these four steps:

1. **`OneTimeSecrecy(CE).Real against ...`** — This is `G_A`. It is the direct game for the theorem. The engine will verify that it is code-equivalent to step 2.

2. **`OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) against ...`** — This is `Security.Real compose R`. The engine inlines `R1` into `OneTimeSecrecy(E1).Real` and verifies that the result is code-equivalent to step 1. This hop is an *interchangeability hop*: the engine checks it automatically.

3. **`OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) against ...`** — This is `Security.Random compose R`. The transition from step 2 to step 3 is the **assumption hop**: the engine accepts it because `OneTimeSecrecy(E1)` appears in the `assume:` block. No code equivalence is checked; the indistinguishability of `E1.Real` and `E1.Random` is taken as given.

4. **`OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) against ...`** — This is `G_B`, and simultaneously the start of the second four-step pattern. The engine verifies that `OneTimeSecrecy(E1).Random compose R1` is code-equivalent to `OneTimeSecrecy(E2).Real compose R2` — two composed forms that both represent the "halfway" state where `c1` is random and `c2` is still real.

The structure is therefore:

- Lines 1 and 2: engine-verified interchangeability (step into R1 via E1.Real).
- Lines 2 and 3: assumption hop (E1.Real to E1.Random, justified by `OneTimeSecrecy(E1)`).
- Lines 3 and 4: engine-verified interchangeability (transition from R1/E1.Random to R2/E2.Real).

For the full structural reference, see the [Proofs language reference]({% link manual/language-reference/proofs.md %}). The [Transformations]({% link manual/transformations.md %}) page explains the canonicalization steps the engine uses to verify code equivalence.

---

## 6. The first reduction in detail

Reduction `R1` adapts the `OneTimeSecrecy(CE)` adversary so it can play against a `OneTimeSecrecy(E1)` challenger:

```prooffrog
// R1: delegates E1 encryption to the challenger, handles E2 encryption itself
Reduction R1(ChainedEncryption CE, SymEnc E1, SymEnc E2) compose OneTimeSecrecy(E1) against OneTimeSecrecy(CE).Adversary {
    CE.Ciphertext ENC(CE.Message m) {
        E2.Key kprime = E2.KeyGen();
        E1.Ciphertext c1 = challenger.ENC(kprime);
        E2.Ciphertext c2 = E2.Enc(kprime, m);
        return [c1, c2];
    }
}
```

**The parameter list: `(ChainedEncryption CE, SymEnc E1, SymEnc E2)`**

The reduction takes three parameters even though the body references only `E1`, `E2`, and `CE.Ciphertext`. `CE` is required because the composed security game is `OneTimeSecrecy(E1)`, and the outer adversary interface is `OneTimeSecrecy(CE).Adversary` — instantiating `CE.Ciphertext` as the return type requires `CE` to be in scope. In general, the parameter list must include every parameter needed to instantiate both the composed game and the theorem-game adversary, even if a parameter is not used inside any oracle body. This is the *reduction parameter rule* (documented in the [Proofs language reference]({% link manual/language-reference/proofs.md %})). Omitting a required parameter produces a confusing instantiation error at the game step that uses the reduction, not at the reduction definition itself.

**The header: `compose OneTimeSecrecy(E1) against OneTimeSecrecy(CE).Adversary`**

This says: the reduction plays as the challenger for `OneTimeSecrecy(CE)` (the outer theorem game), and internally it communicates with a `OneTimeSecrecy(E1)` challenger, which it accesses through the built-in name `challenger`. When this reduction is composed with `OneTimeSecrecy(E1).Real`, the `challenger.ENC(kprime)` call resolves to the Real game's oracle: it generates a fresh `E1` key and returns `E1.Enc(k, kprime)`. When composed with `OneTimeSecrecy(E1).Random`, the call resolves to the Random game's oracle: it returns a uniformly random `E1.Ciphertext`.

**The oracle body**

The `ENC` oracle receives a message `m` of type `CE.Message` (which equals `E2.Message`). It:

1. Generates a fresh `E2` key `kprime` locally.
2. Asks the `E1` challenger to encrypt `kprime` as a message: `challenger.ENC(kprime)`. This is the only call to the external challenger. Because `E2.Key subsets E1.Message`, `kprime` is a valid input.
3. Encrypts the original message `m` directly using `E2.Enc(kprime, m)`, handling `E2`'s layer itself.
4. Returns the pair `[c1, c2]` as a `CE.Ciphertext`.

When the `E1` challenger is in Real mode, the body of `R1 compose OneTimeSecrecy(E1).Real` is code-equivalent to the direct `ChainedEncryption.Enc` logic inside `OneTimeSecrecy(CE).Real`. This is why hop 1-to-2 passes. When the `E1` challenger switches to Random mode (returning a uniform `c1` instead), the body of `R1 compose OneTimeSecrecy(E1).Random` is the halfway game where `c1` is random — which the engine can then connect to `R2 compose OneTimeSecrecy(E2).Real` in the subsequent interchangeability hop.

---

## 7. Verifying

From the `examples/joy/` directory (or the repository root), run:

```bash
proof_frog prove Proofs/Ch2/ChainedEncryptionSecure.proof
```

Expected output:

```
Type checking...

Theorem: OneTimeSecrecy(CE)

  Step 1/5  OneTimeSecrecy(CE).Real
            -> OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) ... ok
  Step 2/5  OneTimeSecrecy(E1).Real compose R1(CE, E1, E2)
            -> OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) ... by assumption
  Step 3/5  OneTimeSecrecy(E1).Random compose R1(CE, E1, E2)
            -> OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) ... ok
  Step 4/5  OneTimeSecrecy(E2).Real compose R2(CE, E1, E2)
            -> OneTimeSecrecy(E2).Random compose R2(CE, E1, E2) ... by assumption
  Step 5/5  OneTimeSecrecy(E2).Random compose R2(CE, E1, E2)
            -> OneTimeSecrecy(CE).Random ... ok

Proof Succeeded!
```

Steps 1, 3, and 5 are equivalence hops verified by the engine. Steps 2 and 4 are assumption hops, one for each of the two `OneTimeSecrecy` assumptions in `assume:`.

In the web editor, open `Proofs/Ch2/ChainedEncryptionSecure.proof` and click the **Run Proof** button. The output panel turns green and shows the same step-by-step report.

---

## 8. Next

The next worked example, [KEM-DEM CPA]({% link manual/worked-examples/kemdem-cpa.md %}), is the graduation piece: a KEM-DEM hybrid encryption construction proved CPA-secure. It uses two independent primitives (a KEM and a symmetric cipher), two reductions that operate in opposite directions of the game sequence, and a lemma invocation. After seeing ChainedEncryption you have all the conceptual tools needed to read it; the KEM-DEM example shows how those tools combine at a scale closer to what real-world proof engineering looks like.
