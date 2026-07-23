---
title: Games
layout: default
parent: Language Reference
grand_parent: Manual
nav_order: 5
---

# Games
{: .no_toc }

A `.game` file defines a *security property* as a pair of games. The adversary interacts with one of the two games — without knowing which — and tries to distinguish them. If no efficient adversary can tell the two games apart (except with small probability), the scheme satisfies the security property. For a precise description of what "interact with a game" means at runtime — how `Initialize` is called, how oracle calls are sequenced, how state is managed — see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

- TOC
{:toc}

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
| `Real` / `Ideal` | Simulation-based security, correctness |

Pick names that make sense for the property in question, and consider how the security property is stated in the relevant literature. Neither side is "preferred": your game hopping proof can go from left to right or right to left; all that matters is that in a proof's `games:` list, the sequence must start on one side and end on the other.

### Distinguishing games versus win/lose and hidden bit games

Following the conventions of Joy of Cryptography, security properties in ProofFrog are always about distinguishing a pair of games. 

Conventional cryptographic literature naturally phrases some security properties as distinguishing a pair of games, but naturally phrases many security properties in terms of single games, where the adversary has to guess a hidden bit (e.g., a traditional formulation of IND-CPA security for encryption) or produce an output satisfying a condition (e.g., hash function collision resistance or unforgeability of a message authentication code). 

In order to model such properties in ProofFrog, they must be phrased in terms of distinguishing a pair of games. This may feel unnatural at times, but is usually doable. 

For example, [unforgeability of a MAC](https://github.com/ProofFrog/examples/blob/main/Games/MAC/SUFCMA.game) can be formulated with a game that provides a `GetTag(m)` oracle and a `CheckTag(m, t)` oracle.  In the real world, `CheckTag` returns the boolean result testing `t == E.MAC(k, m)`, whereas in the ideal world, `CheckTag` only accepts tags that were produced by `GetTag`. An adversary who produces a forgery (that was never queried to the `GetTag` oracle) will indeed be able to distinguish the two games.

---

## The `Game` blocks

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

`Initialize` can have a non-`Void` return type; the semantics of the execution model are that any value returned from `Initialize` is provided to the adversary. For further details on the semantics, see the [Execution Model]({% link manual/language-reference/execution-model.md %}) page.

State fields persist across oracle calls for the entire duration of a game execution. A value written in `Initialize` is visible in every subsequent oracle call; a value written by one oracle call is visible in later oracle calls. Each game execution starts with fresh state — there is no sharing of state between different executions.

`Initialize` is optional. If it is absent, state fields begin in an undefined state (unless their declaration includes an initializer expression). Games with no state fields at all typically need no `Initialize`.



---

## Oracle methods

Oracle methods are the interface the adversary uses to interact with the game. The adversary can call any oracle method in any order, any number of times, with adaptively chosen arguments. The adversary cannot directly inspect any state field; it can only observe the values that oracles return.

Return types follow the same rules as the [Basics]({% link manual/language-reference/basics.md %}) type system:

- Concrete types: `E.Ciphertext`, `BitString<G.lambda>`, `Bool`
- Optional types `T?`: the oracle may return `None` (e.g., a decryption oracle that rejects invalid ciphertexts returns `E.Message?`)
- Tuple types `[T1, T2]`: the oracle returns multiple values at once

Inside an oracle body, calls to scheme and primitive methods (e.g., `E.Enc(k, m)`) are the only way the game exercises the cryptographic construction being studied. The adversary never calls scheme methods directly — it goes through the game's oracles (though by Kerckhoff's principle, the adversary does know which scheme is being used).

{: .warning }
ProofFrog's convention, following Joy of Cryptography, allows all game oracles (other than `Initialize`) to be called arbitrarily many times by the adversary. The language does not natively support restricting an oracle to be called only once, though you can try to encode such a condition using counters. This means that security notions in ProofFrog are often inherently multi-instance. For an example, see the two different formulations of decisional Diffie–Hellman in the examples repository: [multi-challenge DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDHMultiChal.game) versus [single-challenge DDH](https://github.com/ProofFrog/examples/blob/main/Games/Group/DDH.game).

---

## `export as`

The last line of every `.game` file is an `export as` statement that assigns a name to the security property:

```prooffrog
export as INDOT;
```

This name is how the rest of the tool chain refers to the security property. In a proof file, after importing the game file, you write:

- `INDOT(E).Left` — the left game instantiated with scheme `E`
- `INDOT(E).Right` — the right game instantiated with `E`
- `INDOT(E).Adversary` — the type of adversary for this property

The `export as` name is also what appears in the proof's `theorem:` and `assume:` sections. The name must be a valid identifier; by convention it matches the file name (e.g., `INDOT.game` exports `INDOT`).

---

## Helper games as a special case

Not every `.game` file has to define a *cryptographic security property*. Game files can be used to capture facts that ProofFrog's engine is not able to reason about, such as mathematical properties, statistical claims, or additional program equivalence properties. The [`Games/Helpers/`](https://github.com/ProofFrog/examples/tree/main/Games/Helpers) directory contains several *helper games*.
 
Here are some helper games that capture mathematical facts:

- **`DistinctSampling`** ([`DistinctSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/DistinctSampling.game)): sampling uniformly from a set `S` with replacement is indistinguishable from sampling so that every returned value is distinct.
- **`NonzeroSampling`** ([`NonzeroSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/NonzeroSampling.game)): a uniform scalar and a uniform *nonzero* scalar are interchangeable.
- **`Regularity`** ([`Regularity.game`](https://github.com/ProofFrog/examples/blob/main/Games/Hash/Regularity.game)): applying a hash to a uniformly random input yields a uniform output.
- **`RandomTargetGuessing`** ([`RandomTargetGuessing.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/RandomTargetGuessing.game)): guessing a random target is no easier than guessing any fixed value.
- **`ROMProgramming`** ([`ROMProgramming.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/ROMProgramming.game)): facts about programming random oracles.
- **`ROFreshSampling`** ([`ROFreshSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/ROFreshSampling.game), plus numbered variants): a random oracle evaluated at a hidden, freshly sampled input looks uniform.

Helper games are structurally identical to security-property games — they are pairs of games with `export as` — but they appear in a proof's `assume:` block rather than the `theorem:` block. They can be assumed freely because they hold unconditionally or statistically, not by reduction to a computational hardness assumption. For the full catalog of available helper games and when to use each, see the [Canonicalization]({% link manual/canonicalization.md %}) page.

When a mathematical fact is encoded via a helper game and used to bridge a step in a game hopping proof, ProofFrog will still check that the claimed fact was applied properly in the game hopping proof (via an appropriate reduction). However, ProofFrog does not itself check the *validity* of the fact stated in a helper game. It is up to the proof author and the proof reader to confirm that.

Accounting for the *probabilistic loss* such a step incurs used to be a manual job too. Since version 0.6.0 it can be automated: a helper game may declare the loss in an `advantage <= ...;` clause, described next, and the engine will then carry that term into the [advantage bound]({% link manual/advantage-bounds.md %}) it synthesizes for any proof that hops through the game. What remains manual is establishing that the declared number is *right* — the engine trusts the clause exactly as it trusts the game.

---

## The advantage clause

A `.game` file may state how far apart its two games are, in an optional clause placed after both `Game` blocks and before `export as`:

```prooffrog
Game Replacement(Set S) { /* ... */ }
Game NoReplacement(Set S) { /* ... */ }

advantage <= count_Samp * (count_Samp - 1) / (2 * |S|);

export as DistinctSampling;
```

The grammar accepts `<=` or `<`; the two are read the same way, as an upper bound on any adversary's distinguishing advantage between the two games.

### What may appear in the expression

The right-hand side is numeric arithmetic — `+`, `-`, `*`, `/`, `^`, parentheses, and integer literals — over three kinds of name:

| Form | Meaning |
|---|---|
| a game parameter | One of the parameters shared by both `Game` blocks, e.g. the `Set S` above, or the `Int order` of `NonzeroSampling` |
| <code>&#124;T&#124;</code> | The cardinality of a type or set parameter |
| `count_<Oracle>` | The number of times the adversary calls `<Oracle>`, which must be a method of the games other than `Initialize` |

Both `Game` blocks in a file take the same parameter list and expose the same oracles, so there is no ambiguity about what these names refer to.

A game whose two sides are *identically* distributed declares `advantage <= 0;`. `ROMProgramming` does exactly that.

### What the checker does and does not do

{: .important }
An `advantage <= ...;` clause is a **declared, trusted fact — it is not proved**. The semantic checker validates only that the clause is well-formed: that every free name is a real game parameter or a real oracle, and that the arithmetic type-checks. Nothing verifies that the stated probability is correct. The clause therefore inherits exactly the trust status of the helper game it sits on, and a wrong clause produces a proof whose printed bound is too small while still reporting success.

Put a clause only on a game that encodes a *statistical* fact. A game encoding a genuine cryptographic hardness assumption — PRG security, DDH — should carry none: the whole point of reducing to such an assumption is that its advantage stays a symbolic term the reader can see in the final bound. Declaring a number there would silently assert that you had solved the underlying problem.

### How query counts are resolved

`count_Samp` is a placeholder for "the number of times the thing playing this game calls `Samp`". When a proof hops through the helper, the thing playing it is the proof's reduction, so the engine derives each count by statically counting the reduction's calls to that oracle, and reports the result in the *theorem* game's query counts. [Advantage Bounds]({% link manual/advantage-bounds.md %}#how-query-counts-are-resolved) describes that derivation in detail.

---

## Examples

### One-time secrecy

[`Games/SymEnc/INDOT.game`](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDOT.game)

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

export as INDOT;
```

The adversary submits two equal-length messages and receives an encryption of either the left or the right one. A fresh key is sampled per query, so no key reuse is implied. One-time secrecy holds if the adversary cannot tell which message was encrypted.

### CPA security (stateful game)

[`Games/SymEnc/INDCPA_MultiChal.game`](https://github.com/ProofFrog/examples/blob/main/Games/SymEnc/INDCPA_MultiChal.game)

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

export as INDCPA_MultiChal;
```

Like one-time secrecy, but the key is sampled once in `Initialize` and reused across all oracle calls. The state field `k` persists from one `Eavesdrop` call to the next, modelling the chosen-plaintext attack setting where the adversary may request many encryptions under the same key.

### A helper game

[`Games/Helpers/Probability/DistinctSampling.game`](https://github.com/ProofFrog/examples/blob/main/Games/Helpers/Probability/DistinctSampling.game)

```prooffrog
// Assumption: sampling values uniformly (with replacement) is statistically
// close to sampling them so that all returned values are DISTINCT.

Game Replacement(Set S) {
    S Samp() {
        S val <- S;
        return val;
    }
}

Game NoReplacement(Set S) {
    Set<S> seen;

    S Samp() {
        // <-uniq[seen] implicitly adds val to seen, so repeated calls
        // accumulate all prior outputs automatically.
        S val <-uniq[seen] S;
        return val;
    }
}

// Birthday bound: over count_Samp uniform draws from S, the two games differ
// only on a collision.
advantage <= count_Samp * (count_Samp - 1) / (2 * |S|);

export as DistinctSampling;
```

This game captures the fact that sampling with replacement (`Replacement`) is indistinguishable from sampling without replacement (`NoReplacement`) up to the birthday bound. It takes no cryptographic scheme as a parameter — it is a self-contained probabilistic fact. In a proof, it appears under `assume:` rather than `theorem:`.

Note that the exclusion set `seen` is a *field of `NoReplacement`*, not a parameter of `Samp`. That matters: an earlier version of this helper let the caller pass the exclusion set in, which made the assumption false as stated, since a reduction could pass an inflated set and distinguish the two games trivially. Keeping the bookkeeping internal means it can only ever contain the game's own prior outputs. Helper games are universally quantified over the reductions that compose with them, so their interfaces have to be safe against an adversarial caller, not merely against a well-intentioned one.
