---
title: KEM-DEM CPA
layout: linear
parent: Worked Examples
grand_parent: Manual
nav_order: 2
---

# KEM-DEM CPA

The [Chained Encryption]({% link manual/worked-examples/chained-encryption.md %}) worked example used a single primitive twice, with two reductions both aimed at the same assumption. This worked example graduates to a multi-primitive construction: the classical KEM-DEM hybrid public-key encryption scheme. We prove that if the KEM is CPA-secure and the symmetric encryption scheme satisfies one-time secrecy, then the hybrid PKE is CPA-secure. The proof uses three reductions — two to KEM security in opposite directions, with one reduction to SymEnc one-time secrecy in between — and walks through `examples/asymmetric-ladder/kemdem/Hyb-is-CPA.proof` step by step.

---

## 1. The construction

A **Key Encapsulation Mechanism (KEM)** consists of a key-generation algorithm, an encapsulation algorithm `Encaps`, and a decapsulation algorithm `Decaps`. When a sender calls `Encaps(pk)`, it receives a pair: a ciphertext `c_kem` and a shared secret `ss`. The recipient, holding the secret key `sk`, recovers the same shared secret by calling `Decaps(sk, c_kem)`.

The **KEM-DEM paradigm** (also called hybrid encryption) uses the KEM shared secret directly as the key for a symmetric encryption scheme (the DEM, Data Encapsulation Mechanism). To encrypt a message `m`, the sender:

1. Calls `K.Encaps(pk)` to obtain a KEM ciphertext `c_kem` and shared secret `ss`.
2. Uses `ss` as the symmetric key to encrypt `m` with the DEM, producing `c_dem`.
3. Sends `[c_kem, c_dem]`.

The recipient reverses the process: decapsulate `c_kem` to recover `ss`, then use `ss` to decrypt `c_dem`.

This construction is how every modern TLS-like protocol works at a high level: the asymmetric primitive (historically RSA or ECDH, now increasingly a post-quantum KEM) establishes a shared secret, and all subsequent data is encrypted symmetrically.

**Key design choice in this version.** Although the `SymEnc` primitive declares a `KeyGen` method, the `Hyb` scheme used here never calls it — the symmetric key is always the shared secret produced by the KEM. Because the scheme never generates a standalone symmetric key, the proof does not need a key-uniformity assumption: the question of whether the KEM shared secret is uniform enough to serve as a symmetric key is answered by the KEM's own CPA security definition, which says the real shared secret is indistinguishable from a uniform random sample. The result is a clean three-reduction proof. (The main in-repo file `examples/Proofs/PubEnc/KEMDEMCPA.proof` follows a different formulation that does invoke `E.KeyGen()` and consequently needs two additional `KeyUniformity` hops; this page intentionally uses the cleaner version from `examples/asymmetric-ladder/kemdem/`.)

---

## 2. Joy of Cryptography parallel

The KEM-DEM construction and its CPA-security proof appear in Mike Rosulek's [Joy of Cryptography](https://joyofcryptography.com/) and in Boneh-Shoup's "A Graduate Course in Applied Cryptography" (Exercise 11.9, available at [https://toc.cryptobook.us/](https://toc.cryptobook.us/)). The proof here follows the same game-hopping argument described in those references: replace the real KEM shared secret with a random key (using KEM CPA), switch the ciphertext from encrypting the left message to the right message (using SymEnc OTS), and then restore the real KEM shared secret (using KEM CPA again, in the reverse direction). ProofFrog mechanically verifies each hop of this argument.

---

## 3. The three primitives and three games

### 3a. SymEnc — primitive and OTS game

The symmetric encryption primitive is parameterized by a message space, a ciphertext space, and a key space. The primitive declares a `KeyGen` method, but in this construction the `Hyb` scheme never calls it — the symmetric key always comes from outside the primitive (from the KEM's shared secret).

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    Message Dec(Key k, Ciphertext c);
}
```

The one-time secrecy (OTS) game for `SymEnc` is a left-right game: the adversary submits two messages `mL` and `mR`, and the challenger encrypts either `mL` (Left game) or `mR` (Right game) under a freshly sampled key. The adversary must guess which. Crucially, the key is sampled fresh for each call, so the adversary gets to see exactly one ciphertext.

```prooffrog
import 'SymEnc.primitive';

Game Left(SymEnc E) {
    E.Ciphertext ENC(E.Message mL, E.Message mR) {
        E.Key k <- E.Key;
        E.Ciphertext c = E.Enc(k, mL);
        return c;
    }
}

Game Right(SymEnc E) {
    E.Ciphertext ENC(E.Message mL, E.Message mR) {
        E.Key k <- E.Key;
        E.Ciphertext c = E.Enc(k, mR);
        return c;
    }
}

export as OTS;
```

### 3b. KEM — primitive and CPA game

The KEM primitive is parameterized by four spaces: shared secret, ciphertext, public key, and secret key. Encapsulation returns a tuple `[ciphertext, shared_secret]`.

```prooffrog
Primitive KEM(Set SharedSecretSpace, Set CiphertextSpace, Set PKeySpace, Set SKeySpace) {
    Set SharedSecret = SharedSecretSpace;
    Set Ciphertext = CiphertextSpace;
    Set PublicKey = PKeySpace;
    Set SecretKey = SKeySpace;

    [PublicKey, SecretKey] KeyGen();
    [Ciphertext, SharedSecret] Encaps(PublicKey pk);
    SharedSecret Decaps(SecretKey sk, Ciphertext m);
}
```

The KEM CPA game captures indistinguishability of real and ideal shared secrets. In the Real game, the adversary receives a genuine `(ciphertext, shared_secret)` pair from `Encaps`. In the Ideal game, the adversary receives the same ciphertext but a freshly sampled, independent shared secret — completely unrelated to what `Decaps` would recover.

```prooffrog
import 'KEM.primitive';

Game Real(KEM K) {
    K.PublicKey pk;
    K.SecretKey sk;

    Void Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
    }

    K.PublicKey PK() {
        return pk;
    }

    [K.Ciphertext, K.SharedSecret] ENC() {
        [K.Ciphertext, K.SharedSecret] rsp = K.Encaps(pk);
        return rsp;
    }
}

Game Ideal(KEM K) {
    K.PublicKey pk;
    K.SecretKey sk;

    Void Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
    }

    K.PublicKey PK() {
        return pk;
    }

    [K.Ciphertext, K.SharedSecret] ENC() {
        [K.Ciphertext, K.SharedSecret] rsp = K.Encaps(pk);
        K.Ciphertext ctxt = rsp[0];
        K.SharedSecret ss <- K.SharedSecret;
        return [ctxt, ss];
    }
}

export as CPAKEM;
```

### 3c. PKE — primitive and CPA game

The public key encryption primitive (the goal we are trying to prove) follows the standard interface.

```prooffrog
Primitive PKE(Set MessageSpace, Set CiphertextSpace, Set PKeySpace, Set SKeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set PublicKey = PKeySpace;
    Set SecretKey = SKeySpace;

    [PublicKey, SecretKey] KeyGen();
    Ciphertext Enc(PublicKey pk, Message m);
    Message Dec(SecretKey sk, Ciphertext m);
}
```

The PKE CPA game is a left-right game: the adversary requests the public key, submits two messages, and the challenger encrypts either `mL` (Left) or `mR` (Right). The adversary may call `ENC` multiple times (multi-message CPA). The Hyb scheme's theorem says the Left and Right games are indistinguishable.

```prooffrog
import 'PKE.primitive';

Game Left(PKE E) {
    E.PublicKey pk;
    E.SecretKey sk;

    Void Initialize() {
        [E.PublicKey, E.SecretKey] k = E.KeyGen();
        pk = k[0];
        sk = k[1];
    }

    E.PublicKey PK() {
        return pk;
    }

    E.Ciphertext ENC(E.Message mL, E.Message mR) {
        return E.Enc(pk, mL);
    }
}

Game Right(PKE E) {
    E.PublicKey pk;
    E.SecretKey sk;

    Void Initialize() {
        [E.PublicKey, E.SecretKey] k = E.KeyGen();
        pk = k[0];
        sk = k[1];
    }

    E.PublicKey PK() {
        return pk;
    }

    E.Ciphertext ENC(E.Message mL, E.Message mR) {
        return E.Enc(pk, mR);
    }
}

export as CPA;
```

---

## 4. The Hyb scheme

```prooffrog
import 'KEM.primitive';
import 'SymEnc.primitive';
import 'PKE.primitive';

Scheme Hyb(KEM K, SymEnc E) extends PKE {
    requires K.SharedSecret subsets E.Key;

    Set PublicKey = K.PublicKey;
    Set SecretKey = K.SecretKey;
    Set Message = E.Message;
    Set Ciphertext = [K.Ciphertext, E.Ciphertext];

    [PublicKey, SecretKey] KeyGen() {
        return K.KeyGen();
    }

    Ciphertext Enc(PublicKey pk, Message m) {
        [K.Ciphertext, K.SharedSecret] x = K.Encaps(pk);
        K.Ciphertext c_kem = x[0];
        E.Key k_dem = x[1];
        E.Ciphertext c_dem = E.Enc(k_dem, m);
        return [c_kem, c_dem];
    }

    Message Dec(SecretKey sk, Ciphertext c) {
        K.Ciphertext c_kem = c[0];
        E.Ciphertext c_dem = c[1];
        K.SharedSecret k_dem = K.Decaps(sk, c_kem);
        return E.Dec(k_dem, c_dem);
    }
}
```

The scheme is parameterized by a KEM `K` and a SymEnc `E`. It extends the `PKE` primitive, meaning it promises to provide all the methods that `PKE` requires (`KeyGen`, `Enc`, `Dec`).

The `requires K.SharedSecret subsets E.Key;` clause is the structural linchpin of the entire construction. It states that the KEM's shared secret space must be a subset of the SymEnc's key space. Without this clause, the assignment `E.Key k_dem = x[1];` in `Enc` would be a type error — `x[1]` has type `K.SharedSecret`, not `E.Key`. The `requires` clause makes the subtype relationship explicit, so the type checker can accept the code and the proof can proceed without any additional uniformity assumptions.

`KeyGen` simply delegates to the KEM's key generation — the hybrid scheme's key pair is the KEM's key pair. `Enc` encapsulates under the public key to produce the KEM ciphertext `c_kem` and shared secret `k_dem`, then uses that shared secret directly as the DEM key to encrypt the message. `Dec` reverses the process: decapsulate `c_kem` to recover `k_dem`, then use it to decrypt `c_dem`.

The ciphertext type `[K.Ciphertext, E.Ciphertext]` is a tuple. In FrogLang, `[T1, T2]` is the two-component product type, and components are accessed by constant index: `c[0]` is the KEM ciphertext, `c[1]` is the DEM ciphertext.

---

## 5. Proof outline

The proof walks through four intermediate games between the `CPA(H).Left` starting game and the `CPA(H).Right` ending game. The transition between each pair of adjacent games is one of: a code-equivalence check (interchangeability hop, verified by the engine automatically), or an assumption hop (accepted because the assumption appears in `assume:`).

The four intermediate games are:

- **Game 0** — The Hyb scheme encrypts the *left* message `mL` using the *real* KEM shared secret. This is the `CPA(H).Left` game with the scheme inlined.

- **Game 1** — The Hyb scheme encrypts `mL` using a *random* key sampled directly from the shared-secret space, not the one produced by `Encaps`. The KEM ciphertext `c_kem` is still produced by a real `Encaps` call, so it is a valid ciphertext — but the DEM key is now independent of it.

- **Game 2** — The Hyb scheme encrypts the *right* message `mR` using a random key. The transition from Game 1 to Game 2 is justified by SymEnc OTS: because the DEM key is random and fresh, the adversary cannot distinguish whether `mL` or `mR` was encrypted.

- **Game 3** — The Hyb scheme encrypts `mR` using the *real* KEM shared secret. This is the `CPA(H).Right` game with the scheme inlined.

Three reductions bridge the four games:

- **R1** (KEM-CPA, Game 0 to Game 1): Reduces to KEM CPA security in the *Real → Ideal* direction. When the KEM challenger is in Real mode, R1's output is identical to Game 0. When the challenger switches to Ideal mode (returning a random shared secret), R1's output is identical to Game 1.

- **R2** (SymEnc-OTS, Game 1 to Game 2): Reduces to SymEnc one-time secrecy. R2 generates the KEM key pair itself and calls the OTS challenger to encrypt either `mL` or `mR`. When the OTS challenger is in Left mode, R2's output matches Game 1; in Right mode, it matches Game 2.

- **R3** (KEM-CPA, Game 2 to Game 3): Reduces to KEM CPA security in the *Ideal → Real* direction. This is structurally identical to R1 but encrypts `mR`. When the KEM challenger is in Ideal mode, R3's output matches Game 2; when it switches back to Real mode, R3's output matches Game 3.

**R1 and R3 both reduce to the same assumption** — KEM CPA security — but in opposite directions. R1 goes Real → Ideal (the shared secret starts real and becomes random). R3 goes Ideal → Real (the shared secret starts random and becomes real again). Both directions are valid because indistinguishability is symmetric: if no adversary can distinguish Real from Ideal, no adversary can distinguish Ideal from Real either.

---

## 6. Reduction R1 in detail

```prooffrog
// Reduction for hop from Game 0 to Game 1
// - Reduction to CPA security of the KEM. The reduction uses the shared secret
//   from the KEM CPA challenger, which is either real (= Game 0) or random (= Game 1).
Reduction R1(SymEnc E, KEM K, Hyb H) compose CPAKEM(K) against CPA(H).Adversary {
    H.PublicKey PK() {
        return challenger.PK();
    }
    H.Ciphertext ENC(H.Message mL, H.Message mR) {
        [K.Ciphertext, K.SharedSecret] y = challenger.ENC();
        K.Ciphertext c_kem = y[0];
        K.SharedSecret k_dem = y[1];
        E.Ciphertext c_dem = E.Enc(k_dem, mL);
        return [c_kem, c_dem];
    }
}
```

**The header.** `compose CPAKEM(K) against CPA(H).Adversary` says: R1 plays as the challenger for the outer `CPA(H)` game (the PKE CPA game), and internally it communicates with a `CPAKEM(K)` challenger, accessed as `challenger`.

**`PK()`.** R1 simply forwards the KEM's public key from the challenger. The KEM CPA challenger holds the actual key pair (generated in its `Initialize` method); R1 has no key pair of its own. This is why R1 has no state fields — all key material comes from the challenger.

**`ENC(mL, mR)`.** R1 calls `challenger.ENC()` to get a `(c_kem, shared_secret)` pair. It uses `k_dem = y[1]` directly as the DEM key to encrypt the left message `mL`. The result `[c_kem, c_dem]` is a valid Hyb ciphertext.

**The two modes.** If the KEM challenger is in `CPAKEM(K).Real` mode, then `y[1]` is the genuine shared secret that `Decaps(sk, c_kem)` would recover. R1's output then has exactly the same distribution as Game 0 — the Hyb scheme encrypting `mL` under the real shared secret. If the challenger is in `CPAKEM(K).Ideal` mode, then `y[1]` is a uniformly random element of `K.SharedSecret`, independent of `c_kem`. R1's output then has exactly the same distribution as Game 1 — the DEM key is random. The engine verifies these two equivalences as interchangeability hops. The transition between Real and Ideal is justified by the `CPAKEM(K)` assumption.

---

## 7. Reduction R2 in detail

```prooffrog
// Reduction for hop from Game 1 to Game 2
// - Reduction to one-time secrecy of the symmetric encryption scheme. The reduction uses the
//   challenger to encrypt either mL (= Game 1) or mR (= Game 2).
Reduction R2(SymEnc E, KEM K, Hyb H) compose OTS(E) against CPA(H).Adversary {
    K.PublicKey pk;
    K.SecretKey sk;
    Void Initialize() {
        [K.PublicKey, K.SecretKey] k = K.KeyGen();
        pk = k[0];
        sk = k[1];
    }
    H.PublicKey PK() {
        return pk;
    }

    H.Ciphertext ENC(H.Message mL, H.Message mR) {
        [K.Ciphertext, K.SharedSecret] x = K.Encaps(pk);
        K.Ciphertext c_kem = x[0];
        E.Ciphertext c_dem = challenger.ENC(mL, mR);
        return [c_kem, c_dem];
    }
}
```

**State fields.** Unlike R1, R2 has state fields `pk` and `sk` with an `Initialize` method. This is because R2 composes against `OTS(E)`, not `CPAKEM(K)` — the KEM CPA challenger is no longer in scope. R2 must generate the KEM key pair itself to answer the adversary's `PK()` queries. This is a common pattern: a reduction that reduces to one primitive must handle all other primitives on its own.

**`ENC(mL, mR)`.** R2 calls `K.Encaps(pk)` to produce a genuine KEM ciphertext, but then discards the shared secret `x[1]`. Instead, it calls `challenger.ENC(mL, mR)` to let the OTS challenger encrypt either `mL` or `mR` under a fresh random key. The result `[c_kem, c_dem]` is returned as the Hyb ciphertext.

**The two modes.** In `OTS(E).Left` mode, the OTS challenger encrypts `mL` under a random key, so R2's output is: a real KEM ciphertext paired with an encryption of `mL` under a random DEM key. This matches Game 1. In `OTS(E).Right` mode, the OTS challenger encrypts `mR` under a random key, so R2's output matches Game 2. The key point: because the OTS challenger samples a fresh key internally (not the KEM shared secret), this matches the random-key world of Games 1 and 2. The engine verifies this alignment; the Left-to-Right switch is justified by the `OTS(E)` assumption.

---

## 8. Reduction R3 in detail

```prooffrog
// Reduction for hop from Game 2 to Game 3
// - Reduction to CPA security of the KEM. The reduction uses the shared secret
//   from the KEM CPA challenger, which is either random (= Game 2) or real (= Game 3).
Reduction R3(SymEnc E, KEM K, Hyb H) compose CPAKEM(K) against CPA(H).Adversary {
    H.PublicKey PK() {
        return challenger.PK();
    }
    H.Ciphertext ENC(H.Message mL, H.Message mR) {
        [K.Ciphertext, K.SharedSecret] y = challenger.ENC();
        K.Ciphertext c_kem = y[0];
        K.SharedSecret k_dem = y[1];
        E.Ciphertext c_dem = E.Enc(k_dem, mR);
        return [c_kem, c_dem];
    }
}
```

R3 is structurally identical to R1, with one change: it encrypts `mR` instead of `mL`. Like R1, it has no state fields and forwards `PK()` directly from the KEM challenger. It calls `challenger.ENC()` to get `(c_kem, k_dem)` and uses `k_dem` as the DEM key.

When the KEM challenger is in `CPAKEM(K).Ideal` mode, `k_dem` is a random shared secret, and R3's output matches Game 2 (encrypting `mR` under a random key). When the challenger switches to `CPAKEM(K).Real` mode, `k_dem` is the genuine shared secret, and R3's output matches Game 3 (encrypting `mR` under the real shared secret). This is the Ideal → Real direction: the proof has finished using the random-key intermediate world and is now restoring the real KEM shared secret, but on the right-message side.

---

## 9. The games block

The complete `games:` section of `Hyb-is-CPA.proof`, with annotations:

```prooffrog
games:
    // Game 0: start — CPA(H).Left with Hyb scheme inlined
    CPA(H).Left against CPA(H).Adversary;
    // Equivalence: inline Game0 directly
    Game0(K, E, H) against CPA(H).Adversary;
    // Equivalence: rewrite as R1 composed with KEM CPA Real
    CPAKEM(K).Real compose R1(E, K, H) against CPA(H).Adversary;
    // Assumption hop: KEM CPA Real -> Ideal  (R1 direction: real shared secret -> random)
    CPAKEM(K).Ideal compose R1(E, K, H) against CPA(H).Adversary;
    // Equivalence: inline Game1 — DEM key is now random
    Game1(K, E, H) against CPA(H).Adversary;
    // Equivalence: rewrite as R2 composed with OTS Left
    OTS(E).Left compose R2(E, K, H) against CPA(H).Adversary;
    // Assumption hop: OTS Left -> Right  (R2 direction: encrypt mL -> encrypt mR)
    OTS(E).Right compose R2(E, K, H) against CPA(H).Adversary;
    // Equivalence: inline Game2 — encrypting mR under random key
    Game2(K, E, H) against CPA(H).Adversary;
    // Equivalence: rewrite as R3 composed with KEM CPA Ideal
    CPAKEM(K).Ideal compose R3(E, K, H) against CPA(H).Adversary;
    // Assumption hop: KEM CPA Ideal -> Real  (R3 direction: random shared secret -> real)
    CPAKEM(K).Real compose R3(E, K, H) against CPA(H).Adversary;
    // Equivalence: inline Game3
    Game3(K, E, H) against CPA(H).Adversary;
    // End: CPA(H).Right with Hyb scheme inlined
    CPA(H).Right against CPA(H).Adversary;
```

The pattern in each three-reduction block is the standard four-step pattern from the [Proofs language reference]({% link manual/language-reference/proofs.md %}):

1. A direct game (or the previous game).
2. An interchangeability hop to `Security.SideA compose R`.
3. An assumption hop to `Security.SideB compose R`.
4. An interchangeability hop back to a direct game.

R1 uses this pattern with `CPAKEM(K).Real` as SideA and `CPAKEM(K).Ideal` as SideB (Real → Ideal). R2 uses it with `OTS(E).Left` as SideA and `OTS(E).Right` as SideB (Left → Right). R3 uses it with `CPAKEM(K).Ideal` as SideA and `CPAKEM(K).Real` as SideB (Ideal → Real, the reverse direction). The three four-step patterns share their boundary direct-games: `Game1` closes R1 and opens R2, `Game2` closes R2 and opens R3. The first (`CPA(H).Left`) and last (`CPA(H).Right`) of the twelve entries are the two sides of the theorem goal; the ten entries between them are the three four-step patterns glued at those shared boundaries.

The proof also includes explicit intermediate game definitions (`Game0`, `Game1`, `Game2`, `Game3`) as additional documentation. ProofFrog can verify the proof without them (the equivalences they participate in would be direct consecutive hops between composed forms), but writing them out makes each game state legible as a standalone program and helps the reader understand what the proof claims at each stage.

---

## 10. Verifying

{: .important }
**Activate your Python virtual environment first** if it is not already active in this terminal: `source .venv/bin/activate` on macOS/Linux (bash/zsh), `source .venv/bin/activate.fish` on fish, or `.venv\Scripts\Activate.ps1` on Windows PowerShell. See [Installation]({% link manual/installation.md %}).

From the repository root:

```bash
proof_frog prove examples/asymmetric-ladder/kemdem/Hyb-is-CPA.proof
```

Expected output:

```
Proof Succeeded!
```

The full step-by-step output shows 11 hops over 12 game steps: 8 equivalence hops (verified by code canonicalization) and 3 assumption hops (one for each of R1, R2, R3).

In the web editor, open `examples/asymmetric-ladder/kemdem/Hyb-is-CPA.proof` and click **Run Proof**. The output panel turns green with the same step-by-step report.

---

## 11. What this teaches that Chained Encryption did not

- **Multi-primitive composition.** The proof reasons about three distinct primitives simultaneously — a KEM, a SymEnc, and a PKE — each with its own security game and its own type namespace. Reductions must carefully distinguish which primitive's methods and sets they are invoking. The `requires` clause on the scheme is what makes the types align across primitive boundaries.

- **Reductions in opposite directions.** R1 and R3 both reduce to the same underlying assumption (`CPAKEM(K)`), but R1 invokes it in the Real → Ideal direction and R3 invokes it in the Ideal → Real direction. Both are valid because indistinguishability is symmetric. This "go-and-come-back" pattern is fundamental to hybrid encryption proofs: use the KEM assumption to move into a world with a random key, do the message-switching argument, and use the same KEM assumption to move back out. Neither direction is privileged; the same security game serves both roles.

- **Generic construction parameter handling.** The Hyb scheme is parameterized by `(KEM K, SymEnc E)`, and the proof is parameterized by the same values in its `let:` block. Every intermediate game and every reduction carries `(K, E, H)` as parameters. This is how ProofFrog proves theorems about generic constructions rather than concrete instantiations: the proof holds for any choice of `K` and `E` satisfying the stated assumptions and the `requires K.SharedSecret subsets E.Key` constraint.
