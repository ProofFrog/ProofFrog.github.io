---
title: Chained Encryption
layout: linear
parent: Worked Examples
grand_parent: Manual
nav_order: 1
---

# Chained Symmetric Encryption
{: .no_toc }

In Tutorial Part 2 you proved that the one-time pad has one-time secrecy — a one-hop interchangeability proof with an empty `assume:` block. Real cryptographic proofs usually look more like this: they build a scheme out of another scheme and reduce the security of the construction to the security of its building block. 

In this worked example we examine **chained symmetric encryption**, which composes two symmetric encryption schemes {% katex %}E_1{% endkatex %} and {% katex %}E_2{% endkatex %} by sampling a one-time {% katex %}E_2{% endkatex %}-key {% katex %}k'{% endkatex %}, encrypting it using the main key {% katex %}k{% endkatex %}, and then encrypting the message using {% katex %}k'{% endkatex %}:

{% katex display %}
(c_1, c_2) \quad \text{ where } \quad k' \stackrel{\$}\leftarrow E_2.\mathcal{K}, \quad c_1 \gets E_1.\mathsf{Enc}(k, k'), \quad \ c_2 \gets E_2.\mathsf{Enc}(k', m)
{% endkatex %}

We'll give a proof that chained symmetric encryption satisfies one-time secrecy, under the assumption that both {% katex %}E_1{% endkatex %} and {% katex %}E_2{% endkatex %} are one-time secret.

This is the first proof in the manual that uses a reduction, and the first place you will see the standard four-step reduction pattern — the organizing principle behind almost every game-hopping proof you will write.

The full proof is available in the examples repository at [`joy/Proofs/Ch2/ChainedEncryptionSecure.proof`](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch2/ChainedEncryptionSecure.proof).

---

- TOC
{:toc}

---

## 1. What this proves

**Chained symmetric encryption** is Construction 2.6.1 from [Joy of Cryptography](https://joyofcryptography.com/provsec/#sec.modular). It composes two independent symmetric encryption schemes {% katex %}E_1{% endkatex %} and {% katex %}E_2{% endkatex %} into a new symmetric encryption scheme {% katex %}\mathsf{CE} = \mathsf{ChainedEncryption}(E_1, E_2){% endkatex %}. To encrypt a message {% katex %}m{% endkatex %} under a key {% katex %}k{% endkatex %}, the scheme samples a fresh {% katex %}E_2{% endkatex %}-key {% katex %}k'{% endkatex %}, encrypts {% katex %}k'{% endkatex %} under {% katex %}E_1{% endkatex %} with {% katex %}k{% endkatex %} (producing {% katex %}c_1{% endkatex %}), and then encrypts {% katex %}m{% endkatex %} under {% katex %}k'{% endkatex %} with {% katex %}E_2{% endkatex %} (producing {% katex %}c_2{% endkatex %}); the ciphertext is the pair {% katex %}(c_1, c_2){% endkatex %}. 

Its key space is {% katex %}\mathsf{CE}.\mathcal{K} = E_1.\mathcal{K}{% endkatex %} and its message space is {% katex %}\mathsf{CE}.\mathcal{M} = E_2.\mathcal{M}{% endkatex %}. The critical structural requirement is {% katex %}E_2.\mathcal{K} \subseteq E_1.\mathcal{M}{% endkatex %} — so that a freshly generated {% katex %}E_2{% endkatex %}-key can itself be treated as a message for {% katex %}E_1{% endkatex %}.

The theorem we prove is: if both {% katex %}E_1{% endkatex %} and {% katex %}E_2{% endkatex %} satisfy one-time secrecy, then {% katex %}\mathsf{CE}{% endkatex %} also satisfies one-time secrecy.

**Joy of Cryptography parallel.** This mirrors Claim 2.6.2 in *Joy of Cryptography* by Mike Rosulek, which proves the same result. It's helpful to get a good mental model of Rosulek's proof: replace the {% katex %}E_1{% endkatex %} encryption of {% katex %}k'{% endkatex %} with a random ciphertext (using {% katex %}E_1{% endkatex %}'s one-time secrecy), then replace the {% katex %}E_2{% endkatex %} encryption of {% katex %}m{% endkatex %} with a random ciphertext (using {% katex %}E_2{% endkatex %}'s one-time secrecy). At that point both components of the ciphertext are uniformly random and independent of {% katex %}m{% endkatex %}, so the combined ciphertext is uniformly random — which is exactly the random side of one-time secrecy for {% katex %}\mathsf{CE}{% endkatex %}. The FrogLang proof encodes this argument precisely and has the engine verify each step.

---

## 2. The primitive and the security game

Before looking at the construction, let us recall the objects the proof is built on: the **symmetric encryption primitive** that both {% katex %}E_1{% endkatex %}, {% katex %}E_2{% endkatex %}, and the composed {% katex %}\mathsf{CE}{% endkatex %} implement, and the **one-time secrecy** game we are proving about the composed scheme.

### Symmetric encryption primitive

Recall that a symmetric encryption scheme is a triple of algorithms over a key space {% katex %}\mathcal{K}{% endkatex %}, message space {% katex %}\mathcal{M}{% endkatex %}, and ciphertext space {% katex %}\mathcal{C}{% endkatex %}:

{% katex display %}
\begin{array}{l}
\mathsf{KeyGen}: () \to \mathcal{K} \\
\mathsf{Enc}: \mathcal{K} \times \mathcal{M} \to \mathcal{C} \\
\mathsf{Dec}: \mathcal{K} \times \mathcal{C} \to \mathcal{M} \cup \{\bot\} \quad \text{(deterministic)}
\end{array}
{% endkatex %}

The FrogLang primitive file is [`examples/joy/Primitives/SymEnc.primitive`](https://github.com/ProofFrog/examples/blob/main/joy/Primitives/SymEnc.primitive):

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;

    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    deterministic Message? Dec(Key k, Ciphertext c);
}
```

{: .note }
**Try it.** From the `examples/joy/` directory, run `proof_frog check Primitives/SymEnc.primitive` to type-check the primitive file. In the web editor, open the file and click **Type Check**.

The `deterministic` modifier on `Dec` matters to the engine: it lets the canonicalizer treat repeated `Dec` calls with the same arguments as the same value. `KeyGen` and `Enc` are non-deterministic: they may internally sample randomness and thus be probabilistic.

### One-time secrecy game

The security property we are proving — one-time secrecy ([*Joy of Cryptography* Definition 2.5.3](https://joyofcryptography.com/provsec/#sec.abstract-defs:~:text=Definition%202%2E5%2E3%20%28One%2Dtime%20secrecy)) — is phrased as a pair of games, {% katex %}\mathsf{Real}{% endkatex %} and {% katex %}\mathsf{Random}{% endkatex %}, over a single oracle {% katex %}\mathsf{ENC}{% endkatex %}. In the {% katex %}\mathsf{Real}{% endkatex %} game, {% katex %}\mathsf{ENC}(m){% endkatex %} generates a fresh key and returns a genuine encryption of {% katex %}m{% endkatex %}. In the {% katex %}\mathsf{Random}{% endkatex %} game, {% katex %}\mathsf{ENC}(m){% endkatex %} ignores {% katex %}m{% endkatex %} and returns a uniformly random ciphertext. A scheme has one-time secrecy if no adversary can distinguish these two games:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{Real}_E.\mathsf{ENC}(m)} \\
k \gets E.\mathsf{KeyGen}() \\
c \gets E.\mathsf{Enc}(k, m) \\
\text{return } c
\end{array} \qquad
\begin{array}{l}
\underline{\mathsf{Random}_E.\mathsf{ENC}(m)} \\
c \stackrel{\$}{\leftarrow} E.\mathcal{C} \\
\text{return } c
\end{array}
{% endkatex %}

The FrogLang security game file is [`examples/joy/Games/SymEnc/OneTimeSecrecy.game`](https://github.com/ProofFrog/examples/blob/main/joy/Games/SymEnc/OneTimeSecrecy.game):

```prooffrog
// Definition 2.5.3: One-time secrecy
// A scheme has one-time secrecy if encrypting any message produces
// a ciphertext indistinguishable from a uniformly random ciphertext.

import '../../Primitives/SymEnc.primitive';

Game Real(SymEnc E) {
    E.Ciphertext ENC(E.Message m) {
        E.Key k = E.KeyGen();
        E.Ciphertext c = E.Enc(k, m);
        return c;
    }
}

Game Random(SymEnc E) {
    E.Ciphertext ENC(E.Message m) {
        E.Ciphertext c <- E.Ciphertext;
        return c;
    }
}

export as OneTimeSecrecy;
```

{: .note }
**Try it.** From the `examples/joy/` directory, run `proof_frog check Games/SymEnc/OneTimeSecrecy.game` to type-check the game file, or open it in the web editor and click **Type Check**.

The `<- E.Ciphertext` syntax denotes uniform sampling from the set `E.Ciphertext` (corresponding to {% katex %}\stackrel{\$}{\leftarrow}{% endkatex %} in the math). Notice that the games only give the adversary oracle access to `Enc` — not `Dec`, since we don't allow chosen ciphertext attacks. 

One subtlety to remember is that the semantics of security experiments in Joy of Cryptography, and thus ProofFrog, let the adversary call game oracles multiple times. So how can we say that this game models "one-time" secrecy? Because the `ENC` oracle samples a fresh key every time, each encryption key is used only once. This is what makes it *one-time* secrecy rather than CPA security.

---

## 3. The scheme

{% katex %}\mathsf{ChainedEncryption}{% endkatex %} takes two symmetric encryption schemes {% katex %}E_1, E_2{% endkatex %} and produces a new symmetric encryption scheme whose keys come from {% katex %}E_1{% endkatex %}, whose messages come from {% katex %}E_2{% endkatex %}, and whose ciphertexts are pairs. It requires {% katex %}E_2.\mathcal{K} \subseteq E_1.\mathcal{M}{% endkatex %} so that a freshly sampled {% katex %}E_2{% endkatex %} key can be encrypted as a message under {% katex %}E_1{% endkatex %}:

The sets need for the scheme definition are:

{% katex display %}
\begin{array}{l}
\mathcal{K} = E_1.\mathcal{K}, \qquad \mathcal{M} = E_2.\mathcal{M}, \qquad \mathcal{C} = E_1.\mathcal{C} \times E_2.\mathcal{C}
\end{array}
{% endkatex %}

The algorithms comprising the scheme are:

{% katex display %}
\begin{array}{l}
\underline{\mathsf{KeyGen}()} \\
k \gets E_1.\mathsf{KeyGen}() \\
\text{return } k
\end{array}
\quad
\begin{array}{l}
\underline{\mathsf{Enc}(k, m)} \\
k' \gets E_2.\mathsf{KeyGen}() \\
c_1 \gets E_1.\mathsf{Enc}(k, k') \\
c_2 \gets E_2.\mathsf{Enc}(k', m) \\
\text{return } (c_1, c_2)
\end{array}
\quad
\begin{array}{l}
\underline{\mathsf{Dec}(k, (c_1, c_2))} \\
k' \gets E_1.\mathsf{Dec}(k, c_1) \\
\text{if } k' = \bot: \text{ return } \bot \\
\text{return } E_2.\mathsf{Dec}(k', c_2)
\end{array}
{% endkatex %}

The FrogLang scheme file is [`examples/joy/Schemes/SymEnc/ChainedEncryption.scheme`](https://github.com/ProofFrog/examples/blob/main/joy/Schemes/SymEnc/ChainedEncryption.scheme):

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

{: .note }
**Try it.** From the `examples/joy/` directory, run `proof_frog check Schemes/SymEnc/ChainedEncryption.scheme` to type-check the scheme file, or open it in the web editor and click **Type Check**.

The `requires` clause is a structural constraint: `E2.Key subsets E1.Message`. Without this, the scheme cannot instantiate `E1.Enc(k, kprime)` because `kprime` has type `E2.Key` but `E1.Enc` expects an `E1.Message`. The `requires` clause makes this subtype relationship explicit and lets the type checker accept the call.

The `Ciphertext` type is a **tuple**: `[E1.Ciphertext, E2.Ciphertext]`. In FrogLang, `[T1, T2]` is the two-component product type; the components are accessed by constant index: `c[0]` and `c[1]`. The `Dec` method extracts `c[0]` (the `E1` ciphertext), tries to decrypt it with `E1.Dec`, and uses the recovered `kprime` to decrypt `c[1]` with `E2.Dec`. Either decryption step can fail, hence the `E2.Key?` intermediate type and the `None` check.

For the full syntax of `Scheme`, the `requires` clause, tuple types, and method modifiers, see the [Schemes section of the language reference]({% link manual/language-reference/schemes.md %}).

---

## 4. The proof structure

The `games:` block lists six game steps, producing five hops. The overall shape:

- **Step 1**: `OneTimeSecrecy(CE).Real against OneTimeSecrecy(CE).Adversary`
  The starting point: the Real side of the `OneTimeSecrecy` experiment for `CE`, omposed with a generic adversary.

- **Step 2**: `OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Interchangeability hop. The game from step 1 is rewritten in terms of reduction `R1` composed with the Real side of `E1`'s one-time secrecy game. The engine verifies that these two representations are code-equivalent.

- **Step 3**: `OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Assumption hop (Real to Random for `E1`). Justified by `OneTimeSecrecy(E1)` in `assume:`. The engine accepts this without code-equivalence checking since it's anassumption listed in the theorem preconditions.

- **Step 4**: `OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Interchangeability hop. After `E1`'s encryption has been replaced with random, the code is reorganized through reduction `R2`, which hands `E2`'s encryption off to the `E2` challenger. Again engine-verified by code equivalence.

- **Step 5**: `OneTimeSecrecy(E2).Random compose R2(CE, E1, E2) against OneTimeSecrecy(CE).Adversary`
  Assumption hop (Real to Random for `E2`). Justified by `OneTimeSecrecy(E2)` in `assume:`.

- **Step 6**: `OneTimeSecrecy(CE).Random against OneTimeSecrecy(CE).Adversary`
  The ending point: the Random side of the `OneTimeSecrecy` experiment for `CE`. Once both components `c1` and `c2` are uniformly random (component-wise), the joint pair is also uniformly random, which equals a direct sample from `CE.Ciphertext`. The engine verifies this final equivalence.

The proof proceeds in two phases. In the first phase, hops 1 and 2 handle `E1`'s encryption (replacing `c1` with a random ciphertext) by reducing to `OneTimeSecrecy(E1)` via reduction `R1`. In the second phase, hops 4 and 5 handle `E2`'s encryption (replacing `c2` with a random ciphertext) by reducing to `OneTimeSecrecy(E2)` via reduction `R2`. Hop 3 is the pivot interchangeability hop that rewrites the halfway state from the `R1`/`E1.Random` form into the `R2`/`E2.Real` form. Steps 1 through 4 are the first four-step reduction pattern (for `E1`, via `R1`); steps 3 through 6 are the second (for `E2`, via `R2`). The two patterns share step 4 (which serves as both the exit step `G_B` of the first pattern and the entry step `G_A` of the second), so the six game steps cover two four-step patterns with one shared boundary. The two halves of the proof reduce to one-time secrecy of the two underlying schemes, but they do so in different ways.

---

## 5. The four-step reduction pattern, walked through

The standard way to invoke an assumption in a game-hopping proof is the four-step reduction pattern. Suppose the proof is at some game {% katex %}G_A{% endkatex %} and wants to transition to a game {% katex %}G_B{% endkatex %} by appealing to a security assumption on some underlying primitive `Security` (whose two sides are `Security.Real` and `Security.Random`), via a reduction `R`. The pattern occupies four consecutive entries in the `games:` list:

1. {% katex %}G_A{% endkatex %} — some starting game.
2. `Security.Real compose R` — the engine verifies, by code equivalence, that this is interchangeable with {% katex %}G_A{% endkatex %}.
3. `Security.Random compose R` — the **assumption hop**. The engine accepts this transition without checking equivalence because `Security` is in the proof's `assume:` block, so its `Real` and `Random` sides are indistinguishable by hypothesis.
4. {% katex %}G_B{% endkatex %} — the engine verifies, by code equivalence, that this is interchangeable with `Security.Random compose R`.

So the assumption hop (steps 2 → 3) is sandwiched between two engine-verified interchangeability hops (1 → 2 and 3 → 4). The role of `R` is to bridge between the "high-level" games {% katex %}G_A{% endkatex %} and {% katex %}G_B{% endkatex %} and the lower-level `Security` game whose assumption we want to use.

Hops 1 to 3 in this proof are the first complete instance of the pattern, applied to `E1`. Here are the four lines exactly as they appear in [`examples/joy/Proofs/Ch2/ChainedEncryptionSecure.proof`](https://github.com/ProofFrog/examples/blob/main/joy/Proofs/Ch2/ChainedEncryptionSecure.proof):


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

1. **`OneTimeSecrecy(CE).Real against ...`** — This is {% katex %}G_A{% endkatex %}. It is the starting game for the theorem. The engine will verify that it is code-equivalent to step 2.

2. **`OneTimeSecrecy(E1).Real compose R1(CE, E1, E2) against ...`** — This is `Security.Real compose R`. The engine inlines `R1` into `OneTimeSecrecy(E1).Real` and verifies that the result is code-equivalent to step 1. This hop is an *interchangeability hop*: the engine checks it automatically.

3. **`OneTimeSecrecy(E1).Random compose R1(CE, E1, E2) against ...`** — This is `Security.Random compose R`. The transition from step 2 to step 3 is the **assumption hop**: the engine accepts it because `OneTimeSecrecy(E1)` appears in the `assume:` block. No code equivalence is checked; the indistinguishability of `E1.Real` and `E1.Random` is taken as given.

4. **`OneTimeSecrecy(E2).Real compose R2(CE, E1, E2) against ...`** — This is {% katex %}G_B{% endkatex %}, and simultaneously the start of the second four-step pattern. The engine verifies that `OneTimeSecrecy(E1).Random compose R1` is code-equivalent to `OneTimeSecrecy(E2).Real compose R2` — two composed forms that both represent the "halfway" state where `c1` is random and `c2` is still real.

The structure is therefore:

- Lines 1 and 2: engine-verified interchangeability (step into R1 via E1.Real).
- Lines 2 and 3: assumption hop (E1.Real to E1.Random, justified by `OneTimeSecrecy(E1)`).
- Lines 3 and 4: engine-verified interchangeability (transition from R1/E1.Random to R2/E2.Real).

For the full details on the syntax of ProofFrog proofs, see the [proofs section of the language reference]({% link manual/language-reference/proofs.md %}). The [canonicalization]({% link manual/canonicalization.md %}) page explains the canonicalization steps the engine uses to verify code equivalence.

---

## 6. The first reduction in detail

Reduction {% katex %}R_1{% endkatex %} adapts a {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}){% endkatex %} adversary so it can play against a {% katex %}\mathsf{OneTimeSecrecy}(E_1){% endkatex %} challenger. In math, it exposes a single {% katex %}\mathsf{ENC}{% endkatex %} oracle that generates its own {% katex %}E_2{% endkatex %}-key, delegates the {% katex %}E_1{% endkatex %} encryption of {% katex %}k'{% endkatex %} to its external challenger's $\mathsf{ENC}$ oracle, and finishes the {% katex %}E_2{% endkatex %} layer itself:

{% katex display %}
\begin{array}{l}
\underline{R_1.\mathsf{ENC}(m)} \\
k' \gets E_2.\mathsf{KeyGen}() \\
c_1 \gets \mathsf{challenger}.\mathsf{ENC}(k') \\
c_2 \gets E_2.\mathsf{Enc}(k', m) \\
\text{return } (c_1, c_2)
\end{array}
{% endkatex %}

When the external challenger is {% katex %}\mathsf{Real}_{E_1}{% endkatex %}, the inlined body computes {% katex %}c_1 = E_1.\mathsf{Enc}(k, k'){% endkatex %} for a fresh {% katex %}k{% endkatex %} — matching `ChainedEncryption.Enc` exactly. When the challenger is {% katex %}\mathsf{Random}_{E_1}{% endkatex %}, {% katex %}c_1{% endkatex %} becomes a uniform sample from {% katex %}E_1.\mathcal{C}{% endkatex %}.

In FrogLang:

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

{: .note }
**Try it.** {% katex %}R_1{% endkatex %} lives inside `Proofs/Ch2/ChainedEncryptionSecure.proof` along with the rest of the proof. From the `examples/joy/` directory, run `proof_frog prove Proofs/Ch2/ChainedEncryptionSecure.proof` to verify the whole proof, or open the file in the web editor and click **Run Proof**. See [§9 Verifying](#9-verifying) for the expected output.

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

When the `E1` challenger is in Real mode, the body of `R1 compose OneTimeSecrecy(E1).Real` is code-equivalent to the direct `ChainedEncryption.Enc` logic inside `OneTimeSecrecy(CE).Real`. This is why hop 1-to-2 passes. When the `E1` challenger switches to Random mode (returning a uniform `c1` instead), the body of `R1 compose OneTimeSecrecy(E1).Random` is the halfway game where `c1` is random — described in the next section.

---

## 7. The intermediate halfway game

After the assumption hop on {% katex %}E_1{% endkatex %} (the transition from step 2 to step 3 of the games list), the proof has reached a halfway state. Conceptually, this is an *intermediate game* {% katex %}G_{\mathsf{mid}}{% endkatex %} sitting between {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}).\mathsf{Real}{% endkatex %} and {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}).\mathsf{Random}{% endkatex %}, in which {% katex %}c_1{% endkatex %} has already been replaced by a uniform random sample but {% katex %}c_2{% endkatex %} is still a real {% katex %}E_2{% endkatex %} encryption of {% katex %}m{% endkatex %}:

{% katex display %}
\begin{array}{l}
\underline{G_{\mathsf{mid}}.\mathsf{ENC}(m)} \\
c_1 \stackrel{\$}{\leftarrow} E_1.\mathcal{C} \\
k' \gets E_2.\mathsf{KeyGen}() \\
c_2 \gets E_2.\mathsf{Enc}(k', m) \\
\text{return } (c_1, c_2)
\end{array}
{% endkatex %}

This game doesn't need to be written down explicitly in `ChainedEncryptionSecure.proof`, although ProofFrog will let you write it down if you want it as a helpful reminder. Regardless, it shows up implicitly *twice*, in two different syntactic forms:

- as **{% katex %}R_1 \circ \mathsf{OneTimeSecrecy}(E_1).\mathsf{Random}{% endkatex %}** (step 3): {% katex %}R_1{% endkatex %} samples its own {% katex %}k'{% endkatex %}, calls `challenger.ENC(k')`, and the random-side challenger returns a uniform {% katex %}E_1{% endkatex %}-ciphertext, ignoring {% katex %}k'{% endkatex %};
- as **{% katex %}R_2 \circ \mathsf{OneTimeSecrecy}(E_2).\mathsf{Real}{% endkatex %}** (step 4): {% katex %}R_2{% endkatex %} samples {% katex %}c_1{% endkatex %} directly from {% katex %}E_1.\mathcal{C}{% endkatex %}, then asks the real-side {% katex %}E_2{% endkatex %} challenger to encrypt {% katex %}m{% endkatex %}.

Both inline to the same {% katex %}G_{\mathsf{mid}}{% endkatex %} after canonicalization. That is exactly what makes the pivot hop (step 3 → step 4) an interchangeability hop the engine can verify automatically — and it is the technical reason a single proof can chain two assumptions, on {% katex %}E_1{% endkatex %} and on {% katex %}E_2{% endkatex %}, without ever introducing an explicit intermediate game.

It is also instructive to see what {% katex %}G_{\mathsf{mid}}{% endkatex %} *looks like* compared to the two endpoints of the proof. The starting game {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}).\mathsf{Real}{% endkatex %} samples a fresh {% katex %}E_1{% endkatex %}-key {% katex %}k{% endkatex %} and computes {% katex %}c_1 = E_1.\mathsf{Enc}(k, k'){% endkatex %}; in {% katex %}G_{\mathsf{mid}}{% endkatex %} that whole computation has collapsed into the single uniform sample {% katex %}c_1 \stackrel{\$}{\leftarrow} E_1.\mathcal{C}{% endkatex %}. The ending game {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}).\mathsf{Random}{% endkatex %} will further collapse the {% katex %}c_2{% endkatex %} branch the same way (using the {% katex %}E_2{% endkatex %} assumption in the second four-step pattern). So the proof's overall trajectory is: replace {% katex %}c_1{% endkatex %} with a uniform sample (via {% katex %}E_1{% endkatex %}'s assumption), then replace {% katex %}c_2{% endkatex %} with a uniform sample (via {% katex %}E_2{% endkatex %}'s assumption), at which point both components of the ciphertext are uniform and the result is the random side of one-time secrecy for {% katex %}\mathsf{CE}{% endkatex %}.

---

## 8. The second reduction in detail

Reduction {% katex %}R_2{% endkatex %} starts from the intermediate halfway game {% katex %}G_{\mathsf{mid}}{% endkatex %} of §7 and uses the assumption on {% katex %}E_2{% endkatex %} to collapse {% katex %}c_2{% endkatex %} into a uniform sample as well. To do that it must play against a {% katex %}\mathsf{OneTimeSecrecy}(E_2){% endkatex %} challenger; note that, unlike {% katex %}R_1{% endkatex %}, it has no {% katex %}E_1{% endkatex %} challenger available — the {% katex %}\mathsf{OneTimeSecrecy}(E_1){% endkatex %} assumption has already been consumed in the earlier assumption hop — and so it must sample {% katex %}c_1{% endkatex %} directly from {% katex %}E_1.\mathcal{C}{% endkatex %} itself:

{% katex display %}
\begin{array}{l}
\underline{R_2.\mathsf{ENC}(m)} \\
c_1 \stackrel{\$}{\leftarrow} E_1.\mathcal{C} \\
c_2 \gets \mathsf{challenger}.\mathsf{ENC}(m) \\
\text{return } (c_1, c_2)
\end{array}
{% endkatex %}

When the external challenger is {% katex %}\mathsf{Real}_{E_2}{% endkatex %}, the body of {% katex %}R_2{% endkatex %} is exactly the intermediate game {% katex %}G_{\mathsf{mid}}{% endkatex %} from §7 — uniform {% katex %}c_1{% endkatex %} and a real {% katex %}E_2{% endkatex %} encryption of {% katex %}m{% endkatex %}. This is what makes the pivot interchangeability hop (step 3 → step 4) go through. When the challenger then switches to {% katex %}\mathsf{Random}_{E_2}{% endkatex %} (the assumption hop, step 4 → step 5), {% katex %}c_2{% endkatex %} becomes a uniform sample as well, and {% katex %}R_2 \circ \mathsf{OneTimeSecrecy}(E_2).\mathsf{Random}{% endkatex %} matches {% katex %}\mathsf{OneTimeSecrecy}(\mathsf{CE}).\mathsf{Random}{% endkatex %}, finishing the proof.

In FrogLang:

```prooffrog
// R2: c1 is already random; delegates E2 encryption to the challenger
Reduction R2(ChainedEncryption CE, SymEnc E1, SymEnc E2) compose OneTimeSecrecy(E2) against OneTimeSecrecy(CE).Adversary {
    CE.Ciphertext ENC(CE.Message m) {
        E1.Ciphertext c1 <- E1.Ciphertext;
        E2.Ciphertext c2 = challenger.ENC(m);
        E2.Ciphertext c2prime <- E2.Ciphertext;
        return [c1, c2];
    }
}
```

Unlike `R1`, `R2` does not have any `E1` challenger in scope — the proof has already used up `OneTimeSecrecy(E1)` in the earlier assumption hop. The reduction must therefore produce `c1` by itself: it samples `c1` uniformly from `E1.Ciphertext` directly. This is why the halfway state between hops 3 and 4 (the step 4 entry point) canonicalizes to "c1 is a fresh uniform sample" — exactly the state `R1 compose OneTimeSecrecy(E1).Random` leaves us in at step 3. The engine verifies that the two forms agree.

The body then asks the `E2` challenger to encrypt `m` (via `challenger.ENC(m)`) and returns `[c1, c2]`. When the `E2` challenger is in Real mode, `c2 = E2.Enc(k_fresh, m)` for a freshly sampled key, so the overall output matches the halfway state where `c1` is random and `c2` is a real encryption of `m`. When the `E2` challenger switches to Random mode, `c2` becomes a uniform `E2.Ciphertext`, and the output matches the final game `OneTimeSecrecy(CE).Random` where both components are uniformly random.

**A note on `c2prime`.** Line 28 of the proof file samples `E2.Ciphertext c2prime <- E2.Ciphertext;` but never uses the result — `c2prime` is not returned, and no subsequent statement reads it. This is dead code and has no effect on the proof; the canonicalization pipeline eliminates unused samples when comparing the reduction's output to the surrounding games. You can mentally ignore the line when reading the reduction.

---

## 9. Verifying the proof in ProofFrog

{: .important }
**Activate your Python virtual environment first** if it is not already active in this terminal: `source .venv/bin/activate` on macOS/Linux (bash/zsh), `source .venv/bin/activate.fish` on fish, or `.venv\Scripts\Activate.ps1` on Windows PowerShell. See [Installation]({% link manual/installation.md %}).

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

## What comes next
{: .no_toc }

The next worked example, [chosen-plaintext attack security of hybrid public key encryption (the KEM-DEM construction)]({% link manual/worked-examples/kemdem-cpa.md %}), takes us further into game-hopping proofs and ProofFrog. It uses two independent primitives (a KEM and a symmetric cipher), and two reductions that operate in opposite directions of the game sequence. After seeing ChainedEncryption you have all the conceptual tools needed to read it; the KEM-DEM example shows how those tools combine at a scale closer to what real-world proof engineering looks like.
