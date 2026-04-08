---
title: Tutorial Part 2 — OTP has one-time secrecy
layout: default
parent: Manual
nav_order: 3
---

# Tutorial Part 2 — OTP has one-time secrecy

In Tutorial Part 1 you ran an existing proof that OTP has one-time secrecy, broke it on purpose, and fixed it again. Now you will write that exact proof from scratch — all four files of it. By the end of this tutorial you will have defined a cryptographic primitive, a security game, a concrete scheme, and a game-hopping proof file, and you will have seen each one type-check or prove green as you finish it. We follow Joy of Cryptography §2.5 closely; if you have Rosulek's textbook handy, keep it open. Everything you write here is already in the `examples/joy/` directory, so you can always peek at the finished version if you get stuck.

---

## Step 1 — Define the SymEnc primitive

**Joy of Cryptography parallel:** This step encodes Definition 2.5.1 from [Joy of Cryptography](https://joyofcryptography.com/), which defines what a symmetric encryption scheme is: a key space, a message space, a ciphertext space, and three algorithms (KeyGen, Enc, Dec).

### What a primitive is

A **primitive** in FrogLang is a named interface: it declares what sets and methods a cryptographic scheme must provide, without saying anything about how those methods work. Think of it as the abstract type signature that any concrete scheme (like OTP) must satisfy. Primitives cannot call each other's methods; they only declare method signatures.

### Building the file, line by line

Create a new file at the path `examples/joy/Primitives/SymEnc.primitive`. (In the web editor, right-click the `Primitives/` folder and choose New File.)

Start with the opening line:

```prooffrog
Primitive SymEnc(Set MessageSpace, Set CiphertextSpace, Set KeySpace) {
```

The keyword `Primitive` introduces a primitive definition. The name `SymEnc` is what other files will use to refer to it. The parenthesized list `(Set MessageSpace, Set CiphertextSpace, Set KeySpace)` declares three **parameters** of kind `Set` — the caller must supply the three spaces when instantiating a scheme. Parameters of kind `Set` represent abstract sets; they have no internal structure until a scheme binds them to concrete types.

Next, declare the three named fields:

```prooffrog
    Set Message = MessageSpace;
    Set Ciphertext = CiphertextSpace;
    Set Key = KeySpace;
```

These `Set X = Y;` lines create named **slots** that the rest of the world can refer to as `E.Message`, `E.Ciphertext`, and `E.Key` once a scheme `E` extends this primitive. The right-hand side binds the slot to the corresponding parameter. Without these lines, the three parameter names would not be accessible outside the primitive block.

Now declare the three method signatures:

```prooffrog
    Key KeyGen();
    Ciphertext Enc(Key k, Message m);
    deterministic Message? Dec(Key k, Ciphertext c);
```

Primitives declare **method signatures only** — there are no method bodies here. Every scheme that extends `SymEnc` must implement all three methods with exactly these signatures.

Two new constructs appear here:

- `Message?` — the `?` suffix denotes a **nullable** (optional) type. `Dec` returns either a `Message` or `None`; decryption is allowed to fail if the ciphertext is invalid. A scheme returning plain `Message` where the primitive declared `Message?` is a type mismatch the engine will catch.
- `deterministic` — this modifier on `Dec` tells the engine that `Dec` always returns the same output for the same inputs. We will come back to why this matters in Step 4 when the proof engine uses it to justify certain algebraic simplifications.

Close the block:

```prooffrog
}
```

### Complete file

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

### Check it

In the web editor, open `Primitives/SymEnc.primitive` and click **Check** in the toolbar. You should see:

```
Type checking...
Type checking passed.
```

{: .note }
**CLI alternative.** From the `examples/joy/` directory:
```bash
proof_frog check Primitives/SymEnc.primitive
```

### What if it fails

**Parse error / unexpected token.** The most common cause is a missing semicolon. Every field declaration and every method signature must end with `;`. The error message will cite a line number; look there first.

**`Message` cannot be used where `Message?` is expected.** If you wrote `Message Dec(...)` instead of `Message? Dec(...)`, the type-checker will flag a mismatch when you later try to run the proof. Add the `?`.

---

## Step 2 — Define the one-time secrecy game

**Joy of Cryptography parallel:** This step encodes Definition 2.5.3 from [Joy of Cryptography](https://joyofcryptography.com/), which defines one-time secrecy as the indistinguishability of an encryption oracle from a random-ciphertext oracle.

### What a security game is

A **security game** in FrogLang is always a *pair* of games exported under a single name. The adversary is given access to one of the two games but not told which one; security means the adversary cannot reliably distinguish them. This is the left/right (or Real/Random) formulation of indistinguishability used throughout Joy of Cryptography.

The engine requires both games in a pair to expose the exact same method signatures — same names, same parameter types, same return types. The adversary interacts with both games through the same interface; only the internals differ.

### Building the file, line by line

Create `examples/joy/Games/SymEnc/OneTimeSecrecy.game`.

Start with the import:

```prooffrog
import '../../Primitives/SymEnc.primitive';
```

The `import` keyword loads another file and makes its definitions available in the current file. The path is **relative to the directory containing the importing file** — so `../../Primitives/SymEnc.primitive` navigates up two levels from `Games/SymEnc/` to `examples/joy/`, then down into `Primitives/`. This is the same path rule for all four file types.

Now write the first game:

```prooffrog
Game Real(SymEnc E) {
    E.Ciphertext ENC(E.Message m) {
        E.Key k = E.KeyGen();
        E.Ciphertext c = E.Enc(k, m);
        return c;
    }
}
```

The `Game` keyword introduces a game definition. `Real` is its name. The parameter `(SymEnc E)` says this game is parameterized by a scheme `E` that implements the `SymEnc` primitive. Inside the game there is one oracle method, `ENC`, which samples a fresh key, encrypts the adversary's message under that key, and returns the ciphertext.

Now write the second game:

```prooffrog
Game Random(SymEnc E) {
    E.Ciphertext ENC(E.Message m) {
        E.Ciphertext c <- E.Ciphertext;
        return c;
    }
}
```

The `<-` operator is **uniform random sampling**. The line `E.Ciphertext c <- E.Ciphertext;` samples a uniformly random element from `E.Ciphertext` and binds it to `c`. The adversary's message `m` is accepted but not used — the ciphertext is chosen at random regardless of the plaintext. This captures the intuition that a secure encryption scheme's ciphertexts look random.

Notice that both `Real` and `Random` expose an oracle named `ENC` with the same signature: `E.Ciphertext ENC(E.Message m)`. This is mandatory — the engine will reject a game pair with mismatched oracle signatures.

Finally, export the pair under a single name:

```prooffrog
export as OneTimeSecrecy;
```

The `export as` line gives the two-game pair a single name — `OneTimeSecrecy` — that proof files use when stating a theorem. After this line, `OneTimeSecrecy(E).Real` and `OneTimeSecrecy(E).Random` refer to the two games.

### Complete file

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

### Check it

Click **Check** in the web editor, or run:

```bash
proof_frog check Games/SymEnc/OneTimeSecrecy.game
```

Expected output:

```
Type checking...
Type checking passed.
```

### What if it fails: mismatched oracle signatures

The most instructive mistake here is giving the two games oracles with different signatures. For example, suppose you accidentally added an extra parameter to `Random.ENC`:

```prooffrog
// Wrong: extra parameter that Real.ENC does not have
E.Ciphertext ENC(E.Message m, E.Message extra) {
```

The engine rejects this at the type-checking stage with an error like:

```
OneTimeSecrecy.game:17:5: error: Method 'ENC' has different signatures
  in Random and Real: ENC(E.Message m, E.Message extra) vs ENC(E.Message m)
```

The fix is to make both oracles identical: same name, same parameters, same return type. The engine cares only about signatures here, not bodies.

A second common mistake is forgetting the `export as OneTimeSecrecy;` line at the bottom. Without it the file is a valid collection of games but not a named security property, and any proof that tries to reference `OneTimeSecrecy` will fail to find it.

---

## Step 3 — Define the OTP scheme

**Joy of Cryptography parallel:** This step implements Construction 1.2.1 from [Joy of Cryptography](https://joyofcryptography.com/), the One-Time Pad.

### What a scheme is

A **scheme** is a concrete implementation of a primitive. Where the primitive declared method *signatures*, the scheme provides *bodies*. A scheme must implement every method the primitive declares, with exactly the same modifiers and types.

### Building the file, line by line

Create `examples/joy/Schemes/SymEnc/OTP.scheme`.

Start with the import:

```prooffrog
import '../../Primitives/SymEnc.primitive';
```

Same relative-path rule as before: up two levels from `Schemes/SymEnc/` to `examples/joy/`, then down into `Primitives/`.

Declare the scheme:

```prooffrog
Scheme OTP(Int lambda) extends SymEnc {
```

`Scheme OTP(Int lambda)` says this is a scheme named `OTP` parameterized by a single integer `lambda`. The **security parameter** `lambda` is the bit length of the key (and message and ciphertext for OTP). In a real proof, `lambda` appears as a free variable; the scheme is instantiated for a specific value when the proof's `let:` block binds it.

`extends SymEnc` links this scheme to the `SymEnc` primitive. The type checker will verify that `OTP` satisfies every declaration in `SymEnc`.

Now bind the three set slots:

```prooffrog
    Set Key = BitString<lambda>;
    Set Message = BitString<lambda>;
    Set Ciphertext = BitString<lambda>;
```

`BitString<lambda>` is the built-in type of bit strings of length exactly `lambda`. For OTP, keys, messages, and ciphertexts are all `lambda`-bit strings. These assignments satisfy the three `Set` slots declared in the primitive — the engine maps `E.Key` to `BitString<lambda>`, and so on.

Write the `KeyGen` method:

```prooffrog
    Key KeyGen() {
        Key k <- Key;
        return k;
    }
```

`Key k <- Key;` samples a uniformly random element of `Key` (which is `BitString<lambda>`). The `<-` operator always means uniform random sampling; there is no other form of randomness in FrogLang.

Write the `Enc` method:

```prooffrog
    Ciphertext Enc(Key k, Message m) {
        return k + m;
    }
```

{: .note }
**Gotcha: `+` on bit strings is XOR, not addition.** When applied to two values of type `BitString<n>`, the `+` operator computes their bitwise exclusive-or. This is the most common surprise for new FrogLang users. Integer addition on `Int` values uses `+` in the usual sense, but whenever both operands are bit strings, `+` means XOR. The OTP ciphertext `k + m` is therefore `k XOR m`.

Write the `Dec` method:

```prooffrog
    deterministic Message? Dec(Key k, Ciphertext c) {
        return k + c;
    }
```

Two things to note:

- The `deterministic` modifier must appear here because the primitive declared `Dec` with `deterministic`. The type checker requires the scheme to declare exactly the same modifiers as the primitive; you cannot add or remove them. For `Dec`, `deterministic` is correct because XOR of two fixed bit strings always gives the same result.
- The return type is `Message?`, matching the primitive. OTP decryption never actually fails (XOR is always defined), but the primitive contract requires the possibility of failure to be expressed in the type.

Close the block:

```prooffrog
}
```

### Complete file

```prooffrog
// Construction 1.2.1: One-Time Pad
// Encryption: C = K xor M
// Decryption: M = K xor C

import '../../Primitives/SymEnc.primitive';

Scheme OTP(Int lambda) extends SymEnc {
    Set Key = BitString<lambda>;
    Set Message = BitString<lambda>;
    Set Ciphertext = BitString<lambda>;

    Key KeyGen() {
        Key k <- Key;
        return k;
    }

    Ciphertext Enc(Key k, Message m) {
        return k + m;
    }

    deterministic Message? Dec(Key k, Ciphertext c) {
        return k + c;
    }
}
```

### Check it

Click **Check** in the web editor, or run:

```bash
proof_frog check Schemes/SymEnc/OTP.scheme
```

Expected output:

```
Type checking...
Type checking passed.
```

### What if it fails

**Scheme does not correctly implement primitive: ...** If you omit one of the three `Set X = ...;` lines, or use the wrong type for a method parameter, the engine reports which part of the primitive is not satisfied. The error names both the scheme and the primitive so you can compare them side by side.

**Type mismatch on `+`.** If you write `return k + m;` where `k` or `m` has type `Int` instead of `BitString<lambda>`, the engine will complain about a type mismatch. Check that your `Set Key = BitString<lambda>;` lines are present and spelled correctly.

**Missing `deterministic` modifier.** If you write `Message? Dec(...)` without `deterministic`, the type checker will report that the modifier does not match the primitive's declaration. Copy the modifier exactly.

---

## Step 4 — Write the proof

**Joy of Cryptography parallel:** This step carries out Example 2.5.4 from [Joy of Cryptography](https://joyofcryptography.com/), which proves that OTP has one-time secrecy via a single-hop game sequence.

### What a proof file is

A **proof file** assembles the three files you just wrote into a game-hopping argument. It declares the concrete scheme being studied, states the security theorem, and lists a sequence of games that walks from one side of the theorem to the other. The engine checks that each adjacent pair of games in the sequence is interchangeable — that is, equivalent under the semantics of FrogLang.

### Building the file, line by line

Create `examples/joy/Proofs/Ch2/OTPSecure.proof`.

Start with the imports:

```prooffrog
import '../../Schemes/SymEnc/OTP.scheme';
import '../../Games/SymEnc/OneTimeSecrecy.game';
```

Proof files import schemes and games. They do not need to import the primitive directly — the scheme already imports it. The paths are again relative to the directory containing the proof file, `Proofs/Ch2/`.

Now write the `proof:` section marker:

```prooffrog
proof:
```

The `proof:` keyword is a section divider that separates the imports and top-level declarations from the proof body. Everything after it describes the proof itself.

Write the `let:` block:

```prooffrog
let:
    Int lambda;
    OTP E = OTP(lambda);
```

The `let:` block declares the variables and scheme instances used in the proof.

- `Int lambda;` declares `lambda` as a free integer variable — the security parameter. It is not assigned a concrete value; the proof holds for all values of `lambda`.
- `OTP E = OTP(lambda);` instantiates the OTP scheme with parameter `lambda` and names the resulting instance `E`. From this point on, `E` refers to OTP, and expressions like `E.Key`, `E.Message`, `OneTimeSecrecy(E).Real` all expand through this binding.

Write the `assume:` block:

```prooffrog
assume:
```

The `assume:` block lists security assumptions that the proof relies on — for example, "PRF security of F" in a proof that uses a pseudorandom function. For OTP, the block is **empty**. OTP's one-time secrecy is **information-theoretically secure**: the proof holds unconditionally, with no computational assumptions. This is unusual and worth noticing. Most proofs of real-world schemes have non-trivial `assume:` blocks; OTP does not.

Write the `theorem:` block:

```prooffrog
theorem:
    OneTimeSecrecy(E);
```

The `theorem:` block states what we are proving: that the scheme `E` (our OTP instance) satisfies the security property `OneTimeSecrecy`. The engine will check that the `games:` sequence below starts at one side of `OneTimeSecrecy(E)` and ends at the other.

Write the `games:` block:

```prooffrog
games:
    OneTimeSecrecy(E).Real against OneTimeSecrecy(E).Adversary;

    OneTimeSecrecy(E).Random against OneTimeSecrecy(E).Adversary;
```

The `games:` block is the heart of the proof. Each line is a **game step** of the form `<challenger> against <adversary>;`. The engine processes adjacent pairs and checks that each transition is valid.

- The first step must be one side of the theorem (`OneTimeSecrecy(E).Real` here), and the last step must be the other side (`OneTimeSecrecy(E).Random`).
- `OneTimeSecrecy(E).Adversary` is the adversary interface — it is automatically derived from the oracle signatures declared in the game pair.
- There is a single hop here, from `Real` to `Random`. The engine verifies this hop by inlining the OTP scheme into both games and checking that the resulting code is equivalent. After inlining, both games reduce to sampling a uniform random bit string and returning it: in `Real`, `k` is uniform and `k + m` is uniform; in `Random`, the ciphertext is sampled directly as uniform. These are interchangeable, so the hop passes.

### Complete file

```prooffrog
// Example 2.5.4: OTP has one-time secrecy.
// The ciphertext k + m is uniformly distributed when k is uniform,
// so the Real and Random games are interchangeable in one step.

import '../../Schemes/SymEnc/OTP.scheme';
import '../../Games/SymEnc/OneTimeSecrecy.game';

proof:

let:
    Int lambda;
    OTP E = OTP(lambda);

assume:

theorem:
    OneTimeSecrecy(E);

games:
    OneTimeSecrecy(E).Real against OneTimeSecrecy(E).Adversary;

    OneTimeSecrecy(E).Random against OneTimeSecrecy(E).Adversary;
```

### Prove it

<!-- TODO screenshot: green Prove output showing "Proof Succeeded!" -->

Click **Prove** in the web editor. The output panel should turn green and report:

```
Type checking...

Theorem: OneTimeSecrecy(E)

  Step 1/1  OneTimeSecrecy(E).Real -> OneTimeSecrecy(E).Random ... ok

  Step  Hop                                                 Type         Result
  ----  --------------------------------------------------  -----------  ------
     1  OneTimeSecrecy(E).Real -> OneTimeSecrecy(E).Random  equivalence  ok

Proof Succeeded!
```

{: .note }
**CLI alternative.** From the `examples/joy/` directory:
```bash
proof_frog prove Proofs/Ch2/OTPSecure.proof
```

### Why this single hop works

After the engine inlines `OTP` into `OneTimeSecrecy(E).Real`, the game body becomes:

```
Key k <- BitString<lambda>;
Ciphertext c = k + m;
return c;
```

Because `k` is sampled uniformly from `BitString<lambda>` and used exactly once in `k + m`, the result `c` is also uniformly distributed over `BitString<lambda>` — independent of `m`. The engine recognizes this pattern (XOR with a uniform random bit string that is used once) as an equivalence transformation: it can replace `k <- BitString<lambda>; c = k + m;` with `c <- BitString<lambda>;`. After that replacement, the inlined `Real` game and the `Random` game are syntactically identical, and the hop is verified.

This is precisely the reasoning in Joy of Cryptography Example 2.5.4. The `deterministic` modifier on `Dec` that we declared in both the primitive and the scheme is what enables the engine to apply this kind of algebraic simplification without worrying about non-deterministic interference.

### What if it fails

**Cannot find imported file.** If you wrote a path with the wrong number of `../` steps or a misspelled file name, the engine reports that the file cannot be found. Count the directory levels carefully: `Proofs/Ch2/` is two levels below `examples/joy/`, so each path upward needs two `../` segments.

**Theorem mismatch.** If the theorem names a security property or scheme that was not imported or not declared in `let:`, the engine reports that the name is undefined. Check that `OneTimeSecrecy` is imported and that `E` is declared in `let:`.

**Proof Succeeded, but is incomplete.** If the first and last game steps use the same side of the theorem (both `Real`, or both `Random`), the engine accepts all individual hops but reports that the overall sequence is incomplete. This is the error you saw in Tutorial Part 1 when you commented out the second game step. Make sure the sequence starts at `Real` and ends at `Random` (or vice versa).

**A hop fails.** If the engine cannot verify a hop as an equivalence, it will report which step failed and show a diagnostic. For a proof as small as this one, a failing hop usually means the scheme file has a typo — for example, `k * m` instead of `k + m` in `Enc`. See `troubleshooting.md` for a deeper guide to diagnosing failing steps.

---

## What you did not learn yet

Congratulations — you have written a complete game-hopping proof from scratch. OTP is the simplest possible case: one primitive, one scheme, one game pair, one hop, no assumptions. Most real proofs are more complex. Three directions to explore next:

- **Reductions and the four-step pattern.** When a scheme relies on an underlying primitive (like a PRF or a hash function), the proof uses *reductions* to hop via an assumption rather than an equivalence. See the Chained Encryption worked example (coming soon).

- **The rest of the language.** Everything else FrogLang offers — tuples, maps, arrays, random functions, injective annotations, induction — is documented in the [Language Reference]({% link manual/language-reference/index.md %}).

- **What `prove` does under the hood.** The engine's canonicalization pipeline, the Z3/SymPy integration, and the equivalence-checking algorithm are described in Transformations (coming soon).
