---
title: Games
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 5
---

# Games

## Overview

A `.game` file defines a *security property* as a pair of games. The adversary interacts with one of the two games — without knowing which — and tries to distinguish them. If no efficient adversary can tell the two games apart (except with negligible probability), the scheme satisfies the security property. For a precise description of what "interact with a game" means at runtime — how `Initialize` is called, how oracle calls are sequenced, how state is managed — see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

---

## The two-game requirement

Every `.game` file must contain *exactly two* `Game` blocks. The two games must expose the same set of oracle methods with matching signatures: each method must appear in both games under the same name, with the same parameter types and the same return type. The engine rejects mismatched signatures during type-checking.

{: .important }
If the two games differ in any method name, parameter type, or return type, `proof_frog check` reports a type error. Both games must present an identical interface to the adversary — only the implementations may differ.

There is no enforced naming convention for the two sides. Common choices from the literature include:

| Convention | Typical use |
|---|---|
| `Left` / `Right` | General indistinguishability |
| `Real` / `Random` | PRG, PRF security |
| `Real` / `Fake` | Various simulation-based definitions |
| `Real` / `Ideal` | Composable security |

Pick the names that match how the security property is stated in the relevant literature. The proof engine treats whichever game appears first as the "left" side of the indistinguishability challenge and the second as the "right" side; in a proof's `games:` list, the sequence must start on one side and end on the other.

---

## The `Game` block

The general form of a single game is:

```prooffrog
Game SideName(parameters) {
    // Optional state fields (persist across oracle calls)
    Type fieldName;

    // Optional Initialize method (called once before any oracle)
    Void Initialize() {
        // set up state
    }

    // Oracle methods (called by the adversary)
    ReturnType Oracle1(ParamType param, ...) { ... }
    ReturnType Oracle2(ParamType param, ...) { ... }
}
```

A game may take any number of parameters. Parameters are typically primitive or scheme instances (e.g., `SymEnc E`, `PRG G`) or integers (e.g., `Int lambda`). The parameter list is the same for both games in the file.

Both `Initialize` and all oracle methods may use the full statement language described on the [Basics]({% link manual/language-reference/basics.md %}) page: variable declarations, random sampling, conditionals, loops, and return statements.

---

## `Initialize` and state fields

State fields are declared at the top of a game body, before any methods:

```prooffrog
Game Left(SymEnc E) {
    E.Key k;            // state field — persists across oracle calls
    Int callCount;      // another state field

    Void Initialize() {
        k = E.KeyGen(); // set up state before any oracle is called
        callCount = 0;
    }

    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        callCount = callCount + 1;
        return E.Enc(k, mL);
    }
}
```

`Initialize` is run exactly once, before the adversary makes any oracle call. It is the right place to perform setup that must happen once per execution (sampling a key, initializing a counter, populating a table).

State fields persist across oracle calls for the entire duration of a game execution. A value written in `Initialize` is visible in every subsequent oracle call; a value written by one oracle call is visible in later oracle calls. Each game execution starts with fresh state — there is no sharing of state between different executions.

`Initialize` is optional. If it is absent, state fields begin in an undefined state (unless their declaration includes an initializer expression). Games with no state fields at all typically need no `Initialize`.

For the precise semantics — including how `Initialize` interacts with phases, and the scoping rules for local variables vs. state fields — see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

---

## Oracle methods

Oracle methods are the interface the adversary uses to interact with the game. The adversary can call any oracle method in any order, any number of times, with adaptively chosen arguments. The adversary cannot directly inspect any state field; it can only observe the values that oracles return.

Return types follow the same rules as the [Basics]({% link manual/language-reference/basics.md %}) type system:

- Concrete types: `E.Ciphertext`, `BitString<G.lambda>`, `Bool`
- Optional types `T?`: the oracle may return `None` (e.g., a decryption oracle that rejects invalid ciphertexts returns `E.Message?`)
- Tuple types `[T1, T2]`: the oracle returns multiple values at once

Inside an oracle body, calls to scheme and primitive methods (e.g., `E.Enc(k, m)`) are the only way the game exercises the cryptographic construction being studied. The adversary never calls scheme methods directly — it goes through the game's oracles.

---

## `export as`

The last line of every `.game` file is an `export as` statement that assigns a name to the security property:

```prooffrog
export as OneTimeSecrecy;
```

This name is how the rest of the tool chain refers to the security property. In a proof file, after importing the game file, you write:

- `OneTimeSecrecy(E).Left` — the left game instantiated with scheme `E`
- `OneTimeSecrecy(E).Right` — the right game instantiated with `E`
- `OneTimeSecrecy(E).Adversary` — the type of adversary for this property

The `export as` name is also what appears in the proof's `theorem:` and `assume:` sections. The name must be a valid identifier; by convention it matches the file name (e.g., `OneTimeSecrecy.game` exports `OneTimeSecrecy`).

---

## Phases

Some security definitions involve a *staged interaction* in which the adversary alternates between different sets of oracles. The canonical example is CCA (chosen-ciphertext) security: in one stage the adversary may both encrypt and decrypt freely; in the next stage the adversary receives a challenge ciphertext and may no longer query decryption on that specific ciphertext.

FrogLang supports this with the `Phase` construct. A game may contain two or more `Phase` blocks instead of a flat list of oracles. Each phase has its own `Initialize` method and an `oracles:` list:

```prooffrog
Game Left(SymEnc E) {
    E.Key k;
    E.Ciphertext cStar;

    E.Ciphertext Enc(E.Message m) {
        return E.Enc(k, m);
    }

    E.Message? Dec(E.Ciphertext c) {
        return E.Dec(k, c);
    }

    E.Message? restrainedDec(E.Ciphertext c) {
        if (cStar == c) { return None; }
        return E.Dec(k, c);
    }

    Phase {
        Void Initialize() {
            k = E.KeyGen();
        }
        oracles: [Enc, Dec];
    }

    Phase {
        E.Ciphertext Initialize(E.Message mL, E.Message mR) {
            cStar = E.Enc(k, mL);
            return cStar;
        }
        oracles: [Enc, restrainedDec];
    }
}
```

Execution of a phased game proceeds as follows:

1. The first phase's `Initialize` is called automatically before the adversary does anything. In the example above this samples the key.
2. The adversary calls any oracle in the first phase's `oracles:` list — `Enc` and `Dec` — in any order, any number of times.
3. When the adversary is ready to move on, it calls the second phase's `Initialize` with its chosen arguments. In the example this submits the two challenge messages and receives back the challenge ciphertext. Calling a phase's `Initialize` is the signal that transitions to that phase.
4. The adversary then calls any oracle in the second phase's `oracles:` list — `Enc` and `restrainedDec`. The `Dec` oracle is no longer available; `restrainedDec` provides decryption but refuses to answer on the challenge ciphertext.

State fields (`k` and `cStar`) are shared across all phases. A value written in Phase 1 is readable in Phase 2, which is how `restrainedDec` can check `cStar == c`.

Oracle method bodies may be declared anywhere in the game body, outside any `Phase` block. Any method listed in a phase's `oracles:` list must have a body defined in the surrounding game. The two games in a CCA game file both use phases, and — per the two-game requirement — they must expose the same phase structure and oracle signatures.

A game that uses phases is still exported and referenced in exactly the same way as a flat game:

```prooffrog
export as CCA;
```

---

## Helper games as a special case

Not every `.game` file defines a cryptographic security property. The `examples/Games/Misc/` directory contains *helper games* that capture simple probabilistic facts — not assumptions about any cryptographic construction, but mathematical truths about sampling. Examples:

- **`UniqueSampling`** (`UniqueSampling.game`): sampling uniformly from a set `S` is indistinguishable from sampling from `S` with exclusion of a bookkeeping set (rejection sampling).
- **`HashOnUniform`** (`HashOnUniform.game`): applying a hash to a uniformly random input yields a uniform output.
- **`RandomTargetGuessing`** (`RandomTargetGuessing.game`): guessing a random target is no easier than guessing any fixed value.
- **`ROMProgramming`** (`ROMProgramming.game`): facts about programming random oracles.

Helper games are structurally identical to security-property games — they are pairs of games with `export as` — but they appear in a proof's `assume:` block rather than the `theorem:` block. They can be assumed freely because they hold unconditionally or statistically, not by reduction to a computational hardness assumption. For the full catalog of available helper games and when to use each, see the Transformations page.

---

## Examples

### One-time secrecy

Path: `examples/Games/SymEnc/OneTimeSecrecy.game`

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

The adversary submits two equal-length messages and receives an encryption of either the left or the right one. A fresh key is sampled per query, so no key reuse is implied. One-time secrecy holds if the adversary cannot tell which message was encrypted.

### CPA security (stateful game)

Path: `examples/Games/SymEnc/CPA.game`

```prooffrog
import '../../Primitives/SymEnc.primitive';

Game Left(SymEnc E) {
    E.Key k;
    Void Initialize() {
        k = E.KeyGen();
    }
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return E.Enc(k, mL);
    }
}

Game Right(SymEnc E) {
    E.Key k;
    Void Initialize() {
        k = E.KeyGen();
    }
    E.Ciphertext Eavesdrop(E.Message mL, E.Message mR) {
        return E.Enc(k, mR);
    }
}

export as CPA;
```

Like one-time secrecy, but the key is sampled once in `Initialize` and reused across all oracle calls. The state field `k` persists from one `Eavesdrop` call to the next, modelling the chosen-plaintext attack setting where the adversary may request many encryptions under the same key.

### A helper game

Path: `examples/Games/Misc/UniqueSampling.game`

```prooffrog
// Assumption: sampling uniformly from a set S is indistinguishable from
// sampling from S \ bookkeeping.

Game Replacement(Set S) {
    S Samp(Set<S> bookkeeping) {
        S val <- S;
        return val;
    }
}

Game NoReplacement(Set S) {
    S Samp(Set<S> bookkeeping) {
        S val <-uniq[bookkeeping] S;
        return val;
    }
}

export as UniqueSampling;
```

This game captures the fact that sampling with replacement (`Replacement`) is indistinguishable from sampling without replacement (`NoReplacement`) when the bookkeeping set is small relative to the sample space. It takes no cryptographic scheme as a parameter — it is a self-contained probabilistic fact. In a proof, it appears under `assume:` rather than `theorem:`.
